import 'package:flit/data/models/clue_report.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullReportJson() => {
      'id': 42,
      'reporter_id': 'reporter-uuid-001',
      'country_code': 'CY-N',
      'country_name': 'Northern Cyprus',
      'issue': 'Flag is incorrect',
      'notes': 'The flag shown is the Republic of Cyprus flag, not the TRNC.',
      'status': 'pending',
      'reviewed_by': null,
      'reviewed_at': null,
      'action_taken': null,
      'created_at': '2026-03-06T10:00:00.000Z',
      'reporter_username': 'pilot_ace',
    };

Map<String, dynamic> _minimalReportJson() => {
      'id': 1,
      'reporter_id': 'r1',
      'country_code': 'FR',
      'country_name': 'France',
      'issue': 'Other',
    };

Map<String, dynamic> _reviewedReportJson() => {
      'id': 99,
      'reporter_id': 'r-alpha',
      'country_code': 'DE',
      'country_name': 'Germany',
      'issue': 'Capital is incorrect',
      'notes': 'Listed as Bonn instead of Berlin.',
      'status': 'actioned',
      'reviewed_by': 'mod-uuid-007',
      'reviewed_at': '2026-03-06T08:30:00.000Z',
      'action_taken': 'Fixed capital to Berlin.',
      'created_at': '2026-03-05T12:00:00.000Z',
      'reporter_username': null,
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ClueReport.fromJson - full payload', () {
    late ClueReport report;

    setUp(() {
      report = ClueReport.fromJson(_fullReportJson());
    });

    test('id is parsed correctly', () {
      expect(report.id, equals(42));
    });

    test('reporterId is parsed correctly', () {
      expect(report.reporterId, equals('reporter-uuid-001'));
    });

    test('countryCode is parsed correctly', () {
      expect(report.countryCode, equals('CY-N'));
    });

    test('countryName is parsed correctly', () {
      expect(report.countryName, equals('Northern Cyprus'));
    });

    test('issue is parsed correctly', () {
      expect(report.issue, equals('Flag is incorrect'));
    });

    test('notes is parsed correctly when present', () {
      expect(
        report.notes,
        equals('The flag shown is the Republic of Cyprus flag, not the TRNC.'),
      );
    });

    test('status is parsed correctly', () {
      expect(report.status, equals('pending'));
    });

    test('createdAt is parsed as a DateTime', () {
      expect(report.createdAt, isA<DateTime>());
      expect(report.createdAt!.year, equals(2026));
      expect(report.createdAt!.month, equals(3));
      expect(report.createdAt!.day, equals(6));
    });

    test('reporterUsername is parsed correctly', () {
      expect(report.reporterUsername, equals('pilot_ace'));
    });
  });

  group('ClueReport.fromJson - minimal payload (defaults)', () {
    late ClueReport report;

    setUp(() {
      report = ClueReport.fromJson(_minimalReportJson());
    });

    test('status defaults to pending when omitted from JSON', () {
      expect(report.status, equals('pending'));
    });

    test('notes is null when omitted', () {
      expect(report.notes, isNull);
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

    test('reporterUsername is null when omitted', () {
      expect(report.reporterUsername, isNull);
    });
  });

  group('ClueReport.fromJson - reviewed report payload', () {
    late ClueReport report;

    setUp(() {
      report = ClueReport.fromJson(_reviewedReportJson());
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
      expect(report.reviewedAt!.month, equals(3));
      expect(report.reviewedAt!.day, equals(6));
    });

    test('actionTaken is parsed correctly', () {
      expect(report.actionTaken, equals('Fixed capital to Berlin.'));
    });
  });

  group('ClueReport.isPending', () {
    test('isPending is true when status is pending', () {
      final report = ClueReport.fromJson(_fullReportJson());
      expect(report.isPending, isTrue);
    });

    test('isPending is false when status is actioned', () {
      final report = ClueReport.fromJson(_reviewedReportJson());
      expect(report.isPending, isFalse);
    });

    test('isPending is false when status is dismissed', () {
      final json = {..._fullReportJson(), 'status': 'dismissed'};
      final report = ClueReport.fromJson(json);
      expect(report.isPending, isFalse);
    });
  });

  group('ClueReport.toInsertJson', () {
    test('includes required fields', () {
      const report = ClueReport(
        id: 1,
        reporterId: 'r1',
        countryCode: 'FR',
        countryName: 'France',
        issue: 'Flag is incorrect',
        notes: 'Wrong colors.',
      );

      final json = report.toInsertJson();

      expect(json['reporter_id'], equals('r1'));
      expect(json['country_code'], equals('FR'));
      expect(json['country_name'], equals('France'));
      expect(json['issue'], equals('Flag is incorrect'));
      expect(json['notes'], equals('Wrong colors.'));
    });

    test('omits notes key when notes is null', () {
      const report = ClueReport(
        id: 1,
        reporterId: 'r1',
        countryCode: 'FR',
        countryName: 'France',
        issue: 'Other',
      );

      final json = report.toInsertJson();

      expect(json.containsKey('notes'), isFalse);
    });

    test('does not include id in insert payload', () {
      const report = ClueReport(
        id: 99,
        reporterId: 'r1',
        countryCode: 'FR',
        countryName: 'France',
        issue: 'Other',
      );

      final json = report.toInsertJson();
      expect(json.containsKey('id'), isFalse);
    });
  });

  group('ClueIssueType constants', () {
    test('all list contains exactly six issue types', () {
      expect(ClueIssueType.all, hasLength(6));
    });

    test('all list contains every known issue constant', () {
      expect(
        ClueIssueType.all,
        containsAll([
          ClueIssueType.flagIncorrect,
          ClueIssueType.outlineWrong,
          ClueIssueType.capitalIncorrect,
          ClueIssueType.borderCountriesWrong,
          ClueIssueType.statsInaccurate,
          ClueIssueType.other,
        ]),
      );
    });
  });

  group('ClueReport direct construction', () {
    test('const constructor preserves all required fields', () {
      const report = ClueReport(
        id: 7,
        reporterId: 'uid-a',
        countryCode: 'GB',
        countryName: 'United Kingdom',
        issue: ClueIssueType.outlineWrong,
      );

      expect(report.id, equals(7));
      expect(report.reporterId, equals('uid-a'));
      expect(report.countryCode, equals('GB'));
      expect(report.countryName, equals('United Kingdom'));
      expect(report.issue, equals('Outline is wrong'));
      expect(report.status, equals('pending'));
    });

    test('status defaults to pending when not supplied', () {
      const report = ClueReport(
        id: 1,
        reporterId: 'x',
        countryCode: 'US',
        countryName: 'United States',
        issue: 'Other',
      );
      expect(report.status, equals('pending'));
    });
  });
}
