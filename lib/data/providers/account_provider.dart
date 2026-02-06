import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/map/region.dart';
import '../models/avatar_config.dart';
import '../models/pilot_license.dart';
import '../models/player.dart';
import '../services/test_accounts.dart';

/// Current account state.
class AccountState {
  AccountState({
    required this.currentPlayer,
    this.isDebugMode = true,
    this.unlockedRegions = const {},
    AvatarConfig? avatar,
    PilotLicense? license,
    this.ownedAvatarParts = const {},
    this.equippedPlaneId = 'plane_default',
    this.equippedContrailId = 'contrail_default',
  })  : avatar = avatar ?? const AvatarConfig(),
        license = license ?? PilotLicense.random();

  final Player currentPlayer;
  final bool isDebugMode;

  /// Set of region IDs that have been unlocked via coin purchase.
  final Set<String> unlockedRegions;

  /// Player's avatar configuration.
  final AvatarConfig avatar;

  /// Player's pilot license (gacha stats).
  final PilotLicense license;

  /// Set of owned avatar parts (e.g. "hair_mohawk", "hat_crown").
  final Set<String> ownedAvatarParts;

  /// Currently equipped plane cosmetic ID.
  final String equippedPlaneId;

  /// Currently equipped contrail cosmetic ID.
  final String equippedContrailId;

  AccountState copyWith({
    Player? currentPlayer,
    bool? isDebugMode,
    Set<String>? unlockedRegions,
    AvatarConfig? avatar,
    PilotLicense? license,
    Set<String>? ownedAvatarParts,
    String? equippedPlaneId,
    String? equippedContrailId,
  }) =>
      AccountState(
        currentPlayer: currentPlayer ?? this.currentPlayer,
        isDebugMode: isDebugMode ?? this.isDebugMode,
        unlockedRegions: unlockedRegions ?? this.unlockedRegions,
        avatar: avatar ?? this.avatar,
        license: license ?? this.license,
        ownedAvatarParts: ownedAvatarParts ?? this.ownedAvatarParts,
        equippedPlaneId: equippedPlaneId ?? this.equippedPlaneId,
        equippedContrailId: equippedContrailId ?? this.equippedContrailId,
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

  // --- Avatar ---

  /// Update the avatar configuration.
  void updateAvatar(AvatarConfig config) {
    state = state.copyWith(avatar: config);
  }

  /// Purchase an avatar part. Returns true if successful.
  bool purchaseAvatarPart(String partKey, int cost) {
    if (!spendCoins(cost)) return false;
    state = state.copyWith(
      ownedAvatarParts: {...state.ownedAvatarParts, partKey},
    );
    return true;
  }

  /// Check if an avatar part is owned.
  bool isAvatarPartOwned(String partKey) {
    return state.ownedAvatarParts.contains(partKey);
  }

  // --- Equipped cosmetics ---

  /// Equip a plane by ID.
  void equipPlane(String id) {
    state = state.copyWith(equippedPlaneId: id);
  }

  /// Equip a contrail by ID.
  void equipContrail(String id) {
    state = state.copyWith(equippedContrailId: id);
  }

  // --- Pilot License ---

  /// Reroll the pilot license. Returns true if affordable.
  bool rerollLicense({Set<String> lockedStats = const {}, bool lockType = false}) {
    // Calculate cost
    var cost = PilotLicense.rerollAllCost;
    if (lockedStats.length == 1) cost = PilotLicense.lockOneCost;
    if (lockedStats.length == 2) cost = PilotLicense.lockTwoCost;
    if (lockType) cost += PilotLicense.lockTypeCost;

    if (!spendCoins(cost)) return false;

    state = state.copyWith(
      license: PilotLicense.reroll(
        state.license,
        lockedStats: lockedStats,
        lockType: lockType,
      ),
    );
    return true;
  }

  /// Get current coin boost multiplier (for applying to earnings).
  double get coinBoostMultiplier => 1.0 + state.license.coinBoost / 100.0;

  /// Get current fuel boost multiplier (for solo play speed).
  double get fuelBoostMultiplier => 1.0 + state.license.fuelBoost / 100.0;
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

/// Convenience provider for avatar config
final avatarProvider = Provider<AvatarConfig>((ref) {
  return ref.watch(accountProvider).avatar;
});

/// Convenience provider for pilot license
final licenseProvider = Provider<PilotLicense>((ref) {
  return ref.watch(accountProvider).license;
});

/// Convenience provider for equipped plane ID
final equippedPlaneIdProvider = Provider<String>((ref) {
  return ref.watch(accountProvider).equippedPlaneId;
});
