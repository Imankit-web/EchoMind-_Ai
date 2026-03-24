import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';

class BlinkService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Required for eye open probability
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isDisposed = false;
  int _consecutiveBlinkFrames = 0;
  DateTime? _lastBlinkTime;
  
  // Blink Counting System
  int _blinkCount = 0;
  Timer? _windowTimer;
  final int _windowDurationMs = 2500; // 2.5 second window
  final int _cooldownMs = 800; // 800ms cooldown

  final _blinkStreamController = StreamController<int>.broadcast();
  Stream<int> get blinkStream => _blinkStreamController.stream;

  final _countStreamController = StreamController<int>.broadcast();
  Stream<int> get countStream => _countStreamController.stream;

  final _selectionStreamController = StreamController<int>.broadcast();
  Stream<int> get selectionStream => _selectionStreamController.stream;

  final _statusStreamController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusStreamController.stream;

  Future<void> processImage(InputImage inputImage) async {
    if (_isDisposed) return;

    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) return;

    final face = faces.first;
    
    if (face.leftEyeOpenProbability == null || face.rightEyeOpenProbability == null) {
      _statusStreamController.add("Align Properly");
      return;
    }

    if ((face.headEulerAngleY?.abs() ?? 100) > 15 || (face.headEulerAngleZ?.abs() ?? 100) > 15) {
      _statusStreamController.add("Align Properly");
      return;
    }

    _statusStreamController.add("Face Detected");

    final leftEyeOpenProb = face.leftEyeOpenProbability!;
    final rightEyeOpenProb = face.rightEyeOpenProbability!;

    // Detect blink: Both eyes closed (< 0.3)
    if (leftEyeOpenProb < 0.3 && rightEyeOpenProb < 0.3) {
      _consecutiveBlinkFrames++;
    } else {
      // If we had at least 2 consecutive frames of closure, it's a blink
      if (_consecutiveBlinkFrames >= 2) {
        _handleBlinkDetected();
      }
      _consecutiveBlinkFrames = 0;
    }
  }

  void _handleBlinkDetected() {
    final now = DateTime.now();
    
    // Cooldown check
    if (_lastBlinkTime != null && now.difference(_lastBlinkTime!).inMilliseconds < _cooldownMs) {
      return;
    }

    _lastBlinkTime = now;
    _blinkCount++;
    _statusStreamController.add("Blink Detected");
    
    // Notify about the single blink (for pulse animation)
    _blinkStreamController.add(_blinkCount);

    // Reset or start the window timer
    _windowTimer?.cancel();
    _windowTimer = Timer(Duration(milliseconds: _windowDurationMs), () {
      if (_blinkCount > 0) {
        // Map: 1 blink -> 0, 2 blinks -> 1, 3 blinks -> 2 (capped at 3)
        final selectionIndex = (_blinkCount - 1).clamp(0, 2);
        _selectionStreamController.add(selectionIndex);
        _blinkCount = 0;
        _countStreamController.add(0);
      }
    });

    _countStreamController.add(_blinkCount);
  }

  void simulateBlink() {
    _handleBlinkDetected();
  }

  void resetCount() {
    _blinkCount = 0;
    _countStreamController.add(0);
    _windowTimer?.cancel();
  }

  void dispose() {
    _isDisposed = true;
    _faceDetector.close();
    _windowTimer?.cancel();
    _blinkStreamController.close();
    _countStreamController.close();
    _selectionStreamController.close();
    _statusStreamController.close();
  }

  // Helper to convert CameraImage to InputImage
  static InputImage? convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Determine the format based on available image format group
      InputImageFormat format = InputImageFormat.nv21;
      if (image.format.group == ImageFormatGroup.yuv420) {
        format = InputImageFormat.yuv420;
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        format = InputImageFormat.bgra8888;
      }

      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationFromDegrees(camera.sensorOrientation),
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      return null;
    }
  }

  static InputImageRotation _rotationFromDegrees(int degrees) {
    switch (degrees) {
      case 0: return InputImageRotation.rotation0deg;
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }
}
