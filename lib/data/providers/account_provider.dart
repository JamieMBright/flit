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
    this.lastFreeRerollDate,
    this.lastDailyChallengeDate,
  }) : avatar = avatar ?? const AvatarConfig(),
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

  /// Date of the last free licence reroll (YYYY-MM-DD string).
  /// null means the player has never used a free reroll.
  final String? lastFreeRerollDate;

  /// Date of the last daily challenge completion (YYYY-MM-DD string).
  /// null means the player has never completed a daily challenge.
  final String? lastDailyChallengeDate;

  static String _todayStr() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  /// Whether the daily free reroll is available today.
  bool get hasFreeRerollToday {
    if (lastFreeRerollDate == null) return true;
    return lastFreeRerollDate != _todayStr();
  }

  /// Whether the player has completed today's daily challenge.
  /// Returns true whether or not the bonus reroll has been used.
  bool get hasDoneDailyToday {
    if (lastDailyChallengeDate == null) return false;
    final todayStr = _todayStr();
    return lastDailyChallengeDate == todayStr ||
        lastDailyChallengeDate == '${todayStr}_used';
  }

  /// Whether the player has earned a bonus reroll from today's daily scramble
  /// and hasn't used it yet.
  bool get hasDailyScrambleReroll {
    if (lastDailyChallengeDate == null) return false;
    final todayStr = _todayStr();
    // Completed today (exact match) — reroll available.
    // If suffix is '_used', the bonus was already claimed.
    return lastDailyChallengeDate == todayStr;
  }

  AccountState copyWith({
    Player? currentPlayer,
    bool? isDebugMode,
    Set<String>? unlockedRegions,
    AvatarConfig? avatar,
    PilotLicense? license,
    Set<String>? ownedAvatarParts,
    String? equippedPlaneId,
    String? equippedContrailId,
    String? lastFreeRerollDate,
    String? lastDailyChallengeDate,
  }) => AccountState(
    currentPlayer: currentPlayer ?? this.currentPlayer,
    isDebugMode: isDebugMode ?? this.isDebugMode,
    unlockedRegions: unlockedRegions ?? this.unlockedRegions,
    avatar: avatar ?? this.avatar,
    license: license ?? this.license,
    ownedAvatarParts: ownedAvatarParts ?? this.ownedAvatarParts,
    equippedPlaneId: equippedPlaneId ?? this.equippedPlaneId,
    equippedContrailId: equippedContrailId ?? this.equippedContrailId,
    lastFreeRerollDate: lastFreeRerollDate ?? this.lastFreeRerollDate,
    lastDailyChallengeDate:
        lastDailyChallengeDate ?? this.lastDailyChallengeDate,
  );
}

