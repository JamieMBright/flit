import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/avatar_config.dart';
import '../models/pilot_license.dart';
import '../models/player.dart';

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
/// - **Guest-safe** — all writes are no-ops for guest users (id == 'guest').
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

  // Cached write payloads — populated by markDirty calls, flushed by _flush.
  Map<String, dynamic>? _pendingProfile;
  Map<String, dynamic>? _pendingSettings;
  Map<String, dynamic>? _pendingAccountState;

  /// Whether the current session is a guest (no Supabase writes).
  bool get _isGuest => _userId == null || _userId == 'guest';

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Load all user state from Supabase in parallel.
  ///
  /// Returns a [UserPreferencesSnapshot] containing the full state, or null if
  /// the user has no saved data yet (first login).
  Future<UserPreferencesSnapshot?> load(String userId) async {
    _userId = userId;
    if (_isGuest) return null;

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
    if (_isGuest) return;
    _profileDirty = true;
    _pendingProfile = {
      'id': _userId,
      'level': player.level,
      'xp': player.xp,
      'coins': player.coins,
      'games_played': player.gamesPlayed,
      'best_score': player.bestScore,
      'best_time_ms': player.bestTime?.inMilliseconds,
      'total_flight_time_ms': player.totalFlightTime.inMilliseconds,
      'countries_found': player.countriesFound,
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
  }) {
    if (_isGuest) return;
    _settingsDirty = true;
    _pendingSettings = {
      'user_id': _userId,
      'turn_sensitivity': turnSensitivity,
      'invert_controls': invertControls,
      'enable_night': enableNight,
      'map_style': mapStyle,
      'english_labels': englishLabels,
      'difficulty': difficulty,
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
    String? lastFreeRerollDate,
    String? lastDailyChallengeDate,
  }) {
    if (_isGuest) return;
    _accountStateDirty = true;
    _pendingAccountState = {
      'user_id': _userId,
      'avatar_config': avatar.toJson(),
      'license_data': license.toJson(),
      'unlocked_regions': unlockedRegions.toList(),
      'owned_avatar_parts': ownedAvatarParts.toList(),
      'equipped_plane_id': equippedPlaneId,
      'equipped_contrail_id': equippedContrailId,
      'last_free_reroll_date': lastFreeRerollDate,
      'last_daily_challenge_date': lastDailyChallengeDate,
    };
    _scheduleSave();
  }

  /// Insert a game result into the scores table.
  Future<void> saveGameResult({
    required int score,
    required int timeMs,
    required String region,
    required int roundsCompleted,
  }) async {
    if (_isGuest) return;
    try {
      await _client.from('scores').insert({
        'user_id': _userId,
        'score': score,
        'time_ms': timeMs,
        'region': region,
        'rounds_completed': roundsCompleted,
      });
    } catch (e) {
      debugPrint('[UserPreferencesService] saveGameResult failed: $e');
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
    if (_isGuest) return;

    final futures = <Future<void>>[];

    if (_profileDirty && _pendingProfile != null) {
      futures.add(
        _client
            .from('profiles')
            .update(_pendingProfile!)
            .eq('id', _userId!)
            .then((_) {
              _profileDirty = false;
              _pendingProfile = null;
            }),
      );
    }

    if (_settingsDirty && _pendingSettings != null) {
      futures.add(
        _client.from('user_settings').upsert(_pendingSettings!).then((_) {
          _settingsDirty = false;
          _pendingSettings = null;
        }),
      );
    }

    if (_accountStateDirty && _pendingAccountState != null) {
      futures.add(
        _client.from('account_state').upsert(_pendingAccountState!).then((_) {
          _accountStateDirty = false;
          _pendingAccountState = null;
        }),
      );
    }

    if (futures.isNotEmpty) {
      try {
        await Future.wait(futures);
      } catch (e) {
        debugPrint('[UserPreferencesService] flush failed: $e');
      }
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
    if (data == null) return PilotLicense.random();
    final json = data['license_data'];
    if (json is Map<String, dynamic> && json.isNotEmpty) {
      try {
        return PilotLicense.fromJson(json);
      } catch (_) {
        return PilotLicense.random();
      }
    }
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

  String? get lastFreeRerollDate {
    final data = accountState;
    return data?['last_free_reroll_date'] as String?;
  }

  String? get lastDailyChallengeDate {
    final data = accountState;
    return data?['last_daily_challenge_date'] as String?;
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
}
