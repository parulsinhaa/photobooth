// lib/features/photobooth/screens/photobooth_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../templates/strip_templates.dart';
import '../widgets/template_selector.dart';
import '../widgets/countdown_overlay.dart';
import '../../camera/filters/filter_definitions.dart';
import '../../camera/filters/filter_engine.dart';

class PhotoBoothScreen extends StatefulWidget {
  const PhotoBoothScreen({super.key});

  @override
  State<PhotoBoothScreen> createState() => _PhotoBoothScreenState();
}

class _PhotoBoothScreenState extends State<PhotoBoothScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // Booth State
  BoothPhase _phase = BoothPhase.setup;
  int _photoCount = 4;
  int _capturedCount = 0;
  List<File> _capturedPhotos = [];
  StripTemplate _selectedTemplate = StripTemplates.all.first;
  FilterPreset _selectedFilter = FilterPreset.none;

  // Countdown
  int _countdownValue = 3;
  bool _showCountdown = false;
  Timer? _countdownTimer;
  Timer? _boothTimer;

  // Animation controllers
  late AnimationController _flashController;
  late AnimationController _shakeController;
  late AnimationController _progressController;
  late AnimationController _resultController;

  late Animation<double> _shakeAnim;

  // Strip generation
  GlobalKey _stripKey = GlobalKey();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
  }

  void _initAnimations() {
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _cameraController = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  void _startBooth() {
    if (!_cameraReady) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = BoothPhase.shooting;
      _capturedCount = 0;
      _capturedPhotos.clear();
    });
    _captureNextPhoto();
  }

  void _captureNextPhoto() {
    if (_capturedCount >= _photoCount) {
      _finishShooting();
      return;
    }
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _countdownValue = AppConstants.countdownSeconds;
      _showCountdown = true;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _countdownValue--);

      if (_countdownValue <= 0) {
        timer.cancel();
        setState(() => _showCountdown = false);
        _takePhoto();
      }
    });
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    HapticFeedback.heavyImpact();

    // Flash effect
    _flashController.forward(from: 0).then((_) => _flashController.reverse());

    try {
      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);

      setState(() {
        _capturedPhotos.add(file);
        _capturedCount++;
      });

      // Shake camera frame effect
      _shakeController.forward(from: 0);
      _progressController.animateTo(_capturedCount / _photoCount);

      if (_capturedCount < _photoCount) {
        // Wait 1.5 sec then shoot next
        _boothTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) _captureNextPhoto();
        });
      } else {
        _finishShooting();
      }
    } catch (e) {
      debugPrint('Photo capture error: $e');
      // Retry
      _boothTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _captureNextPhoto();
      });
    }
  }

  void _finishShooting() {
    HapticFeedback.heavyImpact();
    setState(() => _phase = BoothPhase.preview);
    _resultController.forward();
  }

  Future<void> _generateStrip() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      // Render strip widget to image
      await Future.delayed(const Duration(milliseconds: 300));
      final boundary = _stripKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) throw Exception('Strip render boundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0); // High DPI
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final stripFile = File('${tempDir.path}/strip_${DateTime.now().millisecondsSinceEpoch}.png');
      await stripFile.writeAsBytes(bytes);

      setState(() => _isGenerating = false);

      if (mounted) {
        context.go('/photobooth/result', extra: {
          'stripPath': stripFile.path,
          'templateId': _selectedTemplate.id,
          'photoCount': _photoCount,
          'filterId': _selectedFilter.id,
        });
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      debugPrint('Strip generation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate strip. Please try again.')),
      );
    }
  }

  void _retake() {
    setState(() {
      _phase = BoothPhase.setup;
      _capturedPhotos.clear();
      _capturedCount = 0;
    });
    _progressController.reset();
    _resultController.reset();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flashController.dispose();
    _shakeController.dispose();
    _progressController.dispose();
    _resultController.dispose();
    _countdownTimer?.cancel();
    _boothTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: _buildPhase(),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case BoothPhase.setup:
        return _buildSetupPhase();
      case BoothPhase.shooting:
        return _buildShootingPhase();
      case BoothPhase.preview:
        return _buildPreviewPhase();
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // SETUP PHASE
  // ──────────────────────────────────────────────────────────────────
  Widget _buildSetupPhase() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.bgDark,
          pinned: true,
          title: const Text('Photo Booth',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text('Help', style: TextStyle(color: AppColors.pink)),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live preview
                if (_cameraReady && _cameraController != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FilterEngine.applyFilter(
                            child: CameraPreview(_cameraController!),
                            filter: _selectedFilter,
                          ),
                          // Strip frame overlay
                          _StripFrameOverlay(
                            photoCount: _photoCount,
                            template: _selectedTemplate,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms)
                else
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.pink),
                    ),
                  ),

                const SizedBox(height: 28),

                // Photo count selector
                const Text('Number of Photos',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [2, 3, 4, 6, 8].map((count) => Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _photoCount = count);
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _photoCount == count
                            ? AppColors.primaryGradient
                            : null,
                          color: _photoCount == count ? null : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _photoCount == count
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Center(
                          child: Text('$count',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: _photoCount == count
                                ? FontWeight.w700
                                : FontWeight.w400,
                              fontSize: 16,
                            )),
                        ),
                      ),
                    ),
                  )).toList(),
                ),

                const SizedBox(height: 28),

                // Template selector
                const Text('Choose Template',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                TemplateSelector(
                  templates: StripTemplates.all,
                  selectedTemplate: _selectedTemplate,
                  photoCount: _photoCount,
                  onSelect: (t) => setState(() => _selectedTemplate = t),
                ),

                const SizedBox(height: 28),

                // Filter selector
                const Text('Filter',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: FilterDefinitions.all.length,
                    itemBuilder: (_, i) {
                      final f = FilterDefinitions.all[i];
                      final selected = _selectedFilter.id == f.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedFilter = f);
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: f.previewColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (f.isPremium)
                                const Icon(Icons.star, color: AppColors.gold, size: 12),
                              const SizedBox(height: 2),
                              Text(f.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 36),

                // Start button
                GestureDetector(
                  onTap: _cameraReady ? _startBooth : null,
                  child: Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: _cameraReady
                        ? AppColors.warmGradient
                        : const LinearGradient(colors: [Color(0xFF333333), Color(0xFF222222)]),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: _cameraReady ? [
                        BoxShadow(
                          color: AppColors.pink.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ] : null,
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text('Start Photo Booth',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            )),
                        ],
                      ),
                    ),
                  ),
                ).animate().scale(duration: 200.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // SHOOTING PHASE
  // ──────────────────────────────────────────────────────────────────
  Widget _buildShootingPhase() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview fullscreen
        if (_cameraReady && _cameraController != null)
          SizedBox.expand(
            child: AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0),
                child: child,
              ),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: FilterEngine.applyFilter(
                    child: CameraPreview(_cameraController!),
                    filter: _selectedFilter,
                  ),
                ),
              ),
            ),
          ),

        // Photo strip frame overlay
        _StripFrameOverlay(
          photoCount: _photoCount,
          template: _selectedTemplate,
          fullscreen: true,
        ),

        // Flash overlay
        AnimatedBuilder(
          animation: _flashController,
          builder: (_, __) => Opacity(
            opacity: _flashController.value * 0.85,
            child: Container(color: Colors.white),
          ),
        ),

        // Top HUD
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_photoCount, (i) {
                    final taken = i < _capturedCount;
                    final current = i == _capturedCount;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: current ? 24 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: taken
                          ? AppColors.pink
                          : current
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                Text(
                  '${_capturedCount + 1} of $_photoCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Thumbnails of captured photos (bottom left)
        Positioned(
          bottom: 40,
          left: 20,
          child: Row(
            children: _capturedPhotos.map((f) => Container(
              width: 48,
              height: 64,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(image: FileImage(f), fit: BoxFit.cover),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            )).toList(),
          ),
        ).animate().slideX(begin: -0.5, duration: 300.ms),

        // Countdown overlay
        if (_showCountdown)
          CountdownOverlay(
            value: _countdownValue,
            onZero: () {},
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // PREVIEW PHASE
  // ──────────────────────────────────────────────────────────────────
  Widget _buildPreviewPhase() {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Your Strip',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _retake,
          tooltip: 'Retake',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Strip preview
            Center(
              child: RepaintBoundary(
                key: _stripKey,
                child: _selectedTemplate.buildStrip(
                  photos: _capturedPhotos,
                  filter: _selectedFilter,
                ),
              ),
            ).animate().scale(begin: const Offset(0.8, 0.8), duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh, color: AppColors.pink),
                    label: const Text('Retake',
                      style: TextStyle(color: AppColors.pink, fontFamily: 'Poppins')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.pink),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _isGenerating ? null : _generateStrip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pink.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isGenerating
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Save Strip',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  )),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

enum BoothPhase { setup, shooting, preview }

// ─────────────────────────────────────────────────────────────────────────────
// Strip Frame Overlay
// ─────────────────────────────────────────────────────────────────────────────
class _StripFrameOverlay extends StatelessWidget {
  final int photoCount;
  final StripTemplate template;
  final bool fullscreen;

  const _StripFrameOverlay({
    required this.photoCount,
    required this.template,
    this.fullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!fullscreen) return const SizedBox.shrink();

    return CustomPaint(
      painter: _FramePainter(photoCount: photoCount, template: template),
      child: const SizedBox.expand(),
    );
  }
}

class _FramePainter extends CustomPainter {
  final int photoCount;
  final StripTemplate template;

  const _FramePainter({required this.photoCount, required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = template.primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw frame divisions based on photo count
    final slotHeight = size.height / photoCount;
    for (int i = 1; i < photoCount; i++) {
      canvas.drawLine(
        Offset(0, slotHeight * i),
        Offset(size.width, slotHeight * i),
        paint,
      );
    }

    // Corner decorations
    final cornerPaint = Paint()
      ..color = template.primaryColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cs = 20.0; // corner size
    // Top-left
    canvas.drawLine(const Offset(8, 8), const Offset(8 + cs, 8), cornerPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(8, 8 + cs), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8 - cs, 8), cornerPaint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8, 8 + cs), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(8, size.height - 8), Offset(8 + cs, size.height - 8), cornerPaint);
    canvas.drawLine(Offset(8, size.height - 8), Offset(8, size.height - 8 - cs), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8 - cs, size.height - 8), cornerPaint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8, size.height - 8 - cs), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
