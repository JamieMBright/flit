import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clue_report.dart';

/// Service for clue reports (submit + admin review).
class ClueReportService {
  ClueReportService._();
  static final instance = ClueReportService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Submit a clue report.
  Future<void> submitReport({
    required String countryCode,
    required String countryName,
    required String issue,
    String? notes,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final report = ClueReport(
      id: 0,
      reporterId: currentUserId,
      countryCode: countryCode,
      countryName: countryName,
      issue: issue,
      notes: notes,
    );
    await _client.from('clue_reports').insert(report.toInsertJson());
  }

  /// Fetch pending clue reports (admin only — RLS-gated).
  Future<List<ClueReport>> fetchPendingReports({int limit = 50}) async {
    final data = await _client
        .from('clue_reports')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(limit);
    final reports = (data as List)
        .map((e) => ClueReport.fromJson(e as Map<String, dynamic>))
        .toList();

    return _enrichWithUsernames(reports);
  }

  /// Fetch all clue reports (admin — any status).
  Future<List<ClueReport>> fetchAllReports({int limit = 100}) async {
    final data = await _client
        .from('clue_reports')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => ClueReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Count pending clue reports (for badge display).
  Future<int> countPending() async {
    final result = await _client
        .from('clue_reports')
        .select('id')
        .eq('status', 'pending')
        .count(CountOption.exact);
    return result.count;
  }

  /// Resolve a clue report (admin action).
  Future<void> resolveReport({
    required int reportId,
    required String status,
    required String actionTaken,
  }) async {
    await _client.rpc(
      'admin_resolve_clue_report',
      params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_action_taken': actionTaken,
      },
    );
  }

  Future<List<ClueReport>> _enrichWithUsernames(
    List<ClueReport> reports,
  ) async {
    final userIds = <String>{};
    for (final r in reports) {
      userIds.add(r.reporterId);
    }
    if (userIds.isEmpty) return reports;

    final profiles = await _client
        .from('profiles')
        .select('id, username')
        .inFilter('id', userIds.toList());

    final nameMap = <String, String>{};
    for (final p in profiles) {
      nameMap[p['id'] as String] = p['username'] as String? ?? '\u2014';
    }

    return reports.map((r) {
      return ClueReport(
        id: r.id,
        reporterId: r.reporterId,
        countryCode: r.countryCode,
        countryName: r.countryName,
        issue: r.issue,
        notes: r.notes,
        status: r.status,
        reviewedBy: r.reviewedBy,
        reviewedAt: r.reviewedAt,
        actionTaken: r.actionTaken,
        createdAt: r.createdAt,
        reporterUsername: nameMap[r.reporterId],
      );
    }).toList();
  }
}
