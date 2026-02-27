import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement.dart';

/// Service for fetching and managing in-app announcements.
class AnnouncementService {
  AnnouncementService._();
  static final instance = AnnouncementService._();

  SupabaseClient get _client => Supabase.instance.client;

  // 2-minute TTL cache.
  static const _ttl = Duration(minutes: 2);
  List<Announcement>? _cache;
  DateTime? _cacheTime;

  /// Fetch active announcements (RLS handles time filtering).
  Future<List<Announcement>> fetchActive() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _ttl) {
      return _cache!;
    }

    try {
      final data = await _client
          .from('announcements')
          .select('*')
          .order('priority', ascending: false)
          .order('created_at', ascending: false)
          .limit(20);
      _cache = (data as List)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
      _cacheTime = DateTime.now();
      return _cache!;
    } catch (_) {
      return _cache ?? [];
    }
  }

  /// Fetch all announcements (admin — active + inactive).
  Future<List<Announcement>> fetchAll({int limit = 50}) async {
    final data = await _client
        .from('announcements')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Whether the user has dismissed a specific announcement locally.
  Future<bool> isDismissed(int announcementId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getStringList('dismissed_announcements') ?? <String>[];
    return dismissed.contains('$announcementId');
  }

  /// Dismiss an announcement locally (doesn't affect server).
  Future<void> dismiss(int announcementId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getStringList('dismissed_announcements') ?? <String>[];
    if (!dismissed.contains('$announcementId')) {
      dismissed.add('$announcementId');
      await prefs.setStringList('dismissed_announcements', dismissed);
    }
  }

  /// Create or update an announcement (admin).
  Future<int> upsert({
    int? id,
    required String title,
    required String body,
    String type = 'info',
    int priority = 0,
    bool isActive = true,
    DateTime? startsAt,
    DateTime? expiresAt,
  }) async {
    final result = await _client.rpc(
      'admin_upsert_announcement',
      params: {
        if (id != null) 'p_id': id,
        'p_title': title,
        'p_body': body,
        'p_type': type,
        'p_priority': priority,
        'p_is_active': isActive,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      },
    );
    invalidateCache();
    return result as int;
  }

  void invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }
}
