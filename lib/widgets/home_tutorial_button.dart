import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/screens/tutorial_page.dart';

class HomeTutorialButton extends StatelessWidget {
  const HomeTutorialButton({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 375).clamp(0.8, 1.6);

    return OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TutorialPage()),
        );
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: kPrimaryColor),
        padding: EdgeInsets.symmetric(
          vertical: 10 * scale,
          horizontal: 10 * scale,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10 * scale),
        ),
      ),
      child: Text(
        "how_to_use".tr(),
        style: TextStyle(
          color: kPrimaryColor,
          fontSize: 15 * scale,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
