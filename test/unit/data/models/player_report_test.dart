import 'package:flit/data/models/player_report.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullReportJson() => {
  'id': 42,
  'reporter_id': 'reporter-uuid-001',
  'reported_id': 'reported-uuid-002',
  'reason': 'cheating',
  'details': 'Used an aimbot on round 5.',
  'status': 'pending',
  'reviewed_by': null,
  'reviewed_at': null,
  'action_taken': null,
  'created_at': '2026-02-01T10:00:00.000Z',
  'reported_username': 'cheater99',
  'reporter_username': 'pilot_ace',
};

Map<String, dynamic> _minimalReportJson() => {
  'id': 1,
  'reporter_id': 'r1',
  'reported_id': 'r2',
  'reason': 'other',
};

Map<String, dynamic> _reviewedReportJson() => {
  'id': 99,
  'reporter_id': 'r-alpha',
  'reported_id': 'r-beta',
  'reason': 'harassment',
  'details': 'Sent offensive messages.',
  'status': 'actioned',
  'reviewed_by': 'mod-uuid-007',
  'reviewed_at': '2026-02-15T08:30:00.000Z',
  'action_taken': 'Temp ban applied for 7 days.',
  'created_at': '2026-02-14T12:00:00.000Z',
  'reported_username': null,
  'reporter_username': null,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // PlayerReport.fromJson — field mapping
  // -------------------------------------------------------------------------

  group('PlayerReport.fromJson - full payload', () {
    late PlayerReport report;

    setUp(() {
      report = PlayerReport.fromJson(_fullReportJson());
    });

    test('id is parsed correctly', () {
      expect(report.id, equals(42));
    });

    test('reporterId is parsed correctly', () {
      expect(report.reporterId, equals('reporter-uuid-001'));
    });

    test('reportedId is parsed correctly', () {
      expect(report.reportedId, equals('reported-uuid-002'));
    });

    test('reason is parsed correctly', () {
      expect(report.reason, equals('cheating'));
    });

    test('details is parsed correctly when present', () {
      expect(report.details, equals('Used an aimbot on round 5.'));
    });

    test('status is parsed correctly', () {
      expect(report.status, equals('pending'));
    });

    test('reviewedBy is null when absent', () {
      expect(report.reviewedBy, isNull);
    });

    test('reviewedAt is null when absent', () {
      expect(report.reviewedAt, isNull);
    });

    test('actionTaken is null when absent', () {
      expect(report.actionTaken, isNull);
    });

    test('createdAt is parsed as a DateTime', () {
      expect(report.createdAt, isA<DateTime>());
      expect(report.createdAt!.year, equals(2026));
      expect(report.createdAt!.month, equals(2));
      expect(report.createdAt!.day, equals(1));
    });

    test('reportedUsername is parsed correctly', () {
      expect(report.reportedUsername, equals('cheater99'));
    });

    test('reporterUsername is parsed correctly', () {
      expect(report.reporterUsername, equals('pilot_ace'));
    });
  });

  // -------------------------------------------------------------------------
  // PlayerReport.fromJson — nullable / default values
  // -------------------------------------------------------------------------

  group('PlayerReport.fromJson - minimal payload (defaults)', () {
    late PlayerReport report;

    setUp(() {
      report = PlayerReport.fromJson(_minimalReportJson());
    });

    test('status defaults to pending when omitted from JSON', () {
      expect(report.status, equals('pending'));
    });

    test('details is null when omitted', () {
      expect(report.details, isNull);
    });

    test('reviewedBy is null when omitted', () {
      expect(report.reviewedBy, isNull);
    });

    test('reviewedAt is null when omitted', () {
      expect(report.reviewedAt, isNull);
    });

    test('actionTaken is null when omitted', () {
      expect(report.actionTaken, isNull);
    });

    test('createdAt is null when omitted', () {
      expect(report.createdAt, isNull);
    });

    test('reportedUsername is null when omitted', () {
      expect(report.reportedUsername, isNull);
    });

    test('reporterUsername is null when omitted', () {
      expect(report.reporterUsername, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // PlayerReport.fromJson — reviewed / actioned report
  // -------------------------------------------------------------------------

  group('PlayerReport.fromJson - reviewed report payload', () {
    late PlayerReport report;

    setUp(() {
      report = PlayerReport.fromJson(_reviewedReportJson());
    });

    test('status is actioned', () {
      expect(report.status, equals('actioned'));
    });

    test('reviewedBy is parsed correctly', () {
      expect(report.reviewedBy, equals('mod-uuid-007'));
    });

    test('reviewedAt is parsed as a DateTime', () {
      expect(report.reviewedAt, isA<DateTime>());
      expect(report.reviewedAt!.year, equals(2026));
      expect(report.reviewedAt!.month, equals(2));
      expect(report.reviewedAt!.day, equals(15));
    });

    test('actionTaken is parsed correctly', () {
      expect(report.actionTaken, equals('Temp ban applied for 7 days.'));
    });
  });

  // -------------------------------------------------------------------------
  // isPending computed property
  // -------------------------------------------------------------------------

  group('PlayerReport.isPending', () {
    test('isPending is true when status is pending', () {
      final report = PlayerReport.fromJson(_fullReportJson());
      expect(report.isPending, isTrue);
    });

    test('isPending is false when status is actioned', () {
      final report = PlayerReport.fromJson(_reviewedReportJson());
      expect(report.isPending, isFalse);
    });

    test('isPending is false when status is reviewed', () {
      final json = {..._fullReportJson(), 'status': 'reviewed'};
      final report = PlayerReport.fromJson(json);
      expect(report.isPending, isFalse);
    });

    test('isPending is false when status is dismissed', () {
      final json = {..._fullReportJson(), 'status': 'dismissed'};
      final report = PlayerReport.fromJson(json);
      expect(report.isPending, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Status values
  // -------------------------------------------------------------------------

  group('PlayerReport status field values', () {
    for (final status in ['pending', 'reviewed', 'actioned', 'dismissed']) {
      test('status "$status" round-trips through fromJson', () {
        final json = {..._fullReportJson(), 'status': status};
        final report = PlayerReport.fromJson(json);
        expect(report.status, equals(status));
      });
    }
  });

  // -------------------------------------------------------------------------
  // toInsertJson
  // -------------------------------------------------------------------------

  group('PlayerReport.toInsertJson', () {
    test('includes reporterId, reportedId, and reason', () {
      const report = PlayerReport(
        id: 1,
        reporterId: 'r1',
        reportedId: 'r2',
        reason: ReportReason.harassment,
        details: 'Details here.',
      );

      final json = report.toInsertJson();

      expect(json['reporter_id'], equals('r1'));
      expect(json['reported_id'], equals('r2'));
      expect(json['reason'], equals('harassment'));
      expect(json['details'], equals('Details here.'));
    });

    test('omits details key when details is null', () {
      const report = PlayerReport(
        id: 1,
        reporterId: 'r1',
        reportedId: 'r2',
        reason: ReportReason.other,
      );

      final json = report.toInsertJson();

      expect(json.containsKey('details'), isFalse);
    });

    test('does not include id in insert payload', () {
      const report = PlayerReport(
        id: 99,
        reporterId: 'r1',
        reportedId: 'r2',
        reason: ReportReason.cheating,
      );

      final json = report.toInsertJson();
      expect(json.containsKey('id'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // ReportReason constants
  // -------------------------------------------------------------------------

  group('ReportReason constants', () {
    test('offensiveUsername equals the expected string', () {
      expect(ReportReason.offensiveUsername, equals('offensive_username'));
    });

    test('cheating equals the expected string', () {
      expect(ReportReason.cheating, equals('cheating'));
    });

    test('harassment equals the expected string', () {
      expect(ReportReason.harassment, equals('harassment'));
    });

    test('other equals the expected string', () {
      expect(ReportReason.other, equals('other'));
    });

    test('all list contains exactly four reasons', () {
      expect(ReportReason.all, hasLength(4));
    });

    test('all list contains every known reason constant', () {
      expect(
        ReportReason.all,
        containsAll([
          ReportReason.offensiveUsername,
          ReportReason.cheating,
          ReportReason.harassment,
          ReportReason.other,
        ]),
      );
    });
  });

  // -------------------------------------------------------------------------
  // ReportReason.label
  // -------------------------------------------------------------------------

  group('ReportReason.label', () {
    test('offensive_username maps to Offensive Username', () {
      expect(
        ReportReason.label(ReportReason.offensiveUsername),
        equals('Offensive Username'),
      );
    });

    test('cheating maps to Cheating', () {
      expect(ReportReason.label(ReportReason.cheating), equals('Cheating'));
    });

    test('harassment maps to Harassment', () {
      expect(ReportReason.label(ReportReason.harassment), equals('Harassment'));
    });

    test('other maps to Other', () {
      expect(ReportReason.label(ReportReason.other), equals('Other'));
    });

    test('unknown reason is returned as-is', () {
      expect(ReportReason.label('unknown_reason'), equals('unknown_reason'));
    });
  });

  // -------------------------------------------------------------------------
  // Direct construction
  // -------------------------------------------------------------------------

  group('PlayerReport direct construction', () {
    test('const constructor preserves all required fields', () {
      const report = PlayerReport(
        id: 7,
        reporterId: 'uid-a',
        reportedId: 'uid-b',
        reason: ReportReason.cheating,
      );

      expect(report.id, equals(7));
      expect(report.reporterId, equals('uid-a'));
      expect(report.reportedId, equals('uid-b'));
      expect(report.reason, equals('cheating'));
      expect(report.status, equals('pending'));
    });

    test('status defaults to pending when not supplied to constructor', () {
      const report = PlayerReport(
        id: 1,
        reporterId: 'x',
        reportedId: 'y',
        reason: 'other',
      );
      expect(report.status, equals('pending'));
    });
  });
}
