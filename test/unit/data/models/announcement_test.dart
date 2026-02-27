import 'package:flit/data/models/announcement.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullAnnouncementJson() => {
  'id': 1,
  'title': 'Scheduled Maintenance',
  'body': 'The servers will be offline tonight from 2–4 AM UTC.',
  'type': 'maintenance',
  'priority': 10,
  'is_active': true,
  'starts_at': '2026-03-01T02:00:00.000Z',
  'expires_at': '2026-03-01T04:00:00.000Z',
  'created_by': 'owner-uuid-001',
  'created_at': '2026-02-28T18:00:00.000Z',
};

Map<String, dynamic> _minimalAnnouncementJson() => {
  'id': 2,
  'title': 'Hello World',
  'body': 'Welcome to Flit!',
};

Map<String, dynamic> _infoAnnouncementJson() => {
  'id': 3,
  'title': 'New Region Unlocked',
  'body': 'South-East Asia clue pack is now live.',
  'type': 'info',
  'priority': 0,
  'is_active': true,
  'starts_at': null,
  'expires_at': null,
  'created_by': 'owner-uuid-001',
  'created_at': '2026-02-20T09:00:00.000Z',
};

Map<String, dynamic> _warningAnnouncementJson() => {
  'id': 4,
  'title': 'Known Issue',
  'body': 'Leaderboard updates may be delayed.',
  'type': 'warning',
  'priority': 5,
  'is_active': false,
  'starts_at': '2026-02-25T00:00:00.000Z',
  'expires_at': '2026-02-27T00:00:00.000Z',
  'created_by': null,
  'created_at': '2026-02-24T22:00:00.000Z',
};

