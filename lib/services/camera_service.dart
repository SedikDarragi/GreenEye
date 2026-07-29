import 'dart:io';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;
  CameraLensDirection _currentDirection = CameraLensDirection.back;
  CameraLensDirection get currentDirection => _currentDirection;

  Future<void> initialize({CameraLensDirection direction = CameraLensDirection.back}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) throw Exception("Camera permission required");

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception("No cameras available");

    _currentDirection = direction;
    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == _currentDirection,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.yuv420 
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
  }

  void dispose() {
    _controller?.dispose();
  }
}