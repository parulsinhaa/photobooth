// lib/features/auth/screens/splash_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _ringController;

  late Animation<double> _orbitAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _ringAnim;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _generateParticles();
    _navigate();
  }

  void _initAnimations() {
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _orbitAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _orbitController, curve: Curves.linear),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });
  }

  void _generateParticles() {
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 0.5,
        speed: _random.nextDouble() * 0.003 + 0.001,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        color: _random.nextInt(4),
        angle: _random.nextDouble() * 2 * math.pi,
      ));
    }
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;

    final onboardingDone = LocalStorage.getBool(AppConstants.onboardingKey) ?? false;
    final token = LocalStorage.getString(AppConstants.tokenKey);

    if (token != null && token.isNotEmpty) {
      context.go('/camera');
    } else if (!onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dark gradient base
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF1A0820), Color(0xFF0D0D0D)],
              ),
            ),
          ),

          // Animated particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),

          // Expanding rings (3D illusion)
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) => CustomPaint(
              painter: _RingPainter(progress: _ringAnim.value),
              child: const SizedBox.expand(),
            ),
          ),

          // Orbiting color blobs (creates 3D depth)
          AnimatedBuilder(
            animation: _orbitAnim,
            builder: (_, __) {
              return Stack(
                children: [
                  // Pink blob orbit
                  Positioned(
                    left: size.width / 2 + math.cos(_orbitAnim.value) * 120 - 30,
                    top: size.height / 2 + math.sin(_orbitAnim.value) * 60 - 30,
                    child: _GlowBlob(
                      color: AppColors.pink,
                      size: 60,
                      opacity: _glowAnim.value * 0.7,
                    ),
                  ),
                  // Lavender blob orbit (opposite)
                  Positioned(
                    left: size.width / 2 + math.cos(_orbitAnim.value + math.pi) * 120 - 25,
                    top: size.height / 2 + math.sin(_orbitAnim.value + math.pi) * 60 - 25,
                    child: _GlowBlob(
                      color: AppColors.lavender,
                      size: 50,
                      opacity: _glowAnim.value * 0.6,
                    ),
                  ),
                  // Peach blob orbit (90 degrees offset)
                  Positioned(
                    left: size.width / 2 + math.cos(_orbitAnim.value + math.pi / 2) * 140 - 20,
                    top: size.height / 2 + math.sin(_orbitAnim.value + math.pi / 2) * 70 - 20,
                    child: _GlowBlob(
                      color: AppColors.peach,
                      size: 40,
                      opacity: _glowAnim.value * 0.5,
                    ),
                  ),
                  // Gold blob
                  Positioned(
                    left: size.width / 2 + math.cos(_orbitAnim.value + math.pi * 1.5) * 100 - 18,
                    top: size.height / 2 + math.sin(_orbitAnim.value + math.pi * 1.5) * 50 - 18,
                    child: _GlowBlob(
                      color: AppColors.gold,
                      size: 36,
                      opacity: _glowAnim.value * 0.5,
                    ),
                  ),
                ],
              );
            },
          ),

          // Center logo with 3D pulse
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnim, _glowAnim]),
              builder: (_, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pink.withOpacity(_glowAnim.value * 0.5),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                          BoxShadow(
                            color: AppColors.lavender.withOpacity(_glowAnim.value * 0.3),
                            blurRadius: 80,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Logo container with glass effect
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A1A2A), Color(0xFF1A1030)],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: _LogoIcon(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // App name and tagline
          Positioned(
            bottom: size.height * 0.28,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (_, child) => Opacity(
                opacity: _textController.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _textController.value)),
                  child: child,
                ),
              ),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.pink, AppColors.lavender, AppColors.peach],
                    ).createShader(bounds),
                    child: const Text(
                      'Photo Booth',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture. Create. Share.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: size.height * 0.12,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.pink.withOpacity(0.8),
                      ),
                      minHeight: 2,
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms, color: AppColors.lavender),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoIcon extends StatelessWidget {
  const _LogoIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(70, 70),
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pinkPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.pink, AppColors.lavender],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Camera body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 4), width: size.width * 0.85, height: size.height * 0.6),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, pinkPaint);

    // Viewfinder bump
    final bumpRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 12, cy - 14), width: 20, height: 12),
      const Radius.circular(4),
    );
    canvas.drawRRect(bumpRect, pinkPaint);

    // Lens outer
    canvas.drawCircle(Offset(cx, cy + 4), 16, whitePaint);

    // Lens inner
    final lensPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF1A0820), Color(0xFF0D0D1A)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy + 4), radius: 12));
    canvas.drawCircle(Offset(cx, cy + 4), 12, lensPaint);

    // Lens shine
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 4, cy), 3, shinePaint);

    // Flash
    final flashPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 22, cy - 12), width: 8, height: 8),
        const Radius.circular(2),
      ),
      flashPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity * 0.3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity),
            blurRadius: size * 1.5,
            spreadRadius: size * 0.5,
          ),
        ],
      ),
    );
  }
}

class _Particle {
  double x, y, size, speed, opacity, angle;
  int color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
    required this.angle,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  const _ParticlePainter({required this.particles, required this.progress});

  static const colors = [
    AppColors.pink,
    AppColors.lavender,
    AppColors.peach,
    AppColors.gold,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final newY = (p.y - progress * p.speed * 10) % 1.0;
      final x = p.x * size.width;
      final y = newY * size.height;

      final paint = Paint()
        ..color = colors[p.color].withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}

class _RingPainter extends CustomPainter {
  final double progress;

  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final radius = 80 + p * 200;
      final opacity = (1 - p) * 0.15;

      final paint = Paint()
        ..color = AppColors.pink.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
