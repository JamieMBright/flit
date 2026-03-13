import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';
import '../../game/tutorial/coach.dart';

/// Aviation-themed dismiss button labels. A random one is picked each time.
const _dismissLabels = [
  'Roger!',
  'Affirmative!',
  'Copy that!',
  'Wilco!',
  'Understood!',
  '10-4!',
];

/// Hint tier descriptions — the coach explains what each hint tier does.
const _hintExplanations = [
  'That hint just revealed a new clue about this country. '
      'Study it carefully — it might be all you need!',
  'I\'ve revealed the name of the target country for you. '
      'Now you know exactly where to fly — head there!',
  'See that dashed line? It\'s a wayline pointing straight '
      'to your target. Follow it!',
  'I\'ve set your course automatically. Sit back and let the '
      'plane fly straight to the destination.',
];

/// Semi-transparent overlay that shows coach tips during campaign missions.
///
/// The coach's avatar sits below the compass. When a tip is active, a speech
/// bubble appears centred on screen. Tips auto-dismiss after a delay or when
/// the button is tapped.
///
/// Also supports time-based "lost" detection: if no correct answer is given
/// within a configurable interval, the coach proactively offers help by
/// highlighting the hint button and forcing the player to use it.
class CoachOverlay extends StatefulWidget {
  const CoachOverlay({super.key, required this.mission});

  final CampaignMission mission;

  @override
  State<CoachOverlay> createState() => CoachOverlayState();
}

