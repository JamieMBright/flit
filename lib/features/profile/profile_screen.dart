import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/web_download.dart';
import '../../core/widgets/settings_sheet.dart';
import '../../core/utils/profanity_filter.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/player.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/account_management_service.dart';
import '../avatar/avatar_editor_screen.dart';
import '../avatar/avatar_widget.dart';
import '../license/license_screen.dart';
import '../../data/services/leaderboard_service.dart';

/// Aviation rank title and icon for player level.
({String title, IconData icon}) _aviationRank(int level) {
  if (level >= 50) {
    return (title: 'Air Marshal', icon: Icons.stars);
  }
  if (level >= 40) {
    return (title: 'Wing Commander', icon: Icons.military_tech);
  }
  if (level >= 30) {
    return (title: 'Squadron Leader', icon: Icons.shield);
  }
  if (level >= 20) {
    return (title: 'Flight Lieutenant', icon: Icons.workspace_premium);
  }
  if (level >= 15) {
    return (title: 'Captain', icon: Icons.anchor);
  }
  if (level >= 10) {
    return (title: 'First Officer', icon: Icons.flight);
  }
  if (level >= 5) {
    return (title: 'Pilot Officer', icon: Icons.flight_takeoff);
  }
  if (level >= 3) {
    return (title: 'Cadet', icon: Icons.school);
  }
  return (title: 'Trainee', icon: Icons.person);
}

