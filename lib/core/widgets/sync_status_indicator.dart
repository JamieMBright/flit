import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/user_preferences_service.dart';
import '../theme/flit_colors.dart';

/// A small indicator that appears when there are failed writes in the offline
/// queue. Shows a warning icon with the count of pending writes.
///
/// Polls [UserPreferencesService] every 5 seconds and only renders when
/// there are pending offline writes (i.e. failed writes waiting for retry).
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  Timer? _timer;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final count = UserPreferencesService.instance.pendingOfflineCount;
    if (count != _pendingCount && mounted) {
      setState(() => _pendingCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCount == 0) return const SizedBox.shrink();

    return Tooltip(
      message: '$_pendingCount pending sync writes',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FlitColors.warning.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.warning.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem, color: FlitColors.warning, size: 14),
            const SizedBox(width: 4),
            Text(
              '$_pendingCount',
              style: const TextStyle(
                color: FlitColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