class CoachOverlayState extends State<CoachOverlay>
    with SingleTickerProviderStateMixin {
  String? _currentMessage;
  String _dismissLabel = _dismissLabels[0];
  bool _visible = false;
  final Set<String> _shownTriggers = {};

  /// When true, the hint button is highlighted and the dismiss button is
  /// hidden — the player must tap the hint button to progress.
  bool _hintForceMode = false;

  /// Whether we're waiting for a hint to be used (after showing a hint
  /// suggestion). When the hint is used, we show an explanation.
  bool _awaitingHintUse = false;

  late final AnimationController _animController;
  late final Animation<double> _slideAnim;

  /// Timer for detecting when the player seems lost.
  Timer? _lostTimer;

  /// How long without progress before showing a "lost" hint.
  static const _lostThreshold = Duration(seconds: 20);

  /// Number of "lost" nudges shown this session — no cap, coach always returns.
  int _lostHintCount = 0;

  // Reserved for future hint-tier-specific explanations.
  // int _currentHintTier = 0;

  static final _rng = Random();

  /// Whether the hint button highlight overlay should be shown.
  bool get isHintForced => _hintForceMode;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _lostTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Start the "lost" detection timer. Call this when a new round/clue begins.
  /// Resets any existing timer.
  void startLostTimer() {
    _lostTimer?.cancel();
    _lostTimer = Timer(_lostThreshold, _onPlayerLost);
  }

  /// Reset the lost timer (call on any player activity: movement, hint use).
  void resetLostTimer() {
    if (_lostTimer == null || !_lostTimer!.isActive) return;
    startLostTimer();
  }

  /// Cancel the lost timer (call on correct answer or round end).
  void cancelLostTimer() {
    _lostTimer?.cancel();
    _lostTimer = null;
  }

  /// Notify the coach that a hint was just used. Shows an explanation of
  /// what the hint tier does and dismisses the hint-force overlay.
  void onHintUsed(int hintTier) {
    // hintTier tracked for future use.
    if (_awaitingHintUse || _hintForceMode) {
      _awaitingHintUse = false;
      setState(() => _hintForceMode = false);

      // Show explanation of what that hint tier did.
      final tierIndex = (hintTier - 1).clamp(0, _hintExplanations.length - 1);
      _showMessage(_hintExplanations[tierIndex]);

      // Restart lost timer — coach will come back if still stuck.
      startLostTimer();
    }
  }

  void _onPlayerLost() {
    if (!mounted) return;
    _lostHintCount++;

    // Always suggest using a hint and force them to press it.
    final coach = widget.mission.coach;
    final message = _lostSuggestion(coach);
    _showHintForceMessage(message);

    // Don't restart timer yet — wait until they use the hint.
  }

  String _lostSuggestion(Coach coach) {
    switch (_lostHintCount) {
      case 1:
        return _firstLostNudge(coach);
      case 2:
        return _secondLostNudge(coach);
      case 3:
        return _thirdLostNudge(coach);
      default:
        return 'Let\'s get you there. Tap the hint button — '
            'I\'ll guide you closer with each one.';
    }
  }

  String _firstLostNudge(Coach coach) {
    switch (coach.id) {
      case 'jrd_tata':
        return 'When I plotted the Karachi-to-Bombay route, I checked '
            'my charts at every turn. There\'s no shame in that — '
            'tap the hint button!';
      case 'lotfia':
        return 'Even I needed help reading my first navigation charts '
            'in Cairo. Try a hint — tap the button below!';
      case 'santos_dumont':
        return 'Before circling the Eiffel Tower, I studied every map '
            'of Paris. A hint is just another chart — tap it!';
      case 'sabiha':
        return 'In combat, hesitation is the enemy. Use your instruments '
            '— tap the hint button, cadet!';
      case 'jean_batten':
        return 'Over the Tasman, I would have given anything for a better '
            'chart. You have one — tap the hint button!';
      case 'saint_exupery':
        return 'What is essential is invisible to the eye — but a hint '
            'can reveal it. Tap the button below!';
      case 'jorge_chavez':
        return 'I calculated every variable before crossing the Alps. '
            'A hint is just another data point — use it!';
      case 'beryl_markham':
        return 'Even a bush pilot checks the charts when the landscape '
            'is unfamiliar. Try a hint — tap the button!';
      case 'emilio_carranza':
        return 'On my goodwill flight, I used every instrument available. '
            'A hint costs less than getting lost — tap it!';
      case 'muqaddasi':
        return 'I walked the entire known world gathering knowledge. '
            'A hint is just another step — tap the button!';
      case 'villamor':
        return 'Even an ace checks his instruments mid-flight. '
            'Tap the hint button — it could save the mission!';
      case 'halim':
        return 'Every mission I flew for independence required preparation. '
            'Use the hint — tap the button below!';
      case 'errol_barrow':
        return 'Forty-five missions taught me: use every advantage. '
            'Tap the hint button, cadet!';
      default:
        return 'Taking your time? That\'s wise — but let me help. '
            'Tap the hint button below!';
    }
  }

  String _secondLostNudge(Coach coach) {
    switch (coach.id) {
      case 'jrd_tata':
        return 'Still searching? I once circled over the Arabian Sea '
            'for an hour finding my bearings. Use another hint!';
      case 'lotfia':
        return 'Still looking? My flight instructor gave me extra '
            'charts when I was stuck. That\'s what hints are for!';
      case 'santos_dumont':
        return 'Still circling? Even my airship needed course corrections '
            'over Paris. Each hint gets you closer — tap it!';
      case 'sabiha':
        return 'Still scanning? In 8,000 hours of flying, I never '
            'hesitated to check my instruments twice. Tap the hint!';
      case 'jean_batten':
        return 'Still out there? Over 14,000 miles I recalculated my '
            'position dozens of times. Use another hint!';
      case 'saint_exupery':
        return 'Still lost? I crashed in the Sahara once because I didn\'t '
            'check the stars. Don\'t make my mistake — use a hint!';
      case 'jorge_chavez':
        return 'Still calculating? I revised my Alpine route three times '
            'before takeoff. Another data point won\'t hurt — hint!';
      case 'beryl_markham':
        return 'Still tracking? The Nandi taught me patience, but also '
            'when to ask the elders. This is that moment — use a hint!';
      case 'emilio_carranza':
        return 'Still flying? My nonstop flight had no room for pride '
            'over preparation. Another hint, cadet!';
      case 'muqaddasi':
        return 'Still wandering? I spent years gathering knowledge before '
            'I could write my geography. Each hint adds to yours!';
      case 'villamor':
        return 'Still circling? Over Manila Bay, every second counted. '
            'Use another hint — that\'s an order!';
      case 'halim':
        return 'Still searching? I flew for freedom with limited fuel. '
            'Every hint conserves yours — use it!';
      case 'errol_barrow':
        return 'Still hunting? Forty-five bombing runs taught me to '
            'use my instruments without ego. Another hint, ace!';
      default:
        return 'Still searching? Every pilot needs instruments. '
            'Use another hint — tap the button!';
    }
  }

  String _thirdLostNudge(Coach coach) {
    switch (coach.id) {
      case 'jrd_tata':
        return 'No shame in it, cadet. Even I got lost over the Deccan '
            'Plateau on my second flight. Use a hint!';
      case 'lotfia':
        return 'Cadet, I defied my father to learn to fly — you can '
            'certainly accept a little help. Tap the hint!';
      case 'santos_dumont':
        return 'Mon ami, even I landed in the wrong field once or twice. '
            'A hint will set you right — tap it!';
      case 'sabiha':
        return 'Cadet, I flew 22 combat missions and still consulted '
            'my wingman. Use the hint — now!';
      case 'jean_batten':
        return 'Cadet, I nearly ran dry over the Timor Sea. A hint '
            'costs less than empty fuel tanks. Tap it!';
      case 'saint_exupery':
        return 'As I wrote — one sees clearly only with the heart. '
            'But right now, use your eyes and tap the hint!';
      case 'jorge_chavez':
        return 'Arriba, siempre arriba — but first, check your '
            'instruments! Tap the hint button, cadet!';
      case 'beryl_markham':
        return 'Even the best tracker loses a trail sometimes. '
            'Pick it up with a hint — tap the button!';
      case 'emilio_carranza':
        return 'My Washington flight had no room for pride. Neither '
            'does this. Tap the hint, cadet!';
      case 'muqaddasi':
        return 'I asked questions in every bazaar from Basra to Cairo. '
            'Asking for help is wisdom, not weakness. Use a hint!';
      case 'villamor':
        return 'In aerial combat, survival beats pride every time. '
            'Tap that hint button — that\'s a direct order!';
      case 'halim':
        return 'I gave my life at 25 for what I believed in. Believe '
            'in the hint button — tap it!';
      case 'errol_barrow':
        return 'I went from cockpit to parliament because I knew when '
            'to change tactics. Change yours — use the hint!';
      default:
        return 'No shame in asking for help, cadet. '
            'Use a hint — tap the button!';
    }
  }

  /// Show a message that forces the player to use the hint button.
  void _showHintForceMessage(String message) {
    setState(() {
      _currentMessage = message;
      _hintForceMode = true;
      _awaitingHintUse = true;
      _visible = true;
    });
    _animController.forward(from: 0);
    // No auto-dismiss — the player must tap the hint button.
  }

  /// Show a tip for the given trigger, if one exists for this mission and
  /// hasn't been shown yet. Returns true if a tip was shown.
  bool showTip(String trigger) {
    if (_shownTriggers.contains(trigger)) return false;
    final tip = widget.mission.tips.cast<CoachTip?>().firstWhere(
          (t) => t!.trigger == trigger,
          orElse: () => null,
        );
    if (tip == null) return false;

    _shownTriggers.add(trigger);
    _showMessage(tip.message);
    return true;
  }

  /// Show a custom message from the coach (not tied to a trigger).
  void showCustomMessage(String message) => _showMessage(message);

  void _showMessage(String message) {
    setState(() {
      _currentMessage = message;
      _dismissLabel = _dismissLabels[_rng.nextInt(_dismissLabels.length)];
      _visible = true;
      _hintForceMode = false;
    });
    _animController.forward(from: 0);

    // Auto-dismiss after 8 seconds (slightly longer to give time to read).
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted &&
          _visible &&
          _currentMessage == message &&
          !_hintForceMode) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _visible = false;
          _currentMessage = null;
          _hintForceMode = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final coach = widget.mission.coach;
    final safePadding = MediaQuery.of(context).padding;
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Hint button highlight overlay — semi-transparent scrim with a
        // spotlight cutout over the hint button, forcing the player to tap it.
        // Uses a custom hit-test widget so taps inside the cutout pass through
        // to the hint button underneath, while taps elsewhere are absorbed.
        if (_hintForceMode)
          Positioned.fill(
            child: _HintSpotlightOverlay(
              screenSize: screenSize,
              safePadding: safePadding,
            ),
          ),

        // Coach avatar sits below the compass (top-right area). Speech bubble
        // appears centred on screen below the avatar.
        Positioned(
          top: safePadding.top + 110,
          right: 12,
          left: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coach avatar — always visible during campaign
              _CoachAvatar(coach: coach),

              // Speech bubble — slides in when a tip is active, centred
              if (_visible && _currentMessage != null)
                Align(
                  alignment: Alignment.center,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(_slideAnim),
                    child: FadeTransition(
                      opacity: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _SpeechBubble(
                          coachName: coach.name,
                          message: _currentMessage!,
                          dismissLabel: _dismissLabel,
                          onDismiss: _dismiss,
                          showDismiss: !_hintForceMode,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small circular coach avatar shown below the compass.
///
/// Shows the coach's portrait image when available, falling back to styled
/// initials with a flag badge.
class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({required this.coach});

  final Coach coach;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: FlitColors.cardBackground,
      border: Border.all(
        color: FlitColors.accent.withValues(alpha: 0.6),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (coach.imageAsset != null) {
      return Container(
        width: size,
        height: size,
        decoration: decoration,
        child: ClipOval(
          child: Image.asset(
            coach.imageAsset!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsFallback(size),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: _initialsFallback(size),
    );
  }

  Widget _initialsFallback(double size) {
    final parts = coach.name.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : parts.first.substring(0, 2);
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: FlitColors.accent,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Speech bubble widget with a small tail pointing up-right toward the avatar.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.coachName,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
    this.showDismiss = true,
  });

  final String coachName;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final bool showDismiss;

  @override
  Widget build(BuildContext context) {
    // Constrain width so it doesn't stretch the full screen on tablets.
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth * 0.75).clamp(220.0, 340.0);

    return SizedBox(
      width: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bubble body — light colour scheme
          Container(
            width: maxWidth,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4C9B8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coach name
                Text(
                  coachName,
                  style: const TextStyle(
                    color: Color(0xFFC45E2C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Message text
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (showDismiss) ...[
                  const SizedBox(height: 8),
                  // Aviation-themed dismiss button
                  Center(
                    child: GestureDetector(
                      onTap: onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: FlitColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: FlitColors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          dismissLabel,
                          style: const TextStyle(
                            color: FlitColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay that paints a dark scrim with a spotlight cutout over the hint
/// button. Wrapped in [IgnorePointer] so it is purely visual — taps pass
/// straight through to the hint button (and other controls) underneath.
/// The coach message guides the player to tap the hint button.
class _HintSpotlightOverlay extends StatelessWidget {
  const _HintSpotlightOverlay({
    required this.screenSize,
    required this.safePadding,
  });

  final Size screenSize;
  final EdgeInsets safePadding;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HintSpotlightPainter(
          screenSize: screenSize,
          safePadding: safePadding,
        ),
      ),
    );
  }
}

/// Paints a semi-transparent overlay with a spotlight cutout over the hint
/// button in the bottom-left of the HUD.
class _HintSpotlightPainter extends CustomPainter {
  _HintSpotlightPainter({
    required this.screenSize,
    required this.safePadding,
  });

  final Size screenSize;
  final EdgeInsets safePadding;

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    // Hint button approximate position: bottom-left area of the HUD.
    final bottom = size.height - safePadding.bottom - 16;
    const pad = 12.0;
    final hintRect = Rect.fromLTRB(
      safePadding.left + 4,
      bottom - 44 - pad,
      size.width * 0.32 + pad,
      bottom + pad,
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, darkPaint);

    final cutoutPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(hintRect, const Radius.circular(22));
    canvas.drawRRect(rrect, cutoutPaint);
    canvas.restore();

    // Pulsing glow border around the cutout.
    final glowPaint = Paint()
      ..color = FlitColors.gold.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(_HintSpotlightPainter oldDelegate) => false;
}
