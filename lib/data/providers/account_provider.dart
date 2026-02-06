import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/map/region.dart';
import '../models/player.dart';
import '../services/test_accounts.dart';

/// Current account state.
class AccountState {
  const AccountState({
    required this.currentPlayer,
    this.isDebugMode = true,
    this.unlockedRegions = const {},
  });

  final Player currentPlayer;
  final bool isDebugMode;

  /// Set of region IDs that have been unlocked via coin purchase.
  final Set<String> unlockedRegions;

  AccountState copyWith({
    Player? currentPlayer,
    bool? isDebugMode,
    Set<String>? unlockedRegions,
  }) =>
      AccountState(
        currentPlayer: currentPlayer ?? this.currentPlayer,
        isDebugMode: isDebugMode ?? this.isDebugMode,
        unlockedRegions: unlockedRegions ?? this.unlockedRegions,
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

  void switchToPlayer1() => switchAccount(TestAccounts.player1);
  void switchToPlayer2() => switchAccount(TestAccounts.player2);
  void switchToGodAccount() => switchAccount(TestAccounts.godAccount);
  void switchToNewPlayer() => switchAccount(TestAccounts.newPlayer);

  /// Add coins to current account
  void addCoins(int amount) {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        coins: state.currentPlayer.coins + amount,
      ),
    );
  }

  /// Spend coins from current account.
  /// Returns true if successful, false if insufficient funds or invalid amount.
  bool spendCoins(int amount) {
    if (amount <= 0) return false;
    if (state.currentPlayer.coins < amount) return false;
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        coins: state.currentPlayer.coins - amount,
      ),
    );
    return true;
  }

  /// Unlock a region with coins. Deducts the cost and marks the region
  /// as purchased. Returns true if successful, false if insufficient funds.
  bool unlockRegion(GameRegion region, int cost) {
    if (!spendCoins(cost)) return false;
    state = state.copyWith(
      unlockedRegions: {...state.unlockedRegions, region.name},
    );
    return true;
  }

  /// Check if a region is unlocked (by level or by purchase).
  bool isRegionUnlocked(GameRegion region) {
    if (state.currentPlayer.level >= region.requiredLevel) return true;
    return state.unlockedRegions.contains(region.name);
  }

  /// Add XP and handle level ups
  void addXp(int amount) {
    var player = state.currentPlayer;
    var newXp = player.xp + amount;
    var newLevel = player.level;

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

/// Convenience provider for purchased region IDs
final purchasedRegionIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(accountProvider).unlockedRegions;
});
