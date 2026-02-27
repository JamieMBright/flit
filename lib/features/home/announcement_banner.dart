import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/announcement.dart';
import '../../data/services/announcement_service.dart';

/// Returns the background color for a given announcement type.
Color _typeColor(String type) {
  switch (type) {
    case 'warning':
      return const Color(0xFFB87D00); // amber/orange
    case 'event':
      return FlitColors.success; // accent green
    case 'maintenance':
      return FlitColors.error; // red
    case 'info':
    default:
      return const Color(0xFF2A6FA8); // subtle blue
  }
}

/// Returns the icon for a given announcement type.
IconData _typeIcon(String type) {
  switch (type) {
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'event':
      return Icons.celebration_rounded;
    case 'maintenance':
      return Icons.build_rounded;
    case 'info':
    default:
      return Icons.info_outline_rounded;
  }
}

/// A dismissible banner that shows the highest-priority active announcement.
///
/// Fetches active announcements from [AnnouncementService] on init, filters
/// dismissed ones, and displays the top-priority entry. Animates in and out
/// with [AnimatedSize]. Returns a shrunk widget when there is nothing to show.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  /// The announcement currently shown, or null when none remain / still loading.
  Announcement? _current;

  /// True while the initial load is in progress.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await AnnouncementService.instance.fetchActive();

      // Filter out any that the user has already dismissed.
      final visible = <Announcement>[];
      for (final a in all) {
        final dismissed = await AnnouncementService.instance.isDismissed(a.id);
        if (!dismissed) {
          visible.add(a);
        }
      }

      // fetchActive() already orders by priority desc, so first entry wins.
      if (mounted) {
        setState(() {
          _current = visible.isNotEmpty ? visible.first : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _dismiss() async {
    final announcement = _current;
    if (announcement == null) return;

    await AnnouncementService.instance.dismiss(announcement.id);

    if (mounted) {
      setState(() {
        _current = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // While loading or nothing to show, collapse the widget to zero height.
    final announcement = _current;
    final visible = !_loading && announcement != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: visible
          ? _BannerContent(announcement: announcement, onDismiss: _dismiss)
          : const SizedBox.shrink(),
    );
  }
}

/// The visual card for a single announcement. Kept as a separate widget so
/// [AnimatedSize] can cleanly animate when it is swapped in and out.
class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.announcement, required this.onDismiss});

  final Announcement announcement;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(announcement.type);
    final icon = _typeIcon(announcement.type);

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),

                // Title + body text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        announcement.title,
                        style: TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        announcement.body,
                        style: const TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dismiss (X) button
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: FlitColors.textMuted,
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
