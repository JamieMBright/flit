import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/flit_colors.dart';

/// Full-screen gate shown when the app version is below the required minimum.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  void _openStore() {
    // Replace with actual App Store / Play Store URLs when published.
    final Uri storeUrl;
    if (kIsWeb) {
      return; // Web is always latest.
    } else if (Platform.isIOS) {
      storeUrl = Uri.parse('https://apps.apple.com/app/flit/idXXXXXXXXXX');
    } else {
      storeUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=app.flit',
      );
    }
    launchUrl(storeUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update,
                  color: FlitColors.accent,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Update Required',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A new version of Flit is available. Please update to '
                  'continue playing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                if (!kIsWeb)
                  ElevatedButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Update Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
