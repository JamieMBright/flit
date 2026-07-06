import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/constants/store_urls.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/url_opener.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../core/utils/platform_stub.dart'
    if (dart.library.io) '../../core/utils/platform_native.dart';

/// Full-screen gate shown when the app version is below the required minimum.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore(BuildContext context) async {
    if (kIsWeb) return; // Web is always latest.
    final url = Platform.isIOS ? StoreUrls.appStore : StoreUrls.playStore;
    await UrlOpener.open(context, url, title: 'Update Flit');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      body: SafeArea(
        child: MenuContentWrapper(
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
                      onPressed: () => _openStore(context),
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
      ),
    );
  }
}
