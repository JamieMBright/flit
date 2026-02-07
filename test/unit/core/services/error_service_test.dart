import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/error_service.dart';

void main() {
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
    test('reportError adds error to pending list', () {
      final service = ErrorService.instance;
      expect(service.pendingErrors, isEmpty);

      service.reportError('Test error', StackTrace.current);

      expect(service.pendingErrors, hasLength(1));
      expect(service.pendingErrors.first.error, equals('Test error'));
    });

    test('reportError adds multiple errors in order', () {
      final service = ErrorService.instance;

      service.reportWarning('First', StackTrace.current);
      service.reportError('Second', StackTrace.current);
      service.reportCritical('Third', StackTrace.current);

      expect(service.pendingErrors, hasLength(3));
      expect(service.pendingErrors[0].error, equals('First'));
      expect(service.pendingErrors[1].error, equals('Second'));
      expect(service.pendingErrors[2].error, equals('Third'));
    });

    test('queue respects max size of 100', () {
      final service = ErrorService.instance;

      for (var i = 0; i < 110; i++) {
        service.reportError('Error $i', StackTrace.current);
      }

      expect(service.pendingErrors.length, equals(100));
      expect(service.pendingErrors.first.error, equals('Error 10'));
      expect(service.pendingErrors.last.error, equals('Error 109'));
    });
  });

  group('ErrorService - JSON Serialization', () {
    test('toJson produces valid schema', () {
      final service = ErrorService.instance;
      service.reportError(
        'Serialization test',
        StackTrace.current,
        context: {'screen': 'game'},
      );

      final json = service.pendingErrors.first.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('error'), isTrue);
      expect(json.containsKey('severity'), isTrue);
      expect(json.containsKey('timestamp'), isTrue);
      expect(json.containsKey('sessionId'), isTrue);
      expect(json['error'], equals('Serialization test'));
      expect(json['severity'], equals('error'));
    });

    test('toJson includes stack trace when present', () {
      final service = ErrorService.instance;
      service.reportError('With stack', StackTrace.current);

      final json = service.pendingErrors.first.toJson();
      expect(json.containsKey('stackTrace'), isTrue);
    });

    test('toJson handles null stack trace', () {
      final service = ErrorService.instance;
      service.reportError('No stack', null);

      final json = service.pendingErrors.first.toJson();
      expect(json['error'], equals('No stack'));
    });
  });

  group('ErrorService - Severity Levels', () {
    test('all severity levels are accepted', () {
      final service = ErrorService.instance;

      service.reportWarning('warning', StackTrace.current);
      service.reportError('error', StackTrace.current);
      service.reportCritical('critical', StackTrace.current);

      expect(service.pendingErrors, hasLength(3));
      expect(
          service.pendingErrors[0].severity, equals(ErrorSeverity.warning));
      expect(service.pendingErrors[1].severity, equals(ErrorSeverity.error));
      expect(
          service.pendingErrors[2].severity, equals(ErrorSeverity.critical));
    });

    test('severity levels have correct ordering', () {
      expect(
          ErrorSeverity.warning.index, lessThan(ErrorSeverity.error.index));
      expect(
          ErrorSeverity.error.index, lessThan(ErrorSeverity.critical.index));
    });
  });

  group('ErrorService - Listeners', () {
    test('errorCountNotifier increments when error is reported', () {
      final service = ErrorService.instance;
      expect(service.errorCountNotifier.value, equals(0));

      service.reportError('Listener test', StackTrace.current);

      expect(service.errorCountNotifier.value, equals(1));
    });

    test('multiple reports increment counter', () {
      final service = ErrorService.instance;

      service.reportError('One', StackTrace.current);
      service.reportError('Two', StackTrace.current);

      expect(service.errorCountNotifier.value, equals(2));
    });

    test('addListener is notified with CapturedError', () {
      final service = ErrorService.instance;
      CapturedError? received;

      service.addListener((error) {
        received = error;
      });

      service.reportError('Listener test', StackTrace.current);

      expect(received, isNotNull);
      expect(received!.error, equals('Listener test'));
    });

    test('removed listener is not notified', () {
      final service = ErrorService.instance;
      var notified = false;

      void listener(CapturedError error) {
        notified = true;
      }

      service.addListener(listener);
      service.removeListener(listener);

      service.reportError('Removed listener test', StackTrace.current);

      expect(notified, isFalse);
    });
  });

  group('ErrorService - Display Errors', () {
    test('displayErrors stores errors newest first', () {
      final service = ErrorService.instance;

      service.reportError('First', StackTrace.current);
      service.reportError('Second', StackTrace.current);

      expect(service.displayErrors, hasLength(2));
      expect(service.displayErrors[0].error, equals('Second'));
      expect(service.displayErrors[1].error, equals('First'));
    });
  });

  group('ErrorService - Reset', () {
    test('reset clears errors and counter', () {
      final service = ErrorService.instance;

      service.reportError('Error', StackTrace.current);
      service.reset();

      expect(service.pendingErrors, isEmpty);
      expect(service.displayErrors, isEmpty);
      expect(service.errorCountNotifier.value, equals(0));
    });

    test('new errors can be added after reset', () {
      final service = ErrorService.instance;

      service.reportError('Before', StackTrace.current);
      service.reset();
      service.reportError('After', StackTrace.current);

      expect(service.pendingErrors, hasLength(1));
      expect(service.pendingErrors.first.error, equals('After'));
    });
  });
}
