import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/app_remote_config.dart';
import '../../data/services/app_config_service.dart';

/// Full-screen display when the server is in maintenance mode.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.message});

  final String? message;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      final compat = await AppConfigService.instance.checkCompatibility();
      if (!mounted) return;
      if (compat == AppCompatibility.ok ||
          compat == AppCompatibility.updateRecommended) {
        // Maintenance is over — pop back to let the auth flow continue.
        Navigator.of(context).pop();
      } else {
        setState(() => _checking = false);
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
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
                  Icons.construction,
                  color: FlitColors.warning,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Under Maintenance',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message ??
                      'Flit is temporarily down for maintenance. '
                          'Please check back shortly.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checking ? null : _retry,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FlitColors.textPrimary,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_checking ? 'Checking...' : 'Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.warning,
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
