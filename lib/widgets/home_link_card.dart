import 'dart:ui';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/controller/home_controller.dart';
import 'package:video_downloader/widgets/glass_container.dart';

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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildModeChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required double scale,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _responsivePadding(context, 7)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999 * scale),
        color: selected
            ? kPrimaryColor.withOpacity(0.22)
            : Colors.white.withOpacity(0.05),
        border: Border.all(
          color: selected ? kPrimaryColor : Colors.white.withOpacity(0.25),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: _responsiveTextStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            color: Colors.white.withOpacity(selected ? 0.98 : 0.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider);
    final message = ref.watch(messageProvider);
    final progress = ref.watch(downloadProgressProvider);
    final phase = ref.watch(transferPhaseProvider);
    final saveWithCaption = ref.watch(saveWithCaptionProvider);
    final mode = ref.watch(downloadModeProvider);

    final percent = (progress * 100).clamp(0, 100).toInt();

    final isDownloading =
        phase == TransferPhase.downloading || phase == TransferPhase.extracting;

    final String phaseLabel = switch (phase) {
      TransferPhase.downloading => 'Downloading: $percent%',
      TransferPhase.extracting => 'Extracting audio...',
      TransferPhase.uploading => 'Sending to Telegram: $percent%',
      _ => '',
    };

    final scale = mediaScale(context);

    final isVideo = mode == DownloadMode.video;
    final isAudio = mode == DownloadMode.audio;
    final isBoth = mode == DownloadMode.both;

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
              final cleaned = controller.cleanYoutubeUrl(value);
              if (cleaned != value) {
                urlController.text = cleaned;
                urlController.selection = TextSelection.fromPosition(
                  TextPosition(offset: cleaned.length),
                );
              }
              ref.read(urlProvider.notifier).state = cleaned;
              controller.updateThumbnailForUrl(cleaned);
            },
          ),
          SizedBox(height: _responsivePadding(context, 8)),
          Text(
            "Download as",
            style: _responsiveTextStyle(
              context,
              size: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 6 * scale),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isLoading
                      ? null
                      : () => ref.read(downloadModeProvider.notifier).state =
                          DownloadMode.video,
                  child: _buildModeChip(
                    context,
                    label: "Video",
                    selected: isVideo,
                    scale: scale,
                  ),
                ),
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                child: GestureDetector(
                  onTap: isLoading
                      ? null
                      : () => ref.read(downloadModeProvider.notifier).state =
                          DownloadMode.audio,
                  child: _buildModeChip(
                    context,
                    label: "Audio",
                    selected: isAudio,
                    scale: scale,
                  ),
                ),
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                child: GestureDetector(
                  onTap: isLoading
                      ? null
                      : () => ref.read(downloadModeProvider.notifier).state =
                          DownloadMode.both,
                  child: _buildModeChip(
                    context,
                    label: "Both",
                    selected: isBoth,
                    scale: scale,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _responsivePadding(context, 8)),
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
          _buildThumbnailPreview(context, ref),
          SizedBox(height: _responsivePadding(context, 15)),
          if (isLoading) ...[
            LinearProgressIndicator(
              color: kPrimaryColor,
              value: progress > 0 ? progress : null,
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                phaseLabel.isNotEmpty
                    ? phaseLabel
                    : (progress > 0 ? '$percent%' : ''),
                style: _responsiveTextStyle(
                  context,
                  size: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
          SizedBox(height: _responsivePadding(context, 5.5)),
          Text(
            message.isEmpty ? '' : message,
            textAlign: TextAlign.center,
            style: _responsiveTextStyle(
              context,
              size: 15.5,
              weight: FontWeight.w500,
              color: message.startsWith('Error:')
                  ? Colors.red.shade300
                  : message.startsWith('Telegram')
                      ? Colors.green.shade300
                      : Colors.white,
            ),
          ),
          const SizedBox(height: 12),
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
                    color: Colors.white.withOpacity(
                      isDownloading ? 0.12 : 0.06,
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: isDownloading
                        ? controller.handleCancel
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 12 * scale),
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
      ),
    );
  }
}
