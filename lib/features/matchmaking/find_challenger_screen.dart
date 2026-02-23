import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/challenge.dart';
import '../../data/models/cosmetic.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/matchmaking_service.dart';
import '../play/play_screen.dart';

/// Matchmaking states for the UI flow.
enum _MatchState {
  /// Initial state — player can submit to pool.
  ready,

  /// Submitting round data to the pool.
  submitting,

  /// Searching for a match in the pool.
  searching,

  /// A match was found — show opponent info.
  matched,

  /// No match found — entry is in the pool, waiting.
  waiting,

  /// An error occurred.
  error,
}

/// Screen for the "Find a Challenger" async matchmaking flow.
///
/// Flow:
/// 1. Player taps "Find a Challenger"
/// 2. Their stats are used to estimate ELO
/// 3. A pool entry is submitted
/// 4. The service searches for a match
/// 5. If matched -> show opponent, navigate to challenge
/// 6. If not matched -> show "waiting" state with pool info
class FindChallengerScreen extends ConsumerStatefulWidget {
  const FindChallengerScreen({super.key});

  @override
  ConsumerState<FindChallengerScreen> createState() =>
      _FindChallengerScreenState();
}

class _FindChallengerScreenState extends ConsumerState<FindChallengerScreen>
    with SingleTickerProviderStateMixin {
  _MatchState _state = _MatchState.ready;
  MatchResult? _matchResult;
  String? _errorMessage;
  List<Map<String, dynamic>> _poolEntries = [];
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadPoolEntries();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPoolEntries() async {
    final entries = await MatchmakingService.instance.getMyPoolEntries();
    if (!mounted) return;
    setState(() => _poolEntries = entries);
  }

  Future<void> _findChallenger() async {
    final account = ref.read(accountProvider);
    final player = account.currentPlayer;

    // Estimate ELO from player stats.
    final elo = MatchmakingService.estimateElo(
      level: player.level,
      bestScore: player.bestScore ?? 0,
    );

    final playerName = player.name;

    setState(() => _state = _MatchState.submitting);

    // Generate a seed for the pool entry.
    final seed = DateTime.now().millisecondsSinceEpoch.toString();

    // Submit an empty rounds entry — the actual rounds will be played
    // after matching, using the challenge's round seeds.
    final poolEntryId = await MatchmakingService.instance.submitToPool(
      seed: seed,
      rounds: [],
      eloRating: elo,
    );

    if (!mounted) return;

    if (poolEntryId == null) {
      setState(() {
        _state = _MatchState.error;
        _errorMessage = 'Failed to submit to matchmaking pool.';
      });
      return;
    }

    // Now search for a match.
    setState(() => _state = _MatchState.searching);

    final result = await MatchmakingService.instance.findMatch(
      eloRating: elo,
      playerName: playerName,
      myPoolEntryId: poolEntryId,
    );

    if (!mounted) return;

    if (result.matched) {
      setState(() {
        _state = _MatchState.matched;
        _matchResult = result;
      });
    } else {
      await _loadPoolEntries();
      if (!mounted) return;
      setState(() {
        _state = _MatchState.waiting;
      });
    }
  }

  Future<void> _checkForMatches() async {
    setState(() => _state = _MatchState.searching);

    final account = ref.read(accountProvider);
    final player = account.currentPlayer;
    final elo = MatchmakingService.estimateElo(
      level: player.level,
      bestScore: player.bestScore ?? 0,
    );

    final result = await MatchmakingService.instance.findMatch(
      eloRating: elo,
      playerName: player.name,
      myPoolEntryId: _poolEntries.isNotEmpty
          ? _poolEntries.first['id'] as String?
          : null,
    );

    if (!mounted) return;

    if (result.matched) {
      setState(() {
        _state = _MatchState.matched;
        _matchResult = result;
      });
    } else {
      await _loadPoolEntries();
      if (!mounted) return;
      setState(() => _state = _MatchState.waiting);
    }
  }

  void _launchChallenge() {
    if (_matchResult == null || _matchResult!.challengeId == null) return;

    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    final account = ref.read(accountProvider);
    final companion = account.avatar.companion;
    final fuelBoost = ref.read(accountProvider.notifier).fuelBoostMultiplier;
    final license = account.license;
    final contrailId = account.equippedContrailId;
    final contrail = CosmeticCatalog.getById(contrailId);
    final contrailPrimary = contrail?.colorScheme?['primary'];
    final contrailSecondary = contrail?.colorScheme?['secondary'];

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => PlayScreen(
              challengeFriendName: _matchResult!.opponentName ?? 'Challenger',
              challengeId: _matchResult!.challengeId,
              totalRounds: Challenge.totalRounds,
              planeColorScheme: plane?.colorScheme,
              planeWingSpan: plane?.wingSpan,
              equippedPlaneId: planeId,
              companionType: companion,
              fuelBoostMultiplier: fuelBoost,

              clueChance: license.clueChance,
              preferredClueType: license.preferredClueType,
              enableFuel: true,
              planeHandling: plane?.handling ?? 1.0,
              planeSpeed: plane?.speed ?? 1.0,
              planeFuelEfficiency: plane?.fuelEfficiency ?? 1.0,
              contrailPrimaryColor: contrailPrimary != null
                  ? Color(contrailPrimary)
                  : null,
              contrailSecondaryColor: contrailSecondary != null
                  ? Color(contrailSecondary)
                  : null,
            ),
          ),
        )
        .then((_) {
          if (mounted) {
            _loadPoolEntries();
            setState(() => _state = _MatchState.ready);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final player = account.currentPlayer;
    final elo = MatchmakingService.estimateElo(
      level: player.level,
      bestScore: player.bestScore ?? 0,
    );

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Find a Challenger'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPoolEntries();
              setState(() => _state = _MatchState.ready);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Player ELO card
              _EloCard(elo: elo, level: player.level),
              const SizedBox(height: 24),
              // Main action area
              Expanded(child: _buildStateContent()),
              // Pool entries
              if (_poolEntries.isNotEmpty && _state != _MatchState.matched) ...[
                const Divider(color: FlitColors.cardBorder, height: 1),
                _PoolEntriesSection(
                  entries: _poolEntries,
                  onCheckMatch: _checkForMatches,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_state) {
      case _MatchState.ready:
        return _ReadyContent(onFindChallenger: _findChallenger);
      case _MatchState.submitting:
        return const _LoadingContent(
          message: 'Submitting to matchmaking pool...',
        );
      case _MatchState.searching:
        return _SearchingContent(pulseController: _pulseController);
      case _MatchState.matched:
        return _MatchedContent(
          matchResult: _matchResult!,
          onPlay: _launchChallenge,
        );
      case _MatchState.waiting:
        return _WaitingContent(
          entryCount: _poolEntries.length,
          onCheckAgain: _checkForMatches,
        );
      case _MatchState.error:
        return _ErrorContent(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: () => setState(() => _state = _MatchState.ready),
        );
    }
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _EloCard extends StatelessWidget {
  const _EloCard({required this.elo, required this.level});

  final int elo;
  final int level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FlitColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.military_tech,
            color: FlitColors.accent,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR RATING',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$elo ELO',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: FlitColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Lv. $level',
            style: const TextStyle(
              color: FlitColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({required this.onFindChallenger});

  final VoidCallback onFindChallenger;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.radar, color: FlitColors.accent, size: 72),
        const SizedBox(height: 20),
        const Text(
          'FIND A CHALLENGER',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Submit your challenge to the matchmaking pool. '
            "We'll find an opponent near your skill level.",
            style: TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FlitColors.backgroundMid,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public, color: FlitColors.textMuted, size: 16),
              SizedBox(width: 6),
              Text(
                'World mode only',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: onFindChallenger,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: FlitColors.accent.withOpacity(0.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 22),
                SizedBox(width: 10),
                Text(
                  'SEARCH',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: FlitColors.accent),
        const SizedBox(height: 20),
        Text(
          message,
          style: const TextStyle(color: FlitColors.textSecondary, fontSize: 14),
        ),
      ],
    ),
  );
}

class _SearchingContent extends StatelessWidget {
  const _SearchingContent({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) => Transform.scale(
            scale: 1.0 + pulseController.value * 0.15,
            child: Icon(
              Icons.radar,
              color: FlitColors.accent.withOpacity(
                0.5 + pulseController.value * 0.5,
              ),
              size: 72,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'SEARCHING...',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Looking for a worthy opponent',
          style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
        ),
      ],
    ),
  );
}

class _MatchedContent extends StatelessWidget {
  const _MatchedContent({required this.matchResult, required this.onPlay});

  final MatchResult matchResult;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flight_takeoff, color: FlitColors.gold, size: 56),
        const SizedBox(height: 16),
        const Text(
          'OPPONENT FOUND!',
          style: TextStyle(
            color: FlitColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.person,
                color: FlitColors.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                matchResult.opponentName ?? 'Challenger',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ready to dogfight!',
                style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: FlitColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FlitColors.warning.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: FlitColors.warning, size: 14),
              SizedBox(width: 6),
              Text(
                '5 rounds \u2022 No retries',
                style: TextStyle(
                  color: FlitColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: onPlay,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: FlitColors.accent.withOpacity(0.4),
            ),
            child: const Text(
              "LET'S GO!",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WaitingContent extends StatelessWidget {
  const _WaitingContent({required this.entryCount, required this.onCheckAgain});

  final int entryCount;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.hourglass_top,
          color: FlitColors.gold.withOpacity(0.7),
          size: 56,
        ),
        const SizedBox(height: 16),
        const Text(
          'IN THE POOL',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Your challenge is in the matchmaking pool! '
            "We'll notify you when an opponent is found.\n\n"
            'You have $entryCount active '
            '${entryCount == 1 ? 'submission' : 'submissions'} waiting.',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onCheckAgain,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('CHECK AGAIN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FlitColors.accent,
                side: const BorderSide(color: FlitColors.accent),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: FlitColors.error, size: 56),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: FlitColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.accent,
            foregroundColor: FlitColors.textPrimary,
          ),
          child: const Text('TRY AGAIN'),
        ),
      ],
    ),
  );
}

class _PoolEntriesSection extends StatelessWidget {
  const _PoolEntriesSection({
    required this.entries,
    required this.onCheckMatch,
  });

  final List<Map<String, dynamic>> entries;
  final VoidCallback onCheckMatch;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'ACTIVE SUBMISSIONS',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            GestureDetector(
              onTap: onCheckMatch,
              child: const Row(
                children: [
                  Icon(Icons.refresh, color: FlitColors.accent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Check for matches',
                    style: TextStyle(
                      color: FlitColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final createdAt = entry['created_at'] != null
                ? DateTime.tryParse(entry['created_at'] as String)
                : null;
            final timeAgo = createdAt != null
                ? _formatTimeAgo(DateTime.now().difference(createdAt))
                : 'just now';
            final elo = entry['elo_rating'] as int? ?? 0;

            return Container(
              width: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FlitColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        color: FlitColors.gold,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ELO $elo',
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted $timeAgo',
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Waiting for match...',
                    style: TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  static String _formatTimeAgo(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'just now';
  }
}
