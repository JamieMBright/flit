import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/session/game_session.dart';

// Local great-circle distance (degrees) so the test is self-contained.
double _gcDistDeg(Vector2 a, Vector2 b) {
  const d = pi / 180.0;
  final lat1 = a.y * d, lat2 = b.y * d;
  final dLat = (b.y - a.y) * d;
  final dLng = (b.x - a.x) * d;
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * atan2(sqrt(h), sqrt(1 - h)) * 180.0 / pi;
}

void main() {
  group('GameSession.seeded — reachable scramble start', () {
    const maxDeg = GameSession.kScrambleStartMaxDistanceDeg;

    test('start is always within the reachable radius of the target', () {
      for (var seed = 0; seed < 300; seed++) {
        final s = GameSession.seeded(seed, maxStartDistanceDeg: maxDeg);
        final dist = _gcDistDeg(s.startPosition, s.targetPosition);
        expect(dist, lessThanOrEqualTo(maxDeg + 0.05),
            reason: 'seed $seed: start ${dist.toStringAsFixed(2)}° from target '
                '(${s.targetCountry.code}) exceeds ${maxDeg}°');
      }
    });

    test('same seed yields an identical start (fair & deterministic)', () {
      for (var seed = 0; seed < 50; seed++) {
        final a = GameSession.seeded(seed, maxStartDistanceDeg: maxDeg);
        final b = GameSession.seeded(seed, maxStartDistanceDeg: maxDeg);
        expect(a.startPosition.x, equals(b.startPosition.x));
        expect(a.startPosition.y, equals(b.startPosition.y));
        expect(a.targetCountry.code, equals(b.targetCountry.code));
      }
    });

    test('reachable start does not change which country is selected', () {
      // The constraint only affects the start position (computed after the
      // country pick), so the seeded country must be unchanged — this keeps
      // DailyChallenge._computeDifficultyPercent's mirror valid.
      for (var seed = 0; seed < 100; seed++) {
        final constrained =
            GameSession.seeded(seed, maxStartDistanceDeg: maxDeg);
        final plain = GameSession.seeded(seed);
        expect(constrained.targetCountry.code, equals(plain.targetCountry.code),
            reason: 'country selection diverged at seed $seed');
      }
    });

    test('unconstrained seeded sessions still span the globe', () {
      var minLng = 999.0, maxLng = -999.0;
      for (var seed = 0; seed < 300; seed++) {
        final s = GameSession.seeded(seed);
        minLng = min(minLng, s.startPosition.x);
        maxLng = max(maxLng, s.startPosition.x);
      }
      expect(maxLng - minLng, greaterThan(180),
          reason: 'global spread retained when no constraint is passed');
    });
  });
}
