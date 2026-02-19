import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class WebCameraOverlay extends StatefulWidget {
  const WebCameraOverlay({super.key});

  @override
  State<WebCameraOverlay> createState() => _WebCameraOverlayState();
}

class _WebCameraOverlayState extends State<WebCameraOverlay> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _error = "No cameras found on this device.");
        return;
      }

      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      debugPrint("Camera Init Error: $e");
      setState(() => _error = "Camera access denied or unavailable.");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          const Text("Live Scanner", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: _error != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        )
                      ],
                    )
                  : _isInit
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: CameraPreview(_controller!),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
                if (_isInit && _error == null)
                  GestureDetector(
                    onTap: () async {
                      try {
                        final image = await _controller!.takePicture();
                        final rawBytes = await image.readAsBytes();
                        // 🔥 WEB FIX: Clone immediately to prevent detachment
                        final clonedBytes = Uint8List.fromList(rawBytes);
                        
                        if (mounted) {
                          Navigator.pop(context, {'bytes': clonedBytes, 'name': image.name});
                        }
                      } catch (e) {
                        debugPrint("Capture Error: $e");
                      }
                    },
                    child: Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          height: 55,
                          width: 55,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 48), // Spacer for balance
              ],
            ),
          ),
        ],
      ),
    );
  }
}
