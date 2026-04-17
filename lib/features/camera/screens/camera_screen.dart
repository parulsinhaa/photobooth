// lib/features/camera/screens/camera_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../filters/filter_engine.dart';
import '../filters/filter_definitions.dart';
import '../widgets/camera_controls.dart';
import '../widgets/filter_strip.dart';
import '../widgets/zoom_slider.dart';
import '../widgets/exposure_slider.dart';
import '../widgets/grid_overlay.dart';
import '../bloc/camera_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  bool _flashEnabled = false;
  bool _gridEnabled = false;
  bool _isCapturing = false;
  bool _showZoomSlider = false;
  bool _showExposureSlider = false;

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  double _currentExposure = 0.0;
  double _minExposure = -2.0;
  double _maxExposure = 2.0;

  // Focus tap
  Offset? _focusPoint;
  late AnimationController _focusAnimController;
  late AnimationController _captureAnimController;
  late AnimationController _recordingAnimController;

  // Filter
  int _selectedFilterIndex = 0;
  FilterPreset _activeFilter = FilterPreset.none;

  // Timer
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Last captured
  File? _lastCapturedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _initCamera();
  }

  void _initAnimations() {
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _captureAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _recordingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _initCamera() async {
    final cameraPermission = await Permission.camera.request();
    final micPermission = await Permission.microphone.request();

    if (!cameraPermission.isGranted || !micPermission.isGranted) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    final oldController = _controller;
    if (oldController != null) {
      _controller = null;
      await oldController.dispose();
    }

    final controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();

      await Future.wait([
        controller.getMinZoomLevel().then((v) => _minZoom = v),
        controller.getMaxZoomLevel().then((v) => _maxZoom = v),
        controller.getMinExposureOffset().then((v) => _minExposure = v),
        controller.getMaxExposureOffset().then((v) => _maxExposure = v),
      ]);

      // Set optimal flash mode
      await controller.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    HapticFeedback.mediumImpact();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _isFrontCamera = !_isFrontCamera;

    setState(() => _isInitialized = false);
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (!_isInitialized || _isCapturing || _controller == null) return;
    if (_isRecording) return;

    HapticFeedback.lightImpact();

    setState(() => _isCapturing = true);
    _captureAnimController.forward().then((_) => _captureAnimController.reverse());

    try {
      final file = await _controller!.takePicture();

      setState(() {
        _lastCapturedFile = File(file.path);
        _isCapturing = false;
      });

      // Show preview thumbnail briefly
      await Future.delayed(const Duration(milliseconds: 300));

    } catch (e) {
      setState(() => _isCapturing = false);
      debugPrint('Capture error: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized || _controller == null) return;

    HapticFeedback.mediumImpact();

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _recordingSeconds++);
        if (_recordingSeconds >= 60) _stopRecording(); // max 60 seconds
      });
    } catch (e) {
      debugPrint('Record start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    try {
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      if (mounted) {
        context.go('/editor', extra: {
          'type': 'video',
          'path': file.path,
        });
      }
    } catch (e) {
      setState(() => _isRecording = false);
      debugPrint('Record stop error: $e');
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null) return;
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clampedZoom);
    setState(() => _currentZoom = clampedZoom);
  }

  Future<void> _setExposure(double exposure) async {
    if (_controller == null) return;
    final clamped = exposure.clamp(_minExposure, _maxExposure);
    await _controller!.setExposureOffset(clamped);
    setState(() => _currentExposure = clamped);
  }

  Future<void> _onTapToFocus(TapUpDetails details) async {
    if (_controller == null || !_isInitialized) return;

    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;

    setState(() => _focusPoint = details.localPosition);
    _focusAnimController.forward(from: 0);

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
    } catch (_) {}

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashEnabled = !_flashEnabled);
    await _controller!.setFlashMode(
      _flashEnabled ? FlashMode.torch : FlashMode.off,
    );
    HapticFeedback.selectionClick();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Camera Access Needed',
            style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: const Text('Photo Booth needs camera and microphone access to work.',
            style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings', style: TextStyle(color: AppColors.pink)),
          ),
        ],
      ),
    );
  }

  String get _recordingTimeString {
    final mins = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !(_controller!.value.isInitialized)) return;

    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
      setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera(_cameras[_selectedCameraIndex]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _focusAnimController.dispose();
    _captureAnimController.dispose();
    _recordingAnimController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            GestureDetector(
              onTapUp: _onTapToFocus,
              onScaleUpdate: (details) {
                if (details.scale != 1.0) {
                  _setZoom(_currentZoom * details.scale);
                }
              },
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize!.height,
                    height: _controller!.value.previewSize!.width,
                    child: FilterEngine.applyFilter(
                      child: CameraPreview(_controller!),
                      filter: _activeFilter,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(color: Colors.black, child: const Center(
              child: CircularProgressIndicator(color: AppColors.pink),
            )),

          // Top gradient overlay
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom gradient overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // Grid overlay
          if (_gridEnabled) const GridOverlay(),

          // Focus indicator
          if (_focusPoint != null)
            AnimatedBuilder(
              animation: _focusAnimController,
              builder: (_, __) {
                final scale = Tween<double>(begin: 1.5, end: 1.0).evaluate(
                  CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
                );
                return Positioned(
                  left: _focusPoint!.dx - 30,
                  top: _focusPoint!.dy - 30,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gold, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Capture flash overlay
          AnimatedBuilder(
            animation: _captureAnimController,
            builder: (_, __) => Opacity(
              opacity: _captureAnimController.value * 0.7,
              child: Container(color: Colors.white),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Flash
                  _TopButton(
                    icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                    color: _flashEnabled ? AppColors.gold : Colors.white,
                    onTap: _toggleFlash,
                  ),
                  const Spacer(),

                  // Recording timer
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _recordingAnimController,
                      builder: (_, child) => Opacity(
                        opacity: 0.5 + _recordingAnimController.value * 0.5,
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(_recordingTimeString,
                              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins',
                                fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Grid
                  _TopButton(
                    icon: _gridEnabled ? Icons.grid_on : Icons.grid_off,
                    color: _gridEnabled ? AppColors.pink : Colors.white,
                    onTap: () => setState(() => _gridEnabled = !_gridEnabled),
                  ),
                ],
              ),
            ),
          ),

          // Right side controls
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Zoom button
                _SideButton(
                  icon: Icons.zoom_in,
                  label: '${_currentZoom.toStringAsFixed(1)}x',
                  onTap: () => setState(() => _showZoomSlider = !_showZoomSlider),
                  active: _showZoomSlider,
                ),
                const SizedBox(height: 16),
                // Exposure button
                _SideButton(
                  icon: Icons.exposure,
                  label: '',
                  onTap: () => setState(() => _showExposureSlider = !_showExposureSlider),
                  active: _showExposureSlider,
                ),
              ],
            ),
          ),

          // Zoom slider
          if (_showZoomSlider)
            Positioned(
              right: 70,
              top: 0,
              bottom: 0,
              child: Center(
                child: ZoomSlider(
                  value: _currentZoom,
                  min: _minZoom,
                  max: _maxZoom,
                  onChanged: _setZoom,
                ),
              ),
            ),

          // Exposure slider
          if (_showExposureSlider)
            Positioned(
              right: 70,
              top: 0,
              bottom: 0,
              child: Center(
                child: ExposureSlider(
                  value: _currentExposure,
                  min: _minExposure,
                  max: _maxExposure,
                  onChanged: _setExposure,
                ),
              ),
            ),

          // Filter strip
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: FilterStrip(
              filters: FilterDefinitions.all,
              selectedIndex: _selectedFilterIndex,
              onFilterSelected: (index, filter) {
                setState(() {
                  _selectedFilterIndex = index;
                  _activeFilter = filter;
                });
              },
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: CameraControls(
                isRecording: _isRecording,
                lastCapturedFile: _lastCapturedFile,
                isFrontCamera: _isFrontCamera,
                onCapture: _capturePhoto,
                onRecordToggle: _toggleRecording,
                onSwitchCamera: _switchCamera,
                onGalleryOpen: () => context.go('/editor', extra: {'type': 'gallery'}),
                onPhotoBoothTap: () => context.go('/photobooth'),
              ),
            ),
          ),

          // Last captured preview (bottom left)
          if (_lastCapturedFile != null)
            Positioned(
              bottom: 100,
              left: 20,
              child: GestureDetector(
                onTap: () => context.go('/editor', extra: {
                  'type': 'photo',
                  'path': _lastCapturedFile!.path,
                }),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    image: DecorationImage(
                      image: FileImage(_lastCapturedFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ).animate().scale(duration: 200.ms, curve: Curves.easeOut),
            ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TopButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: label.isEmpty ? 44 : 52,
        decoration: BoxDecoration(
          color: active
            ? AppColors.pink.withOpacity(0.3)
            : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: active
            ? Border.all(color: AppColors.pink.withOpacity(0.5), width: 1)
            : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Poppins'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
