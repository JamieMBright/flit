import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player_report.dart';

/// Service for player reports (submit + admin review).
class ReportService {
  ReportService._();
  static final instance = ReportService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Submit a report against another player.
  Future<void> submitReport({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final report = PlayerReport(
      id: 0,
      reporterId: currentUserId,
      reportedId: reportedUserId,
      reason: reason,
      details: details,
    );
    await _client.from('player_reports').insert(report.toInsertJson());
  }

  /// Fetch pending reports (admin only — RLS-gated).
  Future<List<PlayerReport>> fetchPendingReports({int limit = 50}) async {
    final data = await _client
        .from('player_reports')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(limit);
    final reports = (data as List)
        .map((e) => PlayerReport.fromJson(e as Map<String, dynamic>))
        .toList();

    // Batch-fetch usernames for reporter + reported
    final userIds = <String>{};
    for (final r in reports) {
      userIds.add(r.reporterId);
      userIds.add(r.reportedId);
    }
    if (userIds.isEmpty) return reports;

    final profiles = await _client
        .from('profiles')
        .select('id, username')
        .inFilter('id', userIds.toList());

    final nameMap = <String, String>{};
    for (final p in profiles) {
      nameMap[p['id'] as String] = p['username'] as String? ?? '—';
    }

    return reports.map((r) {
      return PlayerReport(
        id: r.id,
        reporterId: r.reporterId,
        reportedId: r.reportedId,
        reason: r.reason,
        details: r.details,
        status: r.status,
        reviewedBy: r.reviewedBy,
        reviewedAt: r.reviewedAt,
        actionTaken: r.actionTaken,
        createdAt: r.createdAt,
        reporterUsername: nameMap[r.reporterId],
        reportedUsername: nameMap[r.reportedId],
      );
    }).toList();
  }

  /// Fetch all reports (admin — any status).
  Future<List<PlayerReport>> fetchAllReports({int limit = 100}) async {
    final data = await _client
        .from('player_reports')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => PlayerReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Count pending reports (for badge display).
  Future<int> countPending() async {
    final result = await _client
        .from('player_reports')
        .select('id')
        .eq('status', 'pending')
        .count(CountOption.exact);
    return result.count;
  }

  /// Resolve a report (admin action).
  Future<void> resolveReport({
    required int reportId,
    required String status,
    required String actionTaken,
  }) async {
    await _client.rpc(
      'admin_resolve_report',
      params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_action_taken': actionTaken,
      },
    );
  }
}
