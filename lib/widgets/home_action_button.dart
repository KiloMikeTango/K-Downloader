import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/controller/home_controller.dart';

class HomeActionButton extends ConsumerWidget {
  final HomeController controller;
  final double Function(BuildContext) mediaScale;

  const HomeActionButton({
    super.key,
    required this.controller,
    required this.mediaScale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider);
    final scale = mediaScale(context);

    return SizedBox(
      height: 50 * scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16 * scale),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * scale),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 1.0,
              ),
              color: Colors.white.withOpacity(isLoading ? 0.12 : 0.06),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading ? null : controller.handleDownload,
                borderRadius: BorderRadius.circular(16 * scale),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18 * scale,
                      vertical: 10 * scale,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download,
                          size: 22 * scale,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5 * scale),
                        Text(
                          isLoading ? 'Processing...' : "btn_download".tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14 * scale,
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
      ),
    );
  }
}
