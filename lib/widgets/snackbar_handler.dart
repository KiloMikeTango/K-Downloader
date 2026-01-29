import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_downloader/providers/home_providers.dart';
import 'package:video_downloader/models/enums.dart';

class SnackbarHandler extends ConsumerWidget {
  final Widget child;

  const SnackbarHandler({
    super.key,
    required this.child,
  });

  void _showSnackbar(BuildContext context, WidgetRef ref, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //Smart filtering: NO snackbar during download, ONLY final states
    ref.listen(messageProvider, (prev, next) {
      if (next.isNotEmpty) {
        final phase = ref.read(transferPhaseProvider);
        
        // ✅ SHOW snackbar ONLY for final states, NOT during active operations
        final shouldShowSnackbar = 
            phase == TransferPhase.idle &&  // Completed/Reset
            !next.contains('Downloading') &&  // ❌ No "Downloading..." 
            !next.contains('Extracting') &&   // ❌ No "Extracting..."
            !next.contains('Uploading');      // ❌ No "Sending to Telegram..."

        if (shouldShowSnackbar) {
          final isError = next.contains('Error') || 
                         next.contains('failed') || 
                         next.contains('cancelled') ||
                         next.contains('cancel');
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSnackbar(context, ref, next, isError: isError);
          });
        }
        
        // Clear message after processing
        ref.read(messageProvider.notifier).state = '';
      }
    });

    return child;
  }
}
