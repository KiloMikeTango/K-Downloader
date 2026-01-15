import 'dart:ui';
import '../widgets/post_download_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/controller/home_controller.dart';
import 'package:video_downloader/widgets/home_action_button.dart';
import 'package:video_downloader/widgets/home_background.dart';
import 'package:video_downloader/widgets/home_config_panel.dart';
import 'package:video_downloader/widgets/home_link_card.dart';
import 'package:video_downloader/widgets/home_tutorial_button.dart';

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

  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _chatIdController = TextEditingController();
    _captionController = TextEditingController();
    _controller = HomeController(ref);
    _controller.loadBotToken();
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

  void _maybeShowPostDownloadDialog() {
    final ready = ref.read(postDownloadReadyProvider);
    final lastVideoPath = ref.read(lastVideoPathProvider);
    final lastAudioPath = ref.read(lastAudioPathProvider);

    if (!ready) return;
    if (lastVideoPath == null && lastAudioPath == null) return;
    if (_dialogShowing) return;

    _dialogShowing = true;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => HomePostDownloadDialog(
        controller: _controller,
        mediaScale: _mediaScale,
      ),
    ).whenComplete(() {
      _dialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = ref.watch(urlProvider);
    final postReady = ref.watch(postDownloadReadyProvider);

    if (_urlController.text != currentUrl) {
      _urlController.text = currentUrl;
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: _urlController.text.length),
      );
    }

    // Trigger dialog after build when ready
    if (postReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowPostDownloadDialog();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: Stack(
        children: [
          HomeAnimatedBackground(animation: _bgAnimation),
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
                                    HomeLinkCard(
                                      controller: _controller,
                                      urlController: _urlController,
                                      captionController: _captionController,
                                      mediaScale: _mediaScale,
                                    ),
                                    SizedBox(height: 24 * scale),
                                    HomeActionButton(
                                      controller: _controller,
                                      mediaScale: _mediaScale,
                                    ),
                                    SizedBox(height: 24 * scale),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: HomeTutorialButton(),
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
                                  children: [
                                    HomeConfigPanel(
                                      controller: _controller,
                                      chatIdController: _chatIdController,
                                      mediaScale: _mediaScale,
                                    ),
                                  ],
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
                              HomeLinkCard(
                                controller: _controller,
                                urlController: _urlController,
                                captionController: _captionController,
                                mediaScale: _mediaScale,
                              ),
                              SizedBox(height: 20 * scale),
                              HomeActionButton(
                                controller: _controller,
                                mediaScale: _mediaScale,
                              ),
                              SizedBox(height: 20 * scale),
                              HomeConfigPanel(
                                controller: _controller,
                                chatIdController: _chatIdController,
                                mediaScale: _mediaScale,
                              ),
                              SizedBox(height: 16 * scale),
                              const HomeTutorialButton(),
                              SizedBox(height: 13.5 * scale),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.language,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      final current = context.locale;
                                      if (current.languageCode == 'en') {
                                        context.setLocale(
                                          const Locale('my', 'MM'),
                                        );
                                      } else {
                                        context.setLocale(
                                          const Locale('en', 'EN'),
                                        );
                                      }
                                    },
                                  ),
                                  Text('language'.tr()),
                                ],
                              ),
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