/// Account state notifier.
class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier() : super(AccountState(currentPlayer: TestAccounts.player1));

  /// Switch to a different test account
  void switchAccount(Player player) {
    state = state.copyWith(currentPlayer: player);
  }

  /// Add coins to current account.
  ///
  /// When [applyBoost] is true (default), the pilot license coin boost
  /// multiplier AND level gold multiplier are applied. Pass `false` for
  /// store purchases or debug grants where boosts should not apply.
  ///
  /// Returns the actual amount of coins added (after boosts).
  int addCoins(int amount, {bool applyBoost = true}) {
    var earned = amount;
    if (applyBoost) {
      earned = (amount * totalGoldMultiplier).round();
    }
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        coins: state.currentPlayer.coins + earned,
      ),
    );
    return earned;
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
      currentPlayer: player.copyWith(xp: newXp, level: newLevel),
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

  /// Update best time if better (overall).
  void updateBestTime(Duration time) {
    final current = state.currentPlayer.bestTime;
    if (current == null || time < current) {
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(bestTime: time),
      );
    }
  }

  /// Add flight time to the cumulative total.
  void addFlightTime(Duration time) {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        totalFlightTime: state.currentPlayer.totalFlightTime + time,
      ),
    );
  }

  /// Increment countries found counter.
  void incrementCountriesFound({int count = 1}) {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        countriesFound: state.currentPlayer.countriesFound + count,
      ),
    );
  }

  /// Record a completed game session — updates all relevant stats in one call.
  ///
  /// Licence bonuses always apply (there is no unlicensed flight mode).
  void recordGameCompletion({
    required Duration elapsed,
    required int score,
    required int roundsCompleted,
    int coinReward = 0,
  }) {
    incrementGamesPlayed();
    updateBestTime(elapsed);
    addFlightTime(elapsed);
    incrementCountriesFound(count: roundsCompleted);

    // XP: base 50 + 10 per round + score/100
    final xpEarned = 50 + (roundsCompleted * 10) + (score ~/ 100);
    addXp(xpEarned);

    if (coinReward > 0) {
      addCoins(coinReward);
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

  /// Equip a companion by ID (e.g. 'companion_sparrow').
  /// Updates the avatar configuration with the corresponding companion enum.
  void equipCompanion(String id) {
    final companionName = id.replaceFirst('companion_', '');
    final companion = AvatarCompanion.values.firstWhere(
      (c) => c.name == companionName,
      orElse: () => AvatarCompanion.none,
    );
    state = state.copyWith(avatar: state.avatar.copyWith(companion: companion));
  }

  // --- Pilot License ---

  /// Directly set the pilot license (used when LicenseScreen rerolls locally).
  void updateLicense(PilotLicense license) {
    state = state.copyWith(license: license);
  }

  /// Reroll the pilot license. Returns true if affordable.
  ///
  /// The avatar's [luckBonus] is automatically applied — rarer avatars
  /// grant advantage rolls for better licence stats.
  bool rerollLicense({
    Set<String> lockedStats = const {},
    bool lockType = false,
  }) {
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
        luckBonus: state.avatar.luckBonus,
      ),
    );
    return true;
  }

  /// Use the daily free reroll. Returns true if the free reroll was available.
  ///
  /// The free reroll rerolls ALL stats and the clue type (no locks).
  /// Locking individual stats still costs coins via [rerollLicense].
  bool useFreeReroll() {
    if (!state.hasFreeRerollToday) return false;

    final todayStr = AccountState._todayStr();

    state = state.copyWith(
      license: PilotLicense.reroll(
        state.license,
        luckBonus: state.avatar.luckBonus,
      ),
      lastFreeRerollDate: todayStr,
    );
    return true;
  }

  /// Record that the player completed today's daily challenge.
  void recordDailyChallengeCompletion() {
    state = state.copyWith(lastDailyChallengeDate: AccountState._todayStr());
  }

  /// Use the daily-scramble bonus reroll. Returns true if available.
  ///
  /// Available only if the player has completed today's daily scramble
  /// and hasn't already used this bonus reroll. Rerolls ALL stats.
  bool useDailyScrambleReroll() {
    if (!state.hasDailyScrambleReroll) return false;
    // Mark as used by clearing the daily challenge date (prevents reuse).
    // We use a special suffix to distinguish "completed" from "reroll used".
    final todayStr = AccountState._todayStr();
    state = state.copyWith(
      license: PilotLicense.reroll(
        state.license,
        luckBonus: state.avatar.luckBonus,
      ),
      lastDailyChallengeDate: '${todayStr}_used',
    );
    return true;
  }

  /// Get current coin boost multiplier from pilot license (for applying to earnings).
  double get coinBoostMultiplier => 1.0 + state.license.coinBoost / 100.0;

  /// Get current level-based gold multiplier.
  ///
  /// Each level adds 0.5% bonus, so level 10 = +5%, level 50 = +25%.
  /// This stacks multiplicatively with the license coin boost.
  double get levelGoldMultiplier =>
      1.0 + (state.currentPlayer.level - 1) * 0.005;

  /// Combined total gold multiplier (license + level).
  double get totalGoldMultiplier => coinBoostMultiplier * levelGoldMultiplier;

  /// Get current fuel boost multiplier (for solo play speed).
  double get fuelBoostMultiplier => 1.0 + state.license.fuelBoost / 100.0;
}

/// Account provider
final accountProvider = StateNotifierProvider<AccountNotifier, AccountState>((
  ref,
) {
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
