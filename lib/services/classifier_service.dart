import 'dart:io';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_v2/tflite_v2.dart';

class ClassifierService {
  bool _isModelLoaded = false;
  bool _isProcessing = false;

  Future<void> loadModel() async {
    try {
      // Avoid redundant loading if already initialized
      if (_isModelLoaded) return;

      // Safety check: tflite_v2 only supports mobile platforms
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw Exception("TFLite is only supported on Android and iOS.");
      }

      // Sanity Check: Verify the asset actually contains data
      final ByteData data = await rootBundle.load("assets/models/plant_model.tflite");
      if (data.lengthInBytes == 0) {
        throw Exception(
          "The model file 'plant_model.tflite' is empty (0 bytes). "
          "Please replace it with a valid .tflite model file.");
      }

      await Tflite.loadModel(
        model: "assets/models/plant_model.tflite",
        labels: "assets/models/labels.txt",
        numThreads: 2,
        useGpuDelegate: false, // Set to false for better compatibility on budget devices
      );
      _isModelLoaded = true;
    } catch (e) {
      throw Exception("Failed to load TFLite model: $e");
    }
  }

  Future<List<dynamic>?> predict(CameraImage image, {int rotation = 90}) async {
    // Lock: prevent new inference if one is already in progress
    if (_isProcessing || !_isModelLoaded) return null;
    _isProcessing = true;

    try {
      var recognitions = await Tflite.runModelOnFrame(
        bytesList: image.planes.map((p) => p.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: rotation, 
        numResults: 2, // With only 3-5 classes, the top 2 are usually enough
        threshold: 0.45, // We can be stricter now because the model will be more confident
        asynch: true,
      );
      if (recognitions != null) print("AI Raw Output: $recognitions");
      _isProcessing = false;
      return recognitions;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  void dispose() {
    Tflite.close();
  }
}