Map<String, dynamic> _eventAnnouncementJson() => {
  'id': 5,
  'title': 'Double XP Weekend',
  'body': 'Earn 2x XP this weekend only!',
  'type': 'event',
  'priority': 8,
  'is_active': true,
  'starts_at': '2026-03-07T00:00:00.000Z',
  'expires_at': '2026-03-09T23:59:59.000Z',
  'created_by': 'owner-uuid-001',
  'created_at': '2026-03-01T00:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Announcement.fromJson — full payload
  // -------------------------------------------------------------------------

  group('Announcement.fromJson - full maintenance payload', () {
    late Announcement ann;

    setUp(() {
      ann = Announcement.fromJson(_fullAnnouncementJson());
    });

    test('id is parsed correctly', () {
      expect(ann.id, equals(1));
    });

    test('title is parsed correctly', () {
      expect(ann.title, equals('Scheduled Maintenance'));
    });

    test('body is parsed correctly', () {
      expect(
        ann.body,
        equals('The servers will be offline tonight from 2–4 AM UTC.'),
      );
    });

    test('type is maintenance', () {
      expect(ann.type, equals('maintenance'));
    });

    test('priority is parsed correctly', () {
      expect(ann.priority, equals(10));
    });

    test('isActive is true', () {
      expect(ann.isActive, isTrue);
    });

    test('startsAt is parsed as a DateTime', () {
      expect(ann.startsAt, isA<DateTime>());
      expect(ann.startsAt!.year, equals(2026));
      expect(ann.startsAt!.month, equals(3));
      expect(ann.startsAt!.day, equals(1));
    });

    test('expiresAt is parsed as a DateTime', () {
      expect(ann.expiresAt, isA<DateTime>());
      expect(ann.expiresAt!.year, equals(2026));
      expect(ann.expiresAt!.month, equals(3));
      expect(ann.expiresAt!.day, equals(1));
    });

    test('createdBy is parsed correctly', () {
      expect(ann.createdBy, equals('owner-uuid-001'));
    });

    test('createdAt is parsed as a DateTime', () {
      expect(ann.createdAt, isA<DateTime>());
      expect(ann.createdAt!.year, equals(2026));
      expect(ann.createdAt!.month, equals(2));
      expect(ann.createdAt!.day, equals(28));
    });
  });

  // -------------------------------------------------------------------------
  // Announcement.fromJson — minimal / default values
  // -------------------------------------------------------------------------

  group('Announcement.fromJson - minimal payload (defaults)', () {
    late Announcement ann;

    setUp(() {
      ann = Announcement.fromJson(_minimalAnnouncementJson());
    });

    test('type defaults to info when omitted', () {
      expect(ann.type, equals('info'));
    });

    test('priority defaults to 0 when omitted', () {
      expect(ann.priority, equals(0));
    });

    test('isActive defaults to true when omitted', () {
      expect(ann.isActive, isTrue);
    });

    test('startsAt is null when omitted', () {
      expect(ann.startsAt, isNull);
    });

    test('expiresAt is null when omitted', () {
      expect(ann.expiresAt, isNull);
    });

    test('createdBy is null when omitted', () {
      expect(ann.createdBy, isNull);
    });

    test('createdAt is null when omitted', () {
      expect(ann.createdAt, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Announcement types
  // -------------------------------------------------------------------------

  group('Announcement type - info', () {
    late Announcement ann;
    setUp(() => ann = Announcement.fromJson(_infoAnnouncementJson()));

    test('type is info', () => expect(ann.type, equals('info')));
    test('priority is 0', () => expect(ann.priority, equals(0)));
    test('isActive is true', () => expect(ann.isActive, isTrue));
    test('startsAt is null', () => expect(ann.startsAt, isNull));
    test('expiresAt is null', () => expect(ann.expiresAt, isNull));
  });

  group('Announcement type - warning', () {
    late Announcement ann;
    setUp(() => ann = Announcement.fromJson(_warningAnnouncementJson()));

    test('type is warning', () => expect(ann.type, equals('warning')));
    test('isActive is false', () => expect(ann.isActive, isFalse));
    test('priority is 5', () => expect(ann.priority, equals(5)));
    test('createdBy is null when not provided', () {
      expect(ann.createdBy, isNull);
    });
    test('startsAt is parsed correctly', () {
      expect(ann.startsAt, isA<DateTime>());
      expect(ann.startsAt!.year, equals(2026));
      expect(ann.startsAt!.month, equals(2));
      expect(ann.startsAt!.day, equals(25));
    });
    test('expiresAt is parsed correctly', () {
      expect(ann.expiresAt, isA<DateTime>());
      expect(ann.expiresAt!.year, equals(2026));
      expect(ann.expiresAt!.month, equals(2));
      expect(ann.expiresAt!.day, equals(27));
    });
  });

  group('Announcement type - event', () {
    late Announcement ann;
    setUp(() => ann = Announcement.fromJson(_eventAnnouncementJson()));

    test('type is event', () => expect(ann.type, equals('event')));
    test('priority is 8', () => expect(ann.priority, equals(8)));
    test('isActive is true', () => expect(ann.isActive, isTrue));
    test('startsAt is parsed', () => expect(ann.startsAt, isNotNull));
    test('expiresAt is parsed', () => expect(ann.expiresAt, isNotNull));
  });

  group('Announcement type - maintenance', () {
    late Announcement ann;
    setUp(() => ann = Announcement.fromJson(_fullAnnouncementJson()));

    test('type is maintenance', () => expect(ann.type, equals('maintenance')));
    test('priority is 10', () => expect(ann.priority, equals(10)));
  });

  // -------------------------------------------------------------------------
  // Priority ordering
  // -------------------------------------------------------------------------

  group('Announcement priority ordering', () {
    test('higher priority value is numerically greater', () {
      final low = Announcement.fromJson({
        ..._infoAnnouncementJson(),
        'priority': 1,
      });
      final high = Announcement.fromJson({
        ..._fullAnnouncementJson(),
        'priority': 10,
      });

      expect(high.priority, greaterThan(low.priority));
    });

    test('announcements can be sorted descending by priority', () {
      final announcements = [
        Announcement.fromJson({..._infoAnnouncementJson(), 'priority': 1}),
        Announcement.fromJson({..._fullAnnouncementJson(), 'priority': 10}),
        Announcement.fromJson({..._warningAnnouncementJson(), 'priority': 5}),
      ]..sort((a, b) => b.priority.compareTo(a.priority));

      expect(announcements.map((a) => a.priority).toList(), [10, 5, 1]);
    });

    test('two announcements with equal priority compare as zero', () {
      final a = Announcement.fromJson({
        ..._infoAnnouncementJson(),
        'priority': 3,
      });
      final b = Announcement.fromJson({
        ..._warningAnnouncementJson(),
        'priority': 3,
      });
      expect(a.priority.compareTo(b.priority), equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // Date handling
  // -------------------------------------------------------------------------

  group('Announcement date handling', () {
    test('startsAt preserves UTC hour correctly', () {
      final ann = Announcement.fromJson(_fullAnnouncementJson());
      // '2026-03-01T02:00:00.000Z' → hour == 2 in UTC
      expect(ann.startsAt!.toUtc().hour, equals(2));
    });

    test('expiresAt preserves UTC hour correctly', () {
      final ann = Announcement.fromJson(_fullAnnouncementJson());
      // '2026-03-01T04:00:00.000Z' → hour == 4 in UTC
      expect(ann.expiresAt!.toUtc().hour, equals(4));
    });

    test('startsAt is before expiresAt for a valid window', () {
      final ann = Announcement.fromJson(_fullAnnouncementJson());
      expect(ann.startsAt!.isBefore(ann.expiresAt!), isTrue);
    });

    test('null starts_at in JSON yields null startsAt field', () {
      final ann = Announcement.fromJson(_infoAnnouncementJson());
      expect(ann.startsAt, isNull);
    });

    test('null expires_at in JSON yields null expiresAt field', () {
      final ann = Announcement.fromJson(_infoAnnouncementJson());
      expect(ann.expiresAt, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Direct construction defaults
  // -------------------------------------------------------------------------

  group('Announcement direct construction defaults', () {
    test('type defaults to info', () {
      const ann = Announcement(id: 1, title: 'T', body: 'B');
      expect(ann.type, equals('info'));
    });

    test('priority defaults to 0', () {
      const ann = Announcement(id: 1, title: 'T', body: 'B');
      expect(ann.priority, equals(0));
    });

    test('isActive defaults to true', () {
      const ann = Announcement(id: 1, title: 'T', body: 'B');
      expect(ann.isActive, isTrue);
    });

    test('all date fields are null by default', () {
      const ann = Announcement(id: 1, title: 'T', body: 'B');
      expect(ann.startsAt, isNull);
      expect(ann.expiresAt, isNull);
      expect(ann.createdAt, isNull);
    });
  });
}
