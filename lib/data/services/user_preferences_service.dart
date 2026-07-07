import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/error_service.dart';

import '../../game/economy/consumables.dart';
import '../../game/economy/fuel_tank.dart';
import '../../game/quiz/flight_school_level.dart';
import '../../game/quiz/uncharted_progress.dart';
import '../../game/tutorial/campaign_mission.dart';
import '../models/avatar_config.dart';
import '../models/daily_result.dart';
import '../models/daily_streak.dart';
import '../models/pilot_license.dart';
import '../models/player.dart';
import '../models/season.dart';
import 'leaderboard_service.dart';
import 'score_submitter.dart';

// ---------------------------------------------------------------------------
// Offline write queue
// ---------------------------------------------------------------------------

/// Persists failed Supabase writes to SharedPreferences so they can be
/// retried on the next flush cycle or app resume.
///
/// Entries are stored under [_kKey] as a JSON list. Each entry has:
///   `{'table': String, 'data': Map, 'op': 'upsert'|'insert',
///     'timestamp': int, 'retries': int}`
///
/// The queue is capped at [_kMaxEntries]. When full the oldest entry is
/// dropped to make room for the newest — keeping the queue small and
/// avoiding unbounded growth.
class _PendingWriteQueue {
  static const String _kKey = 'pending_writes';
  static const int _kMaxEntries = 200;
  static const int _kMaxRetries = 5;

  /// In-memory fallback used when SharedPreferences is unavailable.
  List<Map<String, dynamic>> _memory = [];
  SharedPreferences? _prefs;
  bool _prefsAvailable = false;

