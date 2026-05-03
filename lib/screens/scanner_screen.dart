import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../services/classifier_service.dart';
import '../models/plant_disease.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final CameraService _cameraService = CameraService();
  final ClassifierService _classifierService = ClassifierService();
  
  PlantDisease? _currentDisease;
  bool _isAnalyzing = false;
  bool _isSheetExpanded = false;
  DateTime? _lastInferenceTime;
  bool _isFlashOn = false;

  // Stability Buffer Variables
  String? _pendingLabel;
  final List<String> _labelHistory = []; // Buffer for voting system
  double _currentConfidence = 0.0;
  int _consecutiveFrames = 0;
  // Increased to roughly 1.5 - 2 seconds of consistent detection (at ~30fps)
  static const int _requiredStabilityFrames = 15; 

  @override
  void initState() {
    super.initState();
    _setupApp();
  }

  Future<void> _setupApp() async {
    try {
      await _classifierService.loadModel();
      await _cameraService.initialize();
      _startAnalysis();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Setup error: $e");
    }
  }

  void _startAnalysis() {
    _cameraService.controller?.startImageStream((image) async {
      if (_isAnalyzing || _isSheetExpanded) return; // Pause AI when reading info
      
      final now = DateTime.now();
      // Only run inference every 300ms to prevent UI thread starvation
      if (_lastInferenceTime != null && 
          now.difference(_lastInferenceTime!).inMilliseconds < 300) return;
      
      _isAnalyzing = true;

      // Determine rotation based on lens direction
      // Back camera usually needs 90, Front usually needs 270 on Android
      final rotation = _cameraService.currentDirection == CameraLensDirection.back ? 90 : 270;

      final results = await _classifierService.predict(image, rotation: rotation);

      if (results != null && results.isNotEmpty && mounted) {
        _lastInferenceTime = now;
        final topResult = results[0];
        final String label = topResult['label'];
        final double confidence = topResult['confidence'];

        // Add to history for a "Voting" system to handle jitter
        _labelHistory.add(label);
        if (_labelHistory.length > _requiredStabilityFrames) {
          _labelHistory.removeAt(0);
        }

        // Count occurrences of the most frequent label in history
        final counts = <String, int>{};
        for (var l in _labelHistory) { counts[l] = (counts[l] ?? 0) + 1; }
        final mostFrequentLabel = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        final frequency = counts[mostFrequentLabel] ?? 0;

        if (mounted) _currentConfidence = confidence;

        // Update UI if the most frequent label is stable enough
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
      _isAnalyzing = false;
    });
  }

  Future<void> _toggleFlash() async {
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
      _isFlashOn = false; // Reset state if hardware doesn't support it
    }
  }

  Future<void> _toggleCamera() async {
    _isFlashOn = false; // Reset flash state when switching cameras
    final newDirection = _cameraService.currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    // 1. Stop the current stream
    await _cameraService.controller?.stopImageStream();
    // 2. Dispose of the current controller
    _cameraService.dispose();
    // 3. Re-initialize with the new lens
    await _cameraService.initialize(direction: newDirection);
    // 4. Restart the AI analysis
    _startAnalysis();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _classifierService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Mirror the preview if using the front camera for a natural feel
          Transform(
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
          ),

          // Viewfinder Overlay: Helps user center the leaf for better focal accuracy
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
              child: null,
            ),
          ),
          
          // Flash Toggle Button
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

          // Switch Camera Button
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.black54,
              onPressed: _toggleCamera,
              child: const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
          ),

          // Draggable Bottom Sheet for Plant Information
          if (_currentDisease != null)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // Pause analysis if user scrolls up beyond the collapsed state
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
                      border: Border.all(color: _isSheetExpanded ? Colors.greenAccent : Colors.greenAccent.withOpacity(0.3), width: 1),
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

  Widget _buildDetailedInfo(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Grabber Handle
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
        
        // Summary Header (Visible in collapsed state)
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
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
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
                  child: const Icon(Icons.image_not_supported, color: Colors.white24),
                ),
              ),
            ),
          ),

        if (!_isSheetExpanded)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text("Swipe up for details and treatments", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ),

        const SizedBox(height: 20),
        
        // Expanded Content
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

  // Cleanup of unused builder methods from previous iterations
}