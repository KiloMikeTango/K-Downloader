import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/screens/home_page.dart';
import 'package:video_downloader/screens/maintenance_screen.dart';

final remoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _blurAnimation;

  late final AnimationController _dropsController;
  late final Animation<double> _dropsAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _blurAnimation = Tween<double>(begin: 0, end: 18).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
      ),
    );

    // New: looping, slow “liquid” motion
    _dropsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _dropsAnimation = CurvedAnimation(
      parent: _dropsController,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    _checkMaintenanceAndNavigate();
  }

  Future<void> _checkMaintenanceAndNavigate() async {
    final remoteConfig = ref.read(remoteConfigProvider);

    bool isMaintenance = false;

    try {
      await remoteConfig.setDefaults(const {'is_maintenance': false});

      // Run both: 8 sec minimum splash + remote config fetch.
      final splashDelay = Future.delayed(
        const Duration(seconds: 8),
      ); // minimum duration
      final fetchFuture = remoteConfig.fetchAndActivate();

      await Future.wait([splashDelay, fetchFuture]); // wait for both

      isMaintenance = remoteConfig.getBool('is_maintenance');
    } catch (_) {
      // On failure, keep isMaintenance = false and still respect the 8s delay.
    }

    if (!mounted) return;

    if (isMaintenance) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dropsController.dispose();
    super.dispose();
  }

  Widget _buildLiquidGlassBackground(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _dropsAnimation,
      builder: (context, child) {
        final t = _dropsAnimation.value;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kDarkBackgroundColor, Color(0xFF121212)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Big blurred blobs for liquid glass feel.
            Positioned(
              top: -size.height * 0.15 + 10 * (t - 0.5),
              left: -size.width * 0.2,
              child: _GlassBlob(
                width: size.width * 0.8,
                height: size.width * 0.8,
                color: const Color(0xFF4F46E5).withOpacity(0.65),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.2 - 10 * (t - 0.5),
              right: -size.width * 0.15,
              child: _GlassBlob(
                width: size.width * 0.85,
                height: size.width * 0.85,
                color: const Color(0xFFEC4899).withOpacity(0.55),
              ),
            ),
            // Extra smaller “water drops” orbiting around center
            Positioned(
              top: size.height * 0.18 + 18 * (t - 0.5),
              left: size.width * 0.14 + 10 * (0.5 - t),
              child: _GlassDrop(
                diameter: size.width * 0.18,
                color: Colors.white.withOpacity(0.22),
              ),
            ),
            Positioned(
              top: size.height * 0.62 - 20 * (t - 0.5),
              right: size.width * 0.12 + 8 * (t - 0.5),
              child: _GlassDrop(
                diameter: size.width * 0.16,
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            Positioned(
              bottom: size.height * 0.22 + 12 * (0.5 - t),
              left: size.width * 0.32 + 14 * (t - 0.5),
              child: _GlassDrop(
                diameter: size.width * 0.12,
                color: Colors.white.withOpacity(0.18),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width / 375;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildLiquidGlassBackground(context),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Center(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _blurAnimation.value,
                    sigmaY: _blurAnimation.value,
                  ),
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: 0.75 + _scaleAnimation.value * 0.25,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 32 * scale,
                          vertical: 28 * scale,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28 * scale),
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.16),
                            width: 1.3,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App icon in center
                            Container(
                              width: 96 * scale,
                              height: 96 * scale,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24 * scale),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.2,
                                ),
                                image: const DecorationImage(
                                  image: AssetImage('assets/icon/icon.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(height: 18 * scale),
                            Text(
                              'K Downloader',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17 * scale,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            Text(
                              'Saving your favorite clips...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _GlassBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [color, color.withOpacity(0.0)]),
          ),
        ),
      ),
    );
  }
}

class _GlassDrop extends StatelessWidget {
  final double diameter;
  final Color color;

  const _GlassDrop({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [color, color.withOpacity(0.0)]),
          ),
        ),
      ),
    );
  }
}
