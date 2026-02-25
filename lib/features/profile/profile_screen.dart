import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/web_download.dart';
import '../../core/widgets/settings_sheet.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../core/utils/profanity_filter.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/player.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/account_management_service.dart';
import '../../data/services/auth_service.dart';
import '../auth/login_screen.dart';
import '../avatar/avatar_editor_screen.dart';
import '../avatar/avatar_widget.dart';
import '../license/license_screen.dart';
import '../../core/widgets/social_titles_card.dart';
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
  bool _isRefreshingProfile = false;
  int? _bestDailyScore;
  Duration? _bestDailyTime;
  int? _bestTrainingScore;
  Duration? _bestTrainingTime;

  @override
  void initState() {
    super.initState();
    // Pull latest server state so profile stats are always current.
    ref.read(accountProvider.notifier).refreshFromServer();
    _loadBestScores();
  }

  Future<void> _loadBestScores() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final best = await LeaderboardService.instance.fetchBestScoresByMode(
      userId,
    );
    if (!mounted) return;
    setState(() {
      final daily = best['daily'];
      if (daily != null) {
        _bestDailyScore = daily['score'];
        _bestDailyTime = Duration(milliseconds: daily['time_ms'] ?? 0);
      }
      final training = best['training'];
      if (training != null) {
        _bestTrainingScore = training['score'];
        _bestTrainingTime = Duration(milliseconds: training['time_ms'] ?? 0);
      }
    });
  }

  void _openSettings() => showSettingsSheet(context);

  Future<void> _refreshProfile() async {
    if (_isRefreshingProfile) return;
    setState(() => _isRefreshingProfile = true);
    try {
      await ref.read(accountProvider.notifier).refreshFromServer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile refreshed from server'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[ProfileScreen] refresh failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to refresh profile. Please try again.'),
          backgroundColor: FlitColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRefreshingProfile = false);
    }
  }

  void _editProfile() {
    final currentPlayer = ref.read(accountProvider).currentPlayer;
    final usernameController = TextEditingController(
      text: currentPlayer.username,
    );
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
            'Change Username',
            style: TextStyle(color: FlitColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                final username = usernameController.text.trim();
                var hasError = false;

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
                        username: username.isEmpty
                            ? currentPlayer.username
                            : username,
                      ),
                    );
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Username updated'),
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

  void _showNationalityPicker() {
    final currentNationality = ref.read(accountProvider).license.nationality;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlitColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NationalityPickerSheet(
        currentCode: currentNationality,
        onSelected: (code) {
          ref.read(accountProvider.notifier).updateNationality(code);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nationality updated'),
              backgroundColor: FlitColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showGameHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _GameHistoryScreen()));
  }

  void _changePassword() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? error;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

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
            'Change Password',
            style: TextStyle(color: FlitColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FlitColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: FlitColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: FlitColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: FlitColors.textSecondary),
                  hintText: 'At least 6 characters',
                  hintStyle: const TextStyle(color: FlitColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: FlitColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.accent),
                  ),
                ),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: const TextStyle(color: FlitColors.textSecondary),
                  hintText: 'Re-enter new password',
                  hintStyle: const TextStyle(color: FlitColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: FlitColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.accent),
                  ),
                ),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: FlitColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newPwd = newPasswordController.text;
                      final confirmPwd = confirmPasswordController.text;

                      if (newPwd.length < 6) {
                        setDialogState(() {
                          error = 'Password must be at least 6 characters';
                        });
                        return;
                      }
                      if (newPwd != confirmPwd) {
                        setDialogState(() {
                          error = 'Passwords do not match';
                        });
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final result = await AuthService().changePassword(
                        newPassword: newPwd,
                      );

                      if (!dialogContext.mounted) return;

                      if (result.error != null) {
                        setDialogState(() {
                          error = result.error;
                          isLoading = false;
                        });
                      } else {
                        Navigator.of(dialogContext).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Password changed'),
                              backgroundColor: FlitColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FlitColors.accent,
                      ),
                    )
                  : const Text(
                      'Change Password',
                      style: TextStyle(color: FlitColors.accent),
                    ),
            ),
          ],
        ),
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
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // Flush pending preferences before signing out.
              await ref.read(accountProvider.notifier).flushPreferences();
              // Clear the Supabase auth session so auto-login doesn't
              // immediately re-authenticate on the login screen.
              await AuthService().signOut();
              ref.read(accountProvider.notifier).clearPreferences();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
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
          content: const Text(
            'Data export is not available for guest accounts',
          ),
          backgroundColor: FlitColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        currentPlayer: player,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );

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
          const SyncStatusIndicator(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _isRefreshingProfile ? null : _refreshProfile,
            icon: _isRefreshingProfile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
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
            _StatsGrid(
              player: player,
              bestDailyScore: _bestDailyScore,
              bestDailyTime: _bestDailyTime,
              bestTrainingScore: _bestTrainingScore,
              bestTrainingTime: _bestTrainingTime,
            ),
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
            // Nationality
            _NationalitySection(
              nationality: account.license.nationality,
              onTap: () => _showNationalityPicker(),
            ),
            const SizedBox(height: 24),
            // Social titles
            const SocialTitlesCard(),
            const SizedBox(height: 24),
            // Actions
            _ProfileActions(
              onEditProfile: _editProfile,
              onChangePassword: _changePassword,
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
  const _StatsGrid({
    required this.player,
    this.bestDailyScore,
    this.bestDailyTime,
    this.bestTrainingScore,
    this.bestTrainingTime,
  });

  final Player player;
  final int? bestDailyScore;
  final Duration? bestDailyTime;
  final int? bestTrainingScore;
  final Duration? bestTrainingTime;

  static String _fmtBestScore(int? score, Duration? time) {
    if (score == null && time == null) return '--';
    final pts = score?.toString() ?? '0';
    if (time == null) return '$pts pts';
    final s = time.inSeconds;
    final ms = (time.inMilliseconds % 1000) ~/ 10;
    return '$pts pts\n$s.${ms.toString().padLeft(2, '0')}s';
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
        // Middle row: Daily Best, Training Best
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today,
                iconColor: FlitColors.gold,
                value: _fmtBestScore(bestDailyScore, bestDailyTime),
                label: 'Daily Best',
                valueSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                iconColor: FlitColors.accent,
                value: _fmtBestScore(bestTrainingScore, bestTrainingTime),
                label: 'Training Best',
                valueSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bottom row: Air Time
        Row(
          children: [
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
    this.valueSize = 20,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final double valueSize;

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
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: valueSize,
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
    required this.onChangePassword,
    required this.onGameHistory,
    required this.onExportData,
    required this.onDeleteAccount,
    required this.onSignOut,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
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
        icon: Icons.lock_outline,
        label: 'Change Password',
        onTap: onChangePassword,
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
// Nationality Section
// ---------------------------------------------------------------------------

class _NationalitySection extends StatelessWidget {
  const _NationalitySection({required this.nationality, required this.onTap});

  final String? nationality;
  final VoidCallback onTap;

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
            if (nationality != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 32,
                  height: 22,
                  child: Flag.fromString(
                    nationality!,
                    height: 22,
                    width: 32,
                    fit: BoxFit.cover,
                    borderRadius: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nationality',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _NationalityPickerSheet.countryNameForCode(
                            nationality!,
                          ) ??
                          nationality!,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Icon(Icons.flag_outlined, color: FlitColors.textSecondary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Set Nationality',
                  style: TextStyle(color: FlitColors.textPrimary, fontSize: 16),
                ),
              ),
            ],
            const Icon(Icons.chevron_right, color: FlitColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Nationality Picker Bottom Sheet
// ---------------------------------------------------------------------------

class _NationalityPickerSheet extends StatefulWidget {
  const _NationalityPickerSheet({
    required this.currentCode,
    required this.onSelected,
  });

  final String? currentCode;
  final void Function(String code) onSelected;

  /// Look up a country name by its ISO alpha-2 code.
  static String? countryNameForCode(String code) {
    final upper = code.toUpperCase();
    for (final entry in _countries) {
      if (entry.code == upper) return entry.name;
    }
    return null;
  }

  @override
  State<_NationalityPickerSheet> createState() =>
      _NationalityPickerSheetState();
}

class _NationalityPickerSheetState extends State<_NationalityPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CountryEntry> get _filtered {
    if (_query.isEmpty) return _countries;
    final lower = _query.toLowerCase();
    return _countries
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) ||
              c.code.toLowerCase().contains(lower),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FlitColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Nationality',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: FlitColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                hintStyle: const TextStyle(color: FlitColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: FlitColors.textMuted,
                ),
                filled: true,
                fillColor: FlitColors.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FlitColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FlitColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FlitColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          // Country list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final country = _filtered[index];
                final isSelected = country.code == widget.currentCode;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 32,
                      height: 22,
                      child: Flag.fromString(
                        country.code,
                        height: 22,
                        width: 32,
                        fit: BoxFit.cover,
                        borderRadius: 3,
                      ),
                    ),
                  ),
                  title: Text(
                    country.name,
                    style: TextStyle(
                      color: isSelected
                          ? FlitColors.accent
                          : FlitColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: FlitColors.accent)
                      : null,
                  onTap: () => widget.onSelected(country.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple country entry for the nationality picker.
class _CountryEntry {
  const _CountryEntry(this.code, this.name);

  final String code;
  final String name;
}

/// Static list of countries with ISO 3166-1 alpha-2 codes.
const List<_CountryEntry> _countries = [
  _CountryEntry('AF', 'Afghanistan'),
  _CountryEntry('AL', 'Albania'),
  _CountryEntry('DZ', 'Algeria'),
  _CountryEntry('AD', 'Andorra'),
  _CountryEntry('AO', 'Angola'),
  _CountryEntry('AG', 'Antigua and Barbuda'),
  _CountryEntry('AR', 'Argentina'),
  _CountryEntry('AM', 'Armenia'),
  _CountryEntry('AU', 'Australia'),
  _CountryEntry('AT', 'Austria'),
  _CountryEntry('AZ', 'Azerbaijan'),
  _CountryEntry('BS', 'Bahamas'),
  _CountryEntry('BH', 'Bahrain'),
  _CountryEntry('BD', 'Bangladesh'),
  _CountryEntry('BB', 'Barbados'),
  _CountryEntry('BY', 'Belarus'),
  _CountryEntry('BE', 'Belgium'),
  _CountryEntry('BZ', 'Belize'),
  _CountryEntry('BJ', 'Benin'),
  _CountryEntry('BT', 'Bhutan'),
  _CountryEntry('BO', 'Bolivia'),
  _CountryEntry('BA', 'Bosnia and Herzegovina'),
  _CountryEntry('BW', 'Botswana'),
  _CountryEntry('BR', 'Brazil'),
  _CountryEntry('BN', 'Brunei'),
  _CountryEntry('BG', 'Bulgaria'),
  _CountryEntry('BF', 'Burkina Faso'),
  _CountryEntry('BI', 'Burundi'),
  _CountryEntry('CV', 'Cabo Verde'),
  _CountryEntry('KH', 'Cambodia'),
  _CountryEntry('CM', 'Cameroon'),
  _CountryEntry('CA', 'Canada'),
  _CountryEntry('CF', 'Central African Republic'),
  _CountryEntry('TD', 'Chad'),
  _CountryEntry('CL', 'Chile'),
  _CountryEntry('CN', 'China'),
  _CountryEntry('CO', 'Colombia'),
  _CountryEntry('KM', 'Comoros'),
  _CountryEntry('CG', 'Congo'),
  _CountryEntry('CD', 'Congo (DRC)'),
  _CountryEntry('CR', 'Costa Rica'),
  _CountryEntry('CI', "Cote d'Ivoire"),
  _CountryEntry('HR', 'Croatia'),
  _CountryEntry('CU', 'Cuba'),
  _CountryEntry('CY', 'Cyprus'),
  _CountryEntry('CZ', 'Czechia'),
  _CountryEntry('DK', 'Denmark'),
  _CountryEntry('DJ', 'Djibouti'),
  _CountryEntry('DM', 'Dominica'),
  _CountryEntry('DO', 'Dominican Republic'),
  _CountryEntry('EC', 'Ecuador'),
  _CountryEntry('EG', 'Egypt'),
  _CountryEntry('SV', 'El Salvador'),
  _CountryEntry('GQ', 'Equatorial Guinea'),
  _CountryEntry('ER', 'Eritrea'),
  _CountryEntry('EE', 'Estonia'),
  _CountryEntry('SZ', 'Eswatini'),
  _CountryEntry('ET', 'Ethiopia'),
  _CountryEntry('FJ', 'Fiji'),
  _CountryEntry('FI', 'Finland'),
  _CountryEntry('FR', 'France'),
  _CountryEntry('GA', 'Gabon'),
  _CountryEntry('GM', 'Gambia'),
  _CountryEntry('GE', 'Georgia'),
  _CountryEntry('DE', 'Germany'),
  _CountryEntry('GH', 'Ghana'),
  _CountryEntry('GR', 'Greece'),
  _CountryEntry('GD', 'Grenada'),
  _CountryEntry('GT', 'Guatemala'),
  _CountryEntry('GN', 'Guinea'),
  _CountryEntry('GW', 'Guinea-Bissau'),
  _CountryEntry('GY', 'Guyana'),
  _CountryEntry('HT', 'Haiti'),
  _CountryEntry('HN', 'Honduras'),
  _CountryEntry('HU', 'Hungary'),
  _CountryEntry('IS', 'Iceland'),
  _CountryEntry('IN', 'India'),
  _CountryEntry('ID', 'Indonesia'),
  _CountryEntry('IR', 'Iran'),
  _CountryEntry('IQ', 'Iraq'),
  _CountryEntry('IE', 'Ireland'),
  _CountryEntry('IL', 'Israel'),
  _CountryEntry('IT', 'Italy'),
  _CountryEntry('JM', 'Jamaica'),
  _CountryEntry('JP', 'Japan'),
  _CountryEntry('JO', 'Jordan'),
  _CountryEntry('KZ', 'Kazakhstan'),
  _CountryEntry('KE', 'Kenya'),
  _CountryEntry('KI', 'Kiribati'),
  _CountryEntry('KP', 'North Korea'),
  _CountryEntry('KR', 'South Korea'),
  _CountryEntry('KW', 'Kuwait'),
  _CountryEntry('KG', 'Kyrgyzstan'),
  _CountryEntry('LA', 'Laos'),
  _CountryEntry('LV', 'Latvia'),
  _CountryEntry('LB', 'Lebanon'),
  _CountryEntry('LS', 'Lesotho'),
  _CountryEntry('LR', 'Liberia'),
  _CountryEntry('LY', 'Libya'),
  _CountryEntry('LI', 'Liechtenstein'),
  _CountryEntry('LT', 'Lithuania'),
  _CountryEntry('LU', 'Luxembourg'),
  _CountryEntry('MG', 'Madagascar'),
  _CountryEntry('MW', 'Malawi'),
  _CountryEntry('MY', 'Malaysia'),
  _CountryEntry('MV', 'Maldives'),
  _CountryEntry('ML', 'Mali'),
  _CountryEntry('MT', 'Malta'),
  _CountryEntry('MH', 'Marshall Islands'),
  _CountryEntry('MR', 'Mauritania'),
  _CountryEntry('MU', 'Mauritius'),
  _CountryEntry('MX', 'Mexico'),
  _CountryEntry('FM', 'Micronesia'),
  _CountryEntry('MD', 'Moldova'),
  _CountryEntry('MC', 'Monaco'),
  _CountryEntry('MN', 'Mongolia'),
  _CountryEntry('ME', 'Montenegro'),
  _CountryEntry('MA', 'Morocco'),
  _CountryEntry('MZ', 'Mozambique'),
  _CountryEntry('MM', 'Myanmar'),
  _CountryEntry('NA', 'Namibia'),
  _CountryEntry('NR', 'Nauru'),
  _CountryEntry('NP', 'Nepal'),
  _CountryEntry('NL', 'Netherlands'),
  _CountryEntry('NZ', 'New Zealand'),
  _CountryEntry('NI', 'Nicaragua'),
  _CountryEntry('NE', 'Niger'),
  _CountryEntry('NG', 'Nigeria'),
  _CountryEntry('MK', 'North Macedonia'),
  _CountryEntry('NO', 'Norway'),
  _CountryEntry('OM', 'Oman'),
  _CountryEntry('PK', 'Pakistan'),
  _CountryEntry('PW', 'Palau'),
  _CountryEntry('PS', 'Palestine'),
  _CountryEntry('PA', 'Panama'),
  _CountryEntry('PG', 'Papua New Guinea'),
  _CountryEntry('PY', 'Paraguay'),
  _CountryEntry('PE', 'Peru'),
  _CountryEntry('PH', 'Philippines'),
  _CountryEntry('PL', 'Poland'),
  _CountryEntry('PT', 'Portugal'),
  _CountryEntry('QA', 'Qatar'),
  _CountryEntry('RO', 'Romania'),
  _CountryEntry('RU', 'Russia'),
  _CountryEntry('RW', 'Rwanda'),
  _CountryEntry('KN', 'Saint Kitts and Nevis'),
  _CountryEntry('LC', 'Saint Lucia'),
  _CountryEntry('VC', 'Saint Vincent and the Grenadines'),
  _CountryEntry('WS', 'Samoa'),
  _CountryEntry('SM', 'San Marino'),
  _CountryEntry('ST', 'Sao Tome and Principe'),
  _CountryEntry('SA', 'Saudi Arabia'),
  _CountryEntry('SN', 'Senegal'),
  _CountryEntry('RS', 'Serbia'),
  _CountryEntry('SC', 'Seychelles'),
  _CountryEntry('SL', 'Sierra Leone'),
  _CountryEntry('SG', 'Singapore'),
  _CountryEntry('SK', 'Slovakia'),
  _CountryEntry('SI', 'Slovenia'),
  _CountryEntry('SB', 'Solomon Islands'),
  _CountryEntry('SO', 'Somalia'),
  _CountryEntry('ZA', 'South Africa'),
  _CountryEntry('SS', 'South Sudan'),
  _CountryEntry('ES', 'Spain'),
  _CountryEntry('LK', 'Sri Lanka'),
  _CountryEntry('SD', 'Sudan'),
  _CountryEntry('SR', 'Suriname'),
  _CountryEntry('SE', 'Sweden'),
  _CountryEntry('CH', 'Switzerland'),
  _CountryEntry('SY', 'Syria'),
  _CountryEntry('TW', 'Taiwan'),
  _CountryEntry('TJ', 'Tajikistan'),
  _CountryEntry('TZ', 'Tanzania'),
  _CountryEntry('TH', 'Thailand'),
  _CountryEntry('TL', 'Timor-Leste'),
  _CountryEntry('TG', 'Togo'),
  _CountryEntry('TO', 'Tonga'),
  _CountryEntry('TT', 'Trinidad and Tobago'),
  _CountryEntry('TN', 'Tunisia'),
  _CountryEntry('TR', 'Turkey'),
  _CountryEntry('TM', 'Turkmenistan'),
  _CountryEntry('TV', 'Tuvalu'),
  _CountryEntry('UG', 'Uganda'),
  _CountryEntry('UA', 'Ukraine'),
  _CountryEntry('AE', 'United Arab Emirates'),
  _CountryEntry('GB', 'United Kingdom'),
  _CountryEntry('US', 'United States'),
  _CountryEntry('UY', 'Uruguay'),
  _CountryEntry('UZ', 'Uzbekistan'),
  _CountryEntry('VU', 'Vanuatu'),
  _CountryEntry('VA', 'Vatican City'),
  _CountryEntry('VE', 'Venezuela'),
  _CountryEntry('VN', 'Vietnam'),
  _CountryEntry('YE', 'Yemen'),
  _CountryEntry('ZM', 'Zambia'),
  _CountryEntry('ZW', 'Zimbabwe'),
];

// ---------------------------------------------------------------------------
// Export Data dialog
// ---------------------------------------------------------------------------

class _ExportDataDialog extends StatefulWidget {
  const _ExportDataDialog({
    required this.userId,
    required this.email,
    required this.currentPlayer,
  });

  final String userId;
  final String? email;
  final Player currentPlayer;

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
        currentPlayer: widget.currentPlayer,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          ? Text(_error!, style: const TextStyle(color: FlitColors.error))
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
    final matches =
        _emailController.text.trim().toLowerCase() ==
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
          Text('Delete Account', style: TextStyle(color: FlitColors.error)),
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
    required this.roundsCompleted,
    this.roundEmojis,
  });

  final String region;
  final Duration duration;
  final int score;
  final DateTime date;
  final int roundsCompleted;
  final String? roundEmojis;

  /// Generate shareable result text for socials.
  String toShareText() {
    final timeFormatted = _formatShareTime(duration);
    final scoreFormatted = _formatShareScore(score);
    final regionLabel = region[0].toUpperCase() + region.substring(1);
    return '     \u{1F6EB} \u{1F30D} \u{1F6EC}\n'
        'Flit — $regionLabel\n'
        '$clueEmojiRow\n'
        'Score: $scoreFormatted pts\n'
        'Time: $timeFormatted\n'
        'Rounds: $roundsCompleted';
  }

  /// Per-round performance emoji row (colored circles).
  String get clueEmojiRow {
    if (roundEmojis != null && roundEmojis!.isNotEmpty) return roundEmojis!;
    if (roundsCompleted <= 0) return '';
    // Fallback for old rows without stored emojis.
    return List.filled(roundsCompleted, '\u{2B1C}').join();
  }

  static String _formatShareTime(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  static String _formatShareScore(int score) {
    if (score >= 1000) {
      final str = score.toString();
      final result = StringBuffer();
      var count = 0;
      for (var i = str.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) result.write(',');
        result.write(str[i]);
        count++;
      }
      return result.toString().split('').reversed.join();
    }
    return score.toString();
  }
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
    try {
      final data = await LeaderboardService.instance.fetchGameHistory(
        userId: userId,
        limit: 100,
      );
      if (mounted) {
        final parsed = <_GameHistoryEntry>[];
        for (final entry in data) {
          try {
            final timeMs = entry['time_ms'];
            final score = entry['score'];
            final createdAt = entry['created_at'];
            // Skip entries with missing required fields instead of crashing.
            if (timeMs == null || score == null || createdAt == null) continue;
            parsed.add(
              _GameHistoryEntry(
                region: (entry['region'] as String?) ?? 'World',
                duration: Duration(
                  milliseconds: timeMs is int
                      ? timeMs
                      : (timeMs as num).toInt(),
                ),
                score: score is int ? score : (score as num).toInt(),
                date: DateTime.parse(createdAt as String),
                roundsCompleted: (entry['rounds_completed'] as int?) ?? 0,
                roundEmojis: entry['round_emojis'] as String?,
              ),
            );
          } catch (e) {
            // Skip malformed entries rather than failing the entire list.
            debugPrint('[GameHistory] skipping malformed entry: $e');
          }
        }
        setState(() {
          _entries = parsed;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[GameHistory] _loadHistory failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _monthAbbr(local.month);
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  static String _monthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  void _showEntryDetail(BuildContext context, _GameHistoryEntry entry) {
    final isDaily = entry.region.toLowerCase() == 'daily';
    final rounds = entry.clueEmojiRow.runes
        .map((r) => String.fromCharCode(r))
        .toList();
    int perfect = 0, hinted = 0, heavy = 0, failed = 0;
    for (final r in rounds) {
      if (r == '\u{1F7E2}') {
        perfect++;
      } else if (r == '\u{1F7E1}') {
        hinted++;
      } else if (r == '\u{1F7E0}') {
        heavy++;
      } else if (r == '\u{1F534}') {
        failed++;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlitColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: FlitColors.textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              isDaily ? 'DAILY SCRAMBLE' : entry.region.toUpperCase(),
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(entry.date),
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            // Score + time
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${entry.score}',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'pts',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 14),
                ),
                const SizedBox(width: 20),
                Text(
                  _formatDuration(entry.duration),
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 16,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Round breakdown
            if (rounds.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: List.generate(rounds.length, (i) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R${i + 1}',
                        style: const TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(rounds[i], style: const TextStyle(fontSize: 22)),
                    ],
                  );
                }),
              ),
            const SizedBox(height: 16),
            // Legend
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlitColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FlitColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _LegendItem('\u{1F7E2}', '$perfect', 'Perfect'),
                  _LegendItem('\u{1F7E1}', '$hinted', '1-2 hints'),
                  _LegendItem('\u{1F7E0}', '$heavy', '3+ hints'),
                  _LegendItem('\u{1F534}', '$failed', 'Failed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              final isDaily = entry.region.toLowerCase() == 'daily';
              return GestureDetector(
                onTap: () => _showEntryDetail(context, entry),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FlitColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FlitColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      // Region icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: FlitColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            isDaily ? Icons.calendar_today : Icons.public,
                            color: isDaily
                                ? FlitColors.gold
                                : FlitColors.accent,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Region, time, emojis
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDaily ? 'Daily Scramble' : entry.region,
                              style: const TextStyle(
                                color: FlitColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_formatDuration(entry.duration)}  \u2022  ${_formatDate(entry.date)}',
                              style: const TextStyle(
                                color: FlitColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.clueEmojiRow,
                              style: const TextStyle(fontSize: 12),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'pts',
                            style: TextStyle(
                              color: FlitColors.textMuted.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Share button
                      GestureDetector(
                        onTap: () {
                          final text = entry.toShareText();
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Result copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: FlitColors.backgroundLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.share,
                              color: FlitColors.textMuted,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.emoji, this.count, this.label);

  final String emoji;
  final String count;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(height: 2),
      Text(
        count,
        style: const TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: FlitColors.textMuted, fontSize: 9),
      ),
    ],
  );
}
