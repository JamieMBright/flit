import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/error_service.dart';

void main() {
  // Reset the ErrorService singleton before each test to ensure isolation.
  // ErrorService.instance is a singleton; calling reset() clears its state.
  setUp(() {
    ErrorService.instance.reset();
  });

  group('ErrorService - Singleton', () {
    test('returns the same instance every time', () {
      final a = ErrorService.instance;
      final b = ErrorService.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('ErrorService - Error Queuing', () {
    test('enqueue adds error to pending list', () {
      final service = ErrorService.instance;
      expect(service.pendingErrors, isEmpty);

      service.enqueue(
        message: 'Test error',
        severity: ErrorSeverity.error,
      );

      expect(service.pendingErrors, hasLength(1));
      expect(service.pendingErrors.first.message, equals('Test error'));
    });

    test('enqueue adds multiple errors in order', () {
      final service = ErrorService.instance;

      service.enqueue(message: 'First', severity: ErrorSeverity.warning);
      service.enqueue(message: 'Second', severity: ErrorSeverity.error);
      service.enqueue(message: 'Third', severity: ErrorSeverity.critical);

      expect(service.pendingErrors, hasLength(3));
      expect(service.pendingErrors[0].message, equals('First'));
      expect(service.pendingErrors[1].message, equals('Second'));
      expect(service.pendingErrors[2].message, equals('Third'));
    });

    test('queue respects max size of 100', () {
      final service = ErrorService.instance;

      // Enqueue 110 errors - only the most recent 100 should remain.
      for (var i = 0; i < 110; i++) {
        service.enqueue(
          message: 'Error $i',
          severity: ErrorSeverity.error,
        );
      }

      expect(service.pendingErrors.length, equals(100));
      // The oldest errors (0-9) should have been dropped.
      expect(service.pendingErrors.first.message, equals('Error 10'));
      expect(service.pendingErrors.last.message, equals('Error 109'));
    });
  });

  group('ErrorService - JSON Serialization', () {
    test('toJson produces valid schema', () {
      final service = ErrorService.instance;
      service.enqueue(
        message: 'Serialization test',
        severity: ErrorSeverity.error,
        error: Exception('test exception'),
        stackTrace: StackTrace.current,
      );

      final json = service.pendingErrors.first.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('message'), isTrue);
      expect(json.containsKey('severity'), isTrue);
      expect(json.containsKey('timestamp'), isTrue);
      expect(json.containsKey('sessionId'), isTrue);
      expect(json['message'], equals('Serialization test'));
      expect(json['severity'], equals('error'));
    });

    test('toJson includes error details when present', () {
      final service = ErrorService.instance;
      service.enqueue(
        message: 'With error',
        severity: ErrorSeverity.error,
        error: FormatException('bad format'),
      );

      final json = service.pendingErrors.first.toJson();
      expect(json.containsKey('error'), isTrue);
      expect(json['error'], contains('bad format'));
    });

    test('toJson handles null error and stack trace', () {
      final service = ErrorService.instance;
      service.enqueue(
        message: 'No error object',
        severity: ErrorSeverity.warning,
      );

      final json = service.pendingErrors.first.toJson();
      expect(json['message'], equals('No error object'));
      // error and stackTrace may be null or absent
    });
  });

  group('ErrorService - Severity Levels', () {
    test('all severity levels are accepted', () {
      final service = ErrorService.instance;

      service.enqueue(message: 'info', severity: ErrorSeverity.info);
      service.enqueue(message: 'warning', severity: ErrorSeverity.warning);
      service.enqueue(message: 'error', severity: ErrorSeverity.error);
      service.enqueue(message: 'critical', severity: ErrorSeverity.critical);

      expect(service.pendingErrors, hasLength(4));
      expect(service.pendingErrors[0].severity, equals(ErrorSeverity.info));
      expect(service.pendingErrors[1].severity, equals(ErrorSeverity.warning));
      expect(service.pendingErrors[2].severity, equals(ErrorSeverity.error));
      expect(service.pendingErrors[3].severity, equals(ErrorSeverity.critical));
    });

    test('severity levels have correct ordering', () {
      // info < warning < error < critical
      expect(ErrorSeverity.info.index, lessThan(ErrorSeverity.warning.index));
      expect(
          ErrorSeverity.warning.index, lessThan(ErrorSeverity.error.index));
      expect(
          ErrorSeverity.error.index, lessThan(ErrorSeverity.critical.index));
    });
  });

  group('ErrorService - Session ID', () {
    test('session ID is generated and non-empty', () {
      final service = ErrorService.instance;
      expect(service.sessionId, isNotEmpty);
    });

    test('session ID is consistent across calls', () {
      final service = ErrorService.instance;
      final id1 = service.sessionId;
      final id2 = service.sessionId;
      expect(id1, equals(id2));
    });

    test('session ID is included in queued errors', () {
      final service = ErrorService.instance;
      service.enqueue(
        message: 'Session test',
        severity: ErrorSeverity.error,
      );

      final json = service.pendingErrors.first.toJson();
      expect(json['sessionId'], equals(service.sessionId));
    });
  });

  group('ErrorService - Listeners', () {
    test('listener is notified when error is enqueued', () {
      final service = ErrorService.instance;
      var notified = false;

      service.addListener(() {
        notified = true;
      });

      service.enqueue(
        message: 'Listener test',
        severity: ErrorSeverity.error,
      );

      expect(notified, isTrue);
    });

    test('multiple listeners are all notified', () {
      final service = ErrorService.instance;
      var count = 0;

      service.addListener(() => count++);
      service.addListener(() => count++);

      service.enqueue(
        message: 'Multi listener test',
        severity: ErrorSeverity.error,
      );

      expect(count, equals(2));
    });

    test('removed listener is not notified', () {
      final service = ErrorService.instance;
      var notified = false;

      void listener() {
        notified = true;
      }

      service.addListener(listener);
      service.removeListener(listener);

      service.enqueue(
        message: 'Removed listener test',
        severity: ErrorSeverity.error,
      );

      expect(notified, isFalse);
    });
  });

  group('ErrorService - Clear/Reset', () {
    test('clear removes all pending errors', () {
      final service = ErrorService.instance;

      service.enqueue(message: 'Error 1', severity: ErrorSeverity.error);
      service.enqueue(message: 'Error 2', severity: ErrorSeverity.error);
      expect(service.pendingErrors, hasLength(2));

      service.clear();
      expect(service.pendingErrors, isEmpty);
    });

    test('reset clears errors and preserves session ID', () {
      final service = ErrorService.instance;
      final sessionId = service.sessionId;

      service.enqueue(message: 'Error', severity: ErrorSeverity.error);
      service.reset();

      expect(service.pendingErrors, isEmpty);
      // Session ID should remain the same within the same app lifecycle.
      expect(service.sessionId, equals(sessionId));
    });

    test('new errors can be added after clear', () {
      final service = ErrorService.instance;

      service.enqueue(message: 'Before', severity: ErrorSeverity.error);
      service.clear();
      service.enqueue(message: 'After', severity: ErrorSeverity.error);

      expect(service.pendingErrors, hasLength(1));
      expect(service.pendingErrors.first.message, equals('After'));
    });
  });
}
