import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/controller/home_controller.dart';
import 'package:video_downloader/screens/tutorial_page.dart';

// --- Glass Container Widget ---
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsets padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = 0.10,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: kGlassBaseColor.withOpacity(opacity),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// --- HomePage ---
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  late final TextEditingController _urlController;
  late final TextEditingController _chatIdController;
  late final TextEditingController _captionController;

  late final AnimationController _bgController;
  late final Animation<double> _bgAnimation;
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _chatIdController = TextEditingController();
    _captionController = TextEditingController();
    _controller = HomeController(ref);

    _controller.loadSavedChatId(
      onLoadedToController: (value) => _chatIdController.text = value,
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _bgAnimation = CurvedAnimation(
      parent: _bgController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _chatIdController.dispose();
    _captionController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  double _mediaScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 375).clamp(0.8, 1.6);
    return scale;
  }

  TextStyle _responsiveTextStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    final scale = _mediaScale(context);
    return TextStyle(fontSize: size * scale, fontWeight: weight, color: color);
  }

  double _responsivePadding(BuildContext context, double base) {
    final scale = _mediaScale(context);
    return base * scale;
  }

  Widget _buildThumbnailPreview(BuildContext context) {
    final thumbnailUrl = ref.watch(thumbnailUrlProvider);
    final caption = ref.watch(videoCaptionProvider);
    final scale = _mediaScale(context);

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

  Widget _buildLinkCard(BuildContext context, double width) {
    final isLoading = ref.watch(loadingProvider);
    final message = ref.watch(messageProvider);
    final progress = ref.watch(downloadProgressProvider);
    final phase = ref.watch(transferPhaseProvider);
    final saveWithCaption = ref.watch(saveWithCaptionProvider);

    final percent = (progress * 100).clamp(0, 100).toInt();

    final isDownloading = phase == TransferPhase.downloading;
    final String phaseLabel = switch (phase) {
      TransferPhase.downloading => 'Downloading: $percent%',
      TransferPhase.uploading => 'Sending to Telegram: $percent%',
      _ => '',
    };

    final scale = _mediaScale(context);

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
            controller: _urlController,
            enabled: !isLoading,
            style: _responsiveTextStyle(
              context,
              size: 15,
              weight: FontWeight.w500,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'Youtube or Tiktok Link',
              hintText: 'လင့်ထည့်ရန်...',
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
              final cleaned = _controller.cleanYoutubeUrl(value);
              if (cleaned != value) {
                _urlController.text = cleaned;
                _urlController.selection = TextSelection.fromPosition(
                  TextPosition(offset: cleaned.length),
                );
              }
              ref.read(urlProvider.notifier).state = cleaned;
              _controller.updateThumbnailForUrl(cleaned);
            },
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
                  'Save with caption',
                  style: _responsiveTextStyle(
                    context,
                    size: 13.5,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
          _buildThumbnailPreview(context),
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
            message.isEmpty ? 'လင့်ထည့်ပါ...' : message,
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
                        ? () => _controller.handleCancel(
                            ref.read(downloadServiceProvider),
                          )
                        : null,
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
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final isLoading = ref.watch(loadingProvider);
    final scale = _mediaScale(context);

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
                onTap: isLoading ? null : _controller.handleDownload,
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
                        Icon(Icons.send, size: 22 * scale, color: Colors.white),
                        SizedBox(width: 12 * scale),
                        Text(
                          isLoading ? 'Downloading...' : 'Save to Telegram Bot',
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

  Widget _buildConfigPanel(BuildContext context) {
    final isSaved = ref.watch(isChatIdSavedProvider);
    final currentChatId = ref.watch(chatIdProvider);
    final bool isModified = _chatIdController.text.trim() != currentChatId;
    final bool canSave =
        _chatIdController.text.trim().isNotEmpty && (isModified || !isSaved);
    final isLoading = ref.watch(loadingProvider);
    final scale = _mediaScale(context);

    return GlassContainer(
      blur: 18,
      opacity: 0.10,
      padding: EdgeInsets.all(_responsivePadding(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chat ID ထည့်ရန်',
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
                  controller: _chatIdController,
                  keyboardType: TextInputType.number,
                  style: _responsiveTextStyle(
                    context,
                    size: 14,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Chat ID',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintText: 'eg.123456789',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
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
                      borderSide: BorderSide(color: kPrimaryColor, width: 1.5),
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
                        color: Colors.white.withOpacity(canSave ? 0.12 : 0.06),
                      ),
                      child: TextButton(
                        onPressed: (!isLoading && canSave)
                            ? () =>
                                  _controller.saveChatId(_chatIdController.text)
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildTutorialButton(BuildContext context) {
    final scale = _mediaScale(context);
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
        'ဘယ်လိုသုံးရမလဲ?',
        style: TextStyle(
          color: kPrimaryColor,
          fontSize: 15 * scale,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _bgAnimation,
      builder: (context, child) {
        final t = _bgAnimation.value;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kDarkBackgroundColor, Color(0xFF1B2735)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.25 + 40 * (t - 0.5),
              left: -size.width * 0.4,
              child: _HomeGlassBlob(
                width: size.width * 1.0,
                height: size.width * 1.0,
                color: const Color(0xFF4F46E5).withOpacity(0.45),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.28 - 36 * (t - 0.5),
              right: -size.width * 0.35,
              child: _HomeGlassBlob(
                width: size.width * 1.1,
                height: size.width * 1.1,
                color: const Color(0xFF22D3EE).withOpacity(0.40),
              ),
            ),
            Positioned(
              top: size.height * 0.18 + 26 * (t - 0.5),
              right: size.width * 0.18 + 14 * (0.5 - t),
              child: _HomeDrop(
                diameter: size.width * 0.20,
                color: Colors.white.withOpacity(0.22),
              ),
            ),
            Positioned(
              bottom: size.height * 0.20 + 20 * (0.5 - t),
              left: size.width * 0.22 + 16 * (t - 0.5),
              child: _HomeDrop(
                diameter: size.width * 0.16,
                color: Colors.white.withOpacity(0.18),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = ref.watch(urlProvider);

    if (_urlController.text != currentUrl) {
      _urlController.text = currentUrl;
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: _urlController.text.length),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: Stack(
        children: [
          _buildAnimatedBackground(context),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final scale = _mediaScale(context);

                final bool isTablet = width >= 700 && width < 1100;
                final bool isLarge = width >= 1100;

                final horizontalPadding = isLarge
                    ? width * 0.12
                    : (isTablet ? 40.0 : 24.0);
                final verticalPadding = isTablet ? 80.0 : 36.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLarge ? 1000 : (isTablet ? 900 : 620),
                    ),
                    child: isTablet || isLarge
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Icon(
                                      Icons.upload_file,
                                      size: 80 * scale,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    SizedBox(height: 20 * scale),
                                    _buildLinkCard(context, width),
                                    SizedBox(height: 24 * scale),
                                    _buildActionButton(context),
                                    SizedBox(height: 24 * scale),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTutorialButton(context),
                                        ),
                                        SizedBox(width: 12 * scale),
                                        const Expanded(
                                          child: SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 18 * scale),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [_buildConfigPanel(context)],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.upload_file,
                                size: 72 * scale,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              SizedBox(height: 20 * scale),
                              _buildLinkCard(context, width),
                              SizedBox(height: 20 * scale),
                              _buildActionButton(context),
                              SizedBox(height: 20 * scale),
                              _buildConfigPanel(context),
                              SizedBox(height: 16 * scale),
                              _buildTutorialButton(context),
                              SizedBox(height: 26 * scale),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeGlassBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _HomeGlassBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [color, color.withOpacity(0.0)]),
          ),
        ),
      ),
    );
  }
}

class _HomeDrop extends StatelessWidget {
  final double diameter;
  final Color color;

  const _HomeDrop({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [color, color.withOpacity(0.0)]),
          ),
        ),
      ),
    );
  }
}