  /// Must be called once before any other method.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsAvailable = true;
      // Migrate any entries stored when prefs were unavailable.
      if (_memory.isNotEmpty) {
        final existing = _load();
        final merged = [...existing, ..._memory];
        await _save(merged);
        _memory = [];
      }
    } catch (e) {
      debugPrint(
        '[PendingWriteQueue] SharedPreferences unavailable, '
        'falling back to in-memory queue: $e',
      );
      _prefsAvailable = false;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  bool get isEmpty => _loadAll().isEmpty;

  /// Number of entries currently in the offline queue.
  int get length => _loadAll().length;

  /// Add a write to the back of the queue.
  ///
  /// If the queue is already at capacity the oldest entry is removed first.
  Future<void> enqueue(
    String table,
    Map<String, dynamic> data,
    String op,
  ) async {
    final entries = _loadAll();

    if (entries.length >= _kMaxEntries) {
      // Drop the oldest entry (index 0) to stay under the cap.
      entries.removeAt(0);
      debugPrint('[PendingWriteQueue] queue full — dropped oldest entry');
    }

    entries.add({
      'table': table,
      'data': data,
      'op': op,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    });

    await _persist(entries);
  }

  /// Return the oldest entry without removing it, or null if empty.
  Map<String, dynamic>? peek() {
    final entries = _loadAll();
    return entries.isEmpty ? null : entries.first;
  }

  /// Remove and return the oldest entry, or null if empty.
  Future<Map<String, dynamic>?> dequeue() async {
    final entries = _loadAll();
    if (entries.isEmpty) return null;
    final head = entries.removeAt(0);
    await _persist(entries);
    return head;
  }

  /// Increment the retry counter on the oldest entry and re-persist.
  ///
  /// If the entry has reached [_kMaxRetries] it is dropped instead —
  /// with telemetry, because a dropped entry is silently lost data (a
  /// game score, a coin-audit row). Retried entries rotate to the back
  /// of the queue so one poisoned write can't head-block every other
  /// queued write across drain cycles.
  Future<void> incrementRetryOrDrop() async {
    final entries = _loadAll();
    if (entries.isEmpty) return;
    final head = entries.removeAt(0);
    final retries = (head['retries'] as int? ?? 0) + 1;
    if (retries >= _kMaxRetries) {
      debugPrint(
        '[PendingWriteQueue] dropped entry after $_kMaxRetries '
        'retries: table=${head['table']}',
      );
      ErrorService.instance.reportWarning(
        'Pending write dropped after $_kMaxRetries retries '
        '(table=${head['table']}, op=${head['op']}) — data lost',
        StackTrace.current,
        context: {'source': 'PendingWriteQueue'},
      );
    } else {
      entries.add({...head, 'retries': retries});
    }
    await _persist(entries);
  }

  /// Drop queued writes for [table] enqueued before [cutoff].
  ///
  /// Used when the server row turns out to be fresher than local state
  /// (another device, or a server-side reset): replaying those stale
  /// upserts would push the outdated values back to the server.
  Future<void> purgeTableOlderThan(String table, DateTime cutoff) async {
    final entries = _loadAll();
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    final kept = entries.where((e) {
      if (e['table'] != table) return true;
      final ts = e['timestamp'] as int? ?? 0;
      return ts >= cutoffMs;
    }).toList();
    if (kept.length != entries.length) {
      debugPrint(
        '[PendingWriteQueue] purged ${entries.length - kept.length} stale '
        '$table write(s) older than $cutoff (server is fresher)',
      );
      await _persist(kept);
    }
  }

  /// Remove all entries from the queue.
  Future<void> clear() async {
    if (_prefsAvailable) {
      await _prefs!.remove(_kKey);
    } else {
      _memory = [];
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> _loadAll() {
    return _prefsAvailable ? _load() : List.from(_memory);
  }

  List<Map<String, dynamic>> _load() {
    if (!_prefsAvailable) return List.from(_memory);
    try {
      final raw = _prefs!.getString(_kKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<Map<String, dynamic>> entries) async {
    if (_prefsAvailable) {
      await _save(entries);
    } else {
      _memory = entries;
    }
  }

  Future<void> _save(List<Map<String, dynamic>> entries) async {
    try {
      await _prefs!.setString(_kKey, jsonEncode(entries));
    } catch (e) {
      debugPrint('[PendingWriteQueue] failed to persist queue: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// UserPreferencesService
// ---------------------------------------------------------------------------

/// Lightweight, memory-efficient service that syncs user preferences to
/// Supabase.
///
/// Design:
/// - **Single load** on login — pulls profiles, user_settings, and
///   account_state in one round-trip via parallel futures.
/// - **Debounced writes** — dirty flags track which tables changed. A 2-second
///   timer batches mutations into a single upsert per table.
/// - **No duplicate state** — the Riverpod providers own the truth; this
///   service only serialises/deserialises to/from Supabase.
/// - **Offline resilience** — failed writes are persisted to SharedPreferences
///   and retried on the next flush cycle or app resume.
class UserPreferencesService {
  UserPreferencesService._();

  static final UserPreferencesService instance = UserPreferencesService._();

  SupabaseClient get _client => Supabase.instance.client;
  SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } on StateError {
      return null;
    }
  }

  Timer? _debounceTimer;
  String? _userId;

  // Crash-safe local persistence — survives iOS force-close.
  SharedPreferences? _localPrefs;
  static const _kLocalProfile = 'crash_safe_profile';
  static const _kLocalSettings = 'crash_safe_settings';
  static const _kLocalAccountState = 'crash_safe_account_state';

  /// Client-only field stamped into crash-safe caches recording when the
  /// cache was written. Stripped before any merge/upsert — never sent to
  /// Supabase. Lets _recoverLocalCache detect that the server row changed
  /// after the cache was written (other device / server-side reset).
  static const _kCachedAtField = '_cached_at';

  /// Durable server column holding the set of completed Basic Training /
  /// campaign mission IDs. Feature-detected: stripped from writes when the
  /// column is absent (pre-migration), unioned (never shrunk) on merge.
  static const _kCompletedMissionIds = 'completed_mission_ids';

  /// Baseline `account_state` columns known to exist server-side. Used to
  /// feature-detect which keys are safe to upsert when no server row has been
  /// observed yet (brand-new account). Columns added by later migrations
  /// (e.g. [_kCompletedMissionIds]) are NOT in the baseline — they are only
  /// written once observed on a loaded row, so a payload never fails the whole
  /// upsert with PGRST204 for an unknown column. Keys the server does not have
  /// (campaign_progress / uncharted_progress, which never had columns) are
  /// likewise stripped so the write succeeds.
  static const Set<String> _kBaselineAccountColumns = {
    'user_id',
    'avatar_config',
    'license_data',
    'unlocked_regions',
    'owned_avatar_parts',
    'equipped_plane_id',
    'equipped_contrail_id',
    'last_free_reroll_date',
    'last_daily_challenge_date',
    'updated_at',
    'equipped_title_id',
    'daily_streak_data',
    'last_daily_result',
    'owned_cosmetics',
    'free_flight_coins_today',
    'free_flight_coin_date',
    'flight_school_progress',
  };

  /// Column names observed on the loaded `account_state` row — the ground
  /// truth for which columns the server actually has. Populated in [load] from
  /// the raw server row (before any local-cache merge). Null until the first
  /// load with an existing row; callers fall back to [_kBaselineAccountColumns].
  Set<String>? _knownAccountColumns;

  // Dirty flags — only the changed tables are written.
  bool _profileDirty = false;
  bool _settingsDirty = false;
  bool _accountStateDirty = false;

  // Write-version counters — incremented on every save*() call.
  // Used by _flush() to detect if a new mutation occurred during an in-flight
  // network write. If the version has changed by the time the .then() callback
  // fires, the dirty flag and pending data are NOT cleared — the next flush
  // cycle will pick up the newer data. This prevents BUG 1 (silent data loss
  // from overlapping mutations and flushes) and BUG 4 (crash-safe cache
  // cleared while newer data exists).
  int _profileWriteVersion = 0;
  int _settingsWriteVersion = 0;
  int _accountStateWriteVersion = 0;

  /// Whether there are any unsaved writes waiting to be flushed.
  bool get hasPendingWrites =>
      _profileDirty || _settingsDirty || _accountStateDirty;

  /// Whether there are failed writes queued for retry (offline queue).
  bool get hasPendingOfflineWrites => _queueInitialised && !_queue.isEmpty;

  /// Number of entries currently in the offline write queue.
  int get pendingOfflineCount => _queueInitialised ? _queue.length : 0;

  // Cached write payloads — populated by markDirty calls, flushed by _flush.
  Map<String, dynamic>? _pendingProfile;
  Map<String, dynamic>? _pendingSettings;
  Map<String, dynamic>? _pendingAccountState;

  // Offline write queue — survives app restarts via SharedPreferences.
  final _PendingWriteQueue _queue = _PendingWriteQueue();
  bool _queueInitialised = false;

  // Flush mutex — prevents concurrent _flush() calls from racing.
  // When non-null, a flush is in-flight. New callers await the existing
  // flush before checking if another flush is needed.
  Completer<void>? _flushLock;

  // ---------------------------------------------------------------------------
  // Queue initialisation
  // ---------------------------------------------------------------------------

  Future<void> _ensureQueueInitialised() async {
    if (_queueInitialised) return;
    await _queue.init();
    try {
      _localPrefs ??= await SharedPreferences.getInstance();
    } catch (_) {}
    _queueInitialised = true;
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Load all user state from Supabase in parallel.
  ///
  /// Returns a [UserPreferencesSnapshot] containing the full state, or null if
  /// the user has no saved data yet (first login).
  Future<UserPreferencesSnapshot?> load(String userId) async {
    _userId = userId;
    if (_userId == null) return null;

    await _ensureQueueInitialised();

    try {
      // Parallel fetch — one round-trip per table, all concurrent.
      final results = await Future.wait<Map<String, dynamic>?>([
        _client.from('profiles').select().eq('id', userId).maybeSingle(),
        _client
            .from('user_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        _client
            .from('account_state')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
      ]);

      var profileData = results[0];
      var settingsData = results[1];
      var accountData = results[2];

      // Feature-detect account_state columns from the RAW server row (before
      // the local-cache merge, which may inject client-only keys). This is the
      // ground truth for which columns exist server-side, so we only ever
      // upsert columns the server actually has — degrading gracefully before
      // additive migrations (e.g. completed_mission_ids) are applied.
      if (accountData != null) {
        _knownAccountColumns = accountData.keys.toSet();
      }

      if (profileData == null) {
        debugPrint(
          '[UserPreferencesService] load: profiles row is null for $userId',
        );
        return null;
      }

      // Recover any crash-safe data that wasn't flushed (e.g. iOS force-close
      // killed the process before the 2-second debounce timer fired).
      profileData = _recoverLocalCache(
        _kLocalProfile,
        profileData,
        'id',
        userId,
      );
      settingsData = _recoverLocalCache(
        _kLocalSettings,
        settingsData,
        'user_id',
        userId,
      );
      accountData = _recoverLocalCache(
        _kLocalAccountState,
        accountData,
        'user_id',
        userId,
      );

      return UserPreferencesSnapshot(
        profile: profileData!,
        settings: settingsData,
        accountState: accountData,
      );
    } catch (e) {
      debugPrint('[UserPreferencesService] load failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Save (debounced)
  // ---------------------------------------------------------------------------

  /// Mark the profiles table as dirty and queue a write.
  void saveProfile(Player player) {
    _profileWriteVersion++;
    _profileDirty = true;
    _pendingProfile = {
      'id': _userId,
      'username': player.username,
      'display_name': player.displayName,
      'avatar_url': player.avatarUrl,
      'level': player.level,
      'xp': player.xp,
      'coins': player.coins,
      'games_played': player.gamesPlayed,
      'best_score': player.bestScore,
      'best_time_ms': player.bestTime?.inMilliseconds,
      'total_flight_time_ms': player.totalFlightTime.inMilliseconds,
      'countries_found': player.countriesFound,
      'flags_correct': player.flagsCorrect,
      'capitals_correct': player.capitalsCorrect,
      'outlines_correct': player.outlinesCorrect,
      'borders_correct': player.bordersCorrect,
      'stats_correct': player.statsCorrect,
      'best_streak': player.bestStreak,
    };
    _cacheLocally(_kLocalProfile, _pendingProfile!);
    _scheduleSave();
  }

  /// Mark settings as dirty and queue a write.
  void saveSettings({
    required double turnSensitivity,
    required bool invertControls,
    required bool enableNight,
    required bool enableClouds,
    double? cloudCoverage,
    double? cloudOpacity,
    required String mapStyle,
    required bool englishLabels,
    required String difficulty,
    required bool soundEnabled,
    required double musicVolume,
    required double effectsVolume,
    required bool notificationsEnabled,
    required bool hapticEnabled,
  }) {
    _settingsWriteVersion++;
    _settingsDirty = true;
    _pendingSettings = {
      'user_id': _userId,
      'turn_sensitivity': turnSensitivity,
      'invert_controls': invertControls,
      'enable_night': enableNight,
      'enable_clouds': enableClouds,
      if (cloudCoverage != null) 'cloud_coverage': cloudCoverage,
      if (cloudOpacity != null) 'cloud_opacity': cloudOpacity,
      'map_style': mapStyle,
      'english_labels': englishLabels,
      'difficulty': difficulty,
      'sound_enabled': soundEnabled,
      'music_volume': musicVolume,
      'effects_volume': effectsVolume,
      'notifications_enabled': notificationsEnabled,
      'haptic_enabled': hapticEnabled,
    };
    _cacheLocally(_kLocalSettings, _pendingSettings!);
    _scheduleSave();
  }

  /// Mark account state as dirty and queue a write.
  ///
  /// [licenseEconomyExtras] is merged into the `license_data` JSONB blob —
  /// the license_data schema is client-owned, so economy state that has no
  /// dedicated column (fuel tank, refuel canisters, trophy case) rides
  /// inside it without requiring a migration.
  void saveAccountState({
    required AvatarConfig avatar,
    required PilotLicense license,
    required Set<String> unlockedRegions,
    required Set<String> ownedAvatarParts,
    required Set<String> ownedCosmetics,
    required String equippedPlaneId,
    required String equippedContrailId,
    String? equippedTitleId,
    String? lastFreeRerollDate,
    String? lastDailyChallengeDate,
    DailyStreak dailyStreak = const DailyStreak(),
    DailyResult? lastDailyResult,
    int freeFlightCoinsToday = 0,
    String? freeFlightCoinDate,
    Map<String, FlightSchoolProgress> flightSchoolProgress = const {},
    Map<String, UnchartedProgress> unchartedProgress = const {},
    Map<String, dynamic> campaignProgress = const {},
    Set<String> completedMissionIds = const {},
    Map<String, dynamic> licenseEconomyExtras = const {},
  }) {
    _accountStateWriteVersion++;
    _accountStateDirty = true;
    _pendingAccountState = {
      'user_id': _userId,
      'avatar_config': avatar.toJson(),
      'license_data': {...license.toJson(), ...licenseEconomyExtras},
      'unlocked_regions': unlockedRegions.toList(),
      'owned_avatar_parts': ownedAvatarParts.toList(),
      'owned_cosmetics': ownedCosmetics.toList(),
      'equipped_plane_id': equippedPlaneId,
      'equipped_contrail_id': equippedContrailId,
      'equipped_title_id': equippedTitleId,
      'last_free_reroll_date': lastFreeRerollDate,
      'last_daily_challenge_date': lastDailyChallengeDate,
      'daily_streak_data': dailyStreak.toJson(),
      'last_daily_result': lastDailyResult?.toJson(),
      'free_flight_coins_today': freeFlightCoinsToday,
      'free_flight_coin_date': freeFlightCoinDate,
      'flight_school_progress': flightSchoolProgress.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'uncharted_progress': unchartedProgress.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'campaign_progress': campaignProgress,
      // Durable, feature-detected source of truth for mission completion (the
      // unlock/promotion gate). Stripped from the network payload when the
      // column is absent, but always kept in the crash-safe cache so the
      // union-on-merge recovery can never un-complete a mission.
      _kCompletedMissionIds: completedMissionIds.toList(),
    };
    _cacheLocally(_kLocalAccountState, _pendingAccountState!);
    _scheduleSave();
  }

  /// Insert a game result into the scores table.
  ///
  /// Input values are clamped to valid ranges before writing.
  /// If the insert fails, the entry is placed in the offline queue for retry.
  Future<void> saveGameResult({
    required int score,
    required int timeMs,
    required String region,
    required int roundsCompleted,
    String? roundEmojis,
    List<Map<String, dynamic>>? roundDetails,
  }) async {
    await _ensureQueueInitialised();

    // Client-side input validation — clamp to valid ranges.
    const int maxScore = 100000;
    const int maxTimeMs = 3600000; // 1 hour

    int validatedScore = score;
    if (score < 0 || score > maxScore) {
      debugPrint(
        '[UserPreferencesService] saveGameResult: score $score out of range '
        '[0, $maxScore], clamping.',
      );
      validatedScore = score.clamp(0, maxScore);
    }

    int validatedTimeMs = timeMs;
    if (timeMs <= 0 || timeMs >= maxTimeMs) {
      debugPrint(
        '[UserPreferencesService] saveGameResult: timeMs $timeMs out of range '
        '(0, $maxTimeMs), clamping.',
      );
      validatedTimeMs = timeMs.clamp(1, maxTimeMs - 1);
    }

    final data = {
      'user_id': _userId,
      'score': validatedScore,
      'time_ms': validatedTimeMs,
      'region': region,
      'rounds_completed': roundsCompleted,
      if (roundEmojis != null) 'round_emojis': roundEmojis,
      if (roundDetails != null) 'round_details': roundDetails,
    };

    final client = _clientOrNull;
    if (client == null) {
      await _queue.enqueue('scores', data, 'insert');
      return;
    }

    try {
      // Prefer the server-authoritative submit_score RPC (enforces
      // auth.uid() = user_id + server-side bounds). Falls back to a direct
      // INSERT when the RPC isn't migrated yet. See ScoreSubmitter.
      await ScoreSubmitter.submit(client, data);
      // New score is live — stale leaderboard caches must go.
      LeaderboardService.instance.invalidateCache();
    } catch (e) {
      debugPrint(
        '[UserPreferencesService] saveGameResult failed, queuing for retry: $e',
      );
      await _queue.enqueue('scores', data, 'insert');
    }
  }

  /// Insert a coin activity entry for auditing coin balance changes.
  ///
  /// [coinAmount] should be signed (+earn, -spend). [source] describes where
  /// the change came from (e.g. game_completion, cosmetic_purchase, gift_sent).
  Future<void> saveCoinActivity({
    required String username,
    required int coinAmount,
    required String source,
    int? balanceAfter,
  }) async {
    await _ensureQueueInitialised();

    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    if (coinAmount == 0) return;

    final trimmedUsername = username.trim();
    final safeUsername = trimmedUsername.isNotEmpty
        ? trimmedUsername.substring(
            0,
            trimmedUsername.length > 64 ? 64 : trimmedUsername.length,
          )
        : userId;
    final trimmedSource = source.trim();
    final safeSource = trimmedSource.isNotEmpty
        ? trimmedSource.substring(
            0,
            trimmedSource.length > 64 ? 64 : trimmedSource.length,
          )
        : 'unknown';

    final data = {
      'user_id': userId,
      'username': safeUsername,
      'coin_amount': coinAmount,
      'source': safeSource,
      'balance_after': balanceAfter,
    };

    final client = _clientOrNull;
    if (client == null) {
      await _queue.enqueue('coin_activity', data, 'insert');
      return;
    }

    try {
      await client.from('coin_activity').insert(data);
    } catch (e) {
      debugPrint(
        '[UserPreferencesService] saveCoinActivity failed, queuing for retry: $e',
      );
      await _queue.enqueue('coin_activity', data, 'insert');
    }
  }

  // ---------------------------------------------------------------------------
  // Retry pending writes
  // ---------------------------------------------------------------------------

  /// Attempt to flush all entries from the offline write queue.
  ///
  /// Items are processed oldest-first, one at a time, to avoid overwhelming
  /// the server. An entry is removed from the queue only on success. On
  /// failure the retry counter is incremented; entries that exceed
  /// [_PendingWriteQueue._kMaxRetries] are dropped automatically.
  Future<void> retryPendingWrites() async {
    await _ensureQueueInitialised();

    if (_queue.isEmpty) return;
    final client = _clientOrNull;
    if (client == null) {
      debugPrint(
        '[UserPreferencesService] retryPendingWrites: Supabase not initialized — skipping',
      );
      return;
    }

    // Guard: skip retry if there is no authenticated user. Without this,
    // entries queued for a user whose token expired and failed to refresh
    // would waste all retry attempts on auth errors.
    if (client.auth.currentUser == null) {
      debugPrint(
        '[UserPreferencesService] retryPendingWrites: no auth user — skipping',
      );
      return;
    }

    debugPrint('[UserPreferencesService] retryPendingWrites: draining queue…');

    // We loop until the queue is empty or we hit a consecutive failure,
    // at which point we stop to avoid hammering a down server.
    while (!_queue.isEmpty) {
      final entry = _queue.peek();
      if (entry == null) break;

      final table = entry['table'] as String;
      final data = entry['data'] as Map<String, dynamic>;
      final op = entry['op'] as String;

      try {
        if (op == 'insert') {
          // Route queued score inserts through the server-authoritative RPC
          // (with direct-insert fallback) just like the live path.
          if (table == 'scores') {
            await ScoreSubmitter.submit(client, data);
          } else {
            await client.from(table).insert(data);
          }
        } else {
          // Feature-detect columns for account_state so a legacy queued write
          // (enqueued before this build, possibly carrying campaign_progress /
          // uncharted_progress / completed_mission_ids the server has no column
          // for) can't fail forever on an unknown column.
          final payload =
              table == 'account_state' ? _accountPayloadForWrite(data) : data;
          await client.from(table).upsert(payload);
        }
        // Success — remove the entry from the queue.
        await _queue.dequeue();
        // Invalidate leaderboard cache when a queued score lands.
        if (table == 'scores') {
          LeaderboardService.instance.invalidateCache();
        }
        debugPrint(
          '[UserPreferencesService] retryPendingWrites: $op on $table succeeded',
        );
      } catch (e) {
        debugPrint(
          '[UserPreferencesService] retryPendingWrites: $op on $table failed '
          '(retries=${entry['retries']}): $e',
        );
        await _queue.incrementRetryOrDrop();
        // Stop retrying this cycle — likely a network issue; try again later.
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Flush on dispose / sign-out
  // ---------------------------------------------------------------------------

  /// Immediately flush all pending writes (call on sign-out or app pause).
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _flush();
  }

  /// Cancel any pending debounced writes and reset dirty flags.
  ///
  /// Called before loading a new user's data to prevent stale writes from
  /// a prior session from firing after the new data is hydrated.
  void clearDirtyFlags() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _profileDirty = false;
    _settingsDirty = false;
    _accountStateDirty = false;
    _pendingProfile = null;
    _pendingSettings = null;
    _pendingAccountState = null;
    // Bump versions so any in-flight flush .then() callbacks from the old
    // session won't clear the flags/data that belong to the new session.
    _profileWriteVersion++;
    _settingsWriteVersion++;
    _accountStateWriteVersion++;
  }

  /// Clear crash-safe local caches so the next [load] doesn't merge stale
  /// data over the server snapshot.
  ///
  /// Used by admin force-refresh: after an admin set-stat the server has the
  /// authoritative value and we must prevent [_recoverLocalCache] from
  /// overriding it with a stale cached profile (e.g. old level value).
  void clearLocalCaches() {
    _clearLocalCache(_kLocalProfile);
    _clearLocalCache(_kLocalSettings);
    _clearLocalCache(_kLocalAccountState);
    _pendingRecoveryKeys.clear();
  }

  /// Clear cached user, cancel pending writes, and purge the offline queue.
  ///
  /// Called on sign-out or account deletion. The offline queue is cleared to
  /// prevent cross-user contamination — without this, writes queued for user A
  /// could be replayed when user B logs in on the same device.
  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _userId = null;
    _profileDirty = false;
    _settingsDirty = false;
    _accountStateDirty = false;
    _pendingProfile = null;
    _pendingSettings = null;
    _pendingAccountState = null;
    _pendingRecoveryKeys.clear();
    // Purge offline queue and crash-safe cache to prevent cross-user
    // contamination.
    if (_queueInitialised) {
      _queue.clear();
    }
    _clearLocalCache(_kLocalProfile);
    _clearLocalCache(_kLocalSettings);
    _clearLocalCache(_kLocalAccountState);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Immediately persist a payload to SharedPreferences as a crash-safe cache.
  ///
  /// Called from each `save*()` method so that even if the app is force-killed
  /// before the 2-second debounce fires, the data is recoverable from local
  /// storage on the next launch.
  void _cacheLocally(String key, Map<String, dynamic> payload) {
    try {
      // Stamp when this cache was written (without mutating the pending
      // write map) so _recoverLocalCache can tell whether a server row is
      // fresher — e.g. after a server-side account reset.
      final stamped = {
        ...payload,
        _kCachedAtField: DateTime.now().toUtc().toIso8601String(),
      };
      if (_localPrefs == null) {
        // Eagerly initialise if the queue hasn't been set up yet. The
        // getInstance() Future resolves almost instantly on iOS/Android
        // (in-process cache after the first call).
        SharedPreferences.getInstance().then((prefs) {
          _localPrefs = prefs;
          try {
            prefs.setString(key, jsonEncode(stamped));
          } catch (_) {}
        }).catchError((_) {
          // Binding not initialised (e.g. in unit tests) — silently skip.
        });
        return;
      }
      _localPrefs!.setString(key, jsonEncode(stamped));
    } catch (_) {}
  }

  void _clearLocalCache(String key) {
    try {
      _localPrefs?.remove(key);
    } catch (_) {}
  }

  /// Filter an `account_state` write payload down to the columns the server
  /// actually has. Uses columns observed on the loaded row when available,
  /// else the compile-time baseline. Prevents an unknown column from failing
  /// the whole upsert (PGRST204) — the crux of the feature-detect fallback.
  Map<String, dynamic> _accountPayloadForWrite(Map<String, dynamic> full) =>
      filterAccountPayloadForColumns(
        full,
        _knownAccountColumns ?? _kBaselineAccountColumns,
      );

  /// Pure feature-detect filter: keep only [knownColumns] (plus always drop the
  /// client-only cache stamp). Exposed for testing the pre-migration fallback —
  /// an unknown column must be stripped so it can never fail the whole upsert.
  @visibleForTesting
  static Map<String, dynamic> filterAccountPayloadForColumns(
    Map<String, dynamic> full,
    Set<String> knownColumns,
  ) {
    final out = <String, dynamic>{};
    for (final entry in full.entries) {
      if (entry.key == _kCachedAtField) continue;
      if (knownColumns.contains(entry.key)) out[entry.key] = entry.value;
    }
    return out;
  }

  /// Baseline account_state columns (used as the fallback known-column set when
  /// no server row has been observed). Exposed for testing.
  @visibleForTesting
  static Set<String> get baselineAccountColumns => _kBaselineAccountColumns;

  /// Read the completed-mission id list from an account_state map (server row
  /// or local cache), tolerating a missing key / wrong shape.
  static List<String> _missionIdsOf(Map<String, dynamic>? data) {
    final v = data?[_kCompletedMissionIds];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Union of completed-mission ids across two account_state maps. Order is
  /// stable: server ids first, then any local-only ids. This is monotonic —
  /// the result is never smaller than either input, so a stale or empty
  /// server row can never un-complete missions the client already knows about.
  static List<String> _unionMissionIds(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    return <String>{..._missionIdsOf(a), ..._missionIdsOf(b)}.toList();
  }

  /// Exposed for testing the union-on-merge guarantee: the result of merging a
  /// server row's completed missions with a local cache's is never smaller than
  /// either input, so a stale/empty server row can't un-complete a mission.
  @visibleForTesting
  static List<String> unionCompletedMissionIds(
    Map<String, dynamic>? server,
    Map<String, dynamic>? local,
  ) =>
      _unionMissionIds(server, local);

  /// Keys that had crash-safe data recovered during [load]. These are
  /// retained until the recovered data is confirmed flushed to Supabase,
  /// preventing data loss if the flush fails (e.g. network still down
  /// after iOS force-close recovery).
  final Set<String> _pendingRecoveryKeys = {};

  /// Recover locally cached data that was written but never flushed to
  /// Supabase (e.g. after an iOS force-close during the debounce window).
  ///
  /// If found and belonging to [userId], the local data is merged over the
  /// server data. For profile data, monotonic stat fields use max(server,local)
  /// to prevent regression when the local cache is stale (e.g. if another
  /// device updated the server since this cache was written). For non-stat
  /// fields, local still wins (more recent mutation intent).
  Map<String, dynamic>? _recoverLocalCache(
    String key,
    Map<String, dynamic>? serverData,
    String userIdField,
    String userId,
  ) {
    try {
      final cached = _localPrefs?.getString(key);
      if (cached == null) return serverData;

      final localData = jsonDecode(cached) as Map<String, dynamic>;
      // Verify the cached data is for the same user.
      if (localData[userIdField] != userId) {
        _clearLocalCache(key);
        return serverData;
      }

      // Server-authority check: if the server row was updated meaningfully
      // AFTER this cache was written, someone else changed the account on
      // the server side (another device, or an admin/server reset). The
      // server must win outright — otherwise a server-side reset could
      // never take effect (max(server, local) would resurrect the old
      // values and the flush would push them back up). The skew margin
      // covers device/server clock drift.
      final cachedAtRaw = localData.remove(_kCachedAtField);
      final cachedAt =
          cachedAtRaw is String ? DateTime.tryParse(cachedAtRaw) : null;
      final serverUpdatedRaw = serverData?['updated_at'];
      final serverUpdated = serverUpdatedRaw is String
          ? DateTime.tryParse(serverUpdatedRaw)
          : null;
      // An unstamped cache predates this app version; its age is unknowable,
      // so when a server row exists the server wins (worst case: one
      // debounce-window of progress from a pre-update crash is lost, once).
      final serverIsFresher = cachedAt == null
          ? serverUpdated != null
          : serverUpdated != null &&
              serverUpdated.isAfter(cachedAt.add(const Duration(minutes: 2)));
      if (serverIsFresher) {
        // Mission completion is MONOTONIC and must survive even a server-wins
        // reset: a fresher-but-emptier server row (e.g. a server-side account
        // reset that bumped updated_at without any mission data) must never
        // un-complete Basic Training / campaign missions the local cache still
        // remembers. Union the id set into the server-authoritative snapshot
        // and preserve the cache so the next flush pushes the union back up.
        if (key == _kLocalAccountState) {
          final serverIds = _missionIdsOf(serverData);
          final union = _unionMissionIds(serverData, localData);
          if (union.length > serverIds.length) {
            debugPrint(
              '[UserPreferencesService] server $key is fresher but local cache '
              'has ${union.length - serverIds.length} extra completed '
              'mission(s) — server wins all fields except completed missions '
              '(unioned, never shrunk)',
            );
            _pendingRecoveryKeys.add(key);
            return {...?serverData, _kCompletedMissionIds: union};
          }
        }
        debugPrint(
          '[UserPreferencesService] server $key is fresher than local cache '
          '($serverUpdated > $cachedAt) — server wins, cache dropped',
        );
        _clearLocalCache(key);
        return serverData;
      }

      debugPrint(
        '[UserPreferencesService] recovered crash-safe $key for $userId',
      );

      // Mark for deferred clearing — the cache is only cleared after the
      // recovered data is successfully flushed to Supabase.
      _pendingRecoveryKeys.add(key);

      // Local data takes priority — merge over server data.
      if (serverData != null) {
        final merged = {...serverData, ...localData};

        // For profile data, protect monotonic stats from regression.
        // The local cache may be stale if another device updated the server
        // since this cache was written (e.g. session crashed, then played on
        // another device).
        if (key == _kLocalProfile) {
          const monotonicFields = [
            'level',
            'xp',
            'games_played',
            'countries_found',
            'total_flight_time_ms',
            'flags_correct',
            'capitals_correct',
            'outlines_correct',
            'borders_correct',
            'stats_correct',
            'best_streak',
          ];
          for (final field in monotonicFields) {
            final s = serverData[field] as int? ?? 0;
            final l = localData[field] as int? ?? 0;
            merged[field] = s > l ? s : l;
          }
          // best_score: higher is better (nullable).
          final sBest = serverData['best_score'] as int?;
          final lBest = localData['best_score'] as int?;
          if (sBest != null && lBest != null) {
            merged['best_score'] = sBest > lBest ? sBest : lBest;
          } else {
            merged['best_score'] = sBest ?? lBest;
          }
          // best_time_ms: lower is better (nullable).
          final sTime = serverData['best_time_ms'] as int?;
          final lTime = localData['best_time_ms'] as int?;
          if (sTime != null && lTime != null) {
            merged['best_time_ms'] = sTime < lTime ? sTime : lTime;
          } else {
            merged['best_time_ms'] = sTime ?? lTime;
          }
        }

        // For account_state, completed missions are monotonic in BOTH
        // directions: local wins for ordinary fields, but the completed-mission
        // set is the union so neither a stale server row nor a stale local
        // cache can drop a completion recorded on the other side.
        if (key == _kLocalAccountState) {
          merged[_kCompletedMissionIds] =
              _unionMissionIds(serverData, localData);
        }

        return merged;
      }
      return localData;
    } catch (_) {
      return serverData;
    }
  }

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _flush);
  }

  Future<void> _flush() async {
    // ── Flush mutex ──────────────────────────────────────────────────────
    // Prevents concurrent _flush() calls from racing. If another flush is
    // already in-flight (e.g. lifecycle flush + game-completion flush), we
    // wait for it to finish, then re-check dirty flags. This eliminates the
    // race amplification from multiple callers and ensures at most one
    // Supabase write per table is in-flight at any time.
    if (_flushLock != null) {
      try {
        await _flushLock!.future;
      } catch (_) {
        // The previous flush errored — we still need to try.
      }
      // After the previous flush completes, check if we still have dirty data.
      if (!_profileDirty && !_settingsDirty && !_accountStateDirty) {
        return;
      }
    }
    _flushLock = Completer<void>();

    try {
      await _ensureQueueInitialised();

      // Attempt to drain any previously failed writes before issuing new ones.
      await retryPendingWrites();
      final client = _clientOrNull;
      if (client == null) {
        debugPrint(
          '[UserPreferencesService] flush: Supabase not initialized — skipping',
        );
        return;
      }

      final futures = <Future<void>>[];

      // ── Version-guarded writes ───────────────────────────────────────
      // Capture the write-version at flush start. In the .then() callback,
      // only clear the dirty flag / pending data / crash-safe cache if no
      // new mutation has occurred since we captured the payload. This
      // prevents BUG 1 (silent data loss from overlapping mutations and
      // flushes) and BUG 4 (crash-safe cache cleared while newer data
      // exists in memory).

      if (_profileDirty && _pendingProfile != null) {
        final payload = _pendingProfile!;
        final versionAtFlush = _profileWriteVersion;
        futures.add(
          client.from('profiles').upsert(payload).then((_) {
            debugPrint(
              '[UserPreferencesService] flush profiles SUCCEEDED '
              '(games_played=${payload['games_played']}, '
              'best_score=${payload['best_score']}, '
              'coins=${payload['coins']})',
            );
            if (_profileWriteVersion == versionAtFlush) {
              _profileDirty = false;
              _pendingProfile = null;
              _clearLocalCache(_kLocalProfile);
              _pendingRecoveryKeys.remove(_kLocalProfile);
            }
            // Always invalidate leaderboard cache — the write succeeded.
            LeaderboardService.instance.invalidateCache();
          }).catchError((Object e) async {
            debugPrint(
              '[UserPreferencesService] flush profiles failed, queuing: $e',
            );
            await _queue.enqueue('profiles', payload, 'upsert');
          }),
        );
      }

      if (_settingsDirty && _pendingSettings != null) {
        final payload = _pendingSettings!;
        final versionAtFlush = _settingsWriteVersion;
        futures.add(
          client.from('user_settings').upsert(payload).then((_) {
            if (_settingsWriteVersion == versionAtFlush) {
              _settingsDirty = false;
              _pendingSettings = null;
              _clearLocalCache(_kLocalSettings);
              _pendingRecoveryKeys.remove(_kLocalSettings);
            }
          }).catchError((Object e) async {
            debugPrint(
              '[UserPreferencesService] flush user_settings failed, queuing: $e',
            );
            await _queue.enqueue('user_settings', payload, 'upsert');
          }),
        );
      }

      if (_accountStateDirty && _pendingAccountState != null) {
        // Strip keys the server has no column for (feature-detection). A
        // single unknown column (e.g. completed_mission_ids pre-migration,
        // or the never-migrated campaign_progress/uncharted_progress) would
        // otherwise fail the ENTIRE upsert with PGRST204 and silently drop
        // every field. The full state stays in the crash-safe cache.
        final payload = _accountPayloadForWrite(_pendingAccountState!);
        final versionAtFlush = _accountStateWriteVersion;
        futures.add(
          client.from('account_state').upsert(payload).then((_) {
            if (_accountStateWriteVersion == versionAtFlush) {
              _accountStateDirty = false;
              _pendingAccountState = null;
              _clearLocalCache(_kLocalAccountState);
              _pendingRecoveryKeys.remove(_kLocalAccountState);
            }
          }).catchError((Object e) async {
            debugPrint(
              '[UserPreferencesService] flush account_state failed, queuing: $e',
            );
            await _queue.enqueue('account_state', payload, 'upsert');
          }),
        );
      }

      if (futures.isNotEmpty) {
        // We intentionally don't wrap in try/catch here because each future
        // already handles its own error via catchError above.
        await Future.wait(futures);
      }
    } finally {
      _flushLock!.complete();
      _flushLock = null;
    }
  }
}

/// Immutable snapshot of all user data loaded from Supabase.
///
/// Passed to providers on login so they can hydrate in-memory state.
class UserPreferencesSnapshot {
  const UserPreferencesSnapshot({
    required this.profile,
    this.settings,
    this.accountState,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? accountState;

  // ── Profile helpers ──────────────────────────────────────────────────

  Player toPlayer() {
    final p = profile;
    final username = p['username'] as String? ?? p['id'] as String? ?? 'Pilot';
    return Player(
      id: p['id'] as String,
      username: username,
      displayName: p['display_name'] as String? ?? username,
      avatarUrl: p['avatar_url'] as String?,
      level: p['level'] as int? ?? 1,
      xp: p['xp'] as int? ?? 0,
      coins: p['coins'] as int? ?? 100,
      gamesPlayed: p['games_played'] as int? ?? 0,
      bestScore: p['best_score'] as int?,
      bestTime: p['best_time_ms'] != null
          ? Duration(milliseconds: p['best_time_ms'] as int)
          : null,
      totalFlightTime: p['total_flight_time_ms'] != null
          ? Duration(milliseconds: p['total_flight_time_ms'] as int)
          : Duration.zero,
      countriesFound: p['countries_found'] as int? ?? 0,
      flagsCorrect: p['flags_correct'] as int? ?? 0,
      capitalsCorrect: p['capitals_correct'] as int? ?? 0,
      outlinesCorrect: p['outlines_correct'] as int? ?? 0,
      bordersCorrect: p['borders_correct'] as int? ?? 0,
      statsCorrect: p['stats_correct'] as int? ?? 0,
      bestStreak: p['best_streak'] as int? ?? 0,
      adminRole: p['admin_role'] as String?,
      bannedAt: p['banned_at'] != null
          ? DateTime.tryParse(p['banned_at'] as String)
          : null,
      banExpiresAt: p['ban_expires_at'] != null
          ? DateTime.tryParse(p['ban_expires_at'] as String)
          : null,
      banReason: p['ban_reason'] as String?,
      createdAt: p['created_at'] != null
          ? DateTime.tryParse(p['created_at'] as String)
          : null,
    );
  }

  // ── Account state helpers ────────────────────────────────────────────

  AvatarConfig toAvatarConfig() {
    final data = accountState;
    if (data == null) return const AvatarConfig();
    final json = data['avatar_config'];
    if (json is Map<String, dynamic> && json.isNotEmpty) {
      try {
        return AvatarConfig.fromJson(json);
      } catch (_) {
        return const AvatarConfig();
      }
    }
    return const AvatarConfig();
  }

  PilotLicense toPilotLicense() {
    final data = accountState;
    if (data == null) {
      // No account_state row at all — genuinely new account.
      return PilotLicense.random();
    }
    final json = data['license_data'];
    if (json is Map<String, dynamic> && json.isNotEmpty) {
      try {
        return PilotLicense.fromJson(json);
      } catch (e) {
        // Parse failed — log but preserve what we can. Don't silently
        // replace an existing license with a random one.
        debugPrint('[UserPreferencesService] toPilotLicense parse error: $e');
        return PilotLicense.random();
      }
    }
    // license_data key is missing or empty — first time after account_state
    // row was created. Generate a new license for this new player.
    return PilotLicense.random();
  }

  /// The raw `license_data` JSONB map (client-owned schema), or null.
  Map<String, dynamic>? get _licenseData {
    final data = accountState;
    if (data == null) return null;
    final json = data['license_data'];
    if (json is Map) return Map<String, dynamic>.from(json);
    return null;
  }

  /// Meta fuel tank persisted inside license_data (`fuel` key).
  FuelTank toFuelTank() {
    final json = _licenseData?['fuel'];
    try {
      return FuelTank.fromJson(
        json is Map ? Map<String, dynamic>.from(json) : null,
      );
    } catch (e) {
      debugPrint('[UserPreferencesService] toFuelTank parse error: $e');
      return const FuelTank();
    }
  }

  /// Owned refuel canisters persisted inside license_data.
  int get refuelCanisters =>
      (_licenseData?['refuel_canisters'] as num?)?.toInt() ?? 0;

  /// Owned timed consumables persisted inside license_data
  /// (`consumables` key).
  ConsumableInventory toConsumableInventory() {
    final json = _licenseData?['consumables'];
    try {
      return ConsumableInventory.fromJson(
        json is Map ? Map<String, dynamic>.from(json) : null,
      );
    } catch (e) {
      debugPrint(
        '[UserPreferencesService] toConsumableInventory parse error: $e',
      );
      return const ConsumableInventory();
    }
  }

  /// Active timed-effect expiries persisted inside license_data
  /// (`active_effects` key) — timed boosts survive restarts.
  ActiveEffects toActiveEffects() {
    final json = _licenseData?['active_effects'];
    try {
      return ActiveEffects.fromJson(
        json is Map ? Map<String, dynamic>.from(json) : null,
      );
    } catch (e) {
      debugPrint('[UserPreferencesService] toActiveEffects parse error: $e');
      return const ActiveEffects();
    }
  }

  /// Season trophy case persisted inside license_data.
  TrophyCase toTrophyCase() {
    final json = _licenseData?['trophy_case'];
    try {
      return TrophyCase.fromJson(json is List ? json : null);
    } catch (e) {
      debugPrint('[UserPreferencesService] toTrophyCase parse error: $e');
      return const TrophyCase();
    }
  }

  Set<String> get unlockedRegions {
    final data = accountState;
    if (data == null) return {};
    final list = data['unlocked_regions'];
    if (list is List) return list.cast<String>().toSet();
    return {};
  }

  Set<String> get ownedAvatarParts {
    final data = accountState;
    if (data == null) return {};
    final list = data['owned_avatar_parts'];
    if (list is List) return list.cast<String>().toSet();
    return {};
  }

  Set<String> get ownedCosmetics {
    final data = accountState;
    if (data == null) return {};
    final list = data['owned_cosmetics'];
    if (list is List) return list.cast<String>().toSet();
    return {};
  }

  String get equippedPlaneId {
    final data = accountState;
    return data?['equipped_plane_id'] as String? ?? 'plane_default';
  }

  String get equippedContrailId {
    final data = accountState;
    return data?['equipped_contrail_id'] as String? ?? 'contrail_default';
  }

  String? get equippedTitleId {
    final data = accountState;
    return data?['equipped_title_id'] as String?;
  }

  String? get lastFreeRerollDate {
    final data = accountState;
    return data?['last_free_reroll_date'] as String?;
  }

  String? get lastDailyChallengeDate {
    final data = accountState;
    return data?['last_daily_challenge_date'] as String?;
  }

  int get freeFlightCoinsToday {
    final data = accountState;
    return data?['free_flight_coins_today'] as int? ?? 0;
  }

  String? get freeFlightCoinDate {
    final data = accountState;
    return data?['free_flight_coin_date'] as String?;
  }

  DailyStreak toDailyStreak() {
    final data = accountState;
    if (data == null) return const DailyStreak();
    final json = data['daily_streak_data'];
    if (json is Map<String, dynamic> && json.isNotEmpty) {
      try {
        return DailyStreak.fromJson(json);
      } catch (_) {
        return const DailyStreak();
      }
    }
    return const DailyStreak();
  }

  DailyResult? toLastDailyResult() {
    final data = accountState;
    if (data == null) return null;
    final json = data['last_daily_result'];
    if (json is Map<String, dynamic> && json.isNotEmpty) {
      try {
        return DailyResult.fromJson(json);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, FlightSchoolProgress> toFlightSchoolProgress() {
    final data = accountState;
    if (data == null) return {};
    final json = data['flight_school_progress'];
    if (json is Map<String, dynamic>) {
      try {
        return json.map(
          (k, v) => MapEntry(
            k,
            v is Map<String, dynamic>
                ? FlightSchoolProgress.fromJson(v)
                : const FlightSchoolProgress(),
          ),
        );
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Map<String, UnchartedProgress> toUnchartedProgress() {
    final data = accountState;
    if (data == null) return {};
    final json = data['uncharted_progress'];
    if (json is Map<String, dynamic>) {
      try {
        return json.map(
          (k, v) => MapEntry(
            k,
            v is Map<String, dynamic>
                ? UnchartedProgress.fromJson(v)
                : const UnchartedProgress(),
          ),
        );
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  /// Durable set of completed Basic Training / campaign mission IDs, read from
  /// the feature-detected `completed_mission_ids` column. Empty when the column
  /// is absent (pre-migration) — completion then falls back to whatever
  /// [toCampaignProgress] recovered from the crash-safe cache.
  Set<String> toCompletedMissionIds() {
    final data = accountState;
    if (data == null) return {};
    final v = data['completed_mission_ids'];
    if (v is List) {
      return v.map((e) => e.toString()).toSet();
    }
    return {};
  }

  Map<String, CampaignMissionResult> toCampaignProgress() {
    final data = accountState;
    if (data == null) return {};
    final json = data['campaign_progress'];
    if (json is Map<String, dynamic>) {
      try {
        return json.map(
          (k, v) => MapEntry(
            k,
            CampaignMissionResult.fromJson(v as Map<String, dynamic>),
          ),
        );
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  // ── Settings helpers ─────────────────────────────────────────────────

  double get turnSensitivity {
    return (settings?['turn_sensitivity'] as num?)?.toDouble() ?? 0.5;
  }

  bool get invertControls {
    return settings?['invert_controls'] as bool? ?? false;
  }

  bool get enableNight {
    return settings?['enable_night'] as bool? ?? true;
  }

  bool get enableClouds {
    return settings?['enable_clouds'] as bool? ?? true;
  }

  double get cloudCoverage {
    return (settings?['cloud_coverage'] as num?)?.toDouble() ?? 0.64;
  }

  double get cloudOpacity {
    return (settings?['cloud_opacity'] as num?)?.toDouble() ?? 0.85;
  }

  String get mapStyle {
    return settings?['map_style'] as String? ?? 'standard';
  }

  bool get englishLabels {
    return settings?['english_labels'] as bool? ?? true;
  }

  String get difficulty {
    return settings?['difficulty'] as String? ?? 'normal';
  }

  bool get soundEnabled {
    return settings?['sound_enabled'] as bool? ?? true;
  }

  double get musicVolume {
    return (settings?['music_volume'] as num?)?.toDouble() ?? 1.0;
  }

  double get effectsVolume {
    return (settings?['effects_volume'] as num?)?.toDouble() ?? 1.0;
  }

  bool get notificationsEnabled {
    return settings?['notifications_enabled'] as bool? ?? true;
  }

  bool get hapticEnabled {
    return settings?['haptic_enabled'] as bool? ?? true;
  }
}
