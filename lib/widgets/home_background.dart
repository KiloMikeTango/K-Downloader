import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_downloader/constant.dart';

class HomeAnimatedBackground extends StatelessWidget {
  final Animation<double> animation;

  const HomeAnimatedBackground({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kDarkBackgroundColor, Color(0xFF1B2735)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.25 + 40 * (t - 0.5),
              left: -size.width * 0.4,
              child: _HomeGlassBlob(
                width: size.width * 1.0,
                height: size.width * 1.0,
                color: const Color(0xFF4F46E5).withOpacity(0.45),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.28 - 36 * (t - 0.5),
              right: -size.width * 0.35,
              child: _HomeGlassBlob(
                width: size.width * 1.1,
                height: size.width * 1.1,
                color: const Color(0xFF22D3EE).withOpacity(0.40),
              ),
            ),
            Positioned(
              top: size.height * 0.18 + 26 * (t - 0.5),
              right: size.width * 0.18 + 14 * (0.5 - t),
              child: _HomeDrop(
                diameter: size.width * 0.20,
                color: Colors.white.withOpacity(0.22),
              ),
            ),
            Positioned(
              bottom: size.height * 0.20 + 20 * (0.5 - t),
              left: size.width * 0.22 + 16 * (t - 0.5),
              child: _HomeDrop(
                diameter: size.width * 0.16,
                color: Colors.white.withOpacity(0.18),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeGlassBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _HomeGlassBlob({
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

class _HomeDrop extends StatelessWidget {
  final double diameter;
  final Color color;

  const _HomeDrop({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
