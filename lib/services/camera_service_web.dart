import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

class CameraServiceWeb {
  html.MediaStream? _stream;
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvas;
  bool _isFrontCamera = false;
  bool _viewFactoryRegistered = false;
  bool _isInitializing = false;

  Future<void> initialize({bool frontCamera = false}) async {
    if (_isInitializing) return;
    _isInitializing = true;
    _isFrontCamera = frontCamera;

    try {
      // 1. Fully release previous stream first — browser needs time to free hardware
      await _stopCurrentStream();

      // 2. Reuse or create video element (registerViewFactory can only be called once)
      _videoElement ??= html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true');

      _canvas ??= html.CanvasElement(width: 640, height: 480);

      // Register view factory only once — re-registering throws
      if (!_viewFactoryRegistered) {
        ui_web.platformViewRegistry.registerViewFactory(
          'webcam-preview',
          (int viewId) => _videoElement!,
        );
        _viewFactoryRegistered = true;
      }

      // 3. Try ideal constraints first (not exact — avoids OverconstrainedError/NotReadableError)
      Map<String, dynamic> constraints = _buildConstraints(frontCamera);

      try {
        _stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      } on html.DomException catch (e) {
        // Handle NotReadableError: hardware locked (common after quick toggle / another tab holds camera)
        if (e.name == 'NotReadableError') {
          // Wait for OS to release hardware then retry once
          await Future<void>.delayed(const Duration(milliseconds: 600));
          // Ensure still stopped before retry
          await _stopCurrentStream();
          _stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
        } else if (e.name == 'OverconstrainedError' || e.name == 'NotFoundError') {
          // Fallback: try without facingMode / with minimal constraints
          final fallback = <String, dynamic>{
            'video': true,
            'audio': false,
          };
          _stream = await html.window.navigator.mediaDevices!.getUserMedia(fallback);
        } else {
          rethrow;
        }
      }

      _videoElement!.srcObject = _stream;
      // Ensure video metadata is loaded before play
      await _videoElement!.play().catchError((_) async {
        // Autoplay may be blocked without user gesture — wait a tick and retry after muted
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return _videoElement!.play();
      });

      // Wait until video has dimensions
      if (_videoElement!.videoWidth == 0) {
        await _videoElement!.onLoadedMetadata.first.timeout(
          const Duration(seconds: 3),
          onTimeout: () => html.Event('timeout'),
        );
      }
    } finally {
      _isInitializing = false;
    }
  }

  Map<String, dynamic> _buildConstraints(bool frontCamera) {
    return <String, dynamic>{
      'video': {
        'facingMode': {'ideal': frontCamera ? 'user' : 'environment'},
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
      'audio': false,
    };
  }

  Future<void> _stopCurrentStream() async {
    if (_stream != null) {
      for (final track in _stream!.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      _stream = null;
    }
    if (_videoElement?.srcObject != null) {
      _videoElement!.srcObject = null;
    }
    // Give browser time to release the device — critical to avoid NotReadableError on immediate re-acquire
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  html.VideoElement get videoElement => _videoElement!;
  bool get isFrontCamera => _isFrontCamera;
  bool get isInitialized => _stream != null && _videoElement != null;
  double get aspectRatio {
    final w = _videoElement?.videoWidth ?? 640;
    final h = _videoElement?.videoHeight ?? 480;
    if (h == 0) return 640 / 480;
    return w / h;
  }

  int get width => _videoElement?.videoWidth ?? 640;
  int get height => _videoElement?.videoHeight ?? 480;

  Uint8List captureFrame() {
    if (_videoElement == null || _canvas == null || _stream == null) return Uint8List(0);
    if (_videoElement!.videoWidth == 0 || _videoElement!.videoHeight == 0) return Uint8List(0);
    // Resize canvas to actual video size if needed
    final vw = _videoElement!.videoWidth;
    final vh = _videoElement!.videoHeight;
    if (_canvas!.width != vw || _canvas!.height != vh) {
      _canvas!.width = vw;
      _canvas!.height = vh;
    }
    final ctx = _canvas!.context2D;
    ctx.drawImage(_videoElement!, 0, 0);
    final imageData = ctx.getImageData(0, 0, vw, vh);
    // Canvas gives RGBA (4 bytes/px) — classifier expects RGB (3 bytes/px)
    final rgba = imageData.data;
    final rgb = Uint8List(vw * vh * 3);
    for (int i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
      rgb[j] = rgba[i];
      rgb[j + 1] = rgba[i + 1];
      rgb[j + 2] = rgba[i + 2];
    }
    return rgb;
  }

  Future<void> switchCamera() async {
    await initialize(frontCamera: !_isFrontCamera);
  }

  void dispose() {
    // Don't remove video element from DOM — keep it for reuse, just stop stream
    _stream?.getTracks().forEach((t) {
      try {
        t.stop();
      } catch (_) {}
    });
    _stream = null;
    if (_videoElement != null) {
      _videoElement!.srcObject = null;
      // Don't call _videoElement!.remove() — HtmlElementView still references it
      _videoElement!.pause();
    }
  }
}