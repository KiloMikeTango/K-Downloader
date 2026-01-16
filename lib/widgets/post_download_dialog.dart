import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constant.dart';
import '../controller/home_controller.dart';
import '../widgets/glass_container.dart';

class HomePostDownloadDialog extends ConsumerWidget {
  final HomeController controller;
  final double Function(BuildContext) mediaScale;

  const HomePostDownloadDialog({
    super.key,
    required this.controller,
    required this.mediaScale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = mediaScale(context);

    final phase = ref.watch(transferPhaseProvider);
    final progress = ref.watch(downloadProgressProvider);
    final isUploading = phase == TransferPhase.uploading;
    final percent = (progress * 100).clamp(0, 100).toInt();

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * scale),
        child: GlassContainer(
          blur: 18 * scale,
          opacity: 0.10,
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 16 * scale,
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Save Options'.tr(),
                        style: TextStyle(
                          fontSize: 15.5 * scale,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.94),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(6 * scale),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18 * scale,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * scale),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'You can send to Telegram or save to your gallery.'.tr(),
                    style: TextStyle(
                      fontSize: 12.5 * scale,
                      color: Colors.white.withOpacity(0.82),
                      height: 1.35,
                    ),
                  ),
                ),
                SizedBox(height: 14 * scale),

                // Telegram button (primary)
                _GlassActionButton(
                  scale: scale,
                  onTap: isUploading
                      ? null
                      : () async {
                          await controller.handleSaveToTelegram();
                        },
                  backgroundOpacity: 0.18,
                  borderOpacity: 0.45,
                  icon: Icons.send_rounded,
                  iconColor: Colors.white,
                  text: isUploading
                      ? 'Sending to Telegram...'.tr()
                      : 'Save to Telegram'.tr(),
                  textColor: Colors.white,
                ),

                SizedBox(height: 10 * scale),

                // Gallery button (secondary)
                _GlassActionButton(
                  scale: scale,
                  onTap: isUploading
                      ? null
                      : () async {
                          await controller.handleSaveToGallery();
                        },
                  backgroundOpacity: 0.06,
                  borderOpacity: 0.30,
                  icon: Icons.download_rounded,
                  iconColor: Colors.white.withOpacity(0.95),
                  text: 'Save to Gallery'.tr(),
                  textColor: Colors.white.withOpacity(0.95),
                ),

                if (isUploading) ...[
                  SizedBox(height: 14 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999 * scale),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 4.0 * scale,
                      color: Colors.lightBlueAccent,
                      backgroundColor: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${'Sending to Telegram'.tr()} • $percent%',
                      style: TextStyle(
                        fontSize: 11.5 * scale,
                        color: Colors.white.withOpacity(0.90),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final double scale;
  final VoidCallback? onTap;
  final double backgroundOpacity;
  final double borderOpacity;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;

  const _GlassActionButton({
    required this.scale,
    required this.onTap,
    required this.backgroundOpacity,
    required this.borderOpacity,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return SizedBox(
      height: 46 * scale,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999 * scale),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14 * scale, sigmaY: 14 * scale),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: kGlassBaseColor.withOpacity(
                enabled ? backgroundOpacity : backgroundOpacity * 0.6,
              ),
              borderRadius: BorderRadius.circular(999 * scale),
              border: Border.all(
                color: Colors.white.withOpacity(
                  enabled ? borderOpacity : borderOpacity * 0.5,
                ),
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999 * scale),
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20 * scale,
                        color: iconColor.withOpacity(enabled ? 1 : 0.6),
                      ),
                      SizedBox(width: 10 * scale),
                      Text(
                        text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14 * scale,
                          color: textColor.withOpacity(enabled ? 1 : 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
