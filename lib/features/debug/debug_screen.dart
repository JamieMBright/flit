import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/player.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/test_accounts.dart';

/// Debug screen for testing - switch accounts, add coins, etc.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  void _showGiftCoinsDialog(BuildContext context, WidgetRef ref) {
    final usernameController = TextEditingController();
    final amountController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                color: FlitColors.gold,
                size: 36,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gift Coins',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Username',
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
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Amount',
                  hintStyle: const TextStyle(color: FlitColors.textMuted),
                  filled: true,
                  fillColor: FlitColors.backgroundMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final username = usernameController.text.trim();
                      final amount = int.tryParse(amountController.text) ?? 0;
                      if (username.isNotEmpty && amount > 0) {
                        Navigator.of(dialogContext).pop();
                        // TODO: Send via backend API
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gifted $amount coins to @$username'),
                            backgroundColor: FlitColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Gift'),
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
  }

  void _showGiftPremiumDialog(BuildContext context) {
    final usernameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.card_giftcard,
                color: FlitColors.accent,
                size: 36,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gift Premium Upgrade',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Unlocks all premium cosmetics for the user',
                style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Username',
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
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final username = usernameController.text.trim();
                      if (username.isNotEmpty) {
                        Navigator.of(dialogContext).pop();
                        // TODO: Send via backend API
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Premium upgrade gifted to @$username',
                            ),
                            backgroundColor: FlitColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Gift Premium'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGiftCosmeticDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final allCosmetics = CosmeticCatalog.all;
    String selectedItemId = allCosmetics.first.id;
    final items = <String, String>{for (final c in allCosmetics) c.id: c.name};
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                TextField(
                  controller: usernameController,
                  style: const TextStyle(color: FlitColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: const TextStyle(color: FlitColors.textMuted),
                    prefixText: '@',
                    prefixStyle: const TextStyle(
                      color: FlitColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: FlitColors.backgroundMid,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: FlitColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final username = usernameController.text.trim();
                        if (username.isNotEmpty) {
                          Navigator.of(dialogContext).pop();
                          // TODO: Send via backend API
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${items[selectedItemId]} gifted to @$username',
                              ),
                              backgroundColor: FlitColors.success,
                            ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Debug / Test Mode'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current account info
          const _SectionHeader(title: 'Current Account'),
          _AccountCard(player: state.currentPlayer, isSelected: true),
          const SizedBox(height: 24),

          // Switch accounts
          const _SectionHeader(title: 'Switch Account'),
          const SizedBox(height: 8),
          ...TestAccounts.all.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccountCard(
                player: player,
                isSelected: state.currentPlayer.id == player.id,
                onTap: () => notifier.switchAccount(player),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          const _SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: '+100 Coins',
                onTap: () => notifier.addCoins(100, applyBoost: false),
              ),
              _ActionChip(
                label: '+1000 Coins',
                onTap: () => notifier.addCoins(1000, applyBoost: false),
              ),
              _ActionChip(label: '+50 XP', onTap: () => notifier.addXp(50)),
              _ActionChip(label: '+500 XP', onTap: () => notifier.addXp(500)),
              _ActionChip(
                label: '+1 Game',
                onTap: () => notifier.incrementGamesPlayed(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Admin Gifting
          const _SectionHeader(title: 'Admin Gifting'),
          const SizedBox(height: 8),
          _AdminGiftCard(
            icon: Icons.monetization_on,
            iconColor: FlitColors.gold,
            label: 'Gift Coins to Player',
            onTap: () => _showGiftCoinsDialog(context, ref),
          ),
          const SizedBox(height: 8),
          _AdminGiftCard(
            icon: Icons.card_giftcard,
            iconColor: FlitColors.accent,
            label: 'Gift Premium Upgrade',
            onTap: () => _showGiftPremiumDialog(context),
          ),
          const SizedBox(height: 8),
          _AdminGiftCard(
            icon: Icons.star,
            iconColor: const Color(0xFF9B59B6),
            label: 'Gift Cosmetic Item',
            onTap: () => _showGiftCosmeticDialog(context),
          ),
          const SizedBox(height: 24),

          // Game Log
          const _SectionHeader(title: 'Game Log'),
          const SizedBox(height: 8),
          _AdminGiftCard(
            icon: Icons.bug_report,
            iconColor: FlitColors.warning,
            label: 'View Game Log (${GameLog.instance.entries.length} entries)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _GameLogScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // Info
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
                  'Testing Guide',
                  style: TextStyle(
                    color: FlitColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Use Player 1 & Player 2 to test challenges\n'
                  '• God Account has all maps unlocked\n'
                  '• New Player simulates a fresh user\n'
                  '• Changes persist only for this session\n'
                  '• Admin gifting sends gifts to users by username',
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
  const _AccountCard({
    required this.player,
    required this.isSelected,
    this.onTap,
  });

  final Player player;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: isSelected
        ? FlitColors.accent.withOpacity(0.2)
        : FlitColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? FlitColors.accent : FlitColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  player.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
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
                    'Lv.${player.level} • ${player.coins} coins • ${player.gamesPlayed} games',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Selected indicator
            if (isSelected)
              const Icon(Icons.check_circle, color: FlitColors.accent),
          ],
        ),
      ),
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

class _AdminGiftCard extends StatelessWidget {
  const _AdminGiftCard({
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

/// Full-screen log viewer with filtering and copy-to-clipboard.
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
          // Copy all
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
          // Clear
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
          // Filter bar
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
          // Log entries
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
                    reverse: true, // newest first
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

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.debug => FlitColors.textMuted,
      LogLevel.info => FlitColors.textSecondary,
      LogLevel.warning => FlitColors.warning,
      LogLevel.error => FlitColors.error,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
                Text(
                  entry.category,
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
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
                child: Text(
                  '${entry.data}',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            if (entry.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${entry.error}',
                  style: const TextStyle(
                    color: FlitColors.error,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
