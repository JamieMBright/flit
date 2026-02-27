import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/flit_colors.dart';

/// Full-screen "Account Suspended" display.
///
/// Shown when a user's profile has a non-null `banned_at` with either
/// no `ban_expires_at` (permanent) or a future expiry (temporary).
class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key, this.banReason, this.banExpiresAt});

  final String? banReason;
  final DateTime? banExpiresAt;

  bool get _isPermanent => banExpiresAt == null;

  String get _expiryText {
    if (_isPermanent) return 'This ban is permanent.';
    final remaining = banExpiresAt!.difference(DateTime.now());
    if (remaining.isNegative)
      return 'Your ban has expired. Please restart the app.';
    if (remaining.inDays > 0) return 'Expires in ${remaining.inDays} day(s).';
    if (remaining.inHours > 0)
      return 'Expires in ${remaining.inHours} hour(s).';
    return 'Expires in ${remaining.inMinutes} minute(s).';
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
                const Icon(Icons.gavel, color: FlitColors.error, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Account Suspended',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (banReason != null && banReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlitColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlitColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      banReason!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _expiryText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: 'support@flit.app',
                      queryParameters: {'subject': 'Account Suspension Appeal'},
                    );
                    launchUrl(uri);
                  },
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Contact Support'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlitColors.textSecondary,
                    side: const BorderSide(color: FlitColors.cardBorder),
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
