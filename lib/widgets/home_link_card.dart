import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/controllers/home_controller.dart';
import 'package:video_downloader/models/enums.dart';
import 'package:video_downloader/providers/home_providers.dart';
import 'package:video_downloader/utils/media_utils.dart';
import 'package:video_downloader/widgets/glass_container.dart';

// widgets/home_link_card.dart - SIMPLE CONSTRUCTOR
class HomeLinkCard extends ConsumerWidget {
  final HomeController controller;
  final TextEditingController urlController;
  final TextEditingController captionController;
  final double Function(BuildContext) mediaScale;

  const HomeLinkCard({
    super.key,
    required this.controller,
    required this.urlController,
    required this.captionController,
    required this.mediaScale,
  });


  // --- Helper: Responsive Scaling ---
  double _responsivePadding(BuildContext context, double base) {
    final scale = mediaScale(context);
    return base * scale;
  }

  TextStyle _responsiveTextStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    final scale = mediaScale(context);
    return TextStyle(fontSize: size * scale, fontWeight: weight, color: color);
  }

  // --- Widget: Thumbnail Preview ---
  Widget _buildThumbnailPreview(BuildContext context, WidgetRef ref) {
    final thumbnailUrl = ref.watch(thumbnailUrlProvider);
    final caption = ref.watch(videoCaptionProvider);
    final scale = mediaScale(context);

    if ((thumbnailUrl == null || thumbnailUrl.isEmpty) &&
        (caption == null || caption.isEmpty)) {
      return const SizedBox.shrink();
    }

    final radius = 14 * scale;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth * 0.8).clamp(220.0, 480.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _responsivePadding(context, 16.5)),
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.0,
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
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
                                size: 28 * scale,
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
          ),
        if (caption != null && caption.isNotEmpty) ...[
          SizedBox(height: _responsivePadding(context, 10)),
          Text(
            caption,
            textAlign: TextAlign.left,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _responsiveTextStyle(
              context,
              size: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider);
    final progress = ref.watch(downloadProgressProvider);
    final phase = ref.watch(transferPhaseProvider);
    final saveWithCaption = ref.watch(saveWithCaptionProvider);

    final percent = (progress * 100).clamp(0, 100).toInt();
    final isActiveOperation = 
        phase == TransferPhase.downloading || 
        phase == TransferPhase.extracting || 
        phase == TransferPhase.uploading;

    final String phaseLabel = switch (phase) {
      TransferPhase.downloading => 'Downloading: $percent%',
      TransferPhase.extracting => 'Extracting audio...',
      TransferPhase.uploading => 'Sending to Telegram: $percent%',
      _ => '',
    };

    final scale = mediaScale(context);

    return GlassContainer(
      blur: 18,
      opacity: 0.10,
      padding: EdgeInsets.symmetric(
        horizontal: _responsivePadding(context, 18),
        vertical: _responsivePadding(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. URL Input Field
          TextField(
            controller: urlController,
            enabled: !isLoading,
            style: _responsiveTextStyle(
              context,
              size: 15,
              weight: FontWeight.w500,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'Youtube or Tiktok Link',
              hintText: 'Link',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              prefixIcon: Icon(
                Icons.link,
                color: Colors.white.withOpacity(0.7),
              ),
              suffixIcon: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: kPrimaryColor,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: kPrimaryColor, width: 1.8),
              ),
            ),
            onChanged: (value) {
              final cleaned = MediaUtils.cleanYoutubeUrl(value);
              if (cleaned != value) {
                urlController.value = TextEditingValue(
                  text: cleaned,
                  selection: TextSelection.collapsed(offset: cleaned.length),
                );
              }
              ref.read(urlProvider.notifier).state = cleaned;
              controller.updateThumbnailForUrl(cleaned);
            },
          ),
          
          SizedBox(height: _responsivePadding(context, 16)),
          
          // 2. Save with Caption Checkbox (KEEP - used in dialog)
          Row(
            children: [
              Checkbox(
                value: saveWithCaption,
                onChanged: isLoading
                    ? null
                    : (value) {
                        ref.read(saveWithCaptionProvider.notifier).state =
                            value ?? true;
                      },
                activeColor: kPrimaryColor,
                checkColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
              Expanded(
                child: Text(
                  "label_save_with_caption".tr(),
                  style: _responsiveTextStyle(
                    context,
                    size: 13.5,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
          
          // 3. Preview Area
          _buildThumbnailPreview(context, ref),
          
          // 4. Progress
          if (isLoading) ...[
            SizedBox(height: _responsivePadding(context, 12)),
            LinearProgressIndicator(
              color: kPrimaryColor,
              backgroundColor: Colors.white10,
              value: progress > 0 ? progress : null,
              minHeight: 4,
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                phaseLabel.isNotEmpty ? phaseLabel : '$percent%',
                style: _responsiveTextStyle(
                  context,
                  size: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
          
          // 5. Cancel Button
          if (isActiveOperation) ...[
            SizedBox(height: _responsivePadding(context, 8)),
            SizedBox(
              height: 32 * scale,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10 * scale),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10 * scale),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1.0,
                      ),
                      color: Colors.white.withOpacity(0.12),
                    ),
                    child: TextButton.icon(
                      onPressed: controller.handleCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.close, size: 16 * scale),
                      label: Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12 * scale,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
