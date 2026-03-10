import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/challenge.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/friend.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/challenge_service.dart';
import '../../data/services/feature_flag_service.dart';
import '../../data/services/friends_service.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_session.dart';
import '../avatar/avatar_widget.dart';
import '../guide/gameplay_guide_screen.dart';
import '../play/play_screen.dart';
import '../quiz/quiz_game_screen.dart';

/// Friends list screen with add friend and H2H records.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  List<Friend> _friends = [];
  Map<String, HeadToHead> _h2hRecords = {};
  List<
      ({
        int friendshipId,
        String requesterId,
        String username,
        String? displayName,
        String? avatarUrl,
      })> _pendingRequests = [];
  List<
      ({
        int friendshipId,
        String addresseeId,
        String username,
        String? displayName,
        String? avatarUrl,
      })> _sentRequests = [];
  bool _loading = true;
  bool _giftingEnabled = true;

  /// Per-friend challenge status derived from all active challenges.
  Map<String, _FriendChallengeInfo> _challengeInfoMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFeatureFlags();
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final enabled = await FeatureFlagService.instance.isEnabled(
        'gifting_enabled',
      );
      if (!mounted) return;
      setState(() {
        _giftingEnabled = enabled;
      });
    } catch (_) {
      // Default to enabled on failure
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Always invalidate caches before loading so the screen never shows
    // stale data from a previous visit (e.g. pending invites that arrived
    // between navigations would otherwise be hidden by the 60-second TTL).
    FriendsService.instance.invalidateCache();

    final results = await Future.wait([
      FriendsService.instance.fetchFriends(),
      FriendsService.instance.fetchPendingRequests(),
      ChallengeService.instance.fetchAllActiveChallenges(),
      FriendsService.instance.fetchSentRequests(),
    ]);

    final friends = results[0] as List<Friend>;
    final pending = results[1] as List<
        ({
          int friendshipId,
          String requesterId,
          String username,
          String? displayName,
          String? avatarUrl,
        })>;
    final activeChallenges = results[2] as List<Challenge>;
    final sentRequests = results[3] as List<
        ({
          int friendshipId,
          String addresseeId,
          String username,
          String? displayName,
          String? avatarUrl,
        })>;

    // Load H2H records for all friends in parallel.
    final h2hEntries = await Future.wait(
      friends.map(
        (f) => FriendsService.instance.fetchH2HRecord(f.playerId, f.name),
      ),
    );
    final h2hMap = <String, HeadToHead>{};
    for (final h2h in h2hEntries) {
      h2hMap[h2h.friendId] = h2h;
    }

    // Build per-friend challenge status from ALL active challenges.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final infoMap = <String, _FriendChallengeInfo>{};
    if (userId != null) {
      for (final c in activeChallenges) {
        final isChallenger = c.challengerId == userId;
        final friendId = isChallenger ? c.challengedId : c.challengerId;

        // Keep the most recent challenge per friend (list is already sorted).
        if (infoMap.containsKey(friendId)) continue;

        final status = _deriveChallengeStatus(c, userId);
        infoMap[friendId] = _FriendChallengeInfo(
          status: status,
          challenge: c,
          opponentName: isChallenger ? c.challengedName : c.challengerName,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _friends = friends;
      _h2hRecords = h2hMap;
      _pendingRequests = pending;
      _sentRequests = sentRequests;
      _challengeInfoMap = infoMap;
      _loading = false;
    });
  }

  /// Determine the challenge status for the current user.
  static _FriendChallengeStatus _deriveChallengeStatus(
    Challenge c,
    String userId,
  ) {
    final isChallenger = c.challengerId == userId;

    if (c.status == ChallengeStatus.pending) {
      return isChallenger
          ? _FriendChallengeStatus.sent
          : _FriendChallengeStatus.received;
    }

    if (c.status == ChallengeStatus.inProgress) {
      // Check if this user has completed all their rounds.
      final allMyRoundsDone = c.rounds.every((r) {
        if (isChallenger) return r.challengerTime != null;
        return r.challengedTime != null;
      });
      return allMyRoundsDone
          ? _FriendChallengeStatus.theirTurn
          : _FriendChallengeStatus.yourTurn;
    }

    return _FriendChallengeStatus.none;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text('Friends & Challenges'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'How to Play',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GameplayGuideScreen(
                    initialTab: GuideTab.dogfight,
                  ),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddFriendDialog,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: FlitColors.accent),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: FlitColors.accent,
                child: _buildBody(),
              ),
      );

  Widget _buildBody() {
    if (_friends.isEmpty && _pendingRequests.isEmpty && _sentRequests.isEmpty) {
      return const _EmptyState();
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Incoming friend requests
        if (_pendingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'FRIEND REQUESTS',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final req in _pendingRequests)
            _FriendRequestTile(
              username: req.username,
              displayName: req.displayName,
              onAccept: () => _acceptRequest(req.friendshipId),
              onDecline: () => _declineRequest(req.friendshipId),
            ),
          const SizedBox(height: 8),
        ],
        // Pending sent friend requests
        if (_sentRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'SENT REQUESTS',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final req in _sentRequests)
            _SentRequestTile(
              username: req.username,
              displayName: req.displayName,
              onCancel: () => _cancelSentRequest(req.friendshipId),
            ),
          const SizedBox(height: 8),
        ],
        // Friends list
        if (_friends.isNotEmpty) ...[
          if (_pendingRequests.isNotEmpty || _sentRequests.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'FRIENDS',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          for (final friend in _friends)
            _FriendTile(
              friend: friend,
              h2h: _h2hRecords[friend.playerId],
              challengeInfo: _challengeInfoMap[friend.playerId],
              onChallenge: () => _challengeFriend(friend),
              onViewProfile: () => _viewFriendProfile(friend),
              onPlayChallenge: () {
                final info = _challengeInfoMap[friend.playerId];
                if (info != null) {
                  if (info.challenge.gameMode == ChallengeGameMode.quiz) {
                    _launchQuizChallengeGameplay(
                      info.opponentName,
                      info.challenge.id,
                    );
                  } else {
                    _launchChallengeGameplay(
                      info.opponentName,
                      info.challenge.id,
                    );
                  }
                }
              },
            ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Friend request actions
  // ---------------------------------------------------------------------------

  Future<void> _acceptRequest(int friendshipId) async {
    final ok = await FriendsService.instance.acceptFriendRequest(friendshipId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: FlitColors.success,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept request'),
          backgroundColor: FlitColors.error,
        ),
      );
    }
  }

  Future<void> _declineRequest(int friendshipId) async {
    final ok = await FriendsService.instance.declineFriendRequest(friendshipId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request declined'),
          backgroundColor: FlitColors.textMuted,
        ),
      );
      _loadData();
    }
  }

  Future<void> _cancelSentRequest(int friendshipId) async {
    final ok = await FriendsService.instance.cancelFriendRequest(friendshipId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request cancelled'),
          backgroundColor: FlitColors.textMuted,
        ),
      );
      _loadData();
    }
  }

  // ---------------------------------------------------------------------------
  // Add friend
  // ---------------------------------------------------------------------------

  void _showAddFriendDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _AddFriendDialog(
        onAdd: (username) async {
          Navigator.of(context).pop();
          final user = await FriendsService.instance.searchUser(username);
          if (!mounted) return;
          if (user == null) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text('User @$username not found'),
                backgroundColor: FlitColors.error,
              ),
            );
            return;
          }
          final ok = await FriendsService.instance.sendFriendRequest(
            user['id'] as String,
          );
          if (!mounted) return;
          if (ok) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent to @$username'),
                backgroundColor: FlitColors.success,
              ),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not send request to @$username (already sent?)',
                ),
                backgroundColor: FlitColors.error,
              ),
            );
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Challenge a friend
  // ---------------------------------------------------------------------------

  void _challengeFriend(Friend friend) {
    showDialog<ChallengeGameMode>(
      context: context,
      builder: (dialogContext) => _ChallengeModePicker(friendName: friend.name),
    ).then((selectedMode) {
      if (selectedMode == null || !mounted) return;
      _createAndLaunchChallenge(friend, selectedMode);
    });
  }

  Future<void> _createAndLaunchChallenge(
    Friend friend,
    ChallengeGameMode gameMode,
  ) async {
    final account = ref.read(accountProvider);
    final myName = account.currentPlayer.name.isNotEmpty
        ? account.currentPlayer.name
        : 'Player';

    final challengeId = await ChallengeService.instance.createChallenge(
      challengedId: friend.playerId,
      challengedName: friend.name,
      challengerName: myName,
      gameMode: gameMode,
      quizCategory:
          gameMode == ChallengeGameMode.quiz ? QuizCategory.mixed : null,
      quizMode: gameMode == ChallengeGameMode.quiz ? QuizMode.allStates : null,
    );

    if (!mounted) return;
    if (challengeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create challenge'),
          backgroundColor: FlitColors.error,
        ),
      );
      return;
    }

    if (gameMode == ChallengeGameMode.quiz) {
      _launchQuizChallengeGameplay(friend.name, challengeId);
    } else {
      _launchChallengeGameplay(friend.name, challengeId);
    }
  }

  Future<void> _launchChallengeGameplay(
    String opponentName,
    String challengeId,
  ) async {
    // Fetch the challenge to get per-round seeds so both players get
    // identical countries and clues.
    final challenge = await ChallengeService.instance.fetchChallenge(
      challengeId,
    );
    if (!mounted) return;

    final seeds = challenge?.rounds.map((r) => r.seed).toList();

    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    final account = ref.read(accountProvider);
    final companion = account.avatar.companion;
    final fuelBoost = ref.read(accountProvider.notifier).fuelBoostMultiplier;
    final license = account.license;
    final contrailId = ref.read(accountProvider).equippedContrailId;
    final contrail = CosmeticCatalog.getById(contrailId);
    final contrailPrimary = contrail?.colorScheme?['primary'];
    final contrailSecondary = contrail?.colorScheme?['secondary'];

    if (!mounted) return;
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (context) => PlayScreen(
          challengeFriendName: opponentName,
          challengeId: challengeId,
          challengeSeeds: seeds,
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
          contrailPrimaryColor:
              contrailPrimary != null ? Color(contrailPrimary) : null,
          contrailSecondaryColor:
              contrailSecondary != null ? Color(contrailSecondary) : null,
        ),
      ),
    )
        .then((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _launchQuizChallengeGameplay(
    String opponentName,
    String challengeId,
  ) async {
    final challenge = await ChallengeService.instance.fetchChallenge(
      challengeId,
    );
    if (!mounted || challenge == null) return;

    final seed = challenge.rounds.isNotEmpty ? challenge.rounds.first.seed : 42;
    final category = challenge.quizCategory ?? QuizCategory.mixed;
    final quizMode = challenge.quizMode ?? QuizMode.allStates;

    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => QuizGameScreen(
          mode: quizMode,
          categories: {category},
          challengeId: challengeId,
          challengeOpponentName: opponentName,
          seed: seed,
        ),
      ),
    )
        .then((_) {
      if (mounted) _loadData();
    });
  }

  // ---------------------------------------------------------------------------
  // Send coins
  // ---------------------------------------------------------------------------

  void _showSendCoinsDialog(Friend friend) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                color: FlitColors.gold,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Send Coins to ${friend.name}',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(color: FlitColors.textMuted),
                  filled: true,
                  fillColor: FlitColors.backgroundMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Minimum 10 coins',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final amount = int.tryParse(controller.text) ?? 0;
                      final balance = ref.read(currentCoinsProvider);
                      if (amount < 10) return;
                      if (amount > balance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Not enough coins!'),
                            backgroundColor: FlitColors.error,
                          ),
                        );
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      final ok = await FriendsService.instance.sendCoins(
                        recipientId: friend.playerId,
                        amount: amount,
                      );
                      if (!mounted) return;
                      if (ok) {
                        ref.read(accountProvider.notifier).spendCoins(
                              amount,
                              source: 'gift_sent',
                              logActivity: false,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sent $amount coins to ${friend.name}!',
                            ),
                            backgroundColor: FlitColors.success,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to send coins'),
                            backgroundColor: FlitColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.gold,
                      foregroundColor: FlitColors.backgroundDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Friend profile
  // ---------------------------------------------------------------------------

  void _viewFriendProfile(Friend friend) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlitColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _FriendProfileSheet(
        friend: friend,
        h2h: _h2hRecords[friend.playerId],
        giftingEnabled: _giftingEnabled,
        onChallenge: () {
          Navigator.of(sheetContext).pop();
          _challengeFriend(friend);
        },
        onSendCoins: () {
          Navigator.of(sheetContext).pop();
          _showSendCoinsDialog(friend);
        },
        onGiftMembership: () {
          Navigator.of(sheetContext).pop();
          _showGiftMembershipDialog(friend);
        },
        onRemove: () {
          Navigator.of(sheetContext).pop();
          _confirmRemoveFriend(friend);
        },
        onReport: () {
          Navigator.of(sheetContext).pop();
          _showReportDialog(friend);
        },
      ),
    );
  }

  void _showGiftMembershipDialog(Friend friend) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.card_giftcard,
                color: FlitColors.accent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Gift Flit+ to ${friend.name}',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Remove ads, unlock Live Group mode, and more!',
                style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _GiftOption(
                label: '1 Month',
                price: '\$2.99',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Gifted 1 month of Flit+ to ${friend.name}!',
                      ),
                      backgroundColor: FlitColors.success,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _GiftOption(
                label: '1 Year',
                price: '\$24.99',
                isBestValue: true,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Gifted 1 year of Flit+ to ${friend.name}!',
                      ),
                      backgroundColor: FlitColors.success,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: FlitColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(Friend friend) {
    String? selectedReason;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag, color: FlitColors.warning, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Report @${friend.username}',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  'Inappropriate username',
                  'Offensive behaviour',
                  'Spam / scam',
                  'Impersonation',
                ].map(
                  (reason) => RadioListTile<String>(
                    title: Text(
                      reason,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: FlitColors.accent,
                    onChanged: (val) =>
                        setDialogState(() => selectedReason = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: FlitColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: selectedReason != null
                          ? () {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Report submitted. Thanks for keeping '
                                    'Flit safe.',
                                  ),
                                  backgroundColor: FlitColors.success,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.warning,
                        foregroundColor: FlitColors.backgroundDark,
                        disabledBackgroundColor:
                            FlitColors.textMuted.withOpacity(0.3),
                      ),
                      child: const Text('Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveFriend(Friend friend) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_remove,
                color: FlitColors.error,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                'Remove ${friend.name}?',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This will remove them from your friends list. '
                'You can always add them again later.',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.error,
                      foregroundColor: FlitColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'REMOVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      final friendshipId = int.tryParse(friend.id);
      if (friendshipId == null) return;
      final ok = await FriendsService.instance.removeFriend(friendshipId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${friend.name} from friends'),
            backgroundColor: FlitColors.textMuted,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove friend'),
            backgroundColor: FlitColors.error,
          ),
        );
      }
    });
  }
}

