import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart' show CameraLensDirection, FlashMode, CameraPreview;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/camera_service.dart'
    if (dart.library.html) '../services/camera_service_stub.dart'
    hide CameraServiceWeb;
import '../services/classifier_service.dart';
import '../models/plant_disease.dart';

import '../services/camera_service_web.dart'
    if (dart.library.io) '../services/camera_service_stub.dart'
    show CameraServiceWeb;

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ClassifierService _classifierService = ClassifierService();
  late final CameraService _cameraService;
  late final CameraServiceWeb? _cameraServiceWeb;

  PlantDisease? _currentDisease;
  bool _isAnalyzing = false;
  bool _isSheetExpanded = false;
  DateTime? _lastInferenceTime;
  bool _isFlashOn = false;
  Timer? _webTimer;

  String? _pendingLabel;
  final List<String> _labelHistory = [];
  double _currentConfidence = 0.0;
  static const int _requiredStabilityFrames = 15;

  String? _cameraError;
  bool _isInitializing = true;
  bool _isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _cameraServiceWeb = CameraServiceWeb();
    } else {
      _cameraService = CameraService();
      _cameraServiceWeb = null;
    }
    _setupApp();
  }

  Future<void> _setupApp() async {
    try {
      setState(() {
        _isInitializing = true;
        _cameraError = null;
      });
      await _classifierService.loadModel();
      if (kIsWeb) {
        await _cameraServiceWeb!.initialize();
      } else {
        await _cameraService.initialize();
      }
      _startAnalysis();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint("Setup error: $e");
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _cameraError = _friendlyCameraError(e);
        });
      }
    }
  }

  String _friendlyCameraError(Object e) {
    final msg = e.toString();
    if (msg.contains('NotReadableError') || msg.contains('Failed to allocate videosource')) {
      return 'Camera is busy. Another app or browser tab may be using it. Close other tabs/apps that use the camera and tap Retry.';
    }
    if (msg.contains('NotAllowedError') || msg.contains('Permission denied') || msg.contains('NotAllowed')) {
      return 'Camera permission denied. Please allow camera access in your browser (lock icon → Site settings → Allow camera) and tap Retry.';
    }
    if (msg.contains('NotFoundError') || msg.contains('Requested device not found')) {
      return 'No camera found. Connect a camera and tap Retry.';
    }
    if (msg.contains('OverconstrainedError')) {
      return 'Camera does not support the requested mode. Trying fallback — tap Retry.';
    }
    return 'Failed to start camera: $e';
  }

  void _startAnalysis() {
    if (kIsWeb) {
      _webTimer?.cancel();
      _webTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
        if (_isAnalyzing || _isSheetExpanded || !mounted) return;

        final bytes = _cameraServiceWeb!.captureFrame();
        if (bytes.isEmpty) return;

        _isAnalyzing = true;
        _lastInferenceTime = DateTime.now();

        final results = await _classifierService.predictFromBytes(
          bytes,
          _cameraServiceWeb!.width,
          _cameraServiceWeb!.height,
        );

        _processResults(results);
        _isAnalyzing = false;
      });
    } else {
      _cameraService.controller?.startImageStream((image) async {
        if (_isAnalyzing || _isSheetExpanded) return;

        final now = DateTime.now();
        if (_lastInferenceTime != null &&
            now.difference(_lastInferenceTime!).inMilliseconds < 300) return;

        _isAnalyzing = true;

        final rotation = _cameraService.currentDirection == CameraLensDirection.back ? 90 : 270;

        final results = await _classifierService.predict(image, rotation: rotation);

        _processResults(results);
        _isAnalyzing = false;
      });
    }
  }

  void _processResults(List<Map<String, dynamic>>? results) {
    if (results == null || results.isEmpty || !mounted) return;

    final topResult = results[0];
    final String label = topResult['label'];
    final double confidence = topResult['confidence'];

    _labelHistory.add(label);
    if (_labelHistory.length > _requiredStabilityFrames) {
      _labelHistory.removeAt(0);
    }

    final counts = <String, int>{};
    for (var l in _labelHistory) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    final mostFrequentLabel =
        counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final frequency = counts[mostFrequentLabel] ?? 0;

    if (mounted) _currentConfidence = confidence;

    if (frequency >= (_requiredStabilityFrames * 0.7).toInt()) {
      if (confidence >= 0.80 && !mostFrequentLabel.toLowerCase().contains('unko')) {
        if (_currentDisease == null || _pendingLabel != mostFrequentLabel) {
          _pendingLabel = mostFrequentLabel;
          setState(() {
            _currentDisease = PlantDisease.getInfo(mostFrequentLabel);
          });
        }
      } else if (confidence < 0.60 || mostFrequentLabel.toLowerCase().contains('unko')) {
        if (_currentDisease != null) {
          setState(() {
            _currentDisease = null;
            _pendingLabel = null;
            _isSheetExpanded = false;
          });
        }
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (kIsWeb) return;

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      _isFlashOn = !_isFlashOn;
      await controller.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error toggling flash: $e");
      _isFlashOn = false;
    }
  }

  Future<void> _toggleCamera() async {
    if (_isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);
    try {
      if (kIsWeb) {
        // Pause analysis while switching to avoid concurrent capture
        _webTimer?.cancel();
        _webTimer = null;
        try {
          await _cameraServiceWeb!.initialize(
            frontCamera: !_cameraServiceWeb!.isFrontCamera,
          );
          setState(() => _cameraError = null);
        } catch (e) {
          debugPrint("Switch camera error: $e");
          if (mounted) setState(() => _cameraError = _friendlyCameraError(e));
          return;
        } finally {
          // Restart analysis only if widget still mounted and no fatal error
          if (mounted && _cameraError == null) _startAnalysis();
        }
        if (mounted) setState(() {});
      } else {
        _isFlashOn = false;
        final newDirection = _cameraService.currentDirection == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;

        await _cameraService.controller?.stopImageStream();
        _cameraService.dispose();
        await _cameraService.initialize(direction: newDirection);
        _startAnalysis();

        if (mounted) setState(() {});
      }
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
    }
  }

  @override
  void dispose() {
    _webTimer?.cancel();
    if (kIsWeb) {
      _cameraServiceWeb?.dispose();
    } else {
      _cameraService.dispose();
    }
    _classifierService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = kIsWeb
        ? _cameraServiceWeb!.isInitialized
        : (_cameraService.controller != null &&
            _cameraService.controller!.value.isInitialized);

    if (_cameraError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 56, color: Colors.white54),
                const SizedBox(height: 16),
                const Text(
                  'Camera unavailable',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _cameraError = null);
                    _setupApp();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Tip: If it still says “Failed to allocate videosource”, close other tabs using the camera (Meet, Zoom, etc.) and ensure the site is on HTTPS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!isInitialized || _isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildCameraPreview(),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _currentDisease != null ? Colors.greenAccent : Colors.white38,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          if (!kIsWeb)
            Positioned(
              top: 50,
              left: 20,
              child: FloatingActionButton(
                heroTag: 'flash_button',
                mini: true,
                backgroundColor: Colors.black54,
                onPressed: _toggleFlash,
                child: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
              ),
            ),

          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.black54,
              onPressed: _isSwitchingCamera ? null : _toggleCamera,
              child: _isSwitchingCamera
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
          ),

          if (_currentDisease != null)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                final isExpanded = notification.extent > 0.15;
                if (isExpanded != _isSheetExpanded) {
                  setState(() {
                    _isSheetExpanded = isExpanded;
                  });
                }
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.12,
                minChildSize: 0.1,
                maxChildSize: 0.9,
                snap: true,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.95),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(
                        color: _isSheetExpanded
                            ? Colors.greenAccent
                            : Colors.greenAccent.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: _buildDetailedInfo(scrollController),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (kIsWeb) {
      return const SizedBox.expand(
        child: HtmlElementView(viewType: 'webcam-preview'),
      );
    }

    final controller = _cameraService.controller!;
    return Transform(
      alignment: Alignment.center,
      transform: _cameraService.currentDirection == CameraLensDirection.front
          ? Matrix4.rotationY(math.pi)
          : Matrix4.identity(),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1,
            height: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedInfo(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _currentDisease!.name,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                border: Border.all(color: Colors.greenAccent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${(_currentConfidence * 100).toInt()}%",
                style: const TextStyle(
                    color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        if (_currentDisease!.imagePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                _currentDisease!.imagePath!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.white10,
                  child:
                      const Icon(Icons.image_not_supported, color: Colors.white24),
                ),
              ),
            ),
          ),

        if (!_isSheetExpanded)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text("Swipe up for details and treatments",
                style: TextStyle(color: Colors.white24, fontSize: 12)),
          ),

        const SizedBox(height: 20),

        Text(
          _currentDisease!.description,
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
        ),
        const Divider(color: Colors.white24, height: 24),
        const Text(
          "RECOMMENDED TREATMENT:",
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._currentDisease!.treatments.map((treatment) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(color: Colors.greenAccent)),
                  Expanded(
                    child: Text(
                      treatment,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}