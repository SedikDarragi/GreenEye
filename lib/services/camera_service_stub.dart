import 'dart:typed_data';
import 'package:camera/camera.dart';

class CameraService {
  CameraService() {
    throw UnsupportedError('CameraService is not supported on this platform.');
  }
  CameraController? get controller => null;
  CameraLensDirection get currentDirection => CameraLensDirection.back;
  Future<void> initialize({CameraLensDirection direction = CameraLensDirection.back}) async {}
  void dispose() {}
}

class CameraServiceWeb {
  CameraServiceWeb() {
    throw UnsupportedError('CameraServiceWeb is not supported on this platform.');
  }
  bool get isInitialized => false;
  bool get isFrontCamera => false;
  double get aspectRatio => 1.0;
  int get width => 0;
  int get height => 0;
  Uint8List captureFrame() => Uint8List(0);
  Future<void> initialize({bool frontCamera = false}) async {}
  Future<void> switchCamera() async {}
  void dispose() {}
}