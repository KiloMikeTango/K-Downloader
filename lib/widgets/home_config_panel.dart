import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/controllers/home_controller.dart';
import 'package:video_downloader/providers/home_providers.dart';
import 'package:video_downloader/widgets/glass_container.dart';

class HomeConfigPanel extends ConsumerStatefulWidget {
  final HomeController controller;
  final TextEditingController chatIdController;
  final double Function(BuildContext) mediaScale;

  const HomeConfigPanel({
    super.key,
    required this.controller,
    required this.chatIdController,
    required this.mediaScale,
  });

  @override
  ConsumerState<HomeConfigPanel> createState() =>
      _HomeConfigPanelState();
}

class _HomeConfigPanelState extends ConsumerState<HomeConfigPanel> {
  double _responsivePadding(BuildContext context, double base) {
    final scale = widget.mediaScale(context);
    return base * scale;
  }

  TextStyle _responsiveTextStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    final scale = widget.mediaScale(context);
    return TextStyle(fontSize: size * scale, fontWeight: weight, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = ref.watch(isChatIdSavedProvider);
    final currentChatId = ref.watch(chatIdProvider);
    final bool isModified =
        widget.chatIdController.text.trim() != currentChatId;
    final bool canSave =
        widget.chatIdController.text.trim().isNotEmpty &&
            (isModified || !isSaved);
    final isLoading = ref.watch(loadingProvider);
    final scale = widget.mediaScale(context);

    return GlassContainer(
      blur: 18,
      opacity: 0.10,
      padding: EdgeInsets.all(_responsivePadding(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "chatid_card_title".tr(),
            textAlign: TextAlign.center,
            style: _responsiveTextStyle(
              context,
              size: 16,
              weight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: _responsivePadding(context, 12)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: !isLoading,
                  controller: widget.chatIdController,
                  keyboardType: TextInputType.number,
                  style: _responsiveTextStyle(
                    context,
                    size: 14,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Chat ID',
                    labelStyle:
                        TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintText: 'eg.123456789',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    prefixIcon: Icon(
                      Icons.chat_bubble,
                      color: kAccentColor.withOpacity(0.8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: kPrimaryColor, width: 1.5),
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(chatIdProvider.notifier).state = value;
                    ref.read(isChatIdSavedProvider.notifier).state =
                        value.trim() == currentChatId &&
                            currentChatId.isNotEmpty;
                    setState(() {});
                  },
                ),
              ),
              SizedBox(width: 10 * scale),
              SizedBox(
                height: 48 * scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10 * scale),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10 * scale),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.26),
                          width: 1.0,
                        ),
                        color:
                            Colors.white.withOpacity(canSave ? 0.12 : 0.06),
                      ),
                      child: TextButton(
                        onPressed: (!isLoading && canSave)
                            ? () => widget.controller
                                .saveChatId(widget.chatIdController.text)
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12 * scale),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isSaved ? 'SAVED' : 'SAVE ID',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13 * scale,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _responsivePadding(context, 12)),
          Text(
            'Chat ID: ${ref.watch(chatIdProvider)}',
            style: _responsiveTextStyle(
              context,
              size: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
