import 'package:flutter_test/flutter_test.dart';

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
}
