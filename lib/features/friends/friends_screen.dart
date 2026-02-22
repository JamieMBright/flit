import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/challenge.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/friend.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/challenge_service.dart';
import '../../data/services/friends_service.dart';
import '../avatar/avatar_widget.dart';
import '../play/play_screen.dart';

/// Friends list screen with add friend and H2H records.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  List<Friend> _friends = [];
  Map<String, HeadToHead> _h2hRecords = {};
  List<Challenge> _incomingChallenges = [];
  List<
    ({
      int friendshipId,
      String requesterId,
      String username,
      String? displayName,
      String? avatarUrl,
    })
  >
  _pendingRequests = [];
  bool _loading = true;

  // Track pending outgoing challenges
  final Set<String> _pendingChallenges = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      FriendsService.instance.fetchFriends(),
      FriendsService.instance.fetchPendingRequests(),
      ChallengeService.instance.fetchPendingChallenges(),
      ChallengeService.instance.fetchSentChallenges(),
    ]);

    final friends = results[0] as List<Friend>;
    final pending =
        results[1]
            as List<
              ({
                int friendshipId,
                String requesterId,
                String username,
                String? displayName,
                String? avatarUrl,
              })
            >;
    final incoming = results[2] as List<Challenge>;
    final sent = results[3] as List<Challenge>;

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

    // Mark friends with pending sent challenges.
    final pendingIds = <String>{};
    for (final c in sent) {
      if (c.status == ChallengeStatus.pending ||
          c.status == ChallengeStatus.inProgress) {
        pendingIds.add(c.challengedId);
      }
    }

    if (!mounted) return;
    setState(() {
      _friends = friends;
      _h2hRecords = h2hMap;
      _pendingRequests = pending;
      _incomingChallenges = incoming;
      _pendingChallenges
        ..clear()
        ..addAll(pendingIds);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.backgroundMid,
      title: const Text('Friends & Challenges'),
      centerTitle: true,
      actions: [
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
    if (_friends.isEmpty &&
        _pendingRequests.isEmpty &&
        _incomingChallenges.isEmpty) {
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
        // Incoming challenges
        if (_incomingChallenges.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'INCOMING CHALLENGES',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final challenge in _incomingChallenges)
            _IncomingChallengeTile(
              challenge: challenge,
              onAccept: () => _acceptChallenge(challenge),
              onDecline: () => _declineChallenge(challenge),
            ),
          const SizedBox(height: 8),
        ],
        // Friends list
        if (_friends.isNotEmpty) ...[
          if (_pendingRequests.isNotEmpty || _incomingChallenges.isNotEmpty)
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
              hasPendingChallenge: _pendingChallenges.contains(friend.playerId),
              onChallenge: () => _challengeFriend(friend),
              onViewProfile: () => _viewFriendProfile(friend),
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

  // ---------------------------------------------------------------------------
  // Challenge actions
  // ---------------------------------------------------------------------------

  void _acceptChallenge(Challenge challenge) {
    _launchChallengeGameplay(challenge.challengerName, challenge.id);
  }

  Future<void> _declineChallenge(Challenge challenge) async {
    final ok = await ChallengeService.instance.declineChallenge(challenge.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge declined'),
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
                Icons.flight_takeoff,
                color: FlitColors.warning,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                'Challenge ${friend.name}?',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You only get one shot at the clues. Make sure '
                'you have enough time to compete before starting.',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: FlitColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlitColors.warning.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: FlitColors.warning,
                      size: 14,
                    ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text(
                      'NOT YET',
                      style: TextStyle(color: FlitColors.textMuted),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
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
                      "LET'S GO",
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
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      _createAndLaunchChallenge(friend);
    });
  }

  Future<void> _createAndLaunchChallenge(Friend friend) async {
    final account = ref.read(accountProvider);
    final myName = account.currentPlayer.name.isNotEmpty
        ? account.currentPlayer.name
        : 'Player';

    final challengeId = await ChallengeService.instance.createChallenge(
      challengedId: friend.playerId,
      challengedName: friend.name,
      challengerName: myName,
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

    _launchChallengeGameplay(friend.name, challengeId);
  }

  void _launchChallengeGameplay(String opponentName, String challengeId) {
    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    final account = ref.read(accountProvider);
    final companion = account.avatar.companion;
    final fuelBoost = ref.read(accountProvider.notifier).fuelBoostMultiplier;
    final license = account.license;
    final contrailId = ref.read(accountProvider).equippedContrailId;
    final contrail = CosmeticCatalog.getById(contrailId);

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => PlayScreen(
              challengeFriendName: opponentName,
              challengeId: challengeId,
              totalRounds: Challenge.totalRounds,
              planeColorScheme: plane?.colorScheme,
              planeWingSpan: plane?.wingSpan,
              equippedPlaneId: planeId,
              companionType: companion,
              fuelBoostMultiplier: fuelBoost,
              clueBoost: license.clueBoost,
              clueChance: license.clueChance,
              preferredClueType: license.preferredClueType,
              enableFuel: true,
              planeHandling: plane?.handling ?? 1.0,
              planeSpeed: plane?.speed ?? 1.0,
              planeFuelEfficiency: plane?.fuelEfficiency ?? 1.0,
              contrailPrimaryColor: contrail?.colorScheme?['primary'] != null
                  ? Color(contrail!.colorScheme!['primary']!)
                  : null,
              contrailSecondaryColor:
                  contrail?.colorScheme?['secondary'] != null
                  ? Color(contrail!.colorScheme!['secondary']!)
                  : null,
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
                        ref.read(accountProvider.notifier).spendCoins(amount);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final h2h = _h2hRecords[friend.playerId];
        return Padding(
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
              // ── Head-to-head stats ──
              if (h2h != null && h2h.totalChallenges > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Lifetime record
                      const Text(
                        'LIFETIME',
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
                            // Last 10 column
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
                            // Last game column
                            Column(
                              children: [
                                const Text(
                                  'LAST GAME',
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
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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
                  onPressed: () {
                    Navigator.of(context).pop();
                    _challengeFriend(friend);
                  },
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showSendCoinsDialog(friend);
                  },
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
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showGiftMembershipDialog(friend);
                  },
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
              const SizedBox(height: 10),
              // ── Remove friend + Report row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _confirmRemoveFriend(friend);
                    },
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
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showReportDialog(friend);
                    },
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
        );
      },
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
                        disabledBackgroundColor: FlitColors.textMuted
                            .withOpacity(0.3),
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
                '@$username',
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
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: FlitColors.error),
          onPressed: onDecline,
        ),
      ],
    ),
  );
}

class _IncomingChallengeTile extends StatelessWidget {
  const _IncomingChallengeTile({
    required this.challenge,
    required this.onAccept,
    required this.onDecline,
  });

  final Challenge challenge;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.warning.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.flight_takeoff, color: FlitColors.warning, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${challenge.challengerName} challenged you!',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${Challenge.totalRounds} rounds \u2022 Best of 5',
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.accent,
            foregroundColor: FlitColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Play'),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.close, color: FlitColors.textMuted),
          onPressed: onDecline,
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

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    this.h2h,
    this.hasPendingChallenge = false,
    required this.onChallenge,
    required this.onViewProfile,
  });

  final Friend friend;
  final HeadToHead? h2h;
  final bool hasPendingChallenge;
  final VoidCallback onChallenge;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: InkWell(
      onTap: onViewProfile,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (h2h != null && h2h!.totalChallenges > 0)
                    Text(
                      'H2H: ${h2h!.record} (${h2h!.leadText})',
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
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
            if (hasPendingChallenge)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: FlitColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FlitColors.gold.withOpacity(0.3)),
                ),
                child: const Text(
                  'Waiting...',
                  style: TextStyle(
                    color: FlitColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: onChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.accent,
                  foregroundColor: FlitColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Challenge'),
              ),
          ],
        ),
      ),
    ),
  );
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
