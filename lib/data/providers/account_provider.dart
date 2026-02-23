import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/game_settings.dart';
import '../../game/map/region.dart';
import '../models/avatar_config.dart';
import '../models/daily_result.dart';
import '../models/daily_streak.dart';
import '../models/pilot_license.dart';
import '../models/player.dart';
import '../models/social_title.dart';
import '../services/leaderboard_service.dart';
import '../services/user_preferences_service.dart';

/// Current account state.
class AccountState {
  AccountState({
    required this.currentPlayer,
    this.unlockedRegions = const {},
    AvatarConfig? avatar,
    PilotLicense? license,
    this.ownedAvatarParts = const {},
    this.ownedCosmetics = const {},
    this.equippedPlaneId = 'plane_default',
    this.equippedContrailId = 'contrail_default',
    this.equippedTitleId,
    this.lastFreeRerollDate,
    this.lastDailyChallengeDate,
    this.dailyStreak = const DailyStreak(),
    this.lastDailyResult,
  }) : avatar = avatar ?? const AvatarConfig(),
       license = license ?? PilotLicense.random();

  final Player currentPlayer;

  /// Whether the current user has any admin access (from DB admin_role column).
  bool get isAdmin => currentPlayer.isAdmin;

  /// Whether the current user is the owner (god mode).
  bool get isOwner => currentPlayer.isOwner;

  /// Set of region IDs that have been unlocked via coin purchase.
  final Set<String> unlockedRegions;

  /// Player's avatar configuration.
  final AvatarConfig avatar;

  /// Player's pilot license (gacha stats).
  final PilotLicense license;

  /// Set of owned avatar parts (e.g. "hair_mohawk", "hat_crown").
  final Set<String> ownedAvatarParts;

  /// Set of owned shop cosmetics (planes, contrails, companions).
  final Set<String> ownedCosmetics;

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

  /// Daily challenge streak tracking.
  final DailyStreak dailyStreak;

  /// Last completed daily challenge result (for sharing).
  final DailyResult? lastDailyResult;

