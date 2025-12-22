import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_downloader/constant.dart';

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

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
      color: color ?? Colors.white.withOpacity(0.85),
      height: height,
    );
  }

  EdgeInsets _responsivePagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 700) {
      return const EdgeInsets.symmetric(horizontal: 70, vertical: 25);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.30),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: _responsivePagePadding(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24 * s),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.07),
                      Colors.white.withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24 * s),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.26),
                    width: 1,
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tutorialSteps')
                      .orderBy('order')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Tutorial is not available right now.',
                            textAlign: TextAlign.center,
                            style: _responsiveText(
                              context,
                              size: 15,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Tutorial steps မရှိသေးပါ။',
                            textAlign: TextAlign.center,
                            style: _responsiveText(context, size: 14),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.all(18 * s),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => SizedBox(height: 18 * s),
                      itemBuilder: (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>? ?? {};
                        final text = data['text'] as String? ?? '';
                        final imageUrl = data['imageUrl'] as String? ?? '';
                        final buttonText = data['buttonText'] as String?;
                        final buttonUrl = data['buttonUrl'] as String?;

                        return _instructionGlassCard(
                          context: context,
                          index: index,
                          text: text,
                          imageUrl: imageUrl,
                          buttonText: buttonText,
                          buttonUrl: buttonUrl,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructionGlassCard({
    required BuildContext context,
    required int index,
    required String text,
    required String imageUrl,
    String? buttonText,
    String? buttonUrl,
  }) {
    final scale = _scale(context);
    final stepNumber = index + 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18 * scale),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.all(16 * scale),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18 * scale),
            border: Border.all(
              color: Colors.white.withOpacity(0.26),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stepNumber. $text',
                style: _responsiveText(
                  context,
                  size: 15,
                ),
              ),
              SizedBox(height: 10 * scale),
              if (buttonText != null &&
                  buttonText.isNotEmpty &&
                  buttonUrl != null &&
                  buttonUrl.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(buttonUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: kAccentColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * scale,
                        vertical: 4 * scale,
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: _responsiveText(
                        context,
                        size: 15,
                        color: kAccentColor,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 10 * scale),
              if (imageUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14 * scale),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14 * scale),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                            width: 1.0,
                          ),
                        ),
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.black26,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white54,
                                    size: 24 * scale,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
