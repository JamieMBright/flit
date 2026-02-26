import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/economy_config.dart';
import '../../data/models/pilot_license.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/economy_config_service.dart';
import '../debug/avatar_preview_screen.dart';
import '../debug/plane_preview_screen.dart';
import 'admin_stats_screen.dart';

/// Admin panel — visible only to the admin email (jamiebright1@gmail.com).
///
/// Features:
/// - Self-service: unlimited gold, XP, flights
/// - Gift gold / levels / flights to any user by username
/// - Moderation: change any user's username
/// - Game log viewer
/// - Economy config editor (earnings, promotions, gold packages, price overrides)
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

  @override
  void initState() {
    super.initState();
    _loadEconomyConfig();
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

  // ── Supabase helpers ──

  /// Look up a profile row by username. Returns null if not found.
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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Admin Panel'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current account info
          const _SectionHeader(title: 'Current Account'),
          _AccountCard(player: state.currentPlayer),
          const SizedBox(height: 24),

          // Usage Stats
          const _SectionHeader(title: 'Analytics'),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.analytics,
            iconColor: FlitColors.oceanHighlight,
            label: 'Usage Stats',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminStatsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.receipt_long,
            iconColor: FlitColors.gold,
            label: 'Coin Ledger Explorer',
            onTap: () => _showCoinLedgerDialog(context),
          ),
          const SizedBox(height: 24),

          // Quick self-actions
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

          // Admin gifting tools
          const _SectionHeader(title: 'Gift to Player'),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.monetization_on,
            iconColor: FlitColors.gold,
            label: 'Gift Gold',
            onTap: () => _showGiftGoldDialog(context),
          ),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.arrow_upward,
            iconColor: FlitColors.accent,
            label: 'Gift Levels',
            onTap: () => _showGiftLevelsDialog(context),
          ),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.flight,
            iconColor: FlitColors.oceanHighlight,
            label: 'Gift Flights',
            onTap: () => _showGiftFlightsDialog(context),
          ),
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
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.star,
            iconColor: const Color(0xFF9B59B6),
            label: 'Gift Cosmetic Item',
            onTap: () => _showGiftCosmeticDialog(context),
          ),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.badge,
            iconColor: FlitColors.oceanHighlight,
            label: 'Set Player License',
            onTap: () => _showSetLicenseDialog(context),
          ),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.face,
            iconColor: FlitColors.gold,
            label: 'Set Player Avatar',
            onTap: () => _showSetAvatarDialog(context),
          ),
          const SizedBox(height: 24),

          // Moderation
          const _SectionHeader(title: 'Moderation'),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.edit,
            iconColor: FlitColors.warning,
            label: 'Change Player Username',
            onTap: () => _showChangeUsernameDialog(context),
          ),
          const SizedBox(height: 8),
          if (state.currentPlayer.isOwner) ...[
            _AdminActionCard(
              icon: Icons.shield,
              iconColor: FlitColors.accent,
              label: 'Manage Moderators',
              onTap: () => _showManageRoleDialog(context),
            ),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.lock_open,
              iconColor: FlitColors.success,
              label: 'Unlock All (Player)',
              onTap: () => _showUnlockAllDialog(context),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),

          // Design Preview
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
          const SizedBox(height: 24),

          // Economy Config
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
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.local_offer,
              iconColor: FlitColors.accent,
              label: 'Manage Promotions',
              onTap: () => _showPromotionsDialog(context),
            ),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.inventory_2,
              iconColor: FlitColors.gold,
              label: 'Edit Gold Packages',
              onTap: () => _showGoldPackagesDialog(context),
            ),
            const SizedBox(height: 8),
            _AdminActionCard(
              icon: Icons.price_change,
              iconColor: FlitColors.oceanHighlight,
              label: 'Shop Price Overrides',
              onTap: () => _showShopPriceOverridesDialog(context),
            ),
          ],
          const SizedBox(height: 24),

          // Game Log
          const _SectionHeader(title: 'Game Log'),
          const SizedBox(height: 8),
          _AdminActionCard(
            icon: Icons.bug_report,
            iconColor: FlitColors.warning,
            label: 'View Game Log (${GameLog.instance.entries.length} entries)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _GameLogScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // Info footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Only',
                  style: TextStyle(
                    color: FlitColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This panel is only visible to the admin account.\n'
                  'Gift actions write directly to Supabase.\n'
                  'Username changes enforce uniqueness.',
                  style: TextStyle(
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