// =============================================================================
// Widgets
// =============================================================================

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.username,
    this.displayName,
    required this.onAccept,
    required this.onDecline,
  });

  final String username;
  final String? displayName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add, color: FlitColors.accent, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? username,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@$username \u2022 Invite Pending',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: FlitColors.success),
              onPressed: onAccept,
              tooltip: 'Accept',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: FlitColors.error),
              onPressed: onDecline,
              tooltip: 'Decline',
            ),
          ],
        ),
      );
}

class _SentRequestTile extends StatelessWidget {
  const _SentRequestTile({
    required this.username,
    this.displayName,
    required this.onCancel,
  });

  final String username;
  final String? displayName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.textMuted.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_send,
                color: FlitColors.textMuted, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? username,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: FlitColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FlitColors.warning.withOpacity(0.3)),
              ),
              child: const Text(
                'Invite Pending',
                style: TextStyle(
                  color: FlitColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close,
                  color: FlitColors.textMuted, size: 18),
              onPressed: onCancel,
              tooltip: 'Cancel request',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
}

class _GiftOption extends StatelessWidget {
  const _GiftOption({
    required this.label,
    required this.price,
    required this.onTap,
    this.isBestValue = false,
  });

  final String label;
  final String price;
  final VoidCallback onTap;
  final bool isBestValue;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isBestValue
                ? FlitColors.accent.withOpacity(0.1)
                : FlitColors.backgroundMid,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isBestValue ? FlitColors.accent : FlitColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isBestValue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BEST VALUE',
                              style: TextStyle(
                                color: FlitColors.textPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
          ),
        ],
      );
}