/// Profile screen showing player stats and settings.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _openSettings() => showSettingsSheet(context);

  void _editProfile() {
    final currentPlayer = ref.read(accountProvider).currentPlayer;
    final displayNameController = TextEditingController(
      text: currentPlayer.displayName ?? '',
    );
    final usernameController = TextEditingController(
      text: currentPlayer.username,
    );
    String? displayNameError;
    String? usernameError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: FlitColors.cardBorder),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: FlitColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(color: FlitColors.textSecondary),
                  errorText: displayNameError,
                  errorStyle: const TextStyle(color: FlitColors.error),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.accent),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.error),
                  ),
                ),
                onChanged: (_) {
                  if (displayNameError != null) {
                    setDialogState(() => displayNameError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: FlitColors.textSecondary),
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: FlitColors.textMuted),
                  errorText: usernameError,
                  errorStyle: const TextStyle(color: FlitColors.error),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.accent),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.error),
                  ),
                ),
                onChanged: (_) {
                  if (usernameError != null) {
                    setDialogState(() => usernameError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: FlitColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final filter = ProfanityFilter.instance;
                final displayName = displayNameController.text.trim();
                final username = usernameController.text.trim();
                var hasError = false;

                // Validate display name for profanity.
                if (displayName.isNotEmpty &&
                    filter.containsProfanity(displayName)) {
                  setDialogState(() {
                    displayNameError = 'Inappropriate language detected';
                  });
                  hasError = true;
                }

                // Validate username for profanity and format.
                if (username.isNotEmpty &&
                    filter.isInappropriateUsername(username)) {
                  setDialogState(() {
                    usernameError =
                        'Username contains inappropriate content or '
                        'invalid characters';
                  });
                  hasError = true;
                }

                if (hasError) return;

                // Update player via AccountProvider
                ref
                    .read(accountProvider.notifier)
                    .switchAccount(
                      currentPlayer.copyWith(
                        displayName: displayName.isEmpty ? null : displayName,
                        username: username.isEmpty
                            ? currentPlayer.username
                            : username,
                      ),
                    );
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Profile updated'),
                    backgroundColor: FlitColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(color: FlitColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _GameHistoryScreen()));
  }

  void _signOut() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: FlitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // Flush pending preferences before signing out.
              await ref.read(accountProvider.notifier).flushPreferences();
              ref.read(accountProvider.notifier).clearPreferences();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: FlitColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    final player = ref.read(accountProvider).currentPlayer;
    if (player.id.isEmpty || player.id == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data export is not available for guest accounts'),
          backgroundColor: FlitColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ExportDataDialog(
        userId: player.id,
        email: Supabase.instance.client.auth.currentUser?.email,
      ),
    );
  }

  void _deleteAccount() {
    final player = ref.read(accountProvider).currentPlayer;
    if (player.id.isEmpty || player.id == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Account deletion is not available for guest accounts',
          ),
          backgroundColor: FlitColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? '';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DeleteAccountDialog(
        userEmail: userEmail,
        onConfirmDelete: () async {
          Navigator.of(dialogContext).pop();
          await _performAccountDeletion(player.id);
        },
      ),
    );
  }

  Future<void> _performAccountDeletion(String userId) async {
    // Show a loading indicator while deleting.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: FlitColors.accent),
            SizedBox(height: 16),
            Text(
              'Deleting account data...',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    try {
      await AccountManagementService.instance.deleteAccountData(userId);

      // Sign out the Supabase auth session.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Ignore sign-out errors.
      }

      // Clear local state.
      ref.read(accountProvider.notifier).clearPreferences();

      if (context.mounted) {
        // Dismiss the loading dialog.
        Navigator.of(context).pop();
        // Navigate back to the login screen.
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your account has been deleted'),
            backgroundColor: FlitColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss the loading dialog.
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: FlitColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final player = account.currentPlayer;
    final avatarConfig = ref.watch(avatarProvider);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar and name
            _ProfileHeader(player: player, avatarConfig: avatarConfig),
            const SizedBox(height: 24),
            // Level progress
            _LevelProgress(player: player),
            const SizedBox(height: 24),
            // Stats grid
            _StatsGrid(player: player),
            const SizedBox(height: 24),
            // Quick links
            Row(
              children: [
                Expanded(
                  child: _QuickLinkButton(
                    icon: Icons.face,
                    label: 'Avatar',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AvatarEditorScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickLinkButton(
                    icon: Icons.badge,
                    label: 'License',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LicenseScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Actions
            _ProfileActions(
              onEditProfile: _editProfile,
              onGameHistory: _showGameHistory,
              onExportData: _exportData,
              onDeleteAccount: _deleteAccount,
              onSignOut: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.player, required this.avatarConfig});

  final Player player;
  final AvatarConfig avatarConfig;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Avatar
      AvatarWidget(config: avatarConfig, size: 100),
      const SizedBox(height: 16),
      // Name
      Text(
        player.name,
        style: const TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      // Username
      Text(
        '@${player.username}',
        style: const TextStyle(color: FlitColors.textSecondary, fontSize: 14),
      ),
    ],
  );
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _aviationRank(player.level).icon,
                  color: FlitColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _aviationRank(player.level).title,
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Lv.${player.level}',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Text(
              '${player.xp} / ${player.xpForNextLevel} XP',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: player.levelProgress,
            backgroundColor: FlitColors.backgroundMid,
            valueColor: const AlwaysStoppedAnimation<Color>(FlitColors.accent),
            minHeight: 8,
          ),
        ),
      ],
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.player});

  final Player player;

  static String _fmtBestScore(int? score, Duration? time) {
    if (score == null && time == null) return '--';
    final pts = score?.toString() ?? '0';
    if (time == null) return '$pts pts';
    final s = time.inSeconds;
    final ms = (time.inMilliseconds % 1000) ~/ 10;
    return '$pts pts\n${s}.${ms.toString().padLeft(2, '0')}s';
  }

  static String _fmtFlightTime(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top row: Coins, Games, Countries
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.monetization_on,
                iconColor: FlitColors.warning,
                value: player.coins.toString(),
                label: 'Coins',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.games,
                iconColor: FlitColors.accent,
                value: player.gamesPlayed.toString(),
                label: 'Games',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.public,
                iconColor: FlitColors.success,
                value: player.countriesFound.toString(),
                label: 'Found',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bottom row: Best Time, Flight Time
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                iconColor: FlitColors.gold,
                value: _fmtBestScore(player.bestScore, player.bestTime),
                label: 'Best Score',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.flight,
                iconColor: FlitColors.textSecondary,
                value: _fmtFlightTime(player.totalFlightTime),
                label: 'Air Time',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: FlitColors.textMuted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onEditProfile,
    required this.onGameHistory,
    required this.onExportData,
    required this.onDeleteAccount,
    required this.onSignOut,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onGameHistory;
  final VoidCallback onExportData;
  final VoidCallback onDeleteAccount;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ActionButton(
        icon: Icons.edit,
        label: 'Edit Profile',
        onTap: onEditProfile,
      ),
      const SizedBox(height: 12),
      _ActionButton(
        icon: Icons.history,
        label: 'Game History',
        onTap: onGameHistory,
      ),
      const SizedBox(height: 24),
      // Data & Privacy section
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          'DATA & PRIVACY',
          style: TextStyle(
            color: FlitColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      _ActionButton(
        icon: Icons.download,
        label: 'Export My Data',
        onTap: onExportData,
      ),
      const SizedBox(height: 12),
      _ActionButton(
        icon: Icons.delete_forever,
        label: 'Delete Account',
        isDestructive: true,
        onTap: onDeleteAccount,
      ),
      const SizedBox(height: 24),
      _ActionButton(
        icon: Icons.logout,
        label: 'Sign Out',
        isDestructive: true,
        onTap: onSignOut,
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) => Material(
    color: FlitColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? FlitColors.error
                  : FlitColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? FlitColors.error
                    : FlitColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: FlitColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

class _QuickLinkButton extends StatelessWidget {
  const _QuickLinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: FlitColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: FlitColors.accent, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Export Data dialog
// ---------------------------------------------------------------------------

class _ExportDataDialog extends StatefulWidget {
  const _ExportDataDialog({
    required this.userId,
    required this.email,
  });

  final String userId;
  final String? email;

  @override
  State<_ExportDataDialog> createState() => _ExportDataDialogState();
}

class _ExportDataDialogState extends State<_ExportDataDialog> {
  bool _loading = true;
  String? _jsonData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await AccountManagementService.instance.exportUserData(
        userId: widget.userId,
        email: widget.email,
      );
      if (mounted) {
        setState(() {
          _jsonData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to export data: $e';
          _loading = false;
        });
      }
    }
  }

  void _shareData() {
    if (_jsonData == null) return;

    if (WebDownload.isWeb) {
      // On web, trigger a browser download.
      WebDownload.download(_jsonData!, 'flit-data-export.json');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Download started'),
          backgroundColor: FlitColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      // On mobile, copy to clipboard.
      Clipboard.setData(ClipboardData(text: _jsonData!));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data copied to clipboard'),
          backgroundColor: FlitColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: FlitColors.cardBorder),
      ),
      title: const Text(
        'Export My Data',
        style: TextStyle(color: FlitColors.textPrimary),
      ),
      content: _loading
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: FlitColors.accent),
                SizedBox(height: 16),
                Text(
                  'Gathering your data...',
                  style: TextStyle(color: FlitColors.textSecondary),
                ),
              ],
            )
          : _error != null
              ? Text(
                  _error!,
                  style: const TextStyle(color: FlitColors.error),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your data is ready to export. This includes your '
                      'profile, stats, settings, scores history, friends '
                      'list, and challenge history.',
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: FlitColors.backgroundDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: FlitColors.cardBorder),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _jsonData ?? '',
                          style: const TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: FlitColors.textSecondary),
          ),
        ),
        if (!_loading && _error == null)
          TextButton(
            onPressed: _shareData,
            child: Text(
              WebDownload.isWeb ? 'Download JSON' : 'Copy to Clipboard',
              style: const TextStyle(color: FlitColors.accent),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Delete Account dialog
// ---------------------------------------------------------------------------

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({
    required this.userEmail,
    required this.onConfirmDelete,
  });

  final String userEmail;
  final VoidCallback onConfirmDelete;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _emailController = TextEditingController();
  bool _emailMatches = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_checkEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _checkEmail() {
    final matches = _emailController.text.trim().toLowerCase() ==
        widget.userEmail.toLowerCase();
    if (matches != _emailMatches) {
      setState(() => _emailMatches = matches);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: FlitColors.cardBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: FlitColors.error, size: 24),
          SizedBox(width: 8),
          Text(
            'Delete Account',
            style: TextStyle(color: FlitColors.error),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This action is permanent and cannot be undone.',
            style: TextStyle(
              color: FlitColors.error,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'All your data will be permanently deleted, including:',
            style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const _DeletionItem(text: 'Your profile and stats'),
          const _DeletionItem(text: 'All game scores and history'),
          const _DeletionItem(text: 'Friends list and challenges'),
          const _DeletionItem(text: 'Settings and customizations'),
          const _DeletionItem(text: 'Coins and unlocked content'),
          const SizedBox(height: 16),
          Text(
            'Type your email address to confirm:',
            style: TextStyle(
              color: FlitColors.textSecondary.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: FlitColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.userEmail,
              hintStyle: TextStyle(
                color: FlitColors.textMuted.withOpacity(0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FlitColors.error),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: FlitColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _emailMatches ? widget.onConfirmDelete : null,
          child: Text(
            'Delete My Account',
            style: TextStyle(
              color: _emailMatches
                  ? FlitColors.error
                  : FlitColors.textMuted.withOpacity(0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeletionItem extends StatelessWidget {
  const _DeletionItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.remove_circle_outline,
            color: FlitColors.error,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Game History screen showing past game sessions
// ---------------------------------------------------------------------------

class _GameHistoryEntry {
  const _GameHistoryEntry({
    required this.region,
    required this.duration,
    required this.score,
    required this.date,
  });

  final String region;
  final Duration duration;
  final int score;
  final DateTime date;
}

class _GameHistoryScreen extends ConsumerStatefulWidget {
  const _GameHistoryScreen();

  @override
  ConsumerState<_GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<_GameHistoryScreen> {
  List<_GameHistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = ref.read(accountProvider).currentPlayer.id;
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final data = await LeaderboardService.instance.fetchGameHistory(
      userId: userId,
    );
    if (mounted) {
      setState(() {
        _entries = data.map((entry) {
          return _GameHistoryEntry(
            region: (entry['region'] as String?) ?? 'World',
            duration: Duration(milliseconds: entry['time_ms'] as int),
            score: entry['score'] as int,
            date: DateTime.parse(entry['created_at'] as String),
          );
        }).toList();
        _loading = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.backgroundMid,
      title: const Text('Game History'),
      centerTitle: true,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _entries.isEmpty
        ? const Center(
            child: Text(
              'No games played yet',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 16),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlitColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FlitColors.cardBorder),
                ),
                child: Row(
                  children: [
                    // Region icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: FlitColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.public,
                          color: FlitColors.accent,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Region and time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.region,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDuration(entry.duration)}  •  ${_formatDate(entry.date)}',
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          entry.score.toString(),
                          style: const TextStyle(
                            color: FlitColors.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'pts',
                          style: TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
  );
}
