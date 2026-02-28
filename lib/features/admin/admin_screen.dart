import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/admin_config.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../game/clues/clue_types.dart';
import '../../game/data/country_difficulty.dart';
import '../../game/map/country_data.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/economy_config.dart';
import '../../data/models/pilot_license.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/economy_config_service.dart';
import '../../data/models/announcement.dart';
import '../../data/models/app_remote_config.dart';
import '../../data/models/player_report.dart';
import '../../data/services/announcement_service.dart';
import '../../data/services/app_config_service.dart';
import '../../data/services/report_service.dart';
import '../../data/services/feature_flag_service.dart';
import '../debug/avatar_preview_screen.dart';
import '../debug/country_preview_screen.dart';
import '../debug/plane_preview_screen.dart';
import 'admin_stats_screen.dart';

/// Admin panel — visible to users with a non-null `admin_role`.
///
/// Two-tier access controlled by [AdminPermission]:
///
/// **Moderator** (view + moderate):
/// - Look up player profiles and stats
/// - View game histories and recent scores
/// - View coin ledger entries
/// - Change usernames (profanity moderation)
/// - View design previews (planes, avatars, flags, outlines)
/// - View difficulty ratings (read-only)
/// - View analytics dashboard
/// - View game log
///
/// **Owner** (god mode — all of the above plus):
/// - Self-service: unlimited gold, XP, flights
/// - Gift gold / levels / flights to any user by username
/// - Set exact stat values on any player
/// - Gift cosmetic items, set licenses, set avatars
/// - Unlock all items for a player
/// - Manage moderator roles (promote / revoke)
/// - Economy config editor (earnings, promotions, gold packages, price overrides)
/// - Edit difficulty ratings
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  SupabaseClient get _client => Supabase.instance.client;

  // ── Economy Config state ──
  EconomyConfig? _economyConfig;
  bool _economyConfigLoading = true;

  // Report queue
  int _pendingReportCount = 0;

  // Feature flags
  Map<String, bool> _featureFlags = {};
  bool _featureFlagsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEconomyConfig();
    _loadReportCount();
    _loadFeatureFlags();
  }

  Future<void> _loadEconomyConfig() async {
    try {
      final config = await EconomyConfigService.instance.getConfig();
      if (!mounted) return;
      setState(() {
        _economyConfig = config;
        _economyConfigLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _economyConfig = EconomyConfig.defaults();
        _economyConfigLoading = false;
      });
    }
  }

  Future<void> _loadReportCount() async {
    try {
      final count = await ReportService.instance.countPending();
      if (!mounted) return;
      setState(() => _pendingReportCount = count);
    } catch (_) {}
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final flags = await FeatureFlagService.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _featureFlags = flags;
        _featureFlagsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _featureFlagsLoading = false);
    }
  }

  // ── Supabase helpers ──

  /// Fuzzy-search profiles by username, display name, or exact UUID.
  /// Uses the `admin_search_users` RPC (pg_trgm fuzzy matching).
  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    final result = await _client.rpc(
      'admin_search_users',
      params: {'search_query': query},
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// Exact-match lookup by username (used by action dialogs).
  Future<Map<String, dynamic>?> _lookupUser(String username) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('username', username)
        .maybeSingle();
    return data;
  }

  /// Atomically increment a numeric column on a profile row.
  Future<void> _incrementStat(String userId, String column, int amount) async {
    await _client.rpc(
      'admin_increment_stat',
      params: {
        'target_user_id': userId,
        'stat_column': column,
        'amount': amount,
      },
    );
  }

  /// Atomically set a numeric column on a profile row.
  Future<void> _setStat(String userId, String column, int value) async {
    await _client.rpc(
      'admin_set_stat',
      params: {
        'target_user_id': userId,
        'stat_column': column,
        'new_value': value,
      },
    );
  }

  /// Show a snackbar with [message].
  void _snack(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? FlitColors.error : FlitColors.success,
      ),
    );
  }

  // ── Gift Gold ──

  void _showGiftGoldDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.monetization_on,
          iconColor: FlitColors.gold,
          title: 'Gift Gold',
          error: error,
          actionLabel: 'Send Gold',
          actionIcon: Icons.send,
          actionColor: FlitColors.gold,
          onAction: () async {
            final username = usernameCtl.text.trim();
            final amount = int.tryParse(amountCtl.text.trim());

            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }
            if (amount == null || amount <= 0) {
              setDialogState(() => error = 'Enter a valid positive amount');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              await _incrementStat(user['id'] as String, 'coins', amount);

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'Gifted $amount gold to @$username');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            _AmountField(controller: amountCtl, hint: 'Amount of gold'),
          ],
        ),
      ),
    );
  }

  // ── Gift Levels ──

  void _showGiftLevelsDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.arrow_upward,
          iconColor: FlitColors.accent,
          title: 'Gift Levels',
          error: error,
          actionLabel: 'Grant Levels',
          actionIcon: Icons.send,
          actionColor: FlitColors.accent,
          onAction: () async {
            final username = usernameCtl.text.trim();
            final amount = int.tryParse(amountCtl.text.trim());

            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }
            if (amount == null || amount <= 0) {
              setDialogState(() => error = 'Enter a valid positive number');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              await _incrementStat(user['id'] as String, 'level', amount);

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'Granted $amount levels to @$username');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            _AmountField(controller: amountCtl, hint: 'Number of levels'),
          ],
        ),
      ),
    );
  }

  // ── Gift Flights ──

  void _showGiftFlightsDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.flight,
          iconColor: FlitColors.oceanHighlight,
          title: 'Gift Flights',
          error: error,
          actionLabel: 'Grant Flights',
          actionIcon: Icons.send,
          actionColor: FlitColors.oceanHighlight,
          onAction: () async {
            final username = usernameCtl.text.trim();
            final amount = int.tryParse(amountCtl.text.trim());

            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }
            if (amount == null || amount <= 0) {
              setDialogState(() => error = 'Enter a valid positive number');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              await _incrementStat(
                user['id'] as String,
                'games_played',
                amount,
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'Granted $amount flights to @$username');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            _AmountField(controller: amountCtl, hint: 'Number of flights'),
          ],
        ),
      ),
    );
  }

  void _showSetStatDialog(
    BuildContext context, {
    required String title,
    required String statColumn,
    required String valueLabel,
    required IconData icon,
    required Color iconColor,
  }) {
    final usernameCtl = TextEditingController();
    final valueCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: icon,
          iconColor: iconColor,
          title: title,
          error: error,
          actionLabel: 'Set Value',
          actionIcon: Icons.check,
          actionColor: iconColor,
          onAction: () async {
            final username = usernameCtl.text.trim();
            final targetValue = int.tryParse(valueCtl.text.trim());

            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }
            if (targetValue == null || targetValue < 0) {
              setDialogState(() => error = 'Enter a valid value (>= 0)');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              await _setStat(user['id'] as String, statColumn, targetValue);

              // If admin set their own stat, force-refresh to bypass
              // monotonic protection so the new value takes effect.
              final currentUserId = ref.read(accountProvider).currentPlayer.id;
              if (user['id'] == currentUserId) {
                await ref.read(accountProvider.notifier).adminForceRefresh();
              }

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'Set $statColumn for @$username to $targetValue');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            _AmountField(controller: valueCtl, hint: valueLabel),
          ],
        ),
      ),
    );
  }

  void _showCoinLedgerDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.receipt_long,
          iconColor: FlitColors.gold,
          title: 'Coin Ledger Explorer',
          subtitle: 'Inspect coin activity for a player',
          error: error,
          actionLabel: 'Open Ledger',
          actionIcon: Icons.open_in_new,
          actionColor: FlitColors.gold,
          onAction: () async {
            final username = usernameCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _CoinLedgerScreen(
                    userId: user['id'] as String,
                    username: user['username'] as String? ?? username,
                  ),
                ),
              );
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [_UsernameField(controller: usernameCtl)],
        ),
      ),
    );
  }

  // ── User Lookup (moderator + owner) — fuzzy search ──

  void _showUserLookupDialog(BuildContext context) {
    final searchCtl = TextEditingController();
    String? error;
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_search,
                  color: FlitColors.oceanHighlight,
                  size: 36,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Search Players',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search by username, display name, or paste a UUID.',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: searchCtl,
                  style: const TextStyle(color: FlitColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Username, display name, or UUID',
                    hintStyle: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: FlitColors.backgroundDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: FlitColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FlitColors.textMuted,
                              ),
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: (_) async {
                    final query = searchCtl.text.trim();
                    if (query.length < 2) {
                      setDialogState(
                        () => error = 'Enter at least 2 characters',
                      );
                      return;
                    }
                    setDialogState(() {
                      searching = true;
                      error = null;
                    });
                    try {
                      final r = await _searchUsers(query);
                      setDialogState(() {
                        results = r;
                        searching = false;
                        if (r.isEmpty) error = 'No players found for "$query"';
                      });
                    } on PostgrestException catch (e) {
                      setDialogState(() {
                        searching = false;
                        error = 'Search failed: ${e.message}';
                      });
                    } catch (_) {
                      setDialogState(() {
                        searching = false;
                        error = 'Something went wrong';
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: results.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: FlitColors.backgroundDark,
                            height: 1,
                          ),
                          itemBuilder: (_, i) {
                            final user = results[i];
                            final username =
                                user['username'] as String? ?? '???';
                            final displayName =
                                user['display_name'] as String? ?? '';
                            final role = user['admin_role'] as String?;
                            final isBanned = user['banned_at'] != null;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: FlitColors.backgroundDark,
                                radius: 16,
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: FlitColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    '@$username',
                                    style: const TextStyle(
                                      color: FlitColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (role != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: role == 'owner'
                                            ? FlitColors.gold.withOpacity(0.2)
                                            : FlitColors.oceanHighlight
                                                  .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        role,
                                        style: TextStyle(
                                          color: role == 'owner'
                                              ? FlitColors.gold
                                              : FlitColors.oceanHighlight,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isBanned) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: FlitColors.error.withOpacity(
                                          0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'BANNED',
                                        style: TextStyle(
                                          color: FlitColors.error,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: displayName.isNotEmpty
                                  ? Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: FlitColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              onTap: () async {
                                Navigator.of(dialogCtx).pop();
                                if (!context.mounted) return;
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => _UserDetailScreen(
                                      userId: user['id'] as String,
                                      username: username,
                                      userData: user,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: FlitColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final query = searchCtl.text.trim();
                        if (query.length < 2) {
                          setDialogState(
                            () => error = 'Enter at least 2 characters',
                          );
                          return;
                        }
                        setDialogState(() {
                          searching = true;
                          error = null;
                        });
                        try {
                          final r = await _searchUsers(query);
                          setDialogState(() {
                            results = r;
                            searching = false;
                            if (r.isEmpty) {
                              error = 'No players found for "$query"';
                            }
                          });
                        } on PostgrestException catch (e) {
                          setDialogState(() {
                            searching = false;
                            error = 'Search failed: ${e.message}';
                          });
                        } catch (_) {
                          setDialogState(() {
                            searching = false;
                            error = 'Something went wrong';
                          });
                        }
                      },
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.oceanHighlight,
                        foregroundColor: FlitColors.backgroundDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Change Username (moderation) ──

  void _showChangeUsernameDialog(BuildContext context) {
    final oldUsernameCtl = TextEditingController();
    final newUsernameCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.edit,
          iconColor: FlitColors.warning,
          title: 'Change Username',
          subtitle: 'Moderation tool — rename offensive usernames',
          error: error,
          actionLabel: 'Rename',
          actionIcon: Icons.check,
          actionColor: FlitColors.warning,
          onAction: () async {
            final oldName = oldUsernameCtl.text.trim();
            final newName = newUsernameCtl.text.trim();

            if (oldName.isEmpty) {
              setDialogState(() => error = 'Enter the current username');
              return;
            }
            if (newName.isEmpty || newName.length < 3) {
              setDialogState(
                () => error = 'New username must be at least 3 characters',
              );
              return;
            }

            try {
              final user = await _lookupUser(oldName);
              if (user == null) {
                setDialogState(() => error = 'User @$oldName not found');
                return;
              }

              await _client
                  .from('profiles')
                  .update({'username': newName})
                  .eq('id', user['id']);

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'Renamed @$oldName → @$newName');
            } on PostgrestException catch (e) {
              if (e.code == '23505') {
                setDialogState(
                  () => error = 'Username @$newName is already taken',
                );
              } else {
                setDialogState(() => error = 'Failed: ${e.message}');
              }
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(
              controller: oldUsernameCtl,
              hint: 'Current username',
            ),
            const SizedBox(height: 12),
            _UsernameField(controller: newUsernameCtl, hint: 'New username'),
          ],
        ),
      ),
    );
  }

  // ── Gift Cosmetic ──

  void _showGiftCosmeticDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    final allCosmetics = CosmeticCatalog.all;
    String selectedItemId = allCosmetics.first.id;
    final items = <String, String>{for (final c in allCosmetics) c.id: c.name};

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Color(0xFF9B59B6), size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Gift Cosmetic Item',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _UsernameField(controller: usernameCtl),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedItemId,
                    isExpanded: true,
                    dropdownColor: FlitColors.cardBackground,
                    style: const TextStyle(color: FlitColors.textPrimary),
                    underline: const SizedBox.shrink(),
                    items: items.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedItemId = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: FlitColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final username = usernameCtl.text.trim();
                        if (username.isNotEmpty) {
                          Navigator.of(dialogCtx).pop();
                          // TODO: Send via backend API when cosmetics table exists
                          _snack(
                            context,
                            '${items[selectedItemId]} gifted to @$username',
                          );
                        }
                      },
                      icon: const Icon(Icons.card_giftcard, size: 16),
                      label: const Text('Gift Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B59B6),
                        foregroundColor: FlitColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Manage Moderators ──

  void _showManageRoleDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    String selectedRole = 'moderator';
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.shield,
          iconColor: FlitColors.accent,
          title: 'Manage Player Role',
          subtitle: 'Promote to moderator or revoke access.',
          error: error,
          actionLabel: 'Set Role',
          actionIcon: Icons.shield,
          actionColor: FlitColors.accent,
          onAction: () async {
            final username = usernameCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              final userId = user['id'] as String;
              final roleValue = selectedRole == 'revoke' ? null : selectedRole;

              await _client.rpc(
                'admin_set_role',
                params: {'target_user_id': userId, 'p_role': roleValue},
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              final label = roleValue ?? 'regular user';
              if (!context.mounted) return;
              _snack(context, '@$username is now: $label');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedRole,
                isExpanded: true,
                dropdownColor: FlitColors.cardBackground,
                style: const TextStyle(color: FlitColors.textPrimary),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 'moderator',
                    child: Text('Moderator'),
                  ),
                  DropdownMenuItem(
                    value: 'revoke',
                    child: Text('Revoke (Regular User)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedRole = value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Unlock All ──

  void _showUnlockAllDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.lock_open,
          iconColor: FlitColors.success,
          title: 'Unlock All Items',
          subtitle: 'Unlock all shop cosmetics and avatar parts for a player.',
          error: error,
          actionLabel: 'Unlock All',
          actionIcon: Icons.lock_open,
          actionColor: FlitColors.success,
          onAction: () async {
            final username = usernameCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              final userId = user['id'] as String;

              await _client.rpc(
                'admin_unlock_all',
                params: {'target_user_id': userId},
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'All items unlocked for @$username');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [_UsernameField(controller: usernameCtl)],
        ),
      ),
    );
  }

  // ── Set License ──

  void _showSetLicenseDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    final coinBoostCtl = TextEditingController();
    final clueChanceCtl = TextEditingController();
    final fuelBoostCtl = TextEditingController();
    final nationalityCtl = TextEditingController();
    String selectedClueType = 'flag';
    String? error;

    const clueTypes = ['flag', 'outline', 'borders', 'capital', 'stats'];

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.badge,
          iconColor: FlitColors.oceanHighlight,
          title: 'Set Player License',
          subtitle: 'All stats 1-25. Leave blank to randomise.',
          error: error,
          actionLabel: 'Set License',
          actionIcon: Icons.badge,
          actionColor: FlitColors.oceanHighlight,
          onAction: () async {
            final username = usernameCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }

            int? parseStat(String text) {
              if (text.isEmpty) return null;
              final v = int.tryParse(text);
              if (v == null || v < 1 || v > 25) return null;
              return v;
            }

            final coinB = parseStat(coinBoostCtl.text.trim());
            final clueC = parseStat(clueChanceCtl.text.trim());
            final fuelB = parseStat(fuelBoostCtl.text.trim());

            // Validate: non-empty fields must be 1-25
            for (final entry in {
              'Coin Boost': coinBoostCtl.text.trim(),
              'Clue Chance': clueChanceCtl.text.trim(),
              'Fuel Boost': fuelBoostCtl.text.trim(),
            }.entries) {
              if (entry.value.isNotEmpty) {
                final v = int.tryParse(entry.value);
                if (v == null || v < 1 || v > 25) {
                  setDialogState(() => error = '${entry.key} must be 1-25');
                  return;
                }
              }
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              final userId = user['id'] as String;
              final nationality = nationalityCtl.text.trim().toUpperCase();
              final licenseData = {
                'coin_boost': coinB ?? PilotLicense.rollStat(),
                'clue_chance': clueC ?? PilotLicense.rollStat(),
                'fuel_boost': fuelB ?? PilotLicense.rollStat(),
                'preferred_clue_type': selectedClueType,
                if (nationality.isNotEmpty) 'nationality': nationality,
              };

              await _client.rpc(
                'admin_set_license',
                params: {
                  'target_user_id': userId,
                  'p_license_data': licenseData,
                },
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(
                context,
                'License set for @$username: '
                '${licenseData['coin_boost']}/'
                '${licenseData['clue_chance']}/'
                '${licenseData['fuel_boost']} '
                '($selectedClueType)',
              );
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AmountField(
                    controller: coinBoostCtl,
                    hint: 'Coin Boost',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AmountField(
                    controller: clueChanceCtl,
                    hint: 'Clue Chance',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AmountField(controller: fuelBoostCtl, hint: 'Fuel Boost'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedClueType,
                isExpanded: true,
                dropdownColor: FlitColors.cardBackground,
                style: const TextStyle(color: FlitColors.textPrimary),
                underline: const SizedBox.shrink(),
                items: clueTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          'Clue Type: ${t[0].toUpperCase()}${t.substring(1)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedClueType = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            _AmountField(
              controller: nationalityCtl,
              hint: 'Nationality (ISO e.g. GB, US)',
              isNumeric: false,
            ),
          ],
        ),
      ),
    );
  }

  // ── Set Avatar ──

  void _showSetAvatarDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    AvatarStyle selectedStyle = AvatarStyle.adventurer;
    AvatarSkinColor selectedSkin = AvatarSkinColor.medium;
    AvatarHairColor selectedHairColor = AvatarHairColor.brown;
    AvatarHair selectedHair = AvatarHair.short01;
    AvatarEyes selectedEyes = AvatarEyes.variant01;
    AvatarMouth selectedMouth = AvatarMouth.variant01;
    AvatarCompanion selectedCompanion = AvatarCompanion.none;
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.face,
          iconColor: FlitColors.oceanHighlight,
          title: 'Set Player Avatar',
          subtitle: 'Override avatar config for a player.',
          error: error,
          actionLabel: 'Set Avatar',
          actionIcon: Icons.face,
          actionColor: FlitColors.oceanHighlight,
          onAction: () async {
            final username = usernameCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              final userId = user['id'] as String;
              final avatarConfig = AvatarConfig(
                style: selectedStyle,
                skinColor: selectedSkin,
                hairColor: selectedHairColor,
                hair: selectedHair,
                eyes: selectedEyes,
                mouth: selectedMouth,
                companion: selectedCompanion,
              );

              await _client.rpc(
                'admin_set_avatar',
                params: {
                  'target_user_id': userId,
                  'p_avatar_config': avatarConfig.toJson(),
                },
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(
                context,
                'Avatar set for @$username: '
                '${selectedStyle.name} / ${selectedSkin.name}',
              );
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            // Style selector
            const Text(
              'Style',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<AvatarStyle>(
                value: selectedStyle,
                isExpanded: true,
                dropdownColor: FlitColors.cardBackground,
                style: const TextStyle(color: FlitColors.textPrimary),
                underline: const SizedBox.shrink(),
                items: AvatarStyle.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedStyle = v);
                },
              ),
            ),
            const SizedBox(height: 12),
            // Skin color
            const Text(
              'Skin Color',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<AvatarSkinColor>(
                value: selectedSkin,
                isExpanded: true,
                dropdownColor: FlitColors.cardBackground,
                style: const TextStyle(color: FlitColors.textPrimary),
                underline: const SizedBox.shrink(),
                items: AvatarSkinColor.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedSkin = v);
                },
              ),
            ),
            const SizedBox(height: 12),
            // Hair & hair color
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hair Color',
                        style: TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: FlitColors.backgroundMid,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<AvatarHairColor>(
                          value: selectedHairColor,
                          isExpanded: true,
                          dropdownColor: FlitColors.cardBackground,
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 13,
                          ),
                          underline: const SizedBox.shrink(),
                          items: AvatarHairColor.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedHairColor = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Companion selector
            const Text(
              'Companion',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<AvatarCompanion>(
                value: selectedCompanion,
                isExpanded: true,
                dropdownColor: FlitColors.cardBackground,
                style: const TextStyle(color: FlitColors.textPrimary),
                underline: const SizedBox.shrink(),
                items: AvatarCompanion.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedCompanion = v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Economy Config dialogs ──

  /// Earnings Config — 3 editable reward fields.
  void _showEarningsConfigDialog(BuildContext context) {
    final config = _economyConfig ?? EconomyConfig.defaults();
    final scrambleCtl = TextEditingController(
      text: '${config.earnings.dailyScrambleBaseReward}',
    );
    final perClueCtl = TextEditingController(
      text: '${config.earnings.freeFlightPerClueReward}',
    );
    final dailyCapCtl = TextEditingController(
      text: '${config.earnings.freeFlightDailyCap}',
    );
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.monetization_on,
          iconColor: FlitColors.gold,
          title: 'Set Earnings',
          subtitle: 'Configure gold rewards per game mode.',
          error: error,
          actionLabel: 'Save',
          actionIcon: Icons.save,
          actionColor: FlitColors.gold,
          onCancel: () => Navigator.of(dialogCtx).pop(),
          onAction: () async {
            final scramble = int.tryParse(scrambleCtl.text.trim());
            final perClue = int.tryParse(perClueCtl.text.trim());
            final cap = int.tryParse(dailyCapCtl.text.trim());

            if (scramble == null || scramble < 0) {
              setDialogState(
                () => error = 'Daily Scramble Reward must be >= 0',
              );
              return;
            }
            if (perClue == null || perClue < 0) {
              setDialogState(
                () => error = 'Free Flight Per-Clue Reward must be >= 0',
              );
              return;
            }
            if (cap == null || cap < 0) {
              setDialogState(
                () => error = 'Free Flight Daily Cap must be >= 0',
              );
              return;
            }

            try {
              final updated = EconomyConfig(
                earnings: EarningsConfig(
                  dailyScrambleBaseReward: scramble,
                  freeFlightPerClueReward: perClue,
                  freeFlightDailyCap: cap,
                ),
                shopPriceOverrides: config.shopPriceOverrides,
                promotions: config.promotions,
                goldPackages: config.goldPackages,
              );
              await EconomyConfigService.instance.saveConfig(updated);
              if (!mounted) return;
              setState(() => _economyConfig = updated);
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, 'Earnings config saved');
            } catch (_) {
              setDialogState(() => error = 'Failed to save config');
            }
          },
          children: [
            _AdminTextField(
              controller: scrambleCtl,
              label: 'Daily Scramble Base Reward',
            ),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: perClueCtl,
              label: 'Free Flight Per-Clue Reward',
            ),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: dailyCapCtl,
              label: 'Free Flight Daily Cap',
            ),
          ],
        ),
      ),
    );
  }

  /// Promotions Manager — list, toggle, add, and delete promotions.
  void _showPromotionsDialog(BuildContext context) {
    final config = _economyConfig ?? EconomyConfig.defaults();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _PromotionsDialog(
        initialPromotions: config.promotions,
        onSave: (updatedPromotions) async {
          final updated = EconomyConfig(
            earnings: config.earnings,
            shopPriceOverrides: config.shopPriceOverrides,
            promotions: updatedPromotions,
            goldPackages: config.goldPackages,
          );
          await EconomyConfigService.instance.saveConfig(updated);
          if (!mounted) return;
          setState(() => _economyConfig = updated);
          if (!context.mounted) return;
          _snack(context, 'Promotions saved');
        },
      ),
    );
  }

  /// Gold Packages — edit promo prices per package.
  void _showGoldPackagesDialog(BuildContext context) {
    final config = _economyConfig ?? EconomyConfig.defaults();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _GoldPackagesDialog(
        initialPackages: config.goldPackages,
        onSave: (updatedPackages) async {
          final updated = EconomyConfig(
            earnings: config.earnings,
            shopPriceOverrides: config.shopPriceOverrides,
            promotions: config.promotions,
            goldPackages: updatedPackages,
          );
          await EconomyConfigService.instance.saveConfig(updated);
          if (!mounted) return;
          setState(() => _economyConfig = updated);
          if (!context.mounted) return;
          _snack(context, 'Gold packages saved');
        },
      ),
    );
  }

  /// Shop Price Overrides — per-cosmetic price overrides.
  void _showShopPriceOverridesDialog(BuildContext context) {
    final config = _economyConfig ?? EconomyConfig.defaults();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _ShopPriceOverridesDialog(
        initialOverrides: config.shopPriceOverrides,
        onSave: (updatedOverrides) async {
          final updated = EconomyConfig(
            earnings: config.earnings,
            shopPriceOverrides: updatedOverrides,
            promotions: config.promotions,
            goldPackages: config.goldPackages,
          );
          await EconomyConfigService.instance.saveConfig(updated);
          if (!mounted) return;
          setState(() => _economyConfig = updated);
          if (!context.mounted) return;
          _snack(context, 'Price overrides saved');
        },
      ),
    );
  }

  // ── Difficulty Editor ──

  void _showDifficultyEditorDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _DifficultyEditorScreen()),
    );
  }

  // ── Ban Management ──

  void _showBanUserDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    String selectedDuration = '7'; // days
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.gavel,
          iconColor: FlitColors.error,
          title: 'Ban Player',
          subtitle: 'Suspend a player account.',
          error: error,
          actionLabel: 'Ban',
          actionIcon: Icons.gavel,
          actionColor: FlitColors.error,
          onAction: () async {
            final username = usernameCtl.text.trim();
            final reason = reasonCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }
            if (reason.isEmpty) {
              setDialogState(() => error = 'Enter a reason');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              final days = selectedDuration == 'permanent'
                  ? null
                  : int.tryParse(selectedDuration);

              await _client.rpc(
                'admin_ban_user',
                params: {
                  'target_user_id': user['id'],
                  'p_reason': reason,
                  'p_duration_days': days,
                },
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              final label = days != null ? '$days day(s)' : 'permanently';
              _snack(context, '@$username banned $label');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _UsernameField(controller: usernameCtl),
            const SizedBox(height: 12),
            _AmountField(
              controller: reasonCtl,
              hint: 'Reason for ban',
              isNumeric: false,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedDuration,
                isExpanded: true,
                dropdownColor: FlitColors.cardBackground,
                style: const TextStyle(color: FlitColors.textPrimary),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('1 day')),
                  DropdownMenuItem(value: '7', child: Text('7 days')),
                  DropdownMenuItem(value: '30', child: Text('30 days')),
                  DropdownMenuItem(
                    value: 'permanent',
                    child: Text('Permanent'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedDuration = value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnbanUserDialog(BuildContext context) {
    final usernameCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.lock_open,
          iconColor: FlitColors.success,
          title: 'Unban Player',
          error: error,
          actionLabel: 'Unban',
          actionIcon: Icons.lock_open,
          actionColor: FlitColors.success,
          onAction: () async {
            final username = usernameCtl.text.trim();
            if (username.isEmpty) {
              setDialogState(() => error = 'Enter a username');
              return;
            }

            try {
              final user = await _lookupUser(username);
              if (user == null) {
                setDialogState(() => error = 'User @$username not found');
                return;
              }

              await _client.rpc(
                'admin_unban_user',
                params: {'target_user_id': user['id']},
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!context.mounted) return;
              _snack(context, '@$username unbanned');
            } on PostgrestException catch (e) {
              setDialogState(() => error = 'Failed: ${e.message}');
            } catch (_) {
              setDialogState(() => error = 'Something went wrong');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [_UsernameField(controller: usernameCtl)],
        ),
      ),
    );
  }

  // ── Build ──

  /// Shorthand: does the current player have [perm]?
  bool _can(AccountState state, AdminPermission perm) =>
      state.currentPlayer.hasPermission(perm);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);
    final player = state.currentPlayer;
    final roleName = player.isOwner
        ? 'Owner'
        : player.isModerator
        ? 'Moderator'
        : 'Admin';

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text('$roleName Panel'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Current account info ──
          const _SectionHeader(title: 'Current Account'),
          _AccountCard(player: player),
          const SizedBox(height: 24),

          // ── Analytics (moderator + owner) ──
          if (_can(state, AdminPermission.viewAnalytics)) ...[
            const _SectionHeader(title: 'Analytics'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.analytics,
              iconColor: FlitColors.oceanHighlight,
              label: 'Usage Stats',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminStatsScreen(),
                ),
              ),
            ),
            if (_can(state, AdminPermission.viewCoinLedger)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.receipt_long,
                iconColor: FlitColors.gold,
                label: 'Coin Ledger Explorer',
                onTap: () => _showCoinLedgerDialog(context),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // ── User Lookup (moderator + owner) ──
          if (_can(state, AdminPermission.viewUserData)) ...[
            const _SectionHeader(title: 'User Lookup'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.person_search,
              iconColor: FlitColors.oceanHighlight,
              label: 'Look Up Player',
              onTap: () => _showUserLookupDialog(context),
            ),
            const SizedBox(height: 24),
          ],

          // ── Quick self-actions (owner only) ──
          if (_can(state, AdminPermission.selfServiceActions)) ...[
            const _SectionHeader(title: 'Quick Actions (Self)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  label: '+100 Gold',
                  onTap: () => notifier.addCoins(
                    100,
                    applyBoost: false,
                    source: 'admin_grant',
                  ),
                ),
                _ActionChip(
                  label: '+1,000 Gold',
                  onTap: () => notifier.addCoins(
                    1000,
                    applyBoost: false,
                    source: 'admin_grant',
                  ),
                ),
                _ActionChip(
                  label: '+999,999 Gold',
                  onTap: () => notifier.addCoins(
                    999999,
                    applyBoost: false,
                    source: 'admin_grant',
                  ),
                ),
                _ActionChip(label: '+50 XP', onTap: () => notifier.addXp(50)),
                _ActionChip(label: '+500 XP', onTap: () => notifier.addXp(500)),
                _ActionChip(
                  label: '+1 Flight',
                  onTap: () => notifier.incrementGamesPlayed(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ── Gift to Player (owner only) ──
          if (_can(state, AdminPermission.giftGold)) ...[
            const _SectionHeader(title: 'Gift to Player'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.monetization_on,
              iconColor: FlitColors.gold,
              label: 'Gift Gold',
              onTap: () => _showGiftGoldDialog(context),
            ),
            if (_can(state, AdminPermission.giftLevels)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.arrow_upward,
                iconColor: FlitColors.accent,
                label: 'Gift Levels',
                onTap: () => _showGiftLevelsDialog(context),
              ),
            ],
            if (_can(state, AdminPermission.giftFlights)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.flight,
                iconColor: FlitColors.oceanHighlight,
                label: 'Gift Flights',
                onTap: () => _showGiftFlightsDialog(context),
              ),
            ],
            if (_can(state, AdminPermission.setCoins)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.monetization_on_outlined,
                iconColor: FlitColors.gold,
                label: 'Set Coins',
                onTap: () => _showSetStatDialog(
                  context,
                  title: 'Set Coins',
                  statColumn: 'coins',
                  valueLabel: 'Coins total',
                  icon: Icons.monetization_on,
                  iconColor: FlitColors.gold,
                ),
              ),
            ],
            if (_can(state, AdminPermission.setLevel)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.trending_up,
                iconColor: FlitColors.accent,
                label: 'Set Level',
                onTap: () => _showSetStatDialog(
                  context,
                  title: 'Set Level',
                  statColumn: 'level',
                  valueLabel: 'Level',
                  icon: Icons.trending_up,
                  iconColor: FlitColors.accent,
                ),
              ),
            ],
            if (_can(state, AdminPermission.setFlights)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.flight_takeoff,
                iconColor: FlitColors.oceanHighlight,
                label: 'Set Flights',
                onTap: () => _showSetStatDialog(
                  context,
                  title: 'Set Flights',
                  statColumn: 'games_played',
                  valueLabel: 'Flights',
                  icon: Icons.flight_takeoff,
                  iconColor: FlitColors.oceanHighlight,
                ),
              ),
            ],
            if (_can(state, AdminPermission.giftCosmetic)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.star,
                iconColor: const Color(0xFF9B59B6),
                label: 'Gift Cosmetic Item',
                onTap: () => _showGiftCosmeticDialog(context),
              ),
            ],
            if (_can(state, AdminPermission.setLicense)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.badge,
                iconColor: FlitColors.oceanHighlight,
                label: 'Set Player License',
                onTap: () => _showSetLicenseDialog(context),
              ),
            ],
            if (_can(state, AdminPermission.setAvatar)) ...[
              const SizedBox(height: 8),
              _AdminActionCard(
                icon: Icons.face,
                iconColor: FlitColors.gold,
                label: 'Set Player Avatar',
                onTap: () => _showSetAvatarDialog(context),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // ── Moderation (moderator + owner) ──
          if (_can(state, AdminPermission.changeUsername)) ...[
            const _SectionHeader(title: 'Moderation'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.edit,
              iconColor: FlitColors.warning,
              label: 'Change Player Username',
              onTap: () => _showChangeUsernameDialog(context),
            ),
            const SizedBox(height: 8),
          ],
          if (_can(state, AdminPermission.manageRoles)) ...[
            _AdminActionCard(
              icon: Icons.shield,
              iconColor: FlitColors.accent,
              label: 'Manage Moderators',
              onTap: () => _showManageRoleDialog(context),
            ),
            const SizedBox(height: 8),
          ],
          if (_can(state, AdminPermission.unlockAll)) ...[
            _AdminActionCard(
              icon: Icons.lock_open,
              iconColor: FlitColors.success,
              label: 'Unlock All (Player)',
              onTap: () => _showUnlockAllDialog(context),
            ),
            const SizedBox(height: 8),
          ],
          if (_can(state, AdminPermission.changeUsername) ||
              _can(state, AdminPermission.manageRoles))
            const SizedBox(height: 24),

          // ── Ban Management (moderator + owner) ──
          if (_can(state, AdminPermission.tempBanUser)) ...[
            _AdminActionCard(
              icon: Icons.gavel,
              iconColor: FlitColors.error,
              label: 'Ban Player',
              onTap: () => _showBanUserDialog(context),
            ),
            const SizedBox(height: 8),
          ],
          if (_can(state, AdminPermission.unbanUser)) ...[
            _AdminActionCard(
              icon: Icons.lock_open,
              iconColor: FlitColors.success,
              label: 'Unban Player',
              onTap: () => _showUnbanUserDialog(context),
            ),
            const SizedBox(height: 8),
          ],

          // ── Report Queue (moderator + owner) ──
          if (_can(state, AdminPermission.viewReports)) ...[
            const _SectionHeader(title: 'Reports'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.flag,
              iconColor: FlitColors.warning,
              label: _pendingReportCount > 0
                  ? 'Report Queue ($_pendingReportCount pending)'
                  : 'Report Queue',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ReportQueuePlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Difficulty Ratings (view: moderator + owner, edit: owner) ──
          if (_can(state, AdminPermission.viewDifficulty)) ...[
            const _SectionHeader(title: 'Difficulty Ratings'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.speed,
              iconColor: const Color(0xFFFF9800),
              label: _can(state, AdminPermission.editDifficulty)
                  ? 'View / Edit Country Difficulty'
                  : 'View Country Difficulty',
              onTap: () => _showDifficultyEditorDialog(context),
            ),
            const SizedBox(height: 24),
          ],

          // ── Design Preview (moderator + owner) ──
          if (_can(state, AdminPermission.viewDesignPreviews)) ...[
            const _SectionHeader(title: 'Design Preview'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.flight,
              iconColor: FlitColors.accent,
              label: 'Plane Preview (all variants)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PlanePreviewScreen(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.face,
              iconColor: FlitColors.oceanHighlight,
              label: 'Avatar Preview (all styles)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AvatarPreviewScreen(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.flag,
              iconColor: FlitColors.landMassHighlight,
              label: 'Country Preview (flags & outlines)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CountryPreviewScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Economy Config (owner only) ──
          if (_can(state, AdminPermission.editEarnings)) ...[
            const _SectionHeader(title: 'Economy Config'),
            const SizedBox(height: 8),
            if (_economyConfigLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _AdminActionCard(
                icon: Icons.monetization_on,
                iconColor: FlitColors.gold,
                label: 'Set Earnings',
                onTap: () => _showEarningsConfigDialog(context),
              ),
              if (_can(state, AdminPermission.editPromotions)) ...[
                const SizedBox(height: 8),
                _AdminActionCard(
                  icon: Icons.local_offer,
                  iconColor: FlitColors.accent,
                  label: 'Manage Promotions',
                  onTap: () => _showPromotionsDialog(context),
                ),
              ],
              if (_can(state, AdminPermission.editGoldPackages)) ...[
                const SizedBox(height: 8),
                _AdminActionCard(
                  icon: Icons.inventory_2,
                  iconColor: FlitColors.gold,
                  label: 'Edit Gold Packages',
                  onTap: () => _showGoldPackagesDialog(context),
                ),
              ],
              if (_can(state, AdminPermission.editShopPrices)) ...[
                const SizedBox(height: 8),
                _AdminActionCard(
                  icon: Icons.price_change,
                  iconColor: FlitColors.oceanHighlight,
                  label: 'Shop Price Overrides',
                  onTap: () => _showShopPriceOverridesDialog(context),
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],

          // ── App Config (owner only) ──
          if (_can(state, AdminPermission.editAppConfig)) ...[
            const _SectionHeader(title: 'App Config'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.system_update,
              iconColor: FlitColors.accent,
              label: 'Version Gate & Maintenance',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _AppConfigPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Announcements (moderator + owner) ──
          if (_can(state, AdminPermission.viewAnnouncements)) ...[
            const _SectionHeader(title: 'Announcements'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.campaign,
              iconColor: FlitColors.gold,
              label: 'Manage Announcements',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _AnnouncementsPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Feature Flags (owner: edit, moderator: view) ──
          if (_can(state, AdminPermission.viewFeatureFlags)) ...[
            const _SectionHeader(title: 'Feature Flags'),
            const SizedBox(height: 8),
            if (_featureFlagsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ...(_featureFlags.entries.map(
                (entry) => Padding(
                  key: ValueKey('ff_${entry.key}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: FlitColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FlitColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          entry.value ? Icons.toggle_on : Icons.toggle_off,
                          color: entry.value
                              ? FlitColors.success
                              : FlitColors.textMuted,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_can(state, AdminPermission.editFeatureFlags))
                          Switch(
                            value: entry.value,
                            activeColor: FlitColors.success,
                            onChanged: (val) async {
                              // Optimistic local update — avoids a full
                              // async reload that can reorder the list.
                              final oldVal = entry.value;
                              setState(() => _featureFlags[entry.key] = val);
                              try {
                                await FeatureFlagService.instance.setFlag(
                                  flagKey: entry.key,
                                  enabled: val,
                                );
                              } catch (_) {
                                // Revert on failure.
                                if (mounted) {
                                  setState(
                                    () => _featureFlags[entry.key] = oldVal,
                                  );
                                  _snack(
                                    context,
                                    'Failed to update flag',
                                    isError: true,
                                  );
                                }
                              }
                            },
                          )
                        else
                          Text(
                            entry.value ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: entry.value
                                  ? FlitColors.success
                                  : FlitColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )),
            const SizedBox(height: 24),
          ],

          // ── Suspicious Activity (moderator + owner) ──
          if (_can(state, AdminPermission.viewSuspiciousActivity)) ...[
            const _SectionHeader(title: 'Anomaly Detection'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.warning_amber,
              iconColor: FlitColors.error,
              label: 'Suspicious Activity',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _SuspiciousActivityPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Game Log (moderator + owner) ──
          if (_can(state, AdminPermission.viewGameLog)) ...[
            const _SectionHeader(title: 'Game Log'),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.bug_report,
              iconColor: FlitColors.warning,
              label:
                  'View Game Log (${GameLog.instance.entries.length} entries)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _GameLogScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Info footer ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$roleName Panel',
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  player.isOwner
                      ? 'Full owner access. Gift actions write directly to '
                            'Supabase. Username changes enforce uniqueness.'
                      : 'Moderator access. You can view player data, game '
                            'designs, and rename offensive usernames. Economy '
                            'and gifting tools are restricted to owners.',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Detail Screen (moderator + owner)
// ─────────────────────────────────────────────────────────────────────────────

class _UserDetailScreen extends StatefulWidget {
  const _UserDetailScreen({
    required this.userId,
    required this.username,
    required this.userData,
  });

  final String userId;
  final String username;
  final Map<String, dynamic> userData;

  @override
  State<_UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<_UserDetailScreen> {
  SupabaseClient get _client => Supabase.instance.client;
  List<Map<String, dynamic>> _recentGames = [];
  bool _gamesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentGames();
  }

  Future<void> _loadRecentGames() async {
    try {
      final data = await _client
          .from('scores')
          .select('id, score, time_ms, region, game_mode, created_at')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _recentGames = List<Map<String, dynamic>>.from(data);
        _gamesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _gamesLoading = false);
    }
  }

  Future<void> _triggerPasswordReset(BuildContext context) async {
    try {
      await _client.functions.invoke(
        'reset-user-password',
        body: {'user_id': widget.userId},
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
          backgroundColor: FlitColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: FlitColors.error,
        ),
      );
    }
  }

  void _showChangeEmailDialog(BuildContext context) {
    final emailCtl = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.email_outlined,
                  color: FlitColors.gold,
                  size: 36,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Change User Email',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'For @${widget.username}',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtl,
                  style: const TextStyle(color: FlitColors.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'New email address',
                    hintStyle: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: FlitColors.backgroundDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: FlitColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final email = emailCtl.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() => error = 'Enter a valid email');
                          return;
                        }
                        try {
                          await _client.functions.invoke(
                            'change-user-email',
                            body: {
                              'user_id': widget.userId,
                              'new_email': email,
                            },
                          );
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email updated.'),
                                backgroundColor: FlitColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => error = 'Failed: $e');
                        }
                      },
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Change Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.gold,
                        foregroundColor: FlitColors.backgroundDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.userData;
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text('@${widget.username}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile overview ──
          _UserDetailSection(
            title: 'Profile',
            children: [
              _DetailRow('Username', '@${u['username'] ?? '—'}'),
              _DetailRow('Display Name', '${u['display_name'] ?? '—'}'),
              _DetailRow('User ID', '${u['id'] ?? '—'}'),
              _DetailRow('Admin Role', '${u['admin_role'] ?? 'regular'}'),
              _DetailRow(
                'Created',
                u['created_at'] != null
                    ? DateTime.tryParse(
                            u['created_at'] as String,
                          )?.toLocal().toString().split('.').first ??
                          '—'
                    : '—',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Stats ──
          _UserDetailSection(
            title: 'Stats',
            children: [
              _DetailRow('Level', '${u['level'] ?? 0}'),
              _DetailRow('XP', '${u['xp'] ?? 0}'),
              _DetailRow('Coins', '${u['coins'] ?? 0}'),
              _DetailRow('Games Played', '${u['games_played'] ?? 0}'),
              _DetailRow('Best Score', '${u['best_score'] ?? '—'}'),
              _DetailRow(
                'Best Time',
                u['best_time_ms'] != null
                    ? '${(u['best_time_ms'] as int) / 1000}s'
                    : '—',
              ),
              _DetailRow(
                'Total Flight Time',
                u['total_flight_time_ms'] != null
                    ? '${((u['total_flight_time_ms'] as int) / 60000).toStringAsFixed(1)} min'
                    : '—',
              ),
              _DetailRow('Countries Found', '${u['countries_found'] ?? 0}'),
              _DetailRow('Flags Correct', '${u['flags_correct'] ?? 0}'),
              _DetailRow('Capitals Correct', '${u['capitals_correct'] ?? 0}'),
              _DetailRow('Outlines Correct', '${u['outlines_correct'] ?? 0}'),
              _DetailRow('Borders Correct', '${u['borders_correct'] ?? 0}'),
              _DetailRow('Stats Correct', '${u['stats_correct'] ?? 0}'),
              _DetailRow('Best Streak', '${u['best_streak'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 16),

          // ── Ban Status ──
          _UserDetailSection(
            title: 'Ban Status',
            children: [
              _DetailRow(
                'Status',
                u['banned_at'] != null
                    ? (u['ban_expires_at'] != null &&
                              DateTime.tryParse(
                                    u['ban_expires_at'] as String,
                                  )?.isBefore(DateTime.now()) ==
                                  true)
                          ? 'Expired'
                          : 'BANNED'
                    : 'Clean',
              ),
              if (u['banned_at'] != null) ...[
                _DetailRow(
                  'Banned At',
                  DateTime.tryParse(
                        u['banned_at'] as String,
                      )?.toLocal().toString().split('.').first ??
                      '—',
                ),
                _DetailRow(
                  'Expires',
                  u['ban_expires_at'] != null
                      ? DateTime.tryParse(
                              u['ban_expires_at'] as String,
                            )?.toLocal().toString().split('.').first ??
                            '—'
                      : 'Permanent',
                ),
                _DetailRow('Reason', u['ban_reason'] as String? ?? '—'),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Account Recovery Actions ──
          _UserDetailSection(
            title: 'Account Recovery',
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _triggerPasswordReset(context),
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: const Text(
                        'Send Password Reset',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlitColors.oceanHighlight,
                        side: const BorderSide(
                          color: FlitColors.oceanHighlight,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangeEmailDialog(context),
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text(
                        'Change Email (Owner)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlitColors.gold,
                        side: const BorderSide(color: FlitColors.gold),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Recent Games ──
          _UserDetailSection(
            title: 'Recent Games (${_recentGames.length})',
            children: [
              if (_gamesLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recentGames.isEmpty)
                const Text(
                  'No games found.',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
                )
              else
                ...(_recentGames.map((g) {
                  final score = g['score'] as int? ?? 0;
                  final timeMs = g['time_ms'] as int?;
                  final region = g['region'] as String? ?? '—';
                  final mode = g['game_mode'] as String? ?? '—';
                  final date = g['created_at'] != null
                      ? DateTime.tryParse(
                              g['created_at'] as String,
                            )?.toLocal().toString().split('.').first ??
                            '—'
                      : '—';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            date,
                            style: const TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            mode,
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            region,
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '$score',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: FlitColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            timeMs != null
                                ? '${(timeMs / 1000).toStringAsFixed(1)}s'
                                : '—',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserDetailSection extends StatelessWidget {
  const _UserDetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: FlitColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(color: FlitColors.textPrimary, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Coin Ledger Screen
// ─────────────────────────────────────────────────────────────────────────────

class _CoinLedgerScreen extends StatefulWidget {
  const _CoinLedgerScreen({required this.userId, required this.username});

  final String userId;
  final String username;

  @override
  State<_CoinLedgerScreen> createState() => _CoinLedgerScreenState();
}

class _CoinLedgerScreenState extends State<_CoinLedgerScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('coin_activity')
          .select('coin_amount, source, balance_after, created_at')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _entries = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.backgroundMid,
      title: Text('Coin Ledger • @${widget.username}'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: FlitColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          )
        : _entries.isEmpty
        ? const Center(
            child: Text(
              'No coin activity found.',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _entries.length,
            separatorBuilder: (_, __) =>
                const Divider(color: FlitColors.cardBorder, height: 1),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final amount = (entry['coin_amount'] as num?)?.toInt() ?? 0;
              final createdAt = DateTime.tryParse(
                (entry['created_at'] as String?) ?? '',
              );
              final time =
                  createdAt?.toLocal().toString().split('.').first ?? '';
              return ListTile(
                dense: true,
                title: Text(
                  '${amount >= 0 ? '+' : ''}$amount • ${entry['source'] ?? 'unknown'}',
                  style: TextStyle(
                    color: amount >= 0 ? FlitColors.success : FlitColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Balance: ${entry['balance_after'] ?? '—'}\n$time',
                  style: const TextStyle(color: FlitColors.textMuted),
                ),
              );
            },
          ),
  );
}

// ── Shared widgets ──

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        color: FlitColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.player});

  final dynamic player;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FlitColors.accent.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.accent, width: 2),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FlitColors.backgroundMid,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lv.${player.level} • ${player.coins} gold • '
                '${player.gamesPlayed} flights',
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.admin_panel_settings, color: FlitColors.gold),
      ],
    ),
  );
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    onPressed: onTap,
    backgroundColor: FlitColors.cardBackground,
    labelStyle: const TextStyle(color: FlitColors.textPrimary),
    side: const BorderSide(color: FlitColors.cardBorder),
  );
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: FlitColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

/// Reusable admin dialog with consistent styling.
class _AdminDialog extends StatelessWidget {
  const _AdminDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionColor,
    required this.onAction,
    required this.onCancel,
    this.subtitle,
    this.error,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? error;
  final List<Widget> children;
  final String actionLabel;
  final IconData actionIcon;
  final Color actionColor;
  final VoidCallback onAction;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: FlitColors.cardBackground,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ],
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: FlitColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 16),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: FlitColors.backgroundDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Username text field with @ prefix.
class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller, this.hint = 'Username'});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(color: FlitColors.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: FlitColors.textMuted),
      prefixText: '@',
      prefixStyle: const TextStyle(color: FlitColors.textSecondary),
      filled: true,
      fillColor: FlitColors.backgroundMid,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

/// Numeric amount text field.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.hint,
    this.isNumeric = true,
  });

  final TextEditingController controller;
  final String hint;
  final bool isNumeric;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: FlitColors.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: FlitColors.textMuted),
      filled: true,
      fillColor: FlitColors.backgroundMid,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

// ── Game Log Screen (preserved from debug) ──

class _GameLogScreen extends StatefulWidget {
  const _GameLogScreen();

  @override
  State<_GameLogScreen> createState() => _GameLogScreenState();
}

class _GameLogScreenState extends State<_GameLogScreen> {
  LogLevel _minLevel = LogLevel.debug;

  @override
  Widget build(BuildContext context) {
    final log = GameLog.instance;
    final entries = log.entriesAtLevel(_minLevel);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text('Game Log (${entries.length})'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy log',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.export()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log copied to clipboard'),
                  backgroundColor: FlitColors.success,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear log',
            onPressed: () {
              log.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'FILTER:',
                  style: TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                for (final level in LogLevel.values) ...[
                  _FilterChip(
                    label: level.name.toUpperCase(),
                    selected: _minLevel == level,
                    onTap: () => setState(() => _minLevel = level),
                    color: _levelColor(level),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'No log entries',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (_, i) {
                      final entry = entries[entries.length - 1 - i];
                      return _LogEntryTile(entry: entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(LogLevel level) => switch (level) {
    LogLevel.debug => FlitColors.textMuted,
    LogLevel.info => FlitColors.accent,
    LogLevel.warning => FlitColors.warning,
    LogLevel.error => FlitColors.error,
  };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? color : FlitColors.cardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : FlitColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _LogEntryTile extends StatefulWidget {
  const _LogEntryTile({required this.entry});

  final LogEntry entry;

  @override
  State<_LogEntryTile> createState() => _LogEntryTileState();
}

class _LogEntryTileState extends State<_LogEntryTile> {
  bool _isExpanded = false;

  void _copyEntry() {
    final buf = StringBuffer()
      ..writeln(
        '[${widget.entry.timeString}] ${widget.entry.levelTag} '
        '${widget.entry.category}',
      )
      ..writeln(widget.entry.message);
    if (widget.entry.data != null) buf.writeln('Data: ${widget.entry.data}');
    if (widget.entry.error != null) buf.writeln('Error: ${widget.entry.error}');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log entry copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = switch (entry.level) {
      LogLevel.debug => FlitColors.textMuted,
      LogLevel.info => FlitColors.textSecondary,
      LogLevel.warning => FlitColors.warning,
      LogLevel.error => FlitColors.error,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: entry.level == LogLevel.error
                ? Border.all(color: FlitColors.error.withOpacity(0.4))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.timeString,
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      entry.levelTag,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.category,
                      style: const TextStyle(
                        color: FlitColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: FlitColors.textMuted,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SelectableText(
                entry.message,
                style: TextStyle(
                  color: entry.level.index >= LogLevel.warning.index
                      ? color
                      : FlitColors.textPrimary,
                  fontSize: 12,
                ),
              ),
              if (entry.data != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _isExpanded
                      ? SelectableText(
                          '${entry.data}',
                          style: const TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        )
                      : Text(
                          '${entry.data}',
                          style: const TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              if (entry.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _isExpanded
                      ? SelectableText(
                          '${entry.error}',
                          style: const TextStyle(
                            color: FlitColors.error,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        )
                      : Text(
                          '${entry.error}',
                          style: const TextStyle(
                            color: FlitColors.error,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: GestureDetector(
                    onTap: _copyEntry,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 12, color: FlitColors.textMuted),
                        SizedBox(width: 4),
                        Text(
                          'Copy full entry',
                          style: TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Economy Config dialog widgets ──

/// A labelled text field used inside economy config dialogs.
class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.number,
    this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final String? hintText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: FlitColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: FlitColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: FlitColors.textMuted),
          filled: true,
          fillColor: FlitColors.backgroundMid,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    ],
  );
}

/// Dialog for managing promotions (list, add, toggle, delete).
class _PromotionsDialog extends StatefulWidget {
  const _PromotionsDialog({
    required this.initialPromotions,
    required this.onSave,
  });

  final List<Promotion> initialPromotions;
  final Future<void> Function(List<Promotion> promotions) onSave;

  @override
  State<_PromotionsDialog> createState() => _PromotionsDialogState();
}

class _PromotionsDialogState extends State<_PromotionsDialog> {
  late List<Promotion> _promotions;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _promotions = List.from(widget.initialPromotions);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_promotions);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save promotions';
        _saving = false;
      });
    }
  }

  void _showAddForm() {
    final nameCtl = TextEditingController();
    final multiplierCtl = TextEditingController(text: '1.5');
    final discountCtl = TextEditingController(text: '20');
    PromotionType selectedType = PromotionType.earningsBoost;
    DateTime? startDate;
    DateTime? endDate;
    bool manualActive = false;
    Set<String> selectedCategories = {'all'};
    String? formError;

    showDialog<void>(
      context: context,
      builder: (formCtx) => StatefulBuilder(
        builder: (ctx, setFormState) => Dialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Promotion',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (formError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      formError!,
                      style: const TextStyle(
                        color: FlitColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                _AdminTextField(
                  controller: nameCtl,
                  label: 'Name',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Type',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<PromotionType>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor: FlitColors.cardBackground,
                    style: const TextStyle(color: FlitColors.textPrimary),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: PromotionType.earningsBoost,
                        child: Text('Earnings Boost'),
                      ),
                      DropdownMenuItem(
                        value: PromotionType.shopDiscount,
                        child: Text('Shop Discount'),
                      ),
                      DropdownMenuItem(
                        value: PromotionType.both,
                        child: Text('Both'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setFormState(() => selectedType = v);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedType == PromotionType.earningsBoost ||
                    selectedType == PromotionType.both) ...[
                  _AdminTextField(
                    controller: multiplierCtl,
                    label: 'Earnings Multiplier (e.g. 1.5)',
                  ),
                  const SizedBox(height: 12),
                ],
                if (selectedType == PromotionType.shopDiscount ||
                    selectedType == PromotionType.both) ...[
                  _AdminTextField(
                    controller: discountCtl,
                    label: 'Shop Discount % (e.g. 20)',
                  ),
                  const SizedBox(height: 12),
                ],
                // Date pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Date (optional)',
                            style: TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setFormState(() => startDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: FlitColors.backgroundMid,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                startDate != null
                                    ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                                    : 'None',
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Date (optional)',
                            style: TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setFormState(() => endDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: FlitColors.backgroundMid,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                endDate != null
                                    ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                                    : 'None',
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manual Active',
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Switch(
                      value: manualActive,
                      activeColor: FlitColors.accent,
                      onChanged: (v) => setFormState(() => manualActive = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Category selector
                if (selectedType == PromotionType.shopDiscount ||
                    selectedType == PromotionType.both) ...[
                  const Text(
                    'Applies To',
                    style: TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in {
                        'all': 'All Items',
                        'planes': 'Planes',
                        'contrails': 'Contrails',
                        'companions': 'Companions',
                        'gold': 'Gold Packs',
                      }.entries)
                        FilterChip(
                          label: Text(
                            entry.value,
                            style: TextStyle(
                              color: selectedCategories.contains(entry.key)
                                  ? FlitColors.backgroundDark
                                  : FlitColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          selected: selectedCategories.contains(entry.key),
                          selectedColor: FlitColors.gold,
                          backgroundColor: FlitColors.backgroundMid,
                          checkmarkColor: FlitColors.backgroundDark,
                          side: BorderSide(
                            color: selectedCategories.contains(entry.key)
                                ? FlitColors.gold
                                : FlitColors.cardBorder,
                          ),
                          onSelected: (selected) {
                            setFormState(() {
                              if (entry.key == 'all') {
                                selectedCategories = {'all'};
                              } else {
                                selectedCategories.remove('all');
                                if (selected) {
                                  selectedCategories.add(entry.key);
                                } else {
                                  selectedCategories.remove(entry.key);
                                }
                                if (selectedCategories.isEmpty) {
                                  selectedCategories = {'all'};
                                }
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(formCtx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: FlitColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final name = nameCtl.text.trim();
                        if (name.isEmpty) {
                          setFormState(() => formError = 'Name is required');
                          return;
                        }
                        final multiplier =
                            (selectedType == PromotionType.earningsBoost ||
                                selectedType == PromotionType.both)
                            ? double.tryParse(multiplierCtl.text.trim()) ?? 1.0
                            : 1.0;
                        final discount =
                            (selectedType == PromotionType.shopDiscount ||
                                selectedType == PromotionType.both)
                            ? int.tryParse(discountCtl.text.trim()) ?? 0
                            : 0;

                        final promo = Promotion(
                          name: name,
                          type: selectedType,
                          earningsMultiplier: multiplier,
                          shopDiscountPercent: discount,
                          startDate: startDate,
                          endDate: endDate,
                          manualActive: manualActive,
                          appliesTo: selectedCategories.toList(),
                        );

                        setState(() => _promotions = [..._promotions, promo]);
                        Navigator.of(formCtx).pop();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.accent,
                        foregroundColor: FlitColors.backgroundDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _promotionStatusLabel(Promotion p) {
    if (p.manualActive) return 'Active (Manual)';
    final now = DateTime.now();
    final afterStart = p.startDate == null || !now.isBefore(p.startDate!);
    final beforeEnd = p.endDate == null || !now.isAfter(p.endDate!);
    if (afterStart && beforeEnd) return 'Active';
    if (p.startDate != null && now.isBefore(p.startDate!)) return 'Scheduled';
    return 'Expired';
  }

  Color _statusColor(String label) {
    if (label.startsWith('Active')) return FlitColors.success;
    if (label == 'Scheduled') return FlitColors.gold;
    return FlitColors.error;
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: FlitColors.cardBackground,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: FlitColors.accent, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Manage Promotions',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: FlitColors.accent),
                tooltip: 'Add Promotion',
                onPressed: _showAddForm,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: FlitColors.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          if (_promotions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No promotions. Tap + to add one.',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _promotions.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: FlitColors.cardBorder, height: 1),
                itemBuilder: (ctx, index) {
                  final promo = _promotions[index];
                  final statusLabel = _promotionStatusLabel(promo);
                  final statusColor = _statusColor(statusLabel);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                promo.name,
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: promo.manualActive,
                              activeColor: FlitColors.success,
                              onChanged: (v) {
                                final updated = Promotion(
                                  name: promo.name,
                                  type: promo.type,
                                  earningsMultiplier: promo.earningsMultiplier,
                                  shopDiscountPercent:
                                      promo.shopDiscountPercent,
                                  startDate: promo.startDate,
                                  endDate: promo.endDate,
                                  manualActive: v,
                                  appliesTo: promo.appliesTo,
                                );
                                setState(() {
                                  _promotions = [
                                    ..._promotions.sublist(0, index),
                                    updated,
                                    ..._promotions.sublist(index + 1),
                                  ];
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: FlitColors.error,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _promotions = [
                                    ..._promotions.sublist(0, index),
                                    ..._promotions.sublist(index + 1),
                                  ];
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${promo.type.name} • '
                          '${promo.earningsMultiplier}x earnings • '
                          '${promo.shopDiscountPercent}% off • '
                          '${promo.appliesTo.contains('all') || promo.appliesTo.isEmpty ? 'all items' : promo.appliesTo.join(', ')}',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: FlitColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FlitColors.backgroundDark,
                        ),
                      )
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.accent,
                  foregroundColor: FlitColors.backgroundDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Dialog for editing gold package promo prices.
class _GoldPackagesDialog extends StatefulWidget {
  const _GoldPackagesDialog({
    required this.initialPackages,
    required this.onSave,
  });

  final List<GoldPackageConfig> initialPackages;
  final Future<void> Function(List<GoldPackageConfig> packages) onSave;

  @override
  State<_GoldPackagesDialog> createState() => _GoldPackagesDialogState();
}

class _GoldPackagesDialogState extends State<_GoldPackagesDialog> {
  late List<TextEditingController> _controllers;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = widget.initialPackages.map((p) {
      return TextEditingController(
        text: p.promoPrice != null ? '${p.promoPrice}' : '',
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = widget.initialPackages.mapIndexed((i, pkg) {
        final text = _controllers[i].text.trim();
        final promoPrice = text.isEmpty ? null : double.tryParse(text);
        return pkg.withPromoPrice(promoPrice);
      }).toList();
      await widget.onSave(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save packages';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: FlitColors.cardBackground,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2, color: FlitColors.gold, size: 28),
              SizedBox(width: 10),
              Text(
                'Edit Gold Packages',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Set a promo price (leave blank for no promo).',
            style: TextStyle(color: FlitColors.textSecondary, fontSize: 12),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: FlitColors.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          ...widget.initialPackages.mapIndexed(
            (i, pkg) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pkg.coins} coins',
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Base: \$${pkg.basePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controllers[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Promo \$',
                        hintStyle: const TextStyle(color: FlitColors.textMuted),
                        filled: true,
                        fillColor: FlitColors.backgroundMid,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: FlitColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FlitColors.backgroundDark,
                        ),
                      )
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.gold,
                  foregroundColor: FlitColors.backgroundDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Dialog for viewing and editing per-cosmetic price overrides.
class _ShopPriceOverridesDialog extends StatefulWidget {
  const _ShopPriceOverridesDialog({
    required this.initialOverrides,
    required this.onSave,
  });

  final Map<String, int> initialOverrides;
  final Future<void> Function(Map<String, int> overrides) onSave;

  @override
  State<_ShopPriceOverridesDialog> createState() =>
      _ShopPriceOverridesDialogState();
}

class _ShopPriceOverridesDialogState extends State<_ShopPriceOverridesDialog> {
  late Map<String, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;

  static List<Cosmetic> get _allCosmetics => [
    ...CosmeticCatalog.planes,
    ...CosmeticCatalog.contrails,
    ...CosmeticCatalog.companions,
  ];

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final c in _allCosmetics)
        c.id: TextEditingController(
          text: widget.initialOverrides.containsKey(c.id)
              ? '${widget.initialOverrides[c.id]}'
              : '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final overrides = <String, int>{};
      for (final cosmetic in _allCosmetics) {
        final text = _controllers[cosmetic.id]!.text.trim();
        if (text.isNotEmpty) {
          final value = int.tryParse(text);
          if (value != null && value >= 0) {
            overrides[cosmetic.id] = value;
          }
        }
      }
      await widget.onSave(overrides);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save overrides';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cosmetics = _allCosmetics;

    return Dialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.price_change,
                  color: FlitColors.oceanHighlight,
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Shop Price Overrides',
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Leave blank to use catalog price. Overrides apply before promotions.',
              style: TextStyle(color: FlitColors.textSecondary, fontSize: 12),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: FlitColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cosmetics.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: FlitColors.cardBorder, height: 1),
                itemBuilder: (ctx, index) {
                  final cosmetic = cosmetics[index];
                  final ctl = _controllers[cosmetic.id]!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cosmetic.name,
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Catalog: ${cosmetic.price}',
                                style: const TextStyle(
                                  color: FlitColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: ctl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Override',
                              hintStyle: const TextStyle(
                                color: FlitColors.textMuted,
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: FlitColors.backgroundMid,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.restart_alt,
                            color: FlitColors.textMuted,
                            size: 18,
                          ),
                          tooltip: 'Reset to default',
                          onPressed: () => setState(() => ctl.text = ''),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: FlitColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FlitColors.backgroundDark,
                          ),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.oceanHighlight,
                    foregroundColor: FlitColors.backgroundDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to provide indexed map on List.
extension _ListMapIndexed<T> on List<T> {
  List<R> mapIndexed<R>(R Function(int index, T element) f) {
    final result = <R>[];
    for (var i = 0; i < length; i++) {
      result.add(f(i, this[i]));
    }
    return result;
  }
}

// =============================================================================
// Difficulty Editor Screen
// =============================================================================

/// Full-screen admin editor for viewing and filtering country difficulty ratings.
///
/// Shows all playable countries sorted by difficulty with search/filter.
/// Admin can tap a country to see details. Future: admin overrides via Supabase.
class _DifficultyEditorScreen extends StatefulWidget {
  const _DifficultyEditorScreen();

  @override
  State<_DifficultyEditorScreen> createState() =>
      _DifficultyEditorScreenState();
}

class _DifficultyEditorScreenState extends State<_DifficultyEditorScreen> {
  String _search = '';
  String _filterTier = 'all'; // all, easy, medium, hard, veryHard, extreme

  /// Mutable clue type weights — start with compiled-in defaults.
  late final Map<ClueType, double> _clueWeights = {
    for (final e in clueTypeDifficulty.entries) e.key: e.value,
  };

  /// Ordered list of clue types — controls display order of sliders.
  late final List<ClueType> _clueOrder = [
    ClueType.borders,
    ClueType.flag,
    ClueType.capital,
    ClueType.stats,
    ClueType.outline,
  ];

  static const _tierFilters = {
    'all': 'All',
    'veryEasy': 'Very Easy (0–15%)',
    'easy': 'Easy (15–30%)',
    'medium': 'Medium (30–50%)',
    'hard': 'Hard (50–70%)',
    'veryHard': 'Very Hard (70–85%)',
    'extreme': 'Extreme (85–100%)',
  };

  List<_CountryDiffEntry> get _entries {
    final defaults = defaultCountryDifficulty;
    final countries = CountryData.playableCountries;
    final entries = <_CountryDiffEntry>[];

    for (final country in countries) {
      final rating = defaults[country.code] ?? 0.55;
      entries.add(
        _CountryDiffEntry(
          code: country.code,
          name: country.name,
          rating: rating,
        ),
      );
    }

    // Apply search filter
    var filtered = entries.where((e) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.code.toLowerCase().contains(q);
    });

    // Apply tier filter
    if (_filterTier != 'all') {
      filtered = filtered.where((e) {
        switch (_filterTier) {
          case 'veryEasy':
            return e.rating <= 0.15;
          case 'easy':
            return e.rating > 0.15 && e.rating <= 0.30;
          case 'medium':
            return e.rating > 0.30 && e.rating <= 0.50;
          case 'hard':
            return e.rating > 0.50 && e.rating <= 0.70;
          case 'veryHard':
            return e.rating > 0.70 && e.rating <= 0.85;
          case 'extreme':
            return e.rating > 0.85;
          default:
            return true;
        }
      });
    }

    final list = filtered.toList()
      ..sort((a, b) => a.rating.compareTo(b.rating));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text('Country Difficulty (${entries.length})'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                hintStyle: const TextStyle(color: FlitColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: FlitColors.textMuted,
                ),
                filled: true,
                fillColor: FlitColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(color: FlitColors.textPrimary),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Tier filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _tierFilters.entries.map((entry) {
                final isActive = _filterTier == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        color: isActive
                            ? FlitColors.backgroundDark
                            : FlitColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    selected: isActive,
                    selectedColor: FlitColors.accent,
                    backgroundColor: FlitColors.cardBackground,
                    onSelected: (_) => setState(() => _filterTier = entry.key),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Individual clue type difficulty sliders
          _ClueWeightsSection(
            weights: _clueWeights,
            clueOrder: _clueOrder,
            onWeightChanged: (type, value) {
              setState(() => _clueWeights[type] = value);
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _clueOrder.removeAt(oldIndex);
                _clueOrder.insert(newIndex, item);
              });
            },
            onSortLowToHigh: () {
              setState(() {
                _clueOrder.sort(
                  (a, b) => (_clueWeights[a] ?? 0.5).compareTo(
                    _clueWeights[b] ?? 0.5,
                  ),
                );
              });
            },
          ),
          // Country list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final e = entries[index];
                return _DifficultyRow(entry: e);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportQueuePlaceholder extends StatefulWidget {
  const _ReportQueuePlaceholder();

  @override
  State<_ReportQueuePlaceholder> createState() =>
      _ReportQueuePlaceholderState();
}

class _ReportQueuePlaceholderState extends State<_ReportQueuePlaceholder>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<PlayerReport> _pendingReports = [];
  List<PlayerReport> _allReports = [];
  bool _pendingLoading = true;
  bool _allLoading = false;
  bool _allLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPending();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_allLoaded && !_allLoading) {
      _loadAll();
    }
  }

  Future<void> _loadPending() async {
    setState(() {
      _pendingLoading = true;
      _error = null;
    });
    try {
      final reports = await ReportService.instance.fetchPendingReports();
      if (!mounted) return;
      setState(() {
        _pendingReports = reports;
        _pendingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
        _pendingLoading = false;
      });
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _allLoading = true;
      _error = null;
    });
    try {
      final reports = await ReportService.instance.fetchAllReports();
      if (!mounted) return;
      setState(() {
        _allReports = reports;
        _allLoading = false;
        _allLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
        _allLoading = false;
      });
    }
  }

  void _showResolveDialog(PlayerReport report) {
    final actionCtl = TextEditingController();
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.gavel,
          iconColor: FlitColors.success,
          title: 'Resolve Report',
          subtitle:
              '${report.reporterUsername ?? report.reporterId} reported '
              '${report.reportedUsername ?? report.reportedId}',
          error: dialogError,
          actionLabel: 'Resolve',
          actionIcon: Icons.check,
          actionColor: FlitColors.success,
          onAction: () async {
            final action = actionCtl.text.trim();
            if (action.isEmpty) {
              setDialogState(() => dialogError = 'Describe the action taken');
              return;
            }
            try {
              await ReportService.instance.resolveReport(
                reportId: report.id,
                status: 'resolved',
                actionTaken: action,
              );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report resolved'),
                  backgroundColor: FlitColors.success,
                ),
              );
              _loadPending();
              if (_allLoaded) _loadAll();
            } catch (e) {
              setDialogState(() => dialogError = 'Failed: $e');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            TextField(
              controller: actionCtl,
              maxLines: 3,
              style: const TextStyle(color: FlitColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Action taken (e.g. warned user, banned, etc.)',
                hintStyle: const TextStyle(color: FlitColors.textMuted),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismissReport(PlayerReport report) async {
    try {
      await ReportService.instance.resolveReport(
        reportId: report.id,
        status: 'dismissed',
        actionTaken: 'Dismissed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report dismissed'),
          backgroundColor: FlitColors.success,
        ),
      );
      _loadPending();
      if (_allLoaded) _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dismiss: $e'),
          backgroundColor: FlitColors.error,
        ),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildReportCard(PlayerReport report, {bool showActions = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                color: FlitColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${report.reporterUsername ?? report.reporterId} '
                  'reported ${report.reportedUsername ?? report.reportedId}',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FlitColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ReportReason.label(report.reason),
              style: const TextStyle(
                color: FlitColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (report.details != null && report.details!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              report.details!,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatDate(report.createdAt),
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (!report.isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: report.status == 'resolved'
                        ? FlitColors.success.withOpacity(0.15)
                        : FlitColors.textMuted.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: TextStyle(
                      color: report.status == 'resolved'
                          ? FlitColors.success
                          : FlitColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (report.actionTaken != null && report.actionTaken!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Action: ${report.actionTaken}',
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissReport(report),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(color: FlitColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showResolveDialog(report),
                  icon: const Icon(Icons.gavel, size: 16),
                  label: const Text('Resolve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.success,
                    foregroundColor: FlitColors.backgroundDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Report Queue'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FlitColors.accent,
          labelColor: FlitColors.accent,
          unselectedLabelColor: FlitColors.textMuted,
          tabs: [
            Tab(
              text: _pendingReports.isEmpty
                  ? 'Pending'
                  : 'Pending (${_pendingReports.length})',
            ),
            const Tab(text: 'All'),
          ],
        ),
      ),
      body: _error != null && _tabController.index == 0 && _pendingLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: FlitColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Pending tab
                _pendingLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadPending,
                        child: _pendingReports.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 200),
                                  Center(
                                    child: Text(
                                      'No pending reports',
                                      style: TextStyle(
                                        color: FlitColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                itemCount: _pendingReports.length,
                                itemBuilder: (_, i) => _buildReportCard(
                                  _pendingReports[i],
                                  showActions: true,
                                ),
                              ),
                      ),
                // All tab
                _allLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        child: _allReports.isEmpty && _allLoaded
                            ? ListView(
                                children: const [
                                  SizedBox(height: 200),
                                  Center(
                                    child: Text(
                                      'No reports found',
                                      style: TextStyle(
                                        color: FlitColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                itemCount: _allReports.length,
                                itemBuilder: (_, i) =>
                                    _buildReportCard(_allReports[i]),
                              ),
                      ),
              ],
            ),
    );
  }
}

class _AppConfigPlaceholder extends StatefulWidget {
  const _AppConfigPlaceholder();

  @override
  State<_AppConfigPlaceholder> createState() => _AppConfigPlaceholderState();
}

class _AppConfigPlaceholderState extends State<_AppConfigPlaceholder> {
  final _minVersionCtl = TextEditingController();
  final _recommendedVersionCtl = TextEditingController();
  final _maintenanceMessageCtl = TextEditingController();
  bool _maintenanceMode = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  AppRemoteConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _minVersionCtl.dispose();
    _recommendedVersionCtl.dispose();
    _maintenanceMessageCtl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Invalidate cache so we always get fresh data in admin.
      AppConfigService.instance.invalidateCache();
      final config = await AppConfigService.instance.fetchConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _minVersionCtl.text = config.minAppVersion;
        _recommendedVersionCtl.text = config.recommendedVersion;
        _maintenanceMode = config.maintenanceMode;
        _maintenanceMessageCtl.text = config.maintenanceMessage ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load config: $e';
        _loading = false;
      });
    }
  }

  void _confirmAndSave() {
    if (_maintenanceMode && (_config == null || !_config!.maintenanceMode)) {
      // Enabling maintenance mode — confirm first.
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => _AdminDialog(
          icon: Icons.warning_amber,
          iconColor: FlitColors.error,
          title: 'Enable Maintenance Mode?',
          subtitle:
              'This will lock ALL users out of the app until maintenance '
              'mode is disabled.',
          error: null,
          actionLabel: 'Enable',
          actionIcon: Icons.power_settings_new,
          actionColor: FlitColors.error,
          onAction: () {
            Navigator.of(dialogCtx).pop();
            _save();
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: const [],
        ),
      );
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppConfigService.instance.updateConfig(
        minVersion: _minVersionCtl.text.trim(),
        recommendedVersion: _recommendedVersionCtl.text.trim(),
        maintenanceMode: _maintenanceMode,
        maintenanceMessage: _maintenanceMessageCtl.text.trim().isEmpty
            ? null
            : _maintenanceMessageCtl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Config saved'),
          backgroundColor: FlitColors.success,
        ),
      );
      _loadConfig();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: FlitColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: FlitColors.textMuted),
            filled: true,
            fillColor: FlitColors.backgroundDark,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
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
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('App Config'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FlitColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: FlitColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlitColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FlitColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Version Gates',
                          style: TextStyle(
                            color: FlitColors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Minimum App Version',
                          controller: _minVersionCtl,
                          hint: 'e.g. v1.0',
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Recommended Version',
                          controller: _recommendedVersionCtl,
                          hint: 'e.g. v1.5',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlitColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FlitColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maintenance Mode',
                          style: TextStyle(
                            color: FlitColors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _maintenanceMode
                                    ? 'Maintenance is ON — users are locked out'
                                    : 'Maintenance is OFF',
                                style: TextStyle(
                                  color: _maintenanceMode
                                      ? FlitColors.error
                                      : FlitColors.success,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: _maintenanceMode,
                              onChanged: (v) =>
                                  setState(() => _maintenanceMode = v),
                              activeColor: FlitColors.error,
                              inactiveThumbColor: FlitColors.textMuted,
                              inactiveTrackColor: FlitColors.backgroundLight,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          label: 'Maintenance Message',
                          controller: _maintenanceMessageCtl,
                          maxLines: 3,
                          hint: 'Message shown to users during maintenance',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _confirmAndSave,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FlitColors.backgroundDark,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_saving ? 'Saving...' : 'Save Config'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.accent,
                        foregroundColor: FlitColors.backgroundDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AnnouncementsPlaceholder extends StatefulWidget {
  const _AnnouncementsPlaceholder();

  @override
  State<_AnnouncementsPlaceholder> createState() =>
      _AnnouncementsPlaceholderState();
}

class _AnnouncementsPlaceholderState extends State<_AnnouncementsPlaceholder> {
  List<Announcement> _announcements = [];
  bool _loading = true;
  String? _error;

  static const _typeColors = <String, Color>{
    'info': FlitColors.accent,
    'warning': FlitColors.warning,
    'event': FlitColors.gold,
    'maintenance': FlitColors.error,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AnnouncementService.instance.fetchAll();
      if (!mounted) return;
      // Sort by priority desc, then createdAt desc.
      list.sort((a, b) {
        final cmp = b.priority.compareTo(a.priority);
        if (cmp != 0) return cmp;
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      setState(() {
        _announcements = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  void _showAnnouncementDialog({Announcement? existing}) {
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    final bodyCtl = TextEditingController(text: existing?.body ?? '');
    String type = existing?.type ?? 'info';
    int priority = existing?.priority ?? 5;
    bool isActive = existing?.isActive ?? true;
    DateTime? startsAt = existing?.startsAt;
    DateTime? expiresAt = existing?.expiresAt;
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: FlitColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      existing != null ? Icons.edit : Icons.campaign,
                      color: FlitColors.gold,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      existing != null
                          ? 'Edit Announcement'
                          : 'New Announcement',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FlitColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: FlitColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Title
                    TextField(
                      controller: titleCtl,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: const TextStyle(
                          color: FlitColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: FlitColors.backgroundDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: FlitColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: FlitColors.cardBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Body
                    TextField(
                      controller: bodyCtl,
                      maxLines: 3,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Body',
                        labelStyle: const TextStyle(
                          color: FlitColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: FlitColors.backgroundDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: FlitColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: FlitColors.cardBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Type dropdown
                    DropdownButtonFormField<String>(
                      value: type,
                      dropdownColor: FlitColors.backgroundMid,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle: const TextStyle(
                          color: FlitColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: FlitColors.backgroundDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: FlitColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: FlitColors.cardBorder,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'info', child: Text('Info')),
                        DropdownMenuItem(
                          value: 'warning',
                          child: Text('Warning'),
                        ),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Maintenance'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => type = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Priority slider
                    Row(
                      children: [
                        const Text(
                          'Priority',
                          style: TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: priority.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: '$priority',
                            activeColor: FlitColors.accent,
                            inactiveColor: FlitColors.backgroundLight,
                            onChanged: (v) =>
                                setDialogState(() => priority = v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$priority',
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Active toggle
                    Row(
                      children: [
                        const Text(
                          'Active',
                          style: TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setDialogState(() => isActive = v),
                          activeColor: FlitColors.success,
                          inactiveThumbColor: FlitColors.textMuted,
                          inactiveTrackColor: FlitColors.backgroundLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Date pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startsAt ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() => startsAt = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              startsAt != null
                                  ? 'Starts: ${_formatDate(startsAt)}'
                                  : 'Starts at...',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FlitColors.textSecondary,
                              side: const BorderSide(
                                color: FlitColors.cardBorder,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: expiresAt ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() => expiresAt = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              expiresAt != null
                                  ? 'Expires: ${_formatDate(expiresAt)}'
                                  : 'Expires at...',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FlitColors.textSecondary,
                              side: const BorderSide(
                                color: FlitColors.cardBorder,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: FlitColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final title = titleCtl.text.trim();
                            final body = bodyCtl.text.trim();
                            if (title.isEmpty || body.isEmpty) {
                              setDialogState(
                                () =>
                                    dialogError = 'Title and body are required',
                              );
                              return;
                            }
                            try {
                              await AnnouncementService.instance.upsert(
                                id: existing?.id,
                                title: title,
                                body: body,
                                type: type,
                                priority: priority,
                                isActive: isActive,
                                startsAt: startsAt,
                                expiresAt: expiresAt,
                              );
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    existing != null
                                        ? 'Announcement updated'
                                        : 'Announcement created',
                                  ),
                                  backgroundColor: FlitColors.success,
                                ),
                              );
                              _load();
                            } catch (e) {
                              setDialogState(() => dialogError = 'Failed: $e');
                            }
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlitColors.gold,
                            foregroundColor: FlitColors.backgroundDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(Announcement a) async {
    try {
      await AnnouncementService.instance.upsert(
        id: a.id,
        title: a.title,
        body: a.body,
        type: a.type,
        priority: a.priority,
        isActive: !a.isActive,
        startsAt: a.startsAt,
        expiresAt: a.expiresAt,
      );
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle: $e'),
          backgroundColor: FlitColors.error,
        ),
      );
    }
  }

  Widget _buildAnnouncementCard(Announcement a) {
    final typeColor = _typeColors[a.type] ?? FlitColors.accent;

    return GestureDetector(
      onTap: () => _showAnnouncementDialog(existing: a),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: a.isActive
                ? FlitColors.cardBorder
                : FlitColors.textMuted.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.title,
                    style: TextStyle(
                      color: a.isActive
                          ? FlitColors.textPrimary
                          : FlitColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: a.isActive,
                  onChanged: (_) => _toggleActive(a),
                  activeColor: FlitColors.success,
                  inactiveThumbColor: FlitColors.textMuted,
                  inactiveTrackColor: FlitColors.backgroundLight,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              a.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    a.type.toUpperCase(),
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Priority: ${a.priority}',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (a.startsAt != null || a.expiresAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: FlitColors.backgroundLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_formatDate(a.startsAt)} → ${_formatDate(a.expiresAt)}',
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Created: ${_formatDate(a.createdAt)}',
              style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text('Announcements (${_announcements.length})'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAnnouncementDialog(),
        backgroundColor: FlitColors.gold,
        child: const Icon(Icons.add, color: FlitColors.backgroundDark),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: FlitColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _announcements.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text(
                            'No announcements',
                            style: TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _announcements.length,
                      itemBuilder: (_, i) =>
                          _buildAnnouncementCard(_announcements[i]),
                    ),
            ),
    );
  }
}

class _SuspiciousActivityPlaceholder extends StatefulWidget {
  const _SuspiciousActivityPlaceholder();

  @override
  State<_SuspiciousActivityPlaceholder> createState() =>
      _SuspiciousActivityPlaceholderState();
}

class _SuspiciousActivityPlaceholderState
    extends State<_SuspiciousActivityPlaceholder> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _client
          .from('suspicious_activity')
          .select()
          .order('total_games_24h', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  List<String> _getFlags(Map<String, dynamic> row) {
    final flags = <String>[];
    final totalGames = (row['total_games_24h'] as num?)?.toInt() ?? 0;
    final coinsEarned = (row['coins_earned_24h'] as num?)?.toInt() ?? 0;
    final bestScore = (row['best_score'] as num?)?.toInt() ?? 0;

    // Flag thresholds — these are heuristic. Adjust as needed.
    if (totalGames > 100) flags.add('High game count ($totalGames)');
    if (coinsEarned > 10000) flags.add('High coins ($coinsEarned)');
    if (bestScore >= 5000) flags.add('Perfect score ($bestScore)');
    return flags;
  }

  Color _severityColor(int flagCount) {
    if (flagCount >= 2) return FlitColors.error;
    if (flagCount == 1) return FlitColors.warning;
    return FlitColors.textMuted;
  }

  void _showUserDialog(Map<String, dynamic> row) {
    final username = row['username'] as String? ?? 'Unknown';
    final userId = row['user_id'] as String? ?? '';
    final totalGames = (row['total_games_24h'] as num?)?.toInt() ?? 0;
    final coinsEarned = (row['coins_earned_24h'] as num?)?.toInt() ?? 0;
    final bestScore = (row['best_score'] as num?)?.toInt() ?? 0;
    final flags = _getFlags(row);
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _AdminDialog(
          icon: Icons.person_search,
          iconColor: _severityColor(flags.length),
          title: '@$username',
          subtitle: 'Suspicious activity details',
          error: dialogError,
          actionLabel: 'Ban User',
          actionIcon: Icons.block,
          actionColor: FlitColors.error,
          onAction: () async {
            try {
              await _client.rpc(
                'admin_ban_user',
                params: {
                  'target_user_id': userId,
                  'p_reason': 'Suspicious activity — ${flags.join(', ')}',
                  'p_duration_days': null,
                },
              );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Banned @$username'),
                  backgroundColor: FlitColors.success,
                ),
              );
              _load();
            } catch (e) {
              setDialogState(() => dialogError = 'Failed: $e');
            }
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
          children: [
            _SuspiciousDetailRow('Games (24h)', '$totalGames'),
            _SuspiciousDetailRow('Coins earned (24h)', '$coinsEarned'),
            _SuspiciousDetailRow('Best score', '$bestScore'),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Flags:',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...flags.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag,
                        size: 14,
                        color: _severityColor(flags.length),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        f,
                        style: TextStyle(
                          color: _severityColor(flags.length),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text('Suspicious Activity (${_rows.length})'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: FlitColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text(
                            'No suspicious activity detected',
                            style: TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: FlitColors.backgroundMid,
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'USER',
                                  style: TextStyle(
                                    color: FlitColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'GAMES',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: FlitColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'COINS',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: FlitColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'BEST',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: FlitColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              SizedBox(width: 32),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _rows.length,
                            itemBuilder: (_, i) {
                              final row = _rows[i];
                              final username =
                                  row['username'] as String? ?? '—';
                              final totalGames =
                                  (row['total_games_24h'] as num?)?.toInt() ??
                                  0;
                              final coinsEarned =
                                  (row['coins_earned_24h'] as num?)?.toInt() ??
                                  0;
                              final bestScore =
                                  (row['best_score'] as num?)?.toInt() ?? 0;
                              final flags = _getFlags(row);
                              final severity = _severityColor(flags.length);
                              return InkWell(
                                onTap: () => _showUserDialog(row),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: FlitColors.cardBorder
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            if (flags.isNotEmpty)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: severity,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            Flexible(
                                              child: Text(
                                                '@$username',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      severity ==
                                                          FlitColors.textMuted
                                                      ? FlitColors.textPrimary
                                                      : severity,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$totalGames',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: FlitColors.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$coinsEarned',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: FlitColors.gold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$bestScore',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: FlitColors.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: FlitColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

/// Individual clue type difficulty sliders with drag-to-reorder support.
///
/// Each clue type has its own slider to adjust difficulty weight independently.
/// Sliders can be reordered via drag handles. A "Sort Low → High" button
/// re-orders all sliders by their current difficulty value.
class _ClueWeightsSection extends StatelessWidget {
  const _ClueWeightsSection({
    required this.weights,
    required this.clueOrder,
    required this.onWeightChanged,
    required this.onReorder,
    required this.onSortLowToHigh,
  });

  final Map<ClueType, double> weights;
  final List<ClueType> clueOrder;
  final void Function(ClueType, double) onWeightChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onSortLowToHigh;

  static const _clueIcons = <ClueType, IconData>{
    ClueType.borders: Icons.near_me,
    ClueType.flag: Icons.flag,
    ClueType.capital: Icons.location_city,
    ClueType.stats: Icons.bar_chart,
    ClueType.outline: Icons.crop_square,
  };

  static const List<Color> _gradientColors = [
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFFF44336),
  ];

  Color _colorForWeight(double w) {
    final idx = (w * (_gradientColors.length - 1)).round();
    return _gradientColors[idx.clamp(0, _gradientColors.length - 1)];
  }

  /// True when the current order already matches low-to-high by weight.
  bool get _isSortedLowToHigh {
    for (var i = 1; i < clueOrder.length; i++) {
      final prev = weights[clueOrder[i - 1]] ?? 0.5;
      final curr = weights[clueOrder[i]] ?? 0.5;
      if (curr < prev) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: FlitColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Clue Difficulty',
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Sort Low → High button
                  if (_isSortedLowToHigh)
                    GestureDetector(
                      onTap: onSortLowToHigh,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FlitColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: FlitColors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.sort,
                              size: 12,
                              color: FlitColors.accent,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Sort Low → High',
                              style: TextStyle(
                                color: FlitColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: FlitColors.cardBorder, height: 1),
            // Reorderable slider list
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: onReorder,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final elevation = Tween<double>(
                      begin: 0,
                      end: 4,
                    ).animate(animation).value;
                    return Material(
                      color: FlitColors.cardBackground,
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemCount: clueOrder.length,
              itemBuilder: (context, index) {
                final type = clueOrder[index];
                final weight = weights[type] ?? 0.5;
                final label = clueTypeDifficultyLabel[type] ?? type.name;
                final color = _colorForWeight(weight);

                return Padding(
                  key: ValueKey(type),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      // Drag handle
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.drag_indicator,
                            color: FlitColors.textMuted.withOpacity(0.5),
                            size: 16,
                          ),
                        ),
                      ),
                      Icon(
                        _clueIcons[type] ?? Icons.help_outline,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 64,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: color,
                            inactiveTrackColor: FlitColors.backgroundMid,
                            thumbColor: color,
                            overlayColor: color.withOpacity(0.15),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                          ),
                          child: Slider(
                            value: weight,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            onChanged: (v) => onWeightChanged(type, v),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(weight * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Simple key-value row for the suspicious activity detail dialog.
class _SuspiciousDetailRow extends StatelessWidget {
  const _SuspiciousDetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(color: FlitColors.textPrimary, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _CountryDiffEntry {
  const _CountryDiffEntry({
    required this.code,
    required this.name,
    required this.rating,
  });
  final String code;
  final String name;
  final double rating;

  int get percent => (rating * 100).round();
  String get label => difficultyLabel(rating);
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.entry});

  final _CountryDiffEntry entry;

  static const List<Color> _gradientColors = [
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFFF44336),
  ];

  Color get _barColor {
    final idx = difficultyBandIndex(entry.rating);
    return _gradientColors[idx.clamp(0, _gradientColors.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Country code badge
            Container(
              width: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.code,
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Country name
            Expanded(
              child: Text(
                entry.name,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Difficulty bar
            SizedBox(
              width: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: entry.rating,
                  backgroundColor: FlitColors.backgroundMid,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Percentage
            SizedBox(
              width: 32,
              child: Text(
                '${entry.percent}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Label
            SizedBox(
              width: 70,
              child: Text(
                entry.label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
