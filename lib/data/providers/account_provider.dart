import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/admin_config.dart';
import '../../core/services/game_settings.dart';
import '../../game/map/region.dart';
import '../models/avatar_config.dart';
import '../models/pilot_license.dart';
import '../models/player.dart';
import '../models/social_title.dart';
import '../services/user_preferences_service.dart';

/// Current account state.
class AccountState {
  AccountState({
    required this.currentPlayer,
    this.unlockedRegions = const {},
    AvatarConfig? avatar,
    PilotLicense? license,
    this.ownedAvatarParts = const {},
    this.equippedPlaneId = 'plane_default',
    this.equippedContrailId = 'contrail_default',
    this.equippedTitleId,
    this.lastFreeRerollDate,
    this.lastDailyChallengeDate,
  }) : avatar = avatar ?? const AvatarConfig(),
       license = license ?? PilotLicense.random();

  final Player currentPlayer;

  /// Whether the current user is an admin (derived from Supabase auth email).
  bool get isAdmin => AdminConfig.isCurrentUserAdmin;

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

  /// The [SocialTitle.id] the player has chosen to display on their profile.
  /// `null` means no title is shown.
  final String? equippedTitleId;

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

  /// Convenience: resolves [equippedTitleId] to a [SocialTitle] object.
  /// Returns `null` when no title is equipped or the ID is unknown.
  SocialTitle? get equippedTitle {
    if (equippedTitleId == null) return null;
    return SocialTitleCatalog.getById(equippedTitleId!);
  }

  AccountState copyWith({
    Player? currentPlayer,
    Set<String>? unlockedRegions,
    AvatarConfig? avatar,
    PilotLicense? license,
    Set<String>? ownedAvatarParts,
    String? equippedPlaneId,
    String? equippedContrailId,
    // Use Object? sentinel to allow explicitly passing null to clear the title.
    Object? equippedTitleId = _sentinel,
    String? lastFreeRerollDate,
    String? lastDailyChallengeDate,
  }) => AccountState(
    currentPlayer: currentPlayer ?? this.currentPlayer,
    unlockedRegions: unlockedRegions ?? this.unlockedRegions,
    avatar: avatar ?? this.avatar,
    license: license ?? this.license,
    ownedAvatarParts: ownedAvatarParts ?? this.ownedAvatarParts,
    equippedPlaneId: equippedPlaneId ?? this.equippedPlaneId,
    equippedContrailId: equippedContrailId ?? this.equippedContrailId,
    equippedTitleId: equippedTitleId == _sentinel
        ? this.equippedTitleId
        : equippedTitleId as String?,
    lastFreeRerollDate: lastFreeRerollDate ?? this.lastFreeRerollDate,
    lastDailyChallengeDate:
        lastDailyChallengeDate ?? this.lastDailyChallengeDate,
  );
}

// Sentinel used by [AccountState.copyWith] to distinguish "not provided" from
// an explicit `null` for [equippedTitleId].
const Object _sentinel = Object();

