import 'package:flit/features/leaderboard/combined_daily_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tracked (non-golden) widget test for the combined daily share card.
///
/// Lives under test/unit so it RUNS in CI (test/golden is gitignored). It
/// pins the two things most likely to regress silently: whether the detail
/// block appears, and the numeric formatting/threshold helpers.
void main() {
  const emojiStrong = '\u{1F7E2}'; // 🟢
  const emojiSolid = '\u{1F7E1}'; // 🟡
  const emojiFair = '\u{1F7E0}'; // 🟠
  const emojiLow = '\u{1F534}'; // 🔴
  const emojiUnplayed = '\u{26AA}'; // ⚪

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  group('detail block visibility', () {
    const modeBps = {
      'daily': 9000,
      'briefing': 7000,
      'daily_triangulation': 5000,
    };

    testWidgets('detailed:false hides the RANK/FIELD/DAY/PLAYED block',
        (tester) async {
      await tester.pumpWidget(
        wrap(const CombinedDailyShareCard(
          combinedBps: 7000,
          modeEfficiencyBps: modeBps,
        )),
      );

      expect(find.text('RANK'), findsNothing);
      expect(find.text('FIELD'), findsNothing);
      expect(find.text('DAY'), findsNothing);
      expect(find.text('PLAYED'), findsNothing);
    });

    testWidgets('detailed:true shows the RANK/FIELD/DAY/PLAYED block',
        (tester) async {
      await tester.pumpWidget(
        wrap(const CombinedDailyShareCard(
          combinedBps: 7000,
          modeEfficiencyBps: modeBps,
          detailed: true,
          rank: 4,
          totalPlayers: 128,
          dayNumber: 12,
        )),
      );

      expect(find.text('RANK'), findsOneWidget);
      expect(find.text('FIELD'), findsOneWidget);
      expect(find.text('DAY'), findsOneWidget);
      expect(find.text('PLAYED'), findsOneWidget);
      // Values render too.
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget); // all three modes played
    });
  });

  group('_perfEmoji thresholds (via test accessor)', () {
    test('green boundary at 8500/8499 (85%)', () {
      expect(CombinedDailyShareCard.perfEmojiForTest(8500), emojiStrong);
      expect(CombinedDailyShareCard.perfEmojiForTest(8499), emojiSolid);
    });

    test('yellow boundary at 6500/6499 (65%)', () {
      expect(CombinedDailyShareCard.perfEmojiForTest(6500), emojiSolid);
      expect(CombinedDailyShareCard.perfEmojiForTest(6499), emojiFair);
    });

    test('orange boundary at 4000/3999 (40%)', () {
      expect(CombinedDailyShareCard.perfEmojiForTest(4000), emojiFair);
      expect(CombinedDailyShareCard.perfEmojiForTest(3999), emojiLow);
    });

    test('null (unplayed) is white', () {
      expect(CombinedDailyShareCard.perfEmojiForTest(null), emojiUnplayed);
    });
  });

  group('_modePct formatting (via test accessor)', () {
    test('null renders the em dash', () {
      expect(CombinedDailyShareCard.modePctForTest(null), '—');
    });

    test('non-null renders a rounded percentage', () {
      expect(CombinedDailyShareCard.modePctForTest(8740), '87%');
      expect(CombinedDailyShareCard.modePctForTest(5000), '50%');
    });
  });
}
