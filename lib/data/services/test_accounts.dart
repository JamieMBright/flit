import '../models/player.dart';

/// Test accounts for development and testing.
/// These allow testing challenges (both sides) and unlocking all content.
abstract class TestAccounts {
  /// Test account 1 - Regular player
  static Player get player1 => const Player(
        id: 'test-player-1',
        username: 'TestPilot1',
        displayName: 'Test Pilot One',
        level: 5,
        xp: 250,
        coins: 500,
        gamesPlayed: 42,
      );

  /// Test account 2 - Regular player (for testing challenges)
  static Player get player2 => const Player(
        id: 'test-player-2',
        username: 'TestPilot2',
        displayName: 'Test Pilot Two',
        level: 3,
        xp: 150,
        coins: 300,
        gamesPlayed: 28,
      );

  /// God account - All content unlocked
  static Player get godAccount => const Player(
        id: 'god-account',
        username: 'FlitGod',
        displayName: 'Flit God Mode',
        level: 99,
        xp: 9999,
        coins: 999999, // Lots of coins to buy everything
        gamesPlayed: 9999,
      );

  /// New player account - Fresh start
  static Player get newPlayer => const Player(
        id: 'new-player',
        username: 'NewPilot',
        displayName: 'New Pilot',
        level: 1,
        xp: 0,
        coins: 100, // Starting bonus
        gamesPlayed: 0,
      );

  /// All test accounts
  static List<Player> get all => [player1, player2, godAccount, newPlayer];
}
