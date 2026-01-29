import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/controllers/home_controller.dart';
import 'package:video_downloader/models/enums.dart';
import 'package:video_downloader/providers/home_providers.dart';

class PostDownloadOptionsDialog extends ConsumerStatefulWidget {
  final HomeController controller;
  final String videoPath;

  const PostDownloadOptionsDialog({
    super.key,
    required this.controller,
    required this.videoPath,
  });

  @override
  ConsumerState<PostDownloadOptionsDialog> createState() =>
      _PostDownloadOptionsDialogState();
}

class _PostDownloadOptionsDialogState
    extends ConsumerState<PostDownloadOptionsDialog> {
  DownloadMode selectedMode = DownloadMode.video;
  bool isTelegramDestination = true;
  bool useCaption = false;
  bool _isProcessing = false;
  int _saveCount = 0;

  final Color glassBorder = Colors.white.withOpacity(0.2);
  final Color accentBlue = const Color(0xFF42A5F5);

  String get _fileSize {
    try {
      final file = File(widget.videoPath);
      final bytes = file.lengthSync();
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '0 MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 360;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: size.width > 500 ? 420 : double.infinity,
          constraints: BoxConstraints(maxHeight: size.height * 0.8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: glassBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(isCompact),
                Flexible(
                  child: _isProcessing
                      ? _buildProgressSection()
                      : _buildOptionsSection(isCompact),
                ),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Stack(
      children: [
        Container(
          height: isCompact ? 120 : 160,
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0x0A1E3A)),
          child: Image.file(
            File(widget.videoPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.movie, size: 40, color: glassBorder),
          ),
        ),
        Container(
          height: isCompact ? 120 : 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _saveCount > 0 ? 'Saved $_saveCount times' : 'Ready to Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fileSize,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(bool isCompact) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Destination'),
          const SizedBox(height: 10),
          _buildDestinationToggle(),
          const SizedBox(height: 20),

          _label(isTelegramDestination ? 'Selection Mode' : 'Gallery Format'),
          const SizedBox(height: 10),
          _buildFormatGrid(isCompact),
          const SizedBox(height: 20),

          _label('Caption'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => useCaption = !useCaption),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: glassBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    useCaption
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: accentBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Save with caption',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: accentBlue,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDestinationToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glassBorder),
      ),
      child: Row(
        children: [
          _toggleBtn('Telegram', true, Icons.telegram),
          _toggleBtn('Gallery', false, Icons.smartphone),
        ],
      ),
    );
  }

  Widget _toggleBtn(String title, bool value, IconData icon) {
    final isSelected = isTelegramDestination == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isTelegramDestination = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentBlue.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? accentBlue : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatGrid(bool isCompact) {
    final modes = isTelegramDestination
        ? [DownloadMode.video, DownloadMode.audio, DownloadMode.both]
        : [DownloadMode.video];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: modes.map((m) {
        final isSelected = selectedMode == m;
        return GestureDetector(
          onTap: () => setState(() => selectedMode = m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentBlue.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? accentBlue : glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIcon(m),
                  size: 16,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
                const SizedBox(width: 8),
                Text(
                  _getLabel(m),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgressSection() {
    final progress = ref.watch(downloadProgressProvider);
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            ref.watch(messageProvider),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _handleCancel,
              icon: const Icon(Icons.close, color: Colors.white54),
              label: Text(_saveCount > 0 ? 'Close ($_saveCount)' : 'Discard'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleContinue,
              icon: _isProcessing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isProcessing ? 'Saving...' : 'Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLabel(DownloadMode m) {
    if (m == DownloadMode.video) return 'Video';
    if (m == DownloadMode.audio) return 'Audio Only';
    return 'Video + Audio';
  }

  IconData _getIcon(DownloadMode m) {
    if (m == DownloadMode.video) return Icons.videocam;
    if (m == DownloadMode.audio) return Icons.audiotrack;
    return Icons.auto_awesome_motion;
  }

  void _handleCancel() {
    File(widget.videoPath).delete();
    Navigator.pop(context);
  }

  Future<void> _handleContinue() async {
    setState(() => _isProcessing = true);

    try {
      ref.read(saveWithCaptionProvider.notifier).state = useCaption;
      ref.read(downloadModeProvider.notifier).state = selectedMode;

      switch (selectedMode) {
        case DownloadMode.video:
          ref.read(lastVideoPathProvider.notifier).state = widget.videoPath;
          ref.read(lastAudioPathProvider.notifier).state = null;
          break;

        case DownloadMode.audio:
          ref.read(transferPhaseProvider.notifier).state =
              TransferPhase.extracting;
          final service = ref.read(downloadServiceProvider);
          final audioPath = await service.extractMp3FromVideo(widget.videoPath);
          if (audioPath != null) {
            await File(widget.videoPath).delete();
            ref.read(lastVideoPathProvider.notifier).state = null;
            ref.read(lastAudioPathProvider.notifier).state = audioPath;
          }
          break;

        case DownloadMode.both:
          ref.read(lastVideoPathProvider.notifier).state = widget.videoPath;
          ref.read(transferPhaseProvider.notifier).state =
              TransferPhase.extracting;
          final service = ref.read(downloadServiceProvider);
          final audioPath = await service.extractMp3FromVideo(widget.videoPath);
          if (audioPath != null) {
            ref.read(lastAudioPathProvider.notifier).state = audioPath;
          }
          break;
      }

      if (isTelegramDestination) {
        await widget.controller.handleSaveToTelegram();
      } else {
        await widget.controller.handleSaveToGallery();
      }

      setState(() {
        _isProcessing = false;
        _saveCount++;
        selectedMode = DownloadMode.video;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved to ${isTelegramDestination ? "Telegram" : "Gallery"} ✓',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
