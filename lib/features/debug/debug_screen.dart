import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
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
              const Icon(Icons.monetization_on, color: FlitColors.gold, size: 36),
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
                    child: const Text('Cancel',
                        style: TextStyle(color: FlitColors.textMuted)),
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
              const Icon(Icons.card_giftcard, color: FlitColors.accent, size: 36),
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
                    child: const Text('Cancel',
                        style: TextStyle(color: FlitColors.textMuted)),
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
                            content: Text('Premium upgrade gifted to @$username'),
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
    String selectedItemId = 'plane_golden_jet';
    final items = <String, String>{
      'plane_golden_jet': 'Golden Private Jet',
      'plane_diamond_concorde': 'Diamond Concorde',
      'plane_platinum_eagle': 'Platinum Eagle',
      'contrail_gold_dust': 'Gold Dust Trail',
      'contrail_aurora': 'Aurora Trail',
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
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
                      child: const Text('Cancel',
                          style: TextStyle(color: FlitColors.textMuted)),
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
                                  '${items[selectedItemId]} gifted to @$username'),
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
          _AccountCard(
            player: state.currentPlayer,
            isSelected: true,
          ),
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
                onTap: () => notifier.addCoins(100),
              ),
              _ActionChip(
                label: '+1000 Coins',
                onTap: () => notifier.addCoins(1000),
              ),
              _ActionChip(
                label: '+50 XP',
                onTap: () => notifier.addXp(50),
              ),
              _ActionChip(
                label: '+500 XP',
                onTap: () => notifier.addXp(500),
              ),
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
                  const Icon(
                    Icons.check_circle,
                    color: FlitColors.accent,
                  ),
              ],
            ),
          ),
        ),
      );
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
  });

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
