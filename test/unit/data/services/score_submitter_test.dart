import 'package:flit/data/services/score_submitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tests for ScoreSubmitter (WAVE 3, finding #2): the transition-safe routing
/// primitives that let the client PREFER the server-authoritative `submit_score`
/// RPC while falling back to the legacy direct INSERT when the RPC has not been
/// migrated yet.
void main() {
  group('isMissingRpc', () {
    test('true for Postgres undefined-function code 42883', () {
      const e =
          PostgrestException(message: 'undefined function', code: '42883');
      expect(ScoreSubmitter.isMissingRpc(e), isTrue);
    });

    test('true for PostgREST function-not-found code PGRST202', () {
      const e = PostgrestException(
        message: 'Could not find the function',
        code: 'PGRST202',
      );
      expect(ScoreSubmitter.isMissingRpc(e), isTrue);
    });

    test('false for an unrelated Postgres error (e.g. RLS violation 42501)',
        () {
      const e = PostgrestException(message: 'permission denied', code: '42501');
      expect(ScoreSubmitter.isMissingRpc(e), isFalse);
    });

    test('true for a bare message mentioning a missing function', () {
      expect(
        ScoreSubmitter.isMissingRpc(
          Exception('function public.submit_score does not exist'),
        ),
        isTrue,
      );
    });

    test('false for a generic network error', () {
      expect(
        ScoreSubmitter.isMissingRpc(Exception('SocketException: timed out')),
        isFalse,
      );
    });
  });

  group('rpcParamsFor', () {
    test('maps required score columns to p_ params and drops user_id', () {
      final params = ScoreSubmitter.rpcParamsFor({
        'user_id': 'should-be-ignored',
        'score': 4200,
        'time_ms': 65000,
        'region': 'world',
        'rounds_completed': 7,
      });

      expect(params.containsKey('user_id'), isFalse);
      expect(params['p_score'], 4200);
      expect(params['p_time_ms'], 65000);
      expect(params['p_region'], 'world');
      expect(params['p_rounds_completed'], 7);
      // Optional fields omitted when absent.
      expect(params.containsKey('p_round_emojis'), isFalse);
      expect(params.containsKey('p_round_details'), isFalse);
    });

    test('defaults rounds_completed to 0 when missing', () {
      final params = ScoreSubmitter.rpcParamsFor({
        'score': 10,
        'time_ms': 1000,
        'region': 'briefing',
      });
      expect(params['p_rounds_completed'], 0);
    });

    test('forwards optional round_emojis and round_details when present', () {
      final details = [
        {'country': 'fr', 'correct': true},
      ];
      final params = ScoreSubmitter.rpcParamsFor({
        'score': 10,
        'time_ms': 1000,
        'region': 'world',
        'rounds_completed': 1,
        'round_emojis': '🟩',
        'round_details': details,
      });
      expect(params['p_round_emojis'], '🟩');
      expect(params['p_round_details'], details);
    });
  });
}
