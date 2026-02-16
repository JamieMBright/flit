import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/settings_sheet.dart';
import '../../core/utils/profanity_filter.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/player.dart';
import '../../data/providers/account_provider.dart';
import '../avatar/avatar_editor_screen.dart';
import '../avatar/avatar_widget.dart';
import '../license/license_screen.dart';

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
    final displayNameController =
        TextEditingController(text: currentPlayer.displayName ?? '');
    final usernameController = TextEditingController(text: currentPlayer.username);
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
                  labelStyle:
                      const TextStyle(color: FlitColors.textSecondary),
                  errorText: displayNameError,
                  errorStyle: const TextStyle(color: FlitColors.error),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: FlitColors.cardBorder),
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
                  labelStyle:
                      const TextStyle(color: FlitColors.textSecondary),
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: FlitColors.textMuted),
                  errorText: usernameError,
                  errorStyle: const TextStyle(color: FlitColors.error),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: FlitColors.cardBorder),
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
                ref.read(accountProvider.notifier).switchAccount(
                  currentPlayer.copyWith(
                    displayName:
                        displayName.isEmpty ? null : displayName,
                    username:
                        username.isEmpty ? currentPlayer.username : username,
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _GameHistoryScreen(),
      ),
    );
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
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
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
              _ProfileHeader(
                player: player,
                avatarConfig: avatarConfig,
              ),
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
                onSignOut: _signOut,
              ),
            ],
          ),
        ),
      );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.player,
    required this.avatarConfig,
  });

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
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
            ),
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

  static String _fmtTime(Duration? d) {
    if (d == null) return '--';
    final s = d.inSeconds;
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    return '${s}.${ms.toString().padLeft(2, '0')}s';
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
        // Bottom row: Licensed Time, Unlicensed Time, Flight Time
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.badge,
                iconColor: FlitColors.gold,
                value: _fmtTime(player.bestTimeLicensed),
                label: 'Licensed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.timer,
                iconColor: FlitColors.accent,
                value: _fmtTime(player.bestTimeUnlicensed),
                label: 'Unlicensed',
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
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onEditProfile,
    required this.onGameHistory,
    required this.onSignOut,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onGameHistory;
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
          const SizedBox(height: 12),
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
                  color: isDestructive ? FlitColors.error : FlitColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isDestructive ? FlitColors.error : FlitColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: FlitColors.textMuted,
                ),
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

class _GameHistoryScreen extends StatelessWidget {
  const _GameHistoryScreen();

  static final List<_GameHistoryEntry> _entries = [
    _GameHistoryEntry(
      region: 'Western Europe',
      duration: const Duration(minutes: 2, seconds: 14),
      score: 920,
      date: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _GameHistoryEntry(
      region: 'East Africa',
      duration: const Duration(minutes: 3, seconds: 45),
      score: 750,
      date: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    _GameHistoryEntry(
      region: 'South-East Asia',
      duration: const Duration(minutes: 1, seconds: 58),
      score: 1100,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _GameHistoryEntry(
      region: 'South America',
      duration: const Duration(minutes: 4, seconds: 12),
      score: 640,
      date: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    ),
    _GameHistoryEntry(
      region: 'Scandinavia',
      duration: const Duration(minutes: 2, seconds: 33),
      score: 880,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _GameHistoryEntry(
      region: 'Central Asia',
      duration: const Duration(minutes: 5, seconds: 1),
      score: 520,
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    _GameHistoryEntry(
      region: 'Caribbean',
      duration: const Duration(minutes: 2, seconds: 47),
      score: 810,
      date: DateTime.now().subtract(const Duration(days: 4)),
    ),
    _GameHistoryEntry(
      region: 'Oceania',
      duration: const Duration(minutes: 3, seconds: 19),
      score: 700,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    _GameHistoryEntry(
      region: 'Middle East',
      duration: const Duration(minutes: 2, seconds: 5),
      score: 960,
      date: DateTime.now().subtract(const Duration(days: 6)),
    ),
    _GameHistoryEntry(
      region: 'North America',
      duration: const Duration(minutes: 1, seconds: 42),
      score: 1200,
      date: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

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
        body: ListView.separated(
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