/// Account state notifier.
class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier()
    : super(
        AccountState(
          currentPlayer: const Player(
            id: '',
            username: '',
            level: 1,
            xp: 0,
            coins: 0,
          ),
        ),
      );

  final _prefs = UserPreferencesService.instance;

  /// Load full account state from Supabase and hydrate all providers.
  ///
  /// Called after auth completes. Loads profile, settings, avatar, license,
  /// cosmetics, and daily state in one parallel fetch.
  Future<void> loadFromSupabase(String userId) async {
    final snapshot = await _prefs.load(userId);
    if (snapshot == null) return;

    final player = snapshot.toPlayer();

    state = AccountState(
      currentPlayer: player,
      avatar: snapshot.toAvatarConfig(),
      license: snapshot.toPilotLicense(),
      unlockedRegions: snapshot.unlockedRegions,
      ownedAvatarParts: snapshot.ownedAvatarParts,
      equippedPlaneId: snapshot.equippedPlaneId,
      equippedContrailId: snapshot.equippedContrailId,
      equippedTitleId: snapshot.equippedTitleId,
      lastFreeRerollDate: snapshot.lastFreeRerollDate,
      lastDailyChallengeDate: snapshot.lastDailyChallengeDate,
    );

    // Hydrate GameSettings from Supabase data without triggering writes back.
    GameSettings.instance.hydrateFrom(
      turnSensitivity: snapshot.turnSensitivity,
      invertControls: snapshot.invertControls,
      enableNight: snapshot.enableNight,
      englishLabels: snapshot.englishLabels,
      mapStyle: MapStyle.values.firstWhere(
        (s) => s.name == snapshot.mapStyle,
        orElse: () => MapStyle.topo,
      ),
      difficulty: GameDifficulty.values.firstWhere(
        (d) => d.name == snapshot.difficulty,
        orElse: () => GameDifficulty.normal,
      ),
    );
  }

  /// Flush pending writes (call on sign-out or app pause).
  Future<void> flushPreferences() => _prefs.flush();

  /// Clear sync state (call on sign-out).
  void clearPreferences() => _prefs.clear();

  /// Set the current player (called after auth completes).
  void switchAccount(Player player) {
    state = state.copyWith(currentPlayer: player);
  }

  // ── Internal sync helpers ────────────────────────────────────────────

  void _syncProfile() {
    _prefs.saveProfile(state.currentPlayer);
  }

  void _syncAccountState() {
    _prefs.saveAccountState(
      avatar: state.avatar,
      license: state.license,
      unlockedRegions: state.unlockedRegions,
      ownedAvatarParts: state.ownedAvatarParts,
      equippedPlaneId: state.equippedPlaneId,
      equippedContrailId: state.equippedContrailId,
      equippedTitleId: state.equippedTitleId,
      lastFreeRerollDate: state.lastFreeRerollDate,
      lastDailyChallengeDate: state.lastDailyChallengeDate,
    );
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
    _syncProfile();
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
    _syncProfile();
    return true;
  }

  /// Unlock a region with coins. Deducts the cost and marks the region
  /// as purchased. Returns true if successful, false if insufficient funds.
  bool unlockRegion(GameRegion region, int cost) {
    if (!spendCoins(cost)) return false;
    state = state.copyWith(
      unlockedRegions: {...state.unlockedRegions, region.name},
    );
    _syncAccountState();
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
    _syncProfile();
  }

  /// Increment games played
  void incrementGamesPlayed() {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        gamesPlayed: state.currentPlayer.gamesPlayed + 1,
      ),
    );
    _syncProfile();
  }

  /// Update best time if better (overall).
  void updateBestTime(Duration time) {
    final current = state.currentPlayer.bestTime;
    if (current == null || time < current) {
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(bestTime: time),
      );
      _syncProfile();
    }
  }

  /// Update best score if higher.
  void updateBestScore(int score) {
    final current = state.currentPlayer.bestScore;
    if (current == null || score > current) {
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(bestScore: score),
      );
      _syncProfile();
    }
  }

  /// Add flight time to the cumulative total.
  void addFlightTime(Duration time) {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        totalFlightTime: state.currentPlayer.totalFlightTime + time,
      ),
    );
    _syncProfile();
  }

  /// Increment countries found counter.
  void incrementCountriesFound({int count = 1}) {
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        countriesFound: state.currentPlayer.countriesFound + count,
      ),
    );
    _syncProfile();
  }

  /// Record correct answers per clue type.
  ///
  /// Call this after each round with the breakdown of clue types the player
  /// answered correctly this round.
  void recordClueAnswers({
    int flags = 0,
    int capitals = 0,
    int outlines = 0,
    int borders = 0,
    int stats = 0,
  }) {
    final p = state.currentPlayer;
    state = state.copyWith(
      currentPlayer: p.copyWith(
        flagsCorrect: p.flagsCorrect + flags,
        capitalsCorrect: p.capitalsCorrect + capitals,
        outlinesCorrect: p.outlinesCorrect + outlines,
        bordersCorrect: p.bordersCorrect + borders,
        statsCorrect: p.statsCorrect + stats,
      ),
    );
    _syncProfile();
  }

  /// Update the player's best streak if [streak] is higher than the current.
  void updateBestStreak(int streak) {
    if (streak > state.currentPlayer.bestStreak) {
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(bestStreak: streak),
      );
      _syncProfile();
    }
  }

  /// Record a completed game session — updates all relevant stats in one call.
  ///
  /// Licence bonuses always apply (there is no unlicensed flight mode).
  void recordGameCompletion({
    required Duration elapsed,
    required int score,
    required int roundsCompleted,
    int coinReward = 0,
    String region = 'world',
  }) {
    incrementGamesPlayed();
    updateBestScore(score);
    updateBestTime(elapsed);
    addFlightTime(elapsed);
    incrementCountriesFound(count: roundsCompleted);

    // XP: base 50 + 10 per round + score/100
    final xpEarned = 50 + (roundsCompleted * 10) + (score ~/ 100);
    addXp(xpEarned);

    if (coinReward > 0) {
      addCoins(coinReward);
    }

    // Persist individual game result to scores table.
    _prefs.saveGameResult(
      score: score,
      timeMs: elapsed.inMilliseconds,
      region: region,
      roundsCompleted: roundsCompleted,
    );
  }

  // --- Avatar ---

  /// Update the avatar configuration.
  void updateAvatar(AvatarConfig config) {
    state = state.copyWith(avatar: config);
    _syncAccountState();
  }

  /// Purchase an avatar part. Returns true if successful.
  bool purchaseAvatarPart(String partKey, int cost) {
    if (!spendCoins(cost)) return false;
    state = state.copyWith(
      ownedAvatarParts: {...state.ownedAvatarParts, partKey},
    );
    _syncAccountState();
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
    _syncAccountState();
  }

  /// Equip a contrail by ID.
  void equipContrail(String id) {
    state = state.copyWith(equippedContrailId: id);
    _syncAccountState();
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
    _syncAccountState();
  }

  /// Equip a social title by [titleId].
  ///
  /// Silently does nothing if the title ID is not in the catalog. Call
  /// [clearEquippedTitle] to remove the active title.
  void equipTitle(String titleId) {
    // Guard: only allow equipping real catalog titles.
    if (SocialTitleCatalog.getById(titleId) == null) return;
    state = state.copyWith(equippedTitleId: titleId);
    _syncAccountState();
  }

  /// Remove the currently displayed title.
  void clearEquippedTitle() {
    // Explicit null — use the sentinel-aware copyWith.
    state = state.copyWith(equippedTitleId: null);
    _syncAccountState();
  }

  // --- Pilot License ---

  /// Directly set the pilot license (used when LicenseScreen rerolls locally).
  void updateLicense(PilotLicense license) {
    state = state.copyWith(license: license);
    _syncAccountState();
  }

  /// Update the pilot's nationality (ISO 3166-1 alpha-2 code).
  void updateNationality(String? nationality) {
    state = state.copyWith(
      license: state.license.copyWith(nationality: nationality),
    );
    _syncAccountState();
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
    _syncAccountState();
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
    _syncAccountState();
    return true;
  }

  /// Record that the player completed today's daily challenge.
  void recordDailyChallengeCompletion() {
    state = state.copyWith(lastDailyChallengeDate: AccountState._todayStr());
    _syncAccountState();
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
    _syncAccountState();
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

/// Convenience provider for the currently equipped social title (may be null).
final equippedTitleProvider = Provider<SocialTitle?>((ref) {
  return ref.watch(accountProvider).equippedTitle;
});
