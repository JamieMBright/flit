import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/friend.dart';

/// Friends list screen with add friend and H2H records.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Placeholder data - will be replaced with real data from backend
  final List<Friend> _friends = [
    Friend(
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
    Friend(
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text('Friends'),
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
                  return _FriendTile(
                    friend: friend,
                    h2h: h2h,
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
          // TODO: Send friend request
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
    // TODO: Start challenge
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Challenge sent to ${friend.name}!'),
        backgroundColor: FlitColors.accent,
      ),
    );
  }

  void _viewFriendProfile(Friend friend) {
    // TODO: Navigate to friend profile
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    this.h2h,
    required this.onChallenge,
    required this.onViewProfile,
  });

  final Friend friend;
  final HeadToHead? h2h;
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
                      decoration: BoxDecoration(
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
                    // Online indicator
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
                // Challenge button
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
