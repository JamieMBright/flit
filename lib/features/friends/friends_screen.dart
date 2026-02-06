import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/friend.dart';
import '../play/play_screen.dart';

/// Friends list screen with add friend and H2H records.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Placeholder data - will be replaced with real data from backend
  final List<Friend> _friends = [
    const Friend(
      id: '1',
      playerId: 'p1',
      username: 'SpeedyPilot',
      displayName: 'Speedy Pilot',
      isOnline: true,
    ),
    Friend(
      id: '2',
      playerId: 'p2',
      username: 'GeoMaster',
      displayName: 'Geo Master',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    const Friend(
      id: '3',
      playerId: 'p3',
      username: 'WorldFlyer',
      isOnline: true,
    ),
  ];

  final Map<String, HeadToHead> _h2hRecords = {
    'p1': const HeadToHead(
      friendId: 'p1',
      friendName: 'Speedy Pilot',
      wins: 7,
      losses: 4,
      totalChallenges: 11,
    ),
    'p2': const HeadToHead(
      friendId: 'p2',
      friendName: 'Geo Master',
      wins: 3,
      losses: 5,
      totalChallenges: 8,
    ),
    'p3': const HeadToHead(
      friendId: 'p3',
      friendName: 'World Flyer',
      wins: 2,
      losses: 2,
      totalChallenges: 4,
    ),
  };

  // Track pending challenges
  final Set<String> _pendingChallenges = {};

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text('Friends & Challenges'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddFriendDialog,
            ),
          ],
        ),
        body: _friends.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  final h2h = _h2hRecords[friend.playerId];
                  final hasPending = _pendingChallenges.contains(friend.playerId);
                  return _FriendTile(
                    friend: friend,
                    h2h: h2h,
                    hasPendingChallenge: hasPending,
                    onChallenge: () => _challengeFriend(friend),
                    onViewProfile: () => _viewFriendProfile(friend),
                  );
                },
              ),
      );

  void _showAddFriendDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _AddFriendDialog(
        onAdd: (username) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to @$username'),
              backgroundColor: FlitColors.success,
            ),
          );
        },
      ),
    );
  }

  void _challengeFriend(Friend friend) {
    // Navigate directly to play screen for round 1
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayScreen(
          challengeFriendName: friend.name,
        ),
      ),
    ).then((_) {
      // After returning from gameplay, mark challenge as sent
      if (mounted) {
        setState(() {
          _pendingChallenges.add(friend.playerId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent! Waiting for ${friend.name} to play...'),
            backgroundColor: FlitColors.accent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

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
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 12,
                ),
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
                    onPressed: () {
                      final amount = int.tryParse(controller.text) ?? 0;
                      if (amount >= 10) {
                        Navigator.of(dialogContext).pop();
                        // TODO: Deduct from player balance via provider
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sent $amount coins to ${friend.name}!'),
                            backgroundColor: FlitColors.success,
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

  void _viewFriendProfile(Friend friend) {
    // Show friend profile bottom sheet
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
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlitColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: FlitColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    friend.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
              // H2H record
              if (h2h != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniStat('Wins', '${h2h.wins}', FlitColors.success),
                      _MiniStat('Losses', '${h2h.losses}', FlitColors.error),
                      _MiniStat('Total', '${h2h.totalChallenges}', FlitColors.textSecondary),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // Challenge button
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
              // Send Coins button
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
              // Gift Membership button
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
              // Report Username button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
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
                    'REPORT USERNAME',
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
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Gift options
              _GiftOption(
                label: '1 Month',
                price: '\$2.99',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gifted 1 month of Flit+ to ${friend.name}!'),
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
                      content: Text('Gifted 1 year of Flit+ to ${friend.name}!'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flag,
                  color: FlitColors.warning,
                  size: 36,
                ),
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
                ...['Inappropriate username', 'Offensive behaviour', 'Spam / scam', 'Impersonation'].map(
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
                    onChanged: (val) => setDialogState(() => selectedReason = val),
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
                                  content: Text('Report submitted. Thanks for keeping Flit safe.'),
                                  backgroundColor: FlitColors.success,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.warning,
                        foregroundColor: FlitColors.backgroundDark,
                        disabledBackgroundColor: FlitColors.textMuted.withOpacity(0.3),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 11,
            ),
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
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: FlitColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          friend.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                // Name and H2H
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
                      if (h2h != null)
                        Text(
                          'H2H: ${h2h!.record} (${h2h!.leadText})',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          friend.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: friend.isOnline
                                ? FlitColors.success
                                : FlitColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Challenge button or pending status
                if (hasPendingChallenge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add friends to challenge them!',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
}
