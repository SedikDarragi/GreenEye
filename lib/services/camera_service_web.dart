import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

class CameraServiceWeb {
  html.MediaStream? _stream;
  late html.VideoElement _videoElement;
  late html.CanvasElement _canvas;
  bool _isFrontCamera = false;

  Future<void> initialize({bool frontCamera = false}) async {
    _isFrontCamera = frontCamera;

    _videoElement = html.VideoElement()
      ..width = 640
      ..height = 480
      ..autoplay = true;

    _canvas = html.CanvasElement(width: 640, height: 480);

    final constraints = <String, dynamic>{
      'video': {
        'facingMode': frontCamera ? 'user' : 'environment',
        'width': 640,
        'height': 480,
      },
      'audio': false,
    };

    _stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
    _videoElement.srcObject = _stream;
    await _videoElement.play();

    ui_web.platformViewRegistry.registerViewFactory(
      'webcam-preview',
      (int viewId) => _videoElement,
    );
  }

  html.VideoElement get videoElement => _videoElement;
  bool get isFrontCamera => _isFrontCamera;
  bool get isInitialized => _stream != null;
  double get aspectRatio => _videoElement.width! / _videoElement.height!;

  int get width => _videoElement.width!;
  int get height => _videoElement.height!;

  Uint8List captureFrame() {
    final ctx = _canvas.context2D;
    ctx.drawImage(_videoElement, 0, 0);
    final imageData = ctx.getImageData(0, 0, _videoElement.width!, _videoElement.height!);
    return imageData.data as Uint8List;
  }

  Future<void> switchCamera() async {
    _stream?.getTracks().forEach((t) => t.stop());
    _isFrontCamera = !_isFrontCamera;
    await initialize(frontCamera: _isFrontCamera);
  }

  void dispose() {
    _stream?.getTracks().forEach((t) => t.stop());
    _videoElement.remove();
  }
}