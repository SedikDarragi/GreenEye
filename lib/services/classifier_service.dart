import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_litert/flutter_litert.dart';

class ClassifierService {
  Interpreter? _interpreter;
  int _modelInputSize = 224;
  bool _isProcessing = false;
  List<String> _labels = [];

  Future<void> loadModel() async {
    try {
      if (_interpreter != null) return;

      await initializeWeb();

      final ByteData data = await rootBundle.load("assets/models/plant_model.tflite");
      if (data.lengthInBytes == 0) {
        throw Exception("The model file 'plant_model.tflite' is empty.");
      }

      _interpreter = await Interpreter.fromAsset("assets/models/plant_model.tflite");

      final inputShape = _interpreter!.getInputTensor(0).shape;
      if (inputShape.length >= 3) {
        _modelInputSize = inputShape[1] > inputShape[2] ? inputShape[1] : inputShape[2];
      }

      await _loadLabels();
    } catch (e) {
      throw Exception("Failed to load TFLite model: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      _labels = [];
    }
  }

  Future<List<Map<String, dynamic>>?> predict(
    CameraImage image, {
    int rotation = 90,
  }) async {
    if (_isProcessing || _interpreter == null) return null;
    _isProcessing = true;

    try {
      final rgb = _convertToRgb(image);
      final resized = _resizeAndRotate(rgb, image.width, image.height, rotation);
      final input = _normalize(resized);

      final outputSize = _interpreter!.getOutputTensor(0).shape.fold(1, (a, b) => a * b);
      var output = List<double>.filled(outputSize, 0);
      _interpreter!.run(input, output);

      _isProcessing = false;
      final results = _parseOutput(output);
      return results;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> predictFromBytes(
    Uint8List rgb,
    int width,
    int height,
  ) async {
    if (_isProcessing || _interpreter == null) return null;
    _isProcessing = true;

    try {
      final resized = _resizeBilinear(rgb, width, height, _modelInputSize, _modelInputSize);
      final input = _normalize(resized);

      final outputSize = _interpreter!.getOutputTensor(0).shape.fold(1, (a, b) => a * b);
      var output = List<double>.filled(outputSize, 0);
      _interpreter!.run(input, output);

      _isProcessing = false;
      return _parseOutput(output);
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  Uint8List _convertToRgb(CameraImage image) {
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return _bgraToRgb(image);
    }
    return _yuv420ToRgb(image);
  }

  Uint8List _bgraToRgb(CameraImage image) {
    final bytes = image.planes[0].bytes;
    final rgb = Uint8List(image.width * image.height * 3);
    for (int i = 0, j = 0; i + 3 < bytes.length; i += 4, j += 3) {
      rgb[j] = bytes[i + 2];
      rgb[j + 1] = bytes[i + 1];
      rgb[j + 2] = bytes[i];
    }
    return rgb;
  }

  Uint8List _yuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final rgb = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * image.planes[0].bytesPerRow + x;
        final yValue = image.planes[0].bytes[yIndex];

        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
        final u = image.planes[1].bytes[uvIndex] - 128;
        final v = image.planes[2].bytes[uvIndex] - 128;

        int r = (yValue + 1.402 * v).round();
        int g = (yValue - 0.344 * u - 0.714 * v).round();
        int b = (yValue + 1.772 * u).round();

        final i = (y * width + x) * 3;
        rgb[i] = r.clamp(0, 255);
        rgb[i + 1] = g.clamp(0, 255);
        rgb[i + 2] = b.clamp(0, 255);
      }
    }
    return rgb;
  }

  Uint8List _resizeAndRotate(Uint8List rgb, int w, int h, int rotation) {
    Uint8List rotated;
    int rw, rh;

    if (rotation == 90) {
      rotated = Uint8List(w * h * 3);
      rh = w; rw = h;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final src = (y * w + x) * 3;
          final dst = (x * w + (w - 1 - y)) * 3;
          rotated[dst] = rgb[src];
          rotated[dst + 1] = rgb[src + 1];
          rotated[dst + 2] = rgb[src + 2];
        }
      }
    } else if (rotation == 270) {
      rotated = Uint8List(w * h * 3);
      rh = w; rw = h;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final src = (y * w + x) * 3;
          final dst = ((h - 1 - x) * w + y) * 3;
          rotated[dst] = rgb[src];
          rotated[dst + 1] = rgb[src + 1];
          rotated[dst + 2] = rgb[src + 2];
        }
      }
    } else {
      rotated = rgb;
      rw = w; rh = h;
    }

    return _resizeBilinear(rotated, rw, rh, _modelInputSize, _modelInputSize);
  }

  Uint8List _resizeBilinear(Uint8List src, int srcW, int srcH, int dstW, int dstH) {
    final dst = Uint8List(dstW * dstH * 3);
    final xRatio = srcW / dstW;
    final yRatio = srcH / dstH;

    for (int dy = 0; dy < dstH; dy++) {
      for (int dx = 0; dx < dstW; dx++) {
        final sx = dx * xRatio;
        final sy = dy * yRatio;

        final x1 = sx.floor().clamp(0, srcW - 1);
        final y1 = sy.floor().clamp(0, srcH - 1);
        final x2 = (x1 + 1).clamp(0, srcW - 1);
        final y2 = (y1 + 1).clamp(0, srcH - 1);

        final xFrac = sx - x1;
        final yFrac = sy - y1;

        for (int c = 0; c < 3; c++) {
          final p11 = src[(y1 * srcW + x1) * 3 + c];
          final p21 = src[(y1 * srcW + x2) * 3 + c];
          final p12 = src[(y2 * srcW + x1) * 3 + c];
          final p22 = src[(y2 * srcW + x2) * 3 + c];

          final top = p11 + (p21 - p11) * xFrac;
          final bottom = p12 + (p22 - p12) * xFrac;
          final val = (top + (bottom - top) * yFrac).round().clamp(0, 255);

          dst[(dy * dstW + dx) * 3 + c] = val;
        }
      }
    }
    return dst;
  }

  Float32List _normalize(Uint8List rgb) {
    final input = Float32List(1 * _modelInputSize * _modelInputSize * 3);
    for (int i = 0; i < rgb.length; i++) {
      input[i] = (rgb[i] - 127.5) / 127.5;
    }
    return input;
  }

  List<Map<String, dynamic>> _parseOutput(List<double> output) {
    if (output.isEmpty) return [];

    final indexed = <MapEntry<int, double>>[];
    for (int i = 0; i < output.length; i++) {
      if (output[i] >= 0.45) {
        indexed.add(MapEntry(i, output[i]));
      }
    }

    indexed.sort((a, b) => b.value.compareTo(a.value));
    final top = indexed.take(2);

    return top.map((e) => <String, dynamic>{
      'index': e.key,
      'label': e.key < _labels.length ? _labels[e.key] : 'unknown_${e.key}',
      'confidence': e.value,
    }).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}