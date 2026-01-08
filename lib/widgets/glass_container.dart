import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_downloader/constant.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsets padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = 0.10,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: kGlassBaseColor.withOpacity(opacity),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
