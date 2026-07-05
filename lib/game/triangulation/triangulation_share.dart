import '../../data/models/daily_result.dart';
import 'triangulation_scoring.dart';
import 'triangulation_session.dart';

/// Spoiler-free share text for a finished Triangulation game.
///
/// One line of squares per round — one square per guess, coloured by how
/// close that guess was to the hidden capital — ending in the outcome.
/// Reveals nothing about the answer, only how sharply the player homed in:
///
/// ```
///      🛫 🧭 🛬
/// Flit Recon #128  2/3
/// 🟩✅
/// 🟥🟨🟩✅
/// 🟥🟥🟧🟨🟥❌
/// Score: 21,480 pts
/// Time: 1m42s
/// ```
String buildTriangulationShareText(
  TriangulationSession session, {
  required int dayNumber,
}) {
  final rows = session.rounds.map(_roundRow).join('\n');
  final score = DailyResult.formatScore(session.totalScore);
  final time = DailyResult.formatTime(session.totalTimeMs);
  return '     \u{1F6EB} \u{1F9ED} \u{1F6EC}\n'
      'Flit Recon #$dayNumber  '
      '${session.solvedRounds}/${session.rounds.length}\n'
      '$rows\n'
      'Score: $score pts\n'
      'Time: $time';
}

/// Just the emoji grid rows (no header/score) — used by the downloadable
/// image report alongside the full text share.
String triangulationEmojiGrid(TriangulationSession session) =>
    session.rounds.map(_roundRow).join('\n');

String _roundRow(TriangulationRoundState state) {
  final squares = StringBuffer();
  for (final guess in state.guesses) {
    if (guess.isCorrect) continue; // the outcome mark covers the solve
    squares.write(proximityEmoji(guess.distanceKm));
  }
  squares.write(state.solved ? '✅' : '❌');
  return squares.toString();
}

/// Proximity square for a wrong guess — thresholds shared with scoring so
/// share colours and penalties stay consistent.
String proximityEmoji(double distanceKm) {
  if (distanceKm < triHotKm) return '\u{1F7E9}'; // green: red hot
  if (distanceKm < triWarmKm) return '\u{1F7E8}'; // yellow: warm
  if (distanceKm < triCoolKm) return '\u{1F7E7}'; // orange: cool
  return '\u{1F7E5}'; // red: cold
}
