import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/home_controller.dart';

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22 * scale),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18 * scale, sigmaY: 18 * scale),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24 * scale),
            padding: EdgeInsets.symmetric(
              horizontal: 18 * scale,
              vertical: 16 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.50),
              borderRadius: BorderRadius.circular(22 * scale),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with title + close icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Save Options'.tr(),
                          style: TextStyle(
                            fontSize: 15.5 * scale,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: EdgeInsets.all(4 * scale),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18 * scale,
                            color: Colors.white.withOpacity(0.80),
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
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                  SizedBox(height: 14 * scale),

                  // Save to Telegram button
                  SizedBox(
                    height: 46 * scale,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14 * scale),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 14 * scale,
                          sigmaY: 14 * scale,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(
                              isUploading ? 0.16 : 0.12,
                            ),
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14 * scale,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14 * scale),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.0,
                              ),
                            ),
                          ),
                          onPressed: isUploading
                              ? null
                              : () async {
                                  await controller.handleSaveToTelegram();
                                },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 20 * scale),
                              SizedBox(width: 10 * scale),
                              Text(
                                isUploading
                                    ? 'Sending to Telegram...'.tr()
                                    : 'Save to Telegram'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14 * scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10 * scale),

                  // Save to Gallery button
                  SizedBox(
                    height: 46 * scale,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14 * scale),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 14 * scale,
                          sigmaY: 14 * scale,
                        ),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14 * scale),
                            ),
                          ),
                          onPressed: isUploading
                              ? null
                              : () async {
                                  await controller.handleSaveToGallery();
                                },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 20 * scale),
                              SizedBox(width: 10 * scale),
                              Text(
                                'Save to Gallery'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14 * scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Progress indicator when uploading
                  if (isUploading) ...[
                    SizedBox(height: 14 * scale),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 4.0 * scale,
                        color: Colors.lightBlueAccent,
                        backgroundColor: Colors.white.withOpacity(0.16),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${'Sending to Telegram'.tr()} • $percent%',
                        style: TextStyle(
                          fontSize: 11.5 * scale,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
