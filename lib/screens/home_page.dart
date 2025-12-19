import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_downloader/constant.dart';
import 'package:video_downloader/screens/tutorial_page.dart';
import 'package:video_downloader/service/download_service.dart';
import 'package:video_downloader/service/database_service.dart';
import 'package:video_downloader/secrets.dart';

// --- State Providers ---
final urlProvider = StateProvider<String>((ref) => '');
final tokenProvider = StateProvider<String>((ref) => kBotToken);
final chatIdProvider = StateProvider<String>((ref) => '');
final loadingProvider = StateNotifierProvider<StateController<bool>, bool>(
  (ref) => StateController(false),
);
final messageProvider = StateNotifierProvider<StateController<String>, String>(
  (ref) => StateController(''),
);
final downloadServiceProvider = Provider((ref) => DownloadService());
final databaseServiceProvider = Provider((ref) => DatabaseService());
final isChatIdSavedProvider = StateProvider<bool>((ref) => false);

// --- Glass Container Widget ---
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsets padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15,
    this.opacity = 0.05,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: kGlassBaseColor.withOpacity(opacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kGlassBaseColor.withOpacity(0.08),
              width: 1.2,
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

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _urlController;
  late final TextEditingController _chatIdController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _chatIdController = TextEditingController();
    _loadSavedChatId();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  String _cleanYoutubeUrl(String url) {
    if (!(url.contains('youtu.be') || url.contains('youtube.com'))) {
      return url;
    }
    final queryIndex = url.indexOf('?');
    if (queryIndex != -1) {
      return url.substring(0, queryIndex);
    }
    return url;
  }

  Future<void> _loadSavedChatId() async {
    final savedId = await ref.read(databaseServiceProvider).getChatId();
    if (savedId != null && savedId.isNotEmpty) {
      ref.read(chatIdProvider.notifier).state = savedId;
      _chatIdController.text = savedId;
      ref.read(isChatIdSavedProvider.notifier).state = true;
    }
  }

  void _saveChatId() async {
    final chatId = _chatIdController.text.trim();
    if (chatId.isEmpty) {
      ref.read(messageProvider.notifier).state =
          'Chat ID ထည့်ရန်လိုအပ်ပါသည်။';
      return;
    }
    try {
      await ref.read(databaseServiceProvider).saveChatId(chatId);
      ref.read(chatIdProvider.notifier).state = chatId;
      ref.read(isChatIdSavedProvider.notifier).state = true;
      ref.read(messageProvider.notifier).state = 'Chat ID သိမ်းပြီးပါပြီ။';
    } catch (e) {
      ref.read(messageProvider.notifier).state = 'Chat ID သိမ်း၍မရပါ။';
    }
  }

  String _getLinkType(String url) {
    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      return 'youtube';
    }
    if (url.contains('facebook.com') || url.contains('fb.watch')) {
      return 'facebook';
    }
    if (url.contains('tiktok.com')) {
      return 'tiktok';
    }
    return 'invalid';
  }

  void _handleDownload() async {
    final url = ref.read(urlProvider);
    final service = ref.read(downloadServiceProvider);

    final linkType = _getLinkType(url);
    if (linkType == 'invalid') {
      ref.read(messageProvider.notifier).state = 'လင့်မထည့်ရသေးပါ။';
      return;
    }

    ref.read(loadingProvider.notifier).state = true;
    ref.read(messageProvider.notifier).state = 'Download လုပ်နေပါသည်...';
    String? tempFilePath;

    try {
      final token = ref.read(tokenProvider);
      final chatId = ref.read(chatIdProvider);

      if (token.isEmpty || chatId.isEmpty) {
        throw Exception('Chat ID မထည့်ရသေးပါ။');
      }

      if (linkType == 'youtube') {
        final cleanUrl = _cleanYoutubeUrl(url);
        tempFilePath = await service.downloadVideo(cleanUrl);
      } else if (linkType == 'facebook') {
        tempFilePath = await service.downloadFacebookVideo(url);
      } else if (linkType == 'tiktok') {
        tempFilePath = await service.downloadTiktokVideo(url);
      }

      ref.read(messageProvider.notifier).state =
          'Download လုပ်ပြီးပါပြီ၊ Telegram သို့ Video ပို့နေပါသည်...';

      await service.saveToBot(tempFilePath!, token, chatId);
      ref.read(messageProvider.notifier).state =
          'Telegram သို့ Video ပို့ပြီးပါပြီ။';
      _urlController.clear();
    } catch (e) {
      ref.read(messageProvider.notifier).state = 'Error: ${e.toString()}';
      if (tempFilePath != null && await File(tempFilePath).exists()) {
        await File(tempFilePath).delete();
        _urlController.clear();
      }
    } finally {
      ref.read(urlProvider.notifier).state = '';
      ref.read(loadingProvider.notifier).state = false;
    }
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

  Widget _buildLinkCard(BuildContext context, double width) {
    final isLoading = ref.watch(loadingProvider);
    final message = ref.watch(messageProvider);

    return GlassContainer(
      blur: 10,
      opacity: 0.06,
      padding: EdgeInsets.symmetric(
        horizontal: _responsivePadding(context, 18),
        vertical: _responsivePadding(context, 20),
      ),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
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
              fillColor: kGlassBaseColor.withOpacity(0.08),
              prefixIcon: Icon(
                Icons.link,
                color: Colors.white.withOpacity(0.6),
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
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kPrimaryColor, width: 1.8),
              ),
            ),
            onChanged: (value) {
              final cleanedValue = _cleanYoutubeUrl(value);
              if (cleanedValue != value) {
                _urlController.text = cleanedValue;
                _urlController.selection = TextSelection.fromPosition(
                  TextPosition(offset: cleanedValue.length),
                );
              }
              ref.read(urlProvider.notifier).state = cleanedValue;
            },
          ),
          SizedBox(height: _responsivePadding(context, 18)),
          if (ref.watch(loadingProvider))
            LinearProgressIndicator(color: kPrimaryColor),
          SizedBox(height: _responsivePadding(context, 12)),
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
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final isLoading = ref.watch(loadingProvider);
    final scale = _mediaScale(context);

    return SizedBox(
      height: 50 * scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 23, 94, 192),
              Color.fromARGB(255, 38, 94, 212),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10 * scale),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 30, 153, 234).withOpacity(0.35),
              blurRadius: 18 * scale,
              offset: Offset(0, 6 * scale),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : _handleDownload,
            borderRadius: BorderRadius.circular(14 * scale),
            child: Center(
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
    );
  }

  Widget _buildConfigPanel(BuildContext context) {
    final isSaved = ref.watch(isChatIdSavedProvider);
    final currentChatId = ref.watch(chatIdProvider);
    final bool isModified = _chatIdController.text.trim() != currentChatId;
    final bool canSave =
        _chatIdController.text.trim().isNotEmpty && (isModified || !isSaved);
    final scale = _mediaScale(context);

    return GlassContainer(
      blur: 10,
      opacity: 0.06,
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
              color: kGlassBaseColor,
            ),
          ),
          SizedBox(height: _responsivePadding(context, 12)),
          Row(
            children: [
              Expanded(
                child: TextField(
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
                    fillColor: kDarkBackgroundColor.withOpacity(0.4),
                    prefixIcon: Icon(
                      Icons.chat_bubble,
                      color: kAccentColor.withOpacity(0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                child: ElevatedButton(
                  onPressed: canSave ? _saveChatId : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSaved ? Colors.grey : kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10 * scale),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final currentUrl = ref.watch(urlProvider);

    if (currentUrl.isNotEmpty && _urlController.text != currentUrl) {
      _urlController.text = currentUrl;
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: _urlController.text.length),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(backgroundColor: kDarkBackgroundColor, elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kDarkBackgroundColor, Color(0xFF212121)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  size: 80 * scale,
                                  color: kPrimaryColor,
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
                            color: kPrimaryColor,
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
    );
  }
}
