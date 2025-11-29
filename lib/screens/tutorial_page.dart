import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_downloader/constant.dart';

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  static const Color _darkBg = Color(0xFF0E0F12);
  static const Color _textColor = Colors.white70;

  double _scale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width / 380).clamp(0.85, 1.5);
  }

  TextStyle _responsiveText(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color? color,
    double height = 1.4,
  }) {
    final s = _scale(context);
    return TextStyle(
      fontSize: size * s,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  EdgeInsets _responsivePagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 700)
      return const EdgeInsets.symmetric(horizontal: 70, vertical: 25);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'အသုံးပြုနည်း',
          style: _responsiveText(
            context,
            size: 18,
            weight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kDarkBackgroundColor, Colors.black12],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
        ),
      ),

      body: ListView(
        padding: _responsivePagePadding(context),
        children: [
          _instructionBox(
            context: context,
            number: "1",
            text: "Chat ID ယူရန် Telegram Bot ထဲကိုသွားပါ။",
            imagePath: "assets/step1.png",
            buttonText: "@InstantChatIDBot (နှိပ်ပါ)",
            buttonAction: () async {
              final url = Uri.parse("https://t.me/InstantChatIDBot");

              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),

          const SizedBox(height: 18),

          _instructionBox(
            context: context,
            number: "2",
            text: "ID ကို Copy ယူပါ။",
            imagePath: "assets/step2.png",
          ),

          const SizedBox(height: 18),

          _instructionBox(
            context: context,
            number: "3",
            text: "Telegram Bot ကို Start လုပ်ပါ။",
            imagePath: "assets/step3.png",
            buttonText: "@kmt_vidownloader_bot (နှိပ်ပါ)",
            buttonAction: () async {
              final Uri url = Uri.parse('https://t.me/kmt_vidownloader_bot');
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),

          const SizedBox(height: 18),

          _instructionBox(
            context: context,
            number: "4",
            text: "Copy ယူလာတဲ့ ID ကိုထည့်ပါ။",
            imagePath: "assets/step4.png",
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _instructionBox({
    required BuildContext context,
    required String number,
    required String text,
    required String imagePath,
    String? buttonText,
    VoidCallback? buttonAction,
  }) {
    final scale = _scale(context);

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$number. $text",
            style: _responsiveText(context, size: 15, color: _textColor),
          ),

          SizedBox(height: 10 * scale),

          if (buttonText != null && buttonAction != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: buttonAction,
                style: TextButton.styleFrom(foregroundColor: kAccentColor),
                child: Text(
                  buttonText,
                  style: _responsiveText(
                    context,
                    size: 17,
                    color: kAccentColor,
                  ),
                ),
              ),
            ),

          SizedBox(height: 10 * scale),

          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8 * scale),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
