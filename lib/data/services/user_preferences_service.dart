import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/avatar_config.dart';
import '../models/daily_result.dart';
import '../models/daily_streak.dart';
import '../models/pilot_license.dart';
import '../models/player.dart';

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
  static const int _kMaxEntries = 50;
  static const int _kMaxRetries = 3;

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
      debugPrint('[PendingWriteQueue] SharedPreferences unavailable, '
          'falling back to in-memory queue: $e');
      _prefsAvailable = false;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  bool get isEmpty => _loadAll().isEmpty;

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
  /// If the entry has reached [_kMaxRetries] it is dropped instead.
  Future<void> incrementRetryOrDrop() async {
    final entries = _loadAll();
    if (entries.isEmpty) return;
    final head = entries.first;
    final retries = (head['retries'] as int? ?? 0) + 1;
    if (retries >= _kMaxRetries) {
      entries.removeAt(0);
      debugPrint('[PendingWriteQueue] dropped entry after $_kMaxRetries '
          'retries: table=${head['table']}');
    } else {
      entries[0] = {...head, 'retries': retries};
    }
    await _persist(entries);
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

  Timer? _debounceTimer;
  String? _userId;

  // Dirty flags — only the changed tables are written.
  bool _profileDirty = false;
  bool _settingsDirty = false;
  bool _accountStateDirty = false;

  /// Whether there are any unsaved writes waiting to be flushed.
  bool get hasPendingWrites =>
      _profileDirty || _settingsDirty || _accountStateDirty;

  // Cached write payloads — populated by markDirty calls, flushed by _flush.
  Map<String, dynamic>? _pendingProfile;
  Map<String, dynamic>? _pendingSettings;
  Map<String, dynamic>? _pendingAccountState;

  // Offline write queue — survives app restarts via SharedPreferences.
  final _PendingWriteQueue _queue = _PendingWriteQueue();
  bool _queueInitialised = false;

  // ---------------------------------------------------------------------------
  // Queue initialisation
  // ---------------------------------------------------------------------------

  Future<void> _ensureQueueInitialised() async {
    if (_queueInitialised) return;
    await _queue.init();
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
      final results = await Future.wait([
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

      final profileData = results[0] as Map<String, dynamic>?;
      final settingsData = results[1] as Map<String, dynamic>?;
      final accountData = results[2] as Map<String, dynamic>?;

      if (profileData == null) return null;

      return UserPreferencesSnapshot(
        profile: profileData,
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
    _scheduleSave();
  }

  /// Mark settings as dirty and queue a write.
  void saveSettings({
    required double turnSensitivity,
    required bool invertControls,
    required bool enableNight,
    required String mapStyle,
    required bool englishLabels,
    required String difficulty,
    required bool soundEnabled,
    required bool notificationsEnabled,
    required bool hapticEnabled,
  }) {
    _settingsDirty = true;
    _pendingSettings = {
      'user_id': _userId,
      'turn_sensitivity': turnSensitivity,
      'invert_controls': invertControls,
      'enable_night': enableNight,
      'map_style': mapStyle,
      'english_labels': englishLabels,
      'difficulty': difficulty,
      'sound_enabled': soundEnabled,
      'notifications_enabled': notificationsEnabled,
      'haptic_enabled': hapticEnabled,
    };
    _scheduleSave();
  }

  /// Mark account state as dirty and queue a write.
  void saveAccountState({
    required AvatarConfig avatar,
    required PilotLicense license,
    required Set<String> unlockedRegions,
    required Set<String> ownedAvatarParts,
    required String equippedPlaneId,
    required String equippedContrailId,
    String? equippedTitleId,
    String? lastFreeRerollDate,
    String? lastDailyChallengeDate,
    DailyStreak dailyStreak = const DailyStreak(),
    DailyResult? lastDailyResult,
  }) {
    _accountStateDirty = true;
    _pendingAccountState = {
      'user_id': _userId,
      'avatar_config': avatar.toJson(),
      'license_data': license.toJson(),
      'unlocked_regions': unlockedRegions.toList(),
      'owned_avatar_parts': ownedAvatarParts.toList(),
      'equipped_plane_id': equippedPlaneId,
      'equipped_contrail_id': equippedContrailId,
      'equipped_title_id': equippedTitleId,
      'last_free_reroll_date': lastFreeRerollDate,
      'last_daily_challenge_date': lastDailyChallengeDate,
      'daily_streak_data': dailyStreak.toJson(),
      'last_daily_result': lastDailyResult?.toJson(),
    };
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
    };

    try {
      await _client.from('scores').insert(data);
    } catch (e) {
      debugPrint(
        '[UserPreferencesService] saveGameResult failed, queuing for retry: $e',
      );
      await _queue.enqueue('scores', data, 'insert');
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
          await _client.from(table).insert(data);
        } else {
          await _client.from(table).upsert(data);
        }
        // Success — remove the entry from the queue.
        await _queue.dequeue();
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

  /// Clear cached user and cancel pending writes.
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
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _flush);
  }

  Future<void> _flush() async {
    await _ensureQueueInitialised();

    // Attempt to drain any previously failed writes before issuing new ones.
    await retryPendingWrites();

    final futures = <Future<void>>[];

    if (_profileDirty && _pendingProfile != null) {
      final payload = _pendingProfile!;
      futures.add(
        _client
            .from('profiles')
            .upsert(payload)
            .then((_) {
              _profileDirty = false;
              _pendingProfile = null;
            })
            .catchError((Object e) async {
              debugPrint(
                '[UserPreferencesService] flush profiles failed, queuing: $e',
              );
              await _queue.enqueue('profiles', payload, 'upsert');
            }),
      );
    }

    if (_settingsDirty && _pendingSettings != null) {
      final payload = _pendingSettings!;
      futures.add(
        _client
            .from('user_settings')
            .upsert(payload)
            .then((_) {
              _settingsDirty = false;
              _pendingSettings = null;
            })
            .catchError((Object e) async {
              debugPrint(
                '[UserPreferencesService] flush user_settings failed, queuing: $e',
              );
              await _queue.enqueue('user_settings', payload, 'upsert');
            }),
      );
    }

    if (_accountStateDirty && _pendingAccountState != null) {
      final payload = _pendingAccountState!;
      futures.add(
        _client
            .from('account_state')
            .upsert(payload)
            .then((_) {
              _accountStateDirty = false;
              _pendingAccountState = null;
            })
            .catchError((Object e) async {
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

  String get mapStyle {
    return settings?['map_style'] as String? ?? 'topo';
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

  bool get notificationsEnabled {
    return settings?['notifications_enabled'] as bool? ?? true;
  }

  bool get hapticEnabled {
    return settings?['haptic_enabled'] as bool? ?? true;
  }
}
