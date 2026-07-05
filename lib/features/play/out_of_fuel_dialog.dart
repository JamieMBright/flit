import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../game/economy/fuel_tank.dart';

/// Shown mid-flight the moment a free-flight EARNING session runs the meta
/// tank dry (owner spec):
/// (a) explains WHY earnings paused — fuel gates coin farming, flying
///     continues free;
/// (b) shows the wait — time until the next coin's worth of fuel regens
///     and until the tank is full;
/// (c) offers immediate options — use a canister (shows owned count) or
///     an instant coin refuel. One tap = refuel + keep flying.
///
/// Returns true when the player refuelled (so the caller can re-arm the
/// empty-tank trigger for later in the session).
Future<bool> showOutOfFuelDialog(BuildContext context) async {
  final refuelled = await showDialog<bool>(
    context: context,
    builder: (_) => const _OutOfFuelDialog(),
  );
  return refuelled ?? false;
}

class _OutOfFuelDialog extends ConsumerWidget {
  const _OutOfFuelDialog();

  static String _fmt(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '<1m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);
    final now = DateTime.now().toUtc();
    final capacity = notifier.fuelCapacity;
    final tank = account.fuelTank;
    final untilNextCoin =
        tank.timeUntil(now, FuelTank.fuelPerClue, capacity: capacity);
    final untilFull = tank.timeUntil(now, capacity, capacity: capacity);
    final coins = account.currentPlayer.coins;
    final refuelCost = notifier.instantRefuelCost;
    final canisters = account.refuelCanisters;

    void refuel(bool Function() action, String failMessage) {
      final ok = action();
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failMessage),
            backgroundColor: FlitColors.error,
          ),
        );
      }
    }

    return AlertDialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.local_gas_station, color: FlitColors.warning, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'EARNING TANK EMPTY',
              style: TextStyle(
                color: FlitColors.warning,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (a) WHY earnings paused.
          const Text(
            'Coin earnings are paused — fuel gates coin farming. Flying '
            'stays free: keep exploring as long as you like.',
            style: TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // (b) The wait until meaningful regen.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next coin in ${_fmt(untilNextCoin)}',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Full tank in ${_fmt(untilFull)}',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // (c) Immediate options — one tap refuels and continues.
          if (canisters > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => refuel(
                  notifier.useRefuelCanister,
                  'No canisters left',
                ),
                icon: const Icon(Icons.local_gas_station, size: 16),
                label: Text('USE CANISTER ($canisters owned)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.accent,
                  foregroundColor: FlitColors.textPrimary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: coins >= refuelCost
                  ? () => refuel(
                        notifier.refuelWithCoins,
                        'Not enough coins',
                      )
                  : null,
              icon: const Icon(Icons.monetization_on, size: 16),
              label: Text('REFUEL FULL · $refuelCost coins'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.gold,
                foregroundColor: FlitColors.backgroundDark,
                disabledBackgroundColor:
                    FlitColors.textMuted.withValues(alpha: 0.3),
                disabledForegroundColor: FlitColors.textMuted,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          if (coins < refuelCost)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Need ${refuelCost - coins} more coins for a full refuel.',
                style: const TextStyle(
                  color: FlitColors.error,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Keep flying (no earnings)',
            style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
