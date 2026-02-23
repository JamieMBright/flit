import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/avatar_config.dart';
import 'package:flit/data/providers/account_provider.dart';

void main() {
  group('AccountNotifier.loadFromSupabase', () {
    test('returns false when cloud snapshot cannot be loaded', () async {
      final notifier = AccountNotifier();

      final loaded = await notifier.loadFromSupabase('user-123');

      expect(loaded, isFalse);
      expect(notifier.state.currentPlayer.id, isEmpty);
      expect(notifier.state.currentPlayer.level, equals(1));
      expect(notifier.state.currentPlayer.coins, equals(0));
      expect(notifier.state.currentPlayer.gamesPlayed, equals(0));

      notifier.dispose();
    });
  });

  group('AccountNotifier local state updates', () {
    test('recordGameCompletion updates profile stats in-memory', () async {
      final notifier = AccountNotifier();

      await notifier.recordGameCompletion(
        elapsed: const Duration(seconds: 30),
        score: 500,
        roundsCompleted: 2,
      );

      final player = notifier.state.currentPlayer;
      expect(player.gamesPlayed, equals(1));
      expect(player.bestScore, equals(500));
      expect(player.bestTime, equals(const Duration(seconds: 30)));
      expect(player.totalFlightTime, equals(const Duration(seconds: 30)));
      expect(player.countriesFound, equals(2));
      expect(player.level, equals(1));
      expect(player.xp, equals(75));

      notifier.dispose();
    });

    test('updateAvatar updates in-memory avatar config', () async {
      final notifier = AccountNotifier();
      const avatar = AvatarConfig(
        style: AvatarStyle.avataaars,
        eyes: AvatarEyes.variant05,
      );

      await notifier.updateAvatar(avatar);

      expect(notifier.state.avatar, equals(avatar));
      notifier.dispose();
    });

    test('spendCoins supports explicit source/logActivity flags', () {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );
      notifier.addCoins(100, applyBoost: false, source: 'test_grant');

      final spent = notifier.spendCoins(
        25,
        source: 'test_purchase',
        logActivity: false,
      );

      expect(spent, isTrue);
      expect(notifier.state.currentPlayer.coins, equals(75));
      notifier.dispose();
    });
  });
}
