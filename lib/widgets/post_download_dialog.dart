import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../controller/home_controller.dart';

class HomePostDownloadDialog extends StatelessWidget {
  final HomeController controller;
  final double Function(BuildContext) mediaScale;

  const HomePostDownloadDialog({
    super.key,
    required this.controller,
    required this.mediaScale,
  });

  @override
  Widget build(BuildContext context) {
    final scale = mediaScale(context);

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20 * scale),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24 * scale),
            padding: EdgeInsets.symmetric(
              horizontal: 20 * scale,
              vertical: 18 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20 * scale),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What do you want to do?'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can send to Telegram or save to your gallery.'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5 * scale,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  SizedBox(height: 18 * scale),
                  SizedBox(
                    height: 46 * scale,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.send,
                        size: 20 * scale,
                      ),
                      label: Text(
                        'Save to Telegram'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14 * scale,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14 * scale),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await controller.handleSaveToTelegram();
                      },
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  SizedBox(
                    height: 46 * scale,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.download_rounded,
                        size: 20 * scale,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Save to Gallery'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14 * scale,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.4),
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14 * scale),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await controller.handleSaveToGallery();
                      },
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel'.tr(),
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
