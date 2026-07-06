import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/campaign/coached_intro_screen.dart';
import 'package:flit/game/tutorial/coach.dart';

/// The reusable Advanced Training coached-intro scaffold: an ordered beat
/// machine that teaches a system before the real activity, then reports a
/// deliberate "begin". Mirrors the guided thinking of the Basic Training
/// lessons for the lighter Advanced missions.
void main() {
  const beats = [
    CoachIntroBeat(
      icon: Icons.military_tech_rounded,
      headline: 'RATED PLAY',
      message: 'This is rated flying.',
      points: ['Five rounds', 'One score'],
    ),
    CoachIntroBeat(
      icon: Icons.leaderboard_rounded,
      headline: 'THE LADDER',
      message: 'Climb the tiers.',
    ),
  ];

  testWidgets('walks its beats, then pops true on the final launch button',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => const CoachedIntroScreen(
                        coach: coachEmilioCarranza,
                        title: 'First Sortie',
                        beats: beats,
                        launchLabel: 'FLY THE SORTIE',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // First beat: headline + coach line + CONTINUE (not the launch label yet).
    expect(find.text('RATED PLAY'), findsOneWidget);
    expect(find.text('This is rated flying.'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('FLY THE SORTIE'), findsNothing);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    // Last beat: launch label appears.
    expect(find.text('THE LADDER'), findsOneWidget);
    expect(find.text('FLY THE SORTIE'), findsOneWidget);

    await tester.tap(find.text('FLY THE SORTIE'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('backing out reports no proceed', (tester) async {
    bool? result = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => const CoachedIntroScreen(
                        coach: coachEmilioCarranza,
                        title: 'First Sortie',
                        beats: beats,
                        launchLabel: 'FLY THE SORTIE',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The app-bar back button pops without a proceed result.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
