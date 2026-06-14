import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

enum RenderMode { skeleton, glove }

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: HandTrackingHome(cameras: cameras),
    );
  }
}

class HandTrackingHome extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HandTrackingHome({super.key, required this.cameras});

  @override
  State<HandTrackingHome> createState() => _HandTrackingHomeState();
}

class _HandTrackingHomeState extends State<HandTrackingHome> {
  CameraController? _controller;
  bool _isBusy = false;
  List<Hand> _hands = [];
  HandLandmarkerPlugin? _landmarkerPlugin;
  RenderMode _currentMode = RenderMode.skeleton;
  late final WebViewController _webController;
  bool _isEngineReady = false;
  bool _isModelLoaded = false;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWeb();
    _initializeLandmarker();
  }

  void _initializeWeb() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'ENGINE_READY') {
            setState(() => _isEngineReady = true);
            _pushModelToWeb();
          } else if (message.message == 'MODEL_READY') {
            setState(() => _isModelLoaded = true);
          } else if (message.message.startsWith('ERROR')) {
            debugPrint("JS Error: ${message.message}");
          }
        },
      )
      ..loadFlutterAsset('assets/models/index.html');
  }

  Future<void> _pushModelToWeb() async {
    try {
      final base64Model = await rootBundle.loadString('assets/models/gauntlet_base64.txt');
      await _webController.runJavaScript('window.loadModelBase64("$base64Model")');
    } catch (e) {
      debugPrint("Error pushing model: $e");
    }
  }

  void _initializeLandmarker() {
    _landmarkerPlugin = HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );
  }

  void _initializeCamera() async {
    if (_isCameraInitialized) return;
    
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller?.initialize();
    _controller?.startImageStream(_processCameraImage);
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  List<Map<String, double>>? _previousLandmarks;
  final double _smoothingFactor = 0.2; // Lower = smoother but more lag

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || _landmarkerPlugin == null || !mounted || !_isCameraInitialized) return;
    _isBusy = true;

    try {
      final sensorOrientation = widget.cameras[0].sensorOrientation;
      final hands = _landmarkerPlugin!.detect(image, sensorOrientation);
      
      if (mounted) {
        setState(() {
          _hands = hands;
        });

        if (_currentMode == RenderMode.glove && _hands.isNotEmpty) {
          final rawLandmarks = _hands.first.landmarks;
          final orientation = MediaQuery.of(context).orientation;
          
          List<Map<String, double>> currentLandmarks = [];
          
          for (var l in rawLandmarks) {
            double x, y;
            if (orientation == Orientation.portrait) {
              // Match HandPainter logic: x = 1-y, y = x
              x = 1 - l.y;
              y = l.x;
            } else {
              x = l.x;
              y = l.y;
            }
            currentLandmarks.add({'x': x, 'y': y, 'z': l.z});
          }

          // Apply Low-Pass Filter (Smoothing)
          if (_previousLandmarks != null && _previousLandmarks!.length == currentLandmarks.length) {
            for (int i = 0; i < currentLandmarks.length; i++) {
              currentLandmarks[i]['x'] = _previousLandmarks![i]['x']! + 
                  (currentLandmarks[i]['x']! - _previousLandmarks![i]['x']!) * _smoothingFactor;
              currentLandmarks[i]['y'] = _previousLandmarks![i]['y']! + 
                  (currentLandmarks[i]['y']! - _previousLandmarks![i]['y']!) * _smoothingFactor;
              currentLandmarks[i]['z'] = _previousLandmarks![i]['z']! + 
                  (currentLandmarks[i]['z']! - _previousLandmarks![i]['z']!) * _smoothingFactor;
            }
          }
          
          _previousLandmarks = currentLandmarks;
          final jsonStr = jsonEncode(currentLandmarks);
          _webController.runJavaScript('window.updateHand(`${jsonStr.replaceAll('`', '\\`')}`)');
        }
      }
    } catch (e) {
      debugPrint("Error detecting hands: $e");
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _landmarkerPlugin?.dispose();
    super.dispose();
  }

  Widget _buildModeButton(String label, RenderMode mode) {
    bool isSelected = _currentMode == mode;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.greenAccent : Colors.grey[800],
        foregroundColor: isSelected ? Colors.black : Colors.white,
      ),
      onPressed: () => setState(() => _currentMode = mode),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 20),
              Text(
                !_isEngineReady ? "Initializing 3D Engine..." : "Loading 3D Gauntlet...",
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 30),
              if (_isModelLoaded)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: _initializeCamera,
                  child: const Text("START AR GLOVE", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                const Text("(Please wait for model to load)", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("AR-Glove Live Demo")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final previewSize = _controller!.value.previewSize!;
          final previewRatio = previewSize.height / previewSize.width;
          
          double drawWidth, drawHeight;
          if (size.width / size.height > previewRatio) {
            drawHeight = size.height;
            drawWidth = size.height * previewRatio;
          } else {
            drawWidth = size.width;
            drawHeight = size.width / previewRatio;
          }

          return Stack(
            children: [
              Center(
                child: SizedBox(
                  width: drawWidth,
                  height: drawHeight,
                  child: CameraPreview(_controller!),
                ),
              ),
              Center(
                child: SizedBox(
                  width: drawWidth,
                  height: drawHeight,
                  child: CustomPaint(
                    painter: HandPainter(
                      _hands,
                      MediaQuery.of(context).orientation,
                      _currentMode,
                    ),
                  ),
                ),
              ),
              if (_currentMode == RenderMode.glove)
                Center(
                  child: SizedBox(
                    width: drawWidth,
                    height: drawHeight,
                    child: WebViewWidget(controller: _webController),
                  ),
                ),
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModeButton("Skeleton", RenderMode.skeleton),
                    const SizedBox(width: 20),
                    _buildModeButton("Medieval Glove", RenderMode.glove),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HandPainter extends CustomPainter {
  final List<Hand> hands;
  final Orientation orientation;
  final RenderMode mode;

  HandPainter(this.hands, this.orientation, this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;

    final skeletonPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(mode == RenderMode.skeleton ? 1.0 : 0.3)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.red.withOpacity(mode == RenderMode.skeleton ? 1.0 : 0.3)
      ..style = PaintingStyle.fill;

    for (var hand in hands) {
      final landmarks = hand.landmarks;

      Offset getOffset(int index) {
        if (index >= landmarks.length) return Offset.zero;
        final landmark = landmarks[index];
        
        double x, y;
        if (orientation == Orientation.portrait) {
          x = (1 - landmark.y) * size.width;
          y = landmark.x * size.height;
        } else {
          x = landmark.x * size.width;
          y = landmark.y * size.height;
        }
        return Offset(x, y);
      }

      for (int i = 0; i < landmarks.length; i++) {
        canvas.drawCircle(getOffset(i), 3.0, dotPaint);
      }

      void drawLine(int from, int to) {
        final p1 = getOffset(from);
        final p2 = getOffset(to);
        if (p1 != Offset.zero && p2 != Offset.zero) {
          canvas.drawLine(p1, p2, skeletonPaint);
        }
      }

      drawLine(0, 1); drawLine(1, 2); drawLine(2, 3); drawLine(3, 4);
      drawLine(0, 5); drawLine(5, 6); drawLine(6, 7); drawLine(7, 8);
      drawLine(9, 10); drawLine(10, 11); drawLine(11, 12);
      drawLine(13, 14); drawLine(14, 15); drawLine(15, 16);
      drawLine(17, 18); drawLine(18, 19); drawLine(19, 20);
      drawLine(5, 9); drawLine(9, 13); drawLine(13, 17);
      drawLine(0, 17);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