  static String _todayStr() {
    final today = DateTime.now().toUtc();
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
    Set<String>? ownedCosmetics,
    String? equippedPlaneId,
    String? equippedContrailId,
    // Use Object? sentinel to allow explicitly passing null to clear the title.
    Object? equippedTitleId = _sentinel,
    String? lastFreeRerollDate,
    String? lastDailyChallengeDate,
    DailyStreak? dailyStreak,
    Object? lastDailyResult = _sentinel,
  }) => AccountState(
    currentPlayer: currentPlayer ?? this.currentPlayer,
    unlockedRegions: unlockedRegions ?? this.unlockedRegions,
    avatar: avatar ?? this.avatar,
    license: license ?? this.license,
    ownedAvatarParts: ownedAvatarParts ?? this.ownedAvatarParts,
    ownedCosmetics: ownedCosmetics ?? this.ownedCosmetics,
    equippedPlaneId: equippedPlaneId ?? this.equippedPlaneId,
    equippedContrailId: equippedContrailId ?? this.equippedContrailId,
    equippedTitleId: equippedTitleId == _sentinel
        ? this.equippedTitleId
        : equippedTitleId as String?,
    lastFreeRerollDate: lastFreeRerollDate ?? this.lastFreeRerollDate,
    lastDailyChallengeDate:
        lastDailyChallengeDate ?? this.lastDailyChallengeDate,
    dailyStreak: dailyStreak ?? this.dailyStreak,
    lastDailyResult: lastDailyResult == _sentinel
        ? this.lastDailyResult
        : lastDailyResult as DailyResult?,
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

  /// Periodic refresh timer — re-fetches settings from Supabase to keep
  /// the local state in sync (e.g. if changed on another device).
  Timer? _refreshTimer;

  /// How often to refresh settings from the database.
  static const _refreshInterval = Duration(minutes: 5);

  /// The user ID for the current session (used by periodic refresh).
  String? _userId;

  /// Guard flag: prevents writes to Supabase until [loadFromSupabase] has
  /// successfully completed at least once for this session. Without this,
  /// the constructor's default `PilotLicense.random()` could be persisted
  /// to Supabase if any user action triggers [_syncAccountState] before
  /// the real data is loaded — causing the license stats reset bug.
  bool _supabaseLoaded = false;

  /// Load full account state from Supabase and hydrate all providers.
  ///
  /// Called after auth completes. Clears any stale dirty flags from a
  /// previous session before loading, so debounced writes from the old
  /// user don't fire after the new user's data is loaded. Then loads
  /// profile, settings, avatar, license, cosmetics, and daily state in
  /// one parallel fetch. Also starts a periodic refresh timer.
  Future<bool> loadFromSupabase(String userId) async {
    // Clear stale dirty flags / pending payloads from a prior session.
    // This prevents a race where the old user's debounce timer fires
    // after the new user's data has been loaded.
    _prefs.clearDirtyFlags();
    _userId = userId;
    _supabaseLoaded = false;

    // Retry up to 3 times with exponential backoff. Without this, a
    // transient Supabase timeout on cold start (common after iOS force-close)
    // silently leaves the user with default/empty state for the session.
    UserPreferencesSnapshot? snapshot;
    for (var attempt = 0; attempt < 3; attempt++) {
      snapshot = await _prefs.load(userId);
      if (snapshot != null) break;
      debugPrint(
        '[AccountNotifier] loadFromSupabase attempt ${attempt + 1} returned '
        'null — retrying in ${1 << attempt}s',
      );
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
    }

    if (snapshot == null) {
      debugPrint(
        '[AccountNotifier] loadFromSupabase: all retries failed for $userId '
        '— aborting hydration',
      );
      return false;
    }

    await _applySnapshot(snapshot);
    _startPeriodicRefresh();
    return true;
  }

  /// Apply a [UserPreferencesSnapshot] to in-memory state.
  ///
  /// When [hydrateSettings] is false, game settings (sensitivity, difficulty,
  /// sound, etc.) are NOT overwritten from the snapshot. This prevents stale
  /// server data from clobbering local settings that haven't been synced yet
  /// (e.g. during on-demand or periodic refreshes).
  Future<void> _applySnapshot(
    UserPreferencesSnapshot snapshot, {
    bool hydrateSettings = true,
  }) async {
    final player = snapshot.toPlayer();

    state = AccountState(
      currentPlayer: player,
      avatar: snapshot.toAvatarConfig(),
      license: snapshot.toPilotLicense(),
      unlockedRegions: snapshot.unlockedRegions,
      ownedAvatarParts: snapshot.ownedAvatarParts,
      ownedCosmetics: snapshot.ownedCosmetics,
      equippedPlaneId: snapshot.equippedPlaneId,
      equippedContrailId: snapshot.equippedContrailId,
      equippedTitleId: snapshot.equippedTitleId,
      lastFreeRerollDate: snapshot.lastFreeRerollDate,
      lastDailyChallengeDate: snapshot.lastDailyChallengeDate,
      dailyStreak: snapshot.toDailyStreak(),
      lastDailyResult: snapshot.toLastDailyResult(),
    );

    // Mark Supabase data as loaded — enables writes. Must happen AFTER
    // state is set so the first write contains real data, not defaults.
    _supabaseLoaded = true;

    // Only hydrate GameSettings on initial load. On subsequent refreshes,
    // skip this to avoid overwriting local settings with stale server data
    // (debounced writes may not have reached the server yet).
    if (hydrateSettings) {
      await GameSettings.instance.hydrateFrom(
        turnSensitivity: snapshot.turnSensitivity,
        invertControls: snapshot.invertControls,
        enableNight: snapshot.enableNight,
        englishLabels: snapshot.englishLabels,
        mapStyle: MapStyle.values.firstWhere(
          (s) => s.name == snapshot.mapStyle,
          orElse: () => MapStyle.standard,
        ),
        difficulty: GameDifficulty.values.firstWhere(
          (d) => d.name == snapshot.difficulty,
          orElse: () => GameDifficulty.normal,
        ),
        soundEnabled: snapshot.soundEnabled,
        musicVolume: snapshot.musicVolume,
        effectsVolume: snapshot.effectsVolume,
        notificationsEnabled: snapshot.notificationsEnabled,
        hapticEnabled: snapshot.hapticEnabled,
      );
    }
  }

  /// Start a periodic timer that re-fetches user data from Supabase.
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => refreshFromServer(),
    );
  }

  /// Re-fetch all user data from Supabase and re-hydrate local state.
  ///
  /// Skips the refresh if there are pending local writes (to avoid
  /// overwriting unsaved changes).
  ///
  /// Called automatically on a periodic timer, but also available for
  /// on-demand refresh when navigating to key screens (shop, profile, etc.)
  /// so the user always sees the latest server state.
  Future<void> refreshFromServer() async {
    if (_userId == null) return;
    if (_prefs.hasPendingWrites || _prefs.hasPendingOfflineWrites) {
      // Flush pending writes / retry queued offline writes first, then refresh.
      await _prefs.flush();
    }
    if (_prefs.hasPendingWrites || _prefs.hasPendingOfflineWrites) {
      // Don't hydrate from server while local writes are still pending/queued.
      // Hydrating now can overwrite newer local state (e.g. post-game stats or
      // avatar edits) with stale server rows before those writes are retried.
      return;
    }

    try {
      final snapshot = await _prefs.load(_userId!);
      if (snapshot != null) {
        await _applySnapshot(snapshot, hydrateSettings: false);
      }
    } catch (e) {
      debugPrint('[AccountNotifier] refresh failed: $e');
    }
  }

  /// Flush pending writes (call on sign-out or app pause).
  Future<void> flushPreferences() => _prefs.flush();

  /// Clear sync state (call on sign-out).
  void clearPreferences() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _userId = null;
    _supabaseLoaded = false;
    _prefs.clear();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Set the current player (called after auth completes or profile edit).
  ///
  /// Syncs the profile to Supabase so changes like displayName/username
  /// are persisted. The login path follows this with [loadFromSupabase]
  /// which overwrites from DB — that's fine because the DB is authoritative
  /// there. For profile edits, this sync is the only write path.
  void switchAccount(Player player) {
    state = state.copyWith(currentPlayer: player);
    _syncProfile();
  }

  // ── Internal sync helpers ────────────────────────────────────────────

  void _syncProfile() {
    if (!_supabaseLoaded) return;
    _prefs.saveProfile(state.currentPlayer);
    // Invalidate leaderboard cache so username changes are visible immediately
    // on any leaderboard screen opened after the edit, rather than waiting up
    // to 30 seconds for the TTL to expire.
    LeaderboardService.instance.invalidateCache();
  }

  void _syncAccountState() {
    if (!_supabaseLoaded) return;
    _prefs.saveAccountState(
      avatar: state.avatar,
      license: state.license,
      unlockedRegions: state.unlockedRegions,
      ownedAvatarParts: state.ownedAvatarParts,
      ownedCosmetics: state.ownedCosmetics,
      equippedPlaneId: state.equippedPlaneId,
      equippedContrailId: state.equippedContrailId,
      equippedTitleId: state.equippedTitleId,
      lastFreeRerollDate: state.lastFreeRerollDate,
      lastDailyChallengeDate: state.lastDailyChallengeDate,
      dailyStreak: state.dailyStreak,
      lastDailyResult: state.lastDailyResult,
    );
  }

  /// Calculate the total coin cost for locking stats during a reroll.
  ///
  /// Each locked stat has a cost based on its current value, and locking
  /// the preferred clue type has a flat cost.
  int _calculateLockCost(Set<String> lockedStats, bool lockType) {
    var cost = 0;
    for (final stat in lockedStats) {
      int statValue;
      switch (stat) {
        case 'coinBoost':
          statValue = state.license.coinBoost;
        case 'clueChance':
          statValue = state.license.clueChance;
        case 'fuelBoost':
          statValue = state.license.fuelBoost;
        default:
          statValue = 1;
      }
      cost += PilotLicense.lockCostForValue(statValue);
    }
    if (lockType) cost += PilotLicense.lockTypeCost;
    return cost;
  }

  /// Add coins to current account.
  ///
  /// When [applyBoost] is true (default), the pilot license coin boost
  /// multiplier AND level gold multiplier are applied. Pass `false` for
  /// store purchases or debug grants where boosts should not apply.
  ///
  /// Returns the actual amount of coins added (after boosts).
  int addCoins(
    int amount, {
    bool applyBoost = true,
    String source = 'coins_earned',
  }) {
    var earned = amount;
    if (applyBoost) {
      earned = (amount * totalGoldMultiplier).round();
    }
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        coins: state.currentPlayer.coins + earned,
      ),
    );
    _logCoinActivity(amount: earned, source: source);
    _syncProfile();
    return earned;
  }

  /// Spend coins from current account.
  /// Returns true if successful, false if insufficient funds or invalid amount.
  bool spendCoins(
    int amount, {
    String source = 'coins_spent',
    bool logActivity = true,
  }) {
    if (amount <= 0) return false;
    if (state.currentPlayer.coins < amount) return false;
    state = state.copyWith(
      currentPlayer: state.currentPlayer.copyWith(
        coins: state.currentPlayer.coins - amount,
      ),
    );
    if (logActivity) {
      _logCoinActivity(amount: -amount, source: source);
    }
    _syncProfile();
    return true;
  }

  void _logCoinActivity({required int amount, required String source}) {
    final username = state.currentPlayer.username.trim().isNotEmpty
        ? state.currentPlayer.username
        : state.currentPlayer.id;
    // Fire-and-forget on purpose: coin logging should never block gameplay UI.
    // UserPreferencesService handles offline queue fallback on insert failures.
    _prefs.saveCoinActivity(
      username: username,
      coinAmount: amount,
      source: source,
      balanceAfter: state.currentPlayer.coins,
    );
  }

  /// Unlock a region with coins. Deducts the cost and marks the region
  /// as purchased. Returns true if successful, false if insufficient funds.
  bool unlockRegion(GameRegion region, int cost) {
    if (!spendCoins(cost, source: 'region_unlock')) return false;
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
  Future<void> recordGameCompletion({
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
      addCoins(coinReward, source: 'game_completion');
    }

    // Persist individual game result to scores table.
    await _prefs.saveGameResult(
      score: score,
      timeMs: elapsed.inMilliseconds,
      region: region,
      roundsCompleted: roundsCompleted,
    );

    // Flush all pending writes immediately — game completion is a critical
    // save point. Without this, debounced profile/account writes can be lost
    // if the user closes the browser tab within the 2-second debounce window.
    await _prefs.flush();
  }

  // --- Avatar ---

  /// Update the avatar configuration.
  Future<void> updateAvatar(AvatarConfig config) async {
    state = state.copyWith(avatar: config);
    _syncAccountState();
    // Avatar edits are user-facing and should be persisted immediately.
    await _prefs.flush();
  }

  /// Purchase an avatar part. Returns true if successful.
  ///
  /// Attempts server-side validation via the `purchase_avatar_part` DB function.
  /// If the server call fails (offline/network error), falls back to
  /// client-side deduction for offline resilience.
  bool purchaseAvatarPart(String partKey, int cost) {
    if (!spendCoins(cost, source: 'avatar_part_purchase')) return false;
    state = state.copyWith(
      ownedAvatarParts: {...state.ownedAvatarParts, partKey},
    );
    _syncAccountState();

    // Fire-and-forget server-side validation.
    _serverValidateAvatarPartPurchase(partKey, cost);
    return true;
  }

  /// Check if an avatar part is owned.
  bool isAvatarPartOwned(String partKey) {
    return state.ownedAvatarParts.contains(partKey);
  }

  // --- Shop cosmetics (planes, contrails, companions) ---

  /// Purchase a shop cosmetic. Returns true if successful.
  ///
  /// Attempts server-side validation via the `purchase_cosmetic` DB function.
  /// If the server call fails (offline/network error), falls back to
  /// client-side deduction for offline resilience. The optimistic client-side
  /// state is applied immediately for responsive UI.
  bool purchaseCosmetic(String cosmeticId, int cost) {
    if (!spendCoins(cost, source: 'cosmetic_purchase')) return false;
    state = state.copyWith(
      ownedCosmetics: {...state.ownedCosmetics, cosmeticId},
    );
    _syncAccountState();

    // Fire-and-forget server-side validation. If it succeeds, the server
    // has the authoritative state. If it fails, the debounced client-side
    // sync will eventually push the state.
    _serverValidatePurchase(cosmeticId, cost);
    return true;
  }

  /// Attempt server-side atomic purchase via Supabase RPC.
  Future<void> _serverValidatePurchase(String cosmeticId, int cost) async {
    try {
      final userId = state.currentPlayer.id;
      if (userId.isEmpty) return;

      final result = await Supabase.instance.client.rpc(
        'purchase_cosmetic',
        params: {
          'p_user_id': userId,
          'p_cosmetic_id': cosmeticId,
          'p_cost': cost,
        },
      );

      if (result is Map<String, dynamic>) {
        final success = result['success'] as bool? ?? false;
        if (success) {
          // Server confirmed — update local coin balance to match server.
          final serverBalance = result['new_balance'] as int?;
          if (serverBalance != null &&
              serverBalance != state.currentPlayer.coins) {
            final delta = serverBalance - state.currentPlayer.coins;
            state = state.copyWith(
              currentPlayer: state.currentPlayer.copyWith(coins: serverBalance),
            );
            _logCoinActivity(amount: delta, source: 'server_balance_reconcile');
          }
        } else {
          debugPrint(
            '[AccountNotifier] Server purchase validation failed: '
            '${result['error']}',
          );
          // Server says no — but we already applied optimistically.
          // The next periodic refresh will reconcile from the server.
        }
      }
    } catch (e) {
      // Network error — rely on client-side debounced sync.
      debugPrint(
        '[AccountNotifier] Server purchase validation unavailable: $e',
      );
    }
  }

  /// Attempt server-side atomic avatar part purchase via Supabase RPC.
  Future<void> _serverValidateAvatarPartPurchase(
    String partId,
    int cost,
  ) async {
    try {
      final userId = state.currentPlayer.id;
      if (userId.isEmpty) return;

      final result = await Supabase.instance.client.rpc(
        'purchase_avatar_part',
        params: {'p_user_id': userId, 'p_part_id': partId, 'p_cost': cost},
      );

      if (result is Map<String, dynamic>) {
        final success = result['success'] as bool? ?? false;
        if (success) {
          final serverBalance = result['new_balance'] as int?;
          if (serverBalance != null &&
              serverBalance != state.currentPlayer.coins) {
            final delta = serverBalance - state.currentPlayer.coins;
            state = state.copyWith(
              currentPlayer: state.currentPlayer.copyWith(coins: serverBalance),
            );
            _logCoinActivity(amount: delta, source: 'server_balance_reconcile');
          }
        } else {
          debugPrint(
            '[AccountNotifier] Server avatar part purchase failed: '
            '${result['error']}',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[AccountNotifier] Server avatar part purchase unavailable: $e',
      );
    }
  }

  /// Add a cosmetic to owned set without spending coins (e.g. mystery box
  /// where coins are already deducted separately).
  void addOwnedCosmetic(String cosmeticId) {
    state = state.copyWith(
      ownedCosmetics: {...state.ownedCosmetics, cosmeticId},
    );
    _syncAccountState();
  }

  /// Check if a shop cosmetic is owned (or is a default item).
  bool isCosmeticOwned(String cosmeticId) {
    const defaults = {'plane_default', 'contrail_default', 'companion_none'};
    if (defaults.contains(cosmeticId)) return true;
    if (cosmeticId == state.equippedPlaneId) return true;
    if (cosmeticId == state.equippedContrailId) return true;
    if ('companion_${state.avatar.companion.name}' == cosmeticId) return true;
    return state.ownedCosmetics.contains(cosmeticId);
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

    if (!spendCoins(cost, source: 'license_reroll')) return false;

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
  /// The base reroll is free, but locking individual stats still costs coins.
  /// If [lockedStats] or [lockType] are provided, the corresponding lock
  /// costs are charged via [spendCoins]. Returns false if the player cannot
  /// afford the lock costs.
  bool useFreeReroll({
    Set<String> lockedStats = const {},
    bool lockType = false,
  }) {
    if (!state.hasFreeRerollToday) return false;

    // Base reroll is free, but locking stats still costs coins.
    final lockCost = _calculateLockCost(lockedStats, lockType);
    if (lockCost > 0 && !spendCoins(lockCost, source: 'license_lock_cost')) {
      return false;
    }

    final todayStr = AccountState._todayStr();

    state = state.copyWith(
      license: PilotLicense.reroll(
        state.license,
        lockedStats: lockedStats,
        lockType: lockType,
        luckBonus: state.avatar.luckBonus,
      ),
      lastFreeRerollDate: todayStr,
    );
    _syncAccountState();
    return true;
  }

  /// Record that the player completed today's daily challenge.
  ///
  /// Updates the streak counter and persists to Supabase.
  void recordDailyChallengeCompletion() {
    final todayStr = AccountState._todayStr();
    state = state.copyWith(lastDailyChallengeDate: todayStr);

    // Update streak.
    final streak = state.dailyStreak;
    final newTotal = streak.totalCompleted + 1;

    int newCurrent;
    if (streak.isStreakActive || streak.completedToday) {
      // Streak is still going — just increment (or maintain if already done today).
      newCurrent = streak.completedToday
          ? streak.currentStreak
          : streak.currentStreak + 1;
    } else {
      // Streak was broken — start fresh at 1.
      newCurrent = 1;
    }

    final newLongest = newCurrent > streak.longestStreak
        ? newCurrent
        : streak.longestStreak;

    state = state.copyWith(
      dailyStreak: streak.copyWith(
        currentStreak: newCurrent,
        longestStreak: newLongest,
        lastCompletionDate: todayStr,
        totalCompleted: newTotal,
      ),
    );
    _syncAccountState();
  }

  /// Store the daily challenge result (for sharing later).
  void recordDailyResult(DailyResult result) {
    state = state.copyWith(lastDailyResult: result);
    _syncAccountState();
  }

  /// Recover a broken daily streak by spending coins.
  ///
  /// Returns true if the recovery was successful (had enough coins).
  bool recoverStreak() {
    final streak = state.dailyStreak;
    if (!streak.isRecoverable) return false;

    final cost = streak.recoveryCost;
    if (!spendCoins(cost, source: 'streak_recovery')) return false;

    // Fill in the missed days — the streak is restored as if those days
    // were completed. The lastCompletionDate moves to yesterday so the
    // streak is active again (the player still needs to play today).
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';

    state = state.copyWith(
      dailyStreak: streak.copyWith(lastCompletionDate: yesterdayStr),
    );
    _syncAccountState();
    return true;
  }

  /// Use the daily-scramble bonus reroll. Returns true if available.
  ///
  /// Available only if the player has completed today's daily scramble
  /// and hasn't already used this bonus reroll. The base reroll is free,
  /// but locking stats still costs coins. Returns false if the player
  /// cannot afford the lock costs.
  bool useDailyScrambleReroll({
    Set<String> lockedStats = const {},
    bool lockType = false,
  }) {
    if (!state.hasDailyScrambleReroll) return false;

    // Base reroll is free, but locking stats still costs coins.
    final lockCost = _calculateLockCost(lockedStats, lockType);
    if (lockCost > 0 &&
        !spendCoins(lockCost, source: 'daily_scramble_lock_cost')) {
      return false;
    }

    // Mark as used by clearing the daily challenge date (prevents reuse).
    // We use a special suffix to distinguish "completed" from "reroll used".
    final todayStr = AccountState._todayStr();
    state = state.copyWith(
      license: PilotLicense.reroll(
        state.license,
        lockedStats: lockedStats,
        lockType: lockType,
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

/// Convenience provider for daily streak.
final dailyStreakProvider = Provider<DailyStreak>((ref) {
  return ref.watch(accountProvider).dailyStreak;
});

/// Convenience provider for the last daily result (may be null).
final lastDailyResultProvider = Provider<DailyResult?>((ref) {
  return ref.watch(accountProvider).lastDailyResult;
});

/// Convenience provider for owned shop cosmetics.
final ownedCosmeticsProvider = Provider<Set<String>>((ref) {
  return ref.watch(accountProvider).ownedCosmetics;
});
