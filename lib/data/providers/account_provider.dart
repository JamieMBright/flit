import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player.dart';
import '../services/test_accounts.dart';

/// Current account state.
class AccountState {
  const AccountState({
    required this.currentPlayer,
    this.isDebugMode = true, // Default to debug mode during development
  });

  final Player currentPlayer;
  final bool isDebugMode;

  AccountState copyWith({
    Player? currentPlayer,
    bool? isDebugMode,
  }) =>
      AccountState(
        currentPlayer: currentPlayer ?? this.currentPlayer,
        isDebugMode: isDebugMode ?? this.isDebugMode,
      );
}

/// Account state notifier.
class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier()
      : super(AccountState(
          currentPlayer: TestAccounts.player1,
        ));

  /// Switch to a different test account
  void switchAccount(Player player) {
    state = state.copyWith(currentPlayer: player);
  }

  /// Switch to player 1 (for challenge testing)
  void switchToPlayer1() => switchAccount(TestAccounts.player1);

  /// Switch to player 2 (for challenge testing)
  void switchToPlayer2() => switchAccount(TestAccounts.player2);

  /// Switch to god account (all unlocked)
  void switchToGodAccount() => switchAccount(TestAccounts.godAccount);

  /// Switch to new player (fresh start)
  void switchToNewPlayer() => switchAccount(TestAccounts.newPlayer);

  /// Add coins to current account
  void addCoins(int amount) {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        coins: state.currentPlayer.coins + amount,
      ),
    );
  }

  /// Add XP and handle level ups
  void addXp(int amount) {
    var player = state.currentPlayer;
    var newXp = player.xp + amount;
    var newLevel = player.level;

    // Handle level ups
    while (newXp >= newLevel * 100) {
      newXp -= newLevel * 100;
      newLevel++;
    }

    state = state.copyWith(
      currentPlayer: player.copyWith(
        xp: newXp,
        level: newLevel,
      ),
    );
  }

  /// Increment games played
  void incrementGamesPlayed() {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        gamesPlayed: state.currentPlayer.gamesPlayed + 1,
      ),
    );
  }

  /// Update best time if better
  void updateBestTime(Duration time) {
    final current = state.currentPlayer.bestTime;
    if (current == null || time < current) {
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(bestTime: time),
      );
    }
  }

  /// Toggle debug mode
  void toggleDebugMode() {
    state = state.copyWith(isDebugMode: !state.isDebugMode);
  }
}

/// Account provider
final accountProvider =
    StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  return AccountNotifier();
});

/// Convenience provider for current player
final currentPlayerProvider = Provider<Player>((ref) {
  return ref.watch(accountProvider).currentPlayer;
});

/// Convenience provider for current player level
final currentLevelProvider = Provider<int>((ref) {
  return ref.watch(currentPlayerProvider).level;
});

/// Convenience provider for current coins
final currentCoinsProvider = Provider<int>((ref) {
  return ref.watch(currentPlayerProvider).coins;
});