class _FriendTile extends StatefulWidget {
  const _FriendTile({
    required this.friend,
    this.h2h,
    this.challengeInfo,
    required this.onChallenge,
    required this.onViewProfile,
    required this.onPlayChallenge,
  });

  final Friend friend;
  final HeadToHead? h2h;
  final _FriendChallengeInfo? challengeInfo;
  final VoidCallback onChallenge;
  final VoidCallback onViewProfile;
  final VoidCallback onPlayChallenge;

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  bool _expanded = false;
  List<MatchSummary>? _matchHistory;
  bool _loadingHistory = false;

  void _toggleExpand() {
    if (!_expanded &&
        _matchHistory == null &&
        !_loadingHistory &&
        widget.h2h != null &&
        widget.h2h!.totalChallenges > 0) {
      _loadHistory();
    }
    setState(() => _expanded = !_expanded);
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final history = await FriendsService.instance.fetchDetailedH2HHistory(
      widget.friend.playerId,
      limit: 50,
    );
    if (!mounted) return;
    setState(() {
      _matchHistory = history;
      _loadingHistory = false;
    });
  }

  /// Aggregate round-level stats by game mode (levelName).
  Map<String, _ModeBreakdown> _computeModeBreakdown() {
    if (_matchHistory == null) return {};
    final map = <String, _ModeBreakdown>{};
    for (final match in _matchHistory!) {
      for (final round in match.rounds) {
        if (!round.isComplete) continue;
        final modeName = round.levelName ?? round.levelId ?? 'Unknown';
        final entry = map.putIfAbsent(modeName, _ModeBreakdown.new);
        entry.rounds++;
        if (round.youWon == true) {
          entry.wins++;
        } else if (round.youWon == false) {
          entry.losses++;
        }
        if (round.yourScore != null) {
          entry.totalYourScore += round.yourScore!;
          entry.totalTheirScore += round.theirScore ?? 0;
          entry.scoredRounds++;
        }
        if (round.yourTimeMs != null) {
          entry.totalYourTimeMs += round.yourTimeMs!;
          entry.totalTheirTimeMs += round.theirTimeMs ?? 0;
          entry.timedRounds++;
        }
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final h2h = widget.h2h;
    final friend = widget.friend;
    final hasH2H = h2h != null && h2h.totalChallenges > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        children: [
          // ── Main row (tap to expand, long-press for profile) ──
          InkWell(
            onTap: hasH2H ? _toggleExpand : widget.onViewProfile,
            onLongPress: widget.onViewProfile,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar with online indicator
                  Stack(
                    children: [
                      if (friend.avatarConfig != null)
                        AvatarWidget(config: friend.avatarConfig!, size: 48)
                      else
                        AvatarFromUrl(
                          avatarUrl: friend.avatarUrl,
                          name: friend.name,
                          size: 48,
                        ),
                      if (friend.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: FlitColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: FlitColors.cardBackground,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Name, level, H2H info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Name + friendship level
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                friend.name,
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasH2H) ...[
                              const SizedBox(width: 8),
                              _FriendshipLevelBadge(h2h: h2h),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Row 2: H2H record + trend
                        if (hasH2H)
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Matches: ${h2h.record}',
                                  style: const TextStyle(
                                    color: FlitColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: ' \u2022 ${h2h.leadText}',
                                  style: const TextStyle(
                                    color: FlitColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (h2h.last10Total > 0) ...[
                                  TextSpan(
                                    text: ' \u2022 L10: ${h2h.last10Record} ',
                                    style: const TextStyle(
                                      color: FlitColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: h2h.trendArrow,
                                    style: TextStyle(
                                      color: h2h.recentTrend > 0
                                          ? FlitColors.success
                                          : h2h.recentTrend < 0
                                              ? FlitColors.error
                                              : FlitColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          const Text(
                            'No challenges yet',
                            style: TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Expand arrow (only if H2H data exists)
                  if (hasH2H)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: FlitColors.textMuted,
                      size: 20,
                    ),
                  const SizedBox(width: 4),
                  // Challenge status badge
                  _ChallengeStatusBadge(
                    info: widget.challengeInfo,
                    onChallenge: widget.onChallenge,
                    onPlay: widget.onPlayChallenge,
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded: per-mode breakdown ──
          if (_expanded && hasH2H)
            _ExpandedH2HBreakdown(
              loading: _loadingHistory,
              breakdown: _computeModeBreakdown(),
              onViewProfile: widget.onViewProfile,
            ),
        ],
      ),
    );
  }
}

/// Per-game-mode stats aggregated from round-level data.
class _ModeBreakdown {
  int rounds = 0;
  int wins = 0;
  int losses = 0;
  int totalYourScore = 0;
  int totalTheirScore = 0;
  int scoredRounds = 0;
  int totalYourTimeMs = 0;
  int totalTheirTimeMs = 0;
  int timedRounds = 0;

  int get draws => rounds - wins - losses;
  String get record => '$wins-$losses';
  double get winRate => rounds > 0 ? wins / rounds : 0;

  String get avgYourScore => scoredRounds > 0
      ? (totalYourScore / scoredRounds).toStringAsFixed(0)
      : '-';
  String get avgTheirScore => scoredRounds > 0
      ? (totalTheirScore / scoredRounds).toStringAsFixed(0)
      : '-';

  String get avgYourTime {
    if (timedRounds == 0) return '-';
    final avg = totalYourTimeMs / timedRounds / 1000;
    return '${avg.toStringAsFixed(1)}s';
  }

  String get avgTheirTime {
    if (timedRounds == 0) return '-';
    final avg = totalTheirTimeMs / timedRounds / 1000;
    return '${avg.toStringAsFixed(1)}s';
  }
}

class _ExpandedH2HBreakdown extends StatelessWidget {
  const _ExpandedH2HBreakdown({
    required this.loading,
    required this.breakdown,
    required this.onViewProfile,
  });

  final bool loading;
  final Map<String, _ModeBreakdown> breakdown;
  final VoidCallback onViewProfile;

  List<MapEntry<String, _ModeBreakdown>> get _sortedEntries {
    final list = breakdown.entries.toList()
      ..sort((a, b) => b.value.rounds.compareTo(a.value.rounds));
    return list;
  }

  Widget _buildModeRow(MapEntry<String, _ModeBreakdown> entry) {
    final mode = entry.value;
    final winColor = mode.wins > mode.losses
        ? FlitColors.success
        : mode.losses > mode.wins
            ? FlitColors.error
            : FlitColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              mode.record,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: winColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(mode.winRate * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: winColor,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              mode.avgYourScore,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              mode.avgYourTime,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FlitColors.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: FlitColors.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (breakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No round data available',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
              ),
            )
          else ...[
            const Text(
              'HEAD TO HEAD BY MODE',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            // Header row.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('Mode',
                        style: TextStyle(
                            color: FlitColors.textMuted, fontSize: 10)),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('W-L',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: FlitColors.textMuted, fontSize: 10)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('Win%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: FlitColors.textMuted, fontSize: 10)),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text('Avg Pts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: FlitColors.textMuted, fontSize: 10)),
                  ),
                  SizedBox(
                    width: 55,
                    child: Text('Avg Spd',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: FlitColors.textMuted, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const Divider(color: FlitColors.cardBorder, height: 8),
            // Mode rows sorted by rounds played.
            ..._sortedEntries.map(_buildModeRow),
          ],
          // View full profile link.
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              onTap: onViewProfile,
              child: const Text(
                'View full profile',
                style: TextStyle(
                  color: FlitColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog({required this.onAdd});

  final void Function(String username) onAdd;

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Friend',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                style: const TextStyle(color: FlitColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter username',
                  hintStyle: const TextStyle(color: FlitColors.textMuted),
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: FlitColors.textSecondary),
                  filled: true,
                  fillColor: FlitColors.backgroundMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        widget.onAdd(_controller.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                    ),
                    child: const Text('Send Request'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: FlitColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No friends yet',
              style: TextStyle(color: FlitColors.textSecondary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add friends to challenge them!',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
}

// =============================================================================
// Challenge status types
// =============================================================================

/// Per-friend challenge status.
enum _FriendChallengeStatus {
  none, // No active challenge
  sent, // You sent a pending challenge (waiting for them to accept)
  received, // They sent you a pending challenge (tap to play)
  yourTurn, // In-progress challenge, you need to play rounds
  theirTurn, // In-progress challenge, waiting for them
}

/// Challenge info for a specific friend.
class _FriendChallengeInfo {
  const _FriendChallengeInfo({
    required this.status,
    required this.challenge,
    required this.opponentName,
  });

  final _FriendChallengeStatus status;
  final Challenge challenge;
  final String opponentName;
}

// =============================================================================
// Challenge status badge (tappable for "your turn" / "new challenge")
// =============================================================================

class _ChallengeStatusBadge extends StatelessWidget {
  const _ChallengeStatusBadge({
    this.info,
    required this.onChallenge,
    required this.onPlay,
  });

  final _FriendChallengeInfo? info;
  final VoidCallback onChallenge;
  final VoidCallback onPlay;

  /// Whether the active challenge is a quiz (Flight School) mode.
  bool get _isQuizChallenge =>
      info?.challenge.gameMode == ChallengeGameMode.quiz;

  /// Icon appropriate for the challenge's game mode.
  IconData get _modeIcon =>
      _isQuizChallenge ? Icons.quiz_rounded : Icons.flight_takeoff;

  /// Short label for the game mode.
  String get _modeLabel => _isQuizChallenge ? 'Flight School' : 'Dogfight';

  @override
  Widget build(BuildContext context) {
    final status = info?.status ?? _FriendChallengeStatus.none;
    final hasChallenge = status != _FriendChallengeStatus.none;

    Widget badge;
    switch (status) {
      case _FriendChallengeStatus.yourTurn:
        badge = _tappableBadge(
          label: 'YOUR TURN',
          icon: Icons.play_arrow_rounded,
          color: FlitColors.success,
          onTap: onPlay,
        );
      case _FriendChallengeStatus.received:
        badge = _tappableBadge(
          label: 'CHALLENGE',
          icon: _modeIcon,
          color: FlitColors.accent,
          onTap: onPlay,
        );
      case _FriendChallengeStatus.theirTurn:
        badge = _staticBadge(label: 'THEIR TURN', color: FlitColors.gold);
      case _FriendChallengeStatus.sent:
        badge = _staticBadge(label: 'SENT', color: FlitColors.textMuted);
      case _FriendChallengeStatus.none:
        badge = _tappableBadge(
          label: 'CHALLENGE',
          icon: Icons.flash_on,
          color: FlitColors.accent,
          onTap: onChallenge,
        );
    }

    if (!hasChallenge) return badge;

    // Show game mode label under the status badge for active challenges.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 3),
        Text(
          _modeLabel,
          style: TextStyle(
            color: _isQuizChallenge ? FlitColors.gold : FlitColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _tappableBadge({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staticBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// =============================================================================
// Friendship level badge
// =============================================================================

class _FriendshipLevelBadge extends StatelessWidget {
  const _FriendshipLevelBadge({required this.h2h});

  final HeadToHead h2h;

  @override
  Widget build(BuildContext context) {
    final stars = h2h.friendshipStars;
    if (stars == 0) return const SizedBox.shrink();

    final color = _levelColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${'★' * stars} ${h2h.friendshipLevel}',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color get _levelColor {
    final stars = h2h.friendshipStars;
    if (stars >= 5) return FlitColors.gold;
    if (stars >= 4) return FlitColors.error;
    if (stars >= 3) return FlitColors.accent;
    if (stars >= 2) return FlitColors.accentLight;
    return FlitColors.textSecondary;
  }
}

// =============================================================================
// Friend Profile Bottom Sheet (stateful — loads match history)
// =============================================================================

class _FriendProfileSheet extends StatefulWidget {
  const _FriendProfileSheet({
    required this.friend,
    required this.h2h,
    required this.giftingEnabled,
    required this.onChallenge,
    required this.onSendCoins,
    required this.onGiftMembership,
    required this.onRemove,
    required this.onReport,
  });

  final Friend friend;
  final HeadToHead? h2h;
  final bool giftingEnabled;
  final VoidCallback onChallenge;
  final VoidCallback onSendCoins;
  final VoidCallback onGiftMembership;
  final VoidCallback onRemove;
  final VoidCallback onReport;

  @override
  State<_FriendProfileSheet> createState() => _FriendProfileSheetState();
}

class _FriendProfileSheetState extends State<_FriendProfileSheet> {
  List<MatchSummary>? _matchHistory;
  bool _loadingHistory = false;
  int? _expandedMatchIndex;

  @override
  void initState() {
    super.initState();
    if (widget.h2h != null && widget.h2h!.totalChallenges > 0) {
      _loadMatchHistory();
    }
  }

  Future<void> _loadMatchHistory() async {
    setState(() => _loadingHistory = true);
    final history = await FriendsService.instance.fetchDetailedH2HHistory(
      widget.friend.playerId,
    );
    if (!mounted) return;
    setState(() {
      _matchHistory = history;
      _loadingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h2h = widget.h2h;
    final friend = widget.friend;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlitColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (friend.avatarConfig != null)
              AvatarWidget(config: friend.avatarConfig!, size: 64)
            else
              AvatarFromUrl(
                avatarUrl: friend.avatarUrl,
                name: friend.name,
                size: 64,
              ),
            const SizedBox(height: 12),
            Text(
              friend.name,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '@${friend.username}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // ── Head-to-head summary stats ──
            if (h2h != null && h2h.totalChallenges > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundMid,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MATCHES',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MiniStat('W', '${h2h.wins}', FlitColors.success),
                        _MiniStat('L', '${h2h.losses}', FlitColors.error),
                        if (h2h.draws > 0)
                          _MiniStat(
                            'D',
                            '${h2h.draws}',
                            FlitColors.textSecondary,
                          ),
                        _MiniStat(
                          'Total',
                          '${h2h.totalChallenges}',
                          FlitColors.textSecondary,
                        ),
                      ],
                    ),
                    if (h2h.last10Total > 0) ...[
                      const SizedBox(height: 12),
                      const Divider(color: FlitColors.cardBorder, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'LAST 10',
                                style: TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h2h.last10Record,
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'LAST MATCH',
                                style: TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h2h.lastGameText,
                                style: TextStyle(
                                  color: h2h.lastGameWon == true
                                      ? FlitColors.success
                                      : h2h.lastGameWon == false
                                          ? FlitColors.error
                                          : FlitColors.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'TREND',
                                style: TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h2h.trendArrow,
                                style: TextStyle(
                                  color: h2h.recentTrend > 0
                                      ? FlitColors.success
                                      : h2h.recentTrend < 0
                                          ? FlitColors.error
                                          : FlitColors.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Match history with round details ──
              if (_loadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: FlitColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_matchHistory != null && _matchHistory!.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RECENT MATCHES',
                    style: TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._matchHistory!.asMap().entries.map(
                      (entry) => _MatchHistoryTile(
                        match: entry.value,
                        isExpanded: _expandedMatchIndex == entry.key,
                        onTap: () {
                          setState(() {
                            _expandedMatchIndex =
                                _expandedMatchIndex == entry.key
                                    ? null
                                    : entry.key;
                          });
                        },
                      ),
                    ),
              ],
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundMid,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No challenges yet \u2014 be the first!',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            // ── Challenge button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.accent,
                  foregroundColor: FlitColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'CHALLENGE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            if (widget.giftingEnabled) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onSendCoins,
                  icon: const Icon(
                    Icons.monetization_on,
                    size: 18,
                    color: FlitColors.gold,
                  ),
                  label: const Text(
                    'SEND COINS',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlitColors.gold,
                    side: const BorderSide(color: FlitColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onGiftMembership,
                  icon: const Icon(
                    Icons.card_giftcard,
                    size: 18,
                    color: FlitColors.accent,
                  ),
                  label: const Text(
                    'GIFT MEMBERSHIP',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlitColors.accent,
                    side: const BorderSide(color: FlitColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            // ── Remove friend + Report row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: widget.onRemove,
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    size: 16,
                    color: FlitColors.error,
                  ),
                  label: const Text(
                    'REMOVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: FlitColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: widget.onReport,
                  icon: const Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: FlitColors.textMuted,
                  ),
                  label: const Text(
                    'REPORT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: FlitColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Match History Tile (expandable to show per-round detail)
// =============================================================================

class _MatchHistoryTile extends StatelessWidget {
  const _MatchHistoryTile({
    required this.match,
    required this.isExpanded,
    required this.onTap,
  });

  final MatchSummary match;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resultColor = match.youWon == true
        ? FlitColors.success
        : match.youWon == false
            ? FlitColors.error
            : FlitColors.textMuted;
    final resultLabel = match.youWon == true
        ? 'W'
        : match.youWon == false
            ? 'L'
            : 'D';
    final daysAgo = DateTime.now().difference(match.playedAt).inDays;
    final dateLabel = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? 'Yesterday'
            : '$daysAgo days ago';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FlitColors.backgroundMid,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isExpanded
                  ? resultColor.withOpacity(0.4)
                  : FlitColors.cardBorder,
            ),
          ),
          child: Column(
            children: [
              // Summary row
              Row(
                children: [
                  // Result badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: resultColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        resultLabel,
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Score
                  Text(
                    match.scoreText,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  // Date
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: FlitColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
              // Expanded round details
              if (isExpanded) ...[
                const SizedBox(height: 10),
                const Divider(color: FlitColors.cardBorder, height: 1),
                const SizedBox(height: 8),
                ...match.rounds
                    .where((r) => r.isComplete)
                    .map((round) => _RoundOutcomeRow(round: round)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Round outcome row layout:
/// `yourScore | yourEmoji | Clue (type) | theirEmoji | theirScore`
class _RoundOutcomeRow extends StatelessWidget {
  const _RoundOutcomeRow({required this.round});

  final RoundOutcome round;

  @override
  Widget build(BuildContext context) {
    final youWon = round.youWon;
    final hasScores = round.yourScore != null && round.theirScore != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Your score
          SizedBox(
            width: 48,
            child: Text(
              hasScores
                  ? _formatScore(round.yourScore!)
                  : _formatMs(round.yourTimeMs),
              style: TextStyle(
                color: youWon == true
                    ? FlitColors.success
                    : FlitColors.textPrimary,
                fontSize: 11,
                fontWeight:
                    youWon == true ? FontWeight.w600 : FontWeight.normal,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          // Your hint emoji
          SizedBox(
            width: 18,
            child: Text(
              round.yourHintEmoji,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          // Clue label (country + type)
          Expanded(
            child: Text(
              round.clueLabel.isNotEmpty
                  ? round.clueLabel
                  : 'Round ${round.roundNumber}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Their hint emoji
          SizedBox(
            width: 18,
            child: Text(
              round.theirHintEmoji,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          // Their score
          SizedBox(
            width: 48,
            child: Text(
              hasScores
                  ? _formatScore(round.theirScore!)
                  : _formatMs(round.theirTimeMs),
              style: TextStyle(
                color:
                    youWon == false ? FlitColors.error : FlitColors.textPrimary,
                fontSize: 11,
                fontWeight:
                    youWon == false ? FontWeight.w600 : FontWeight.normal,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatScore(int score) {
    if (score >= 1000) {
      final s = score.toString();
      final buf = StringBuffer();
      var count = 0;
      for (var i = s.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) buf.write(',');
        buf.write(s[i]);
        count++;
      }
      return buf.toString().split('').reversed.join();
    }
    return score.toString();
  }

  static String _formatMs(int? ms) {
    if (ms == null) return '--';
    final seconds = ms ~/ 1000;
    final centis = (ms % 1000) ~/ 10;
    return '$seconds.${centis.toString().padLeft(2, '0')}s';
  }
}

// =============================================================================
// Challenge Mode Picker Dialog
// =============================================================================

/// Dialog that lets the user choose a game mode before sending a challenge.
class _ChallengeModePicker extends StatelessWidget {
  const _ChallengeModePicker({required this.friendName});

  final String friendName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_mma, color: FlitColors.accent, size: 36),
            const SizedBox(height: 16),
            Text(
              'Challenge $friendName',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a game mode:',
              style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Dogfight (flight mode)
            _ChallengeModeOption(
              icon: Icons.flight_takeoff,
              title: 'Dogfight',
              subtitle: '5 rounds \u2022 Fly to countries',
              color: FlitColors.accent,
              onTap: () => Navigator.of(context).pop(ChallengeGameMode.flight),
            ),
            const SizedBox(height: 10),
            // Flight School (quiz mode)
            _ChallengeModeOption(
              icon: Icons.quiz_rounded,
              title: 'Flight School',
              subtitle: 'Quiz \u2022 Tap US states',
              color: FlitColors.gold,
              onTap: () => Navigator.of(context).pop(ChallengeGameMode.quiz),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: FlitColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeModeOption extends StatelessWidget {
  const _ChallengeModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlitColors.backgroundMid,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
