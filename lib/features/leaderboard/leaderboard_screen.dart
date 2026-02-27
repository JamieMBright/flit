import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/pilot_license.dart';
import '../../data/models/player_report.dart';
import '../../data/services/leaderboard_service.dart';
import '../../data/services/report_service.dart';
import '../avatar/avatar_widget.dart';
import '../license/license_screen.dart';
import '../shop/shop_screen.dart';

/// Font family fallback list for rendering emojis across platforms.
///
/// iOS/macOS use Apple Color Emoji, Windows uses Segoe UI Emoji, Android/Web
/// use Noto Color Emoji. Providing all three ensures coloured emoji glyphs
/// instead of outlined tofu boxes.
const List<String> _emojiFontFallback = [
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Noto Color Emoji',
];

/// Maps a round-result emoji character to its display color.
///
/// Used to render painted circles (Container + BoxShape.circle) instead of text
/// emojis, avoiding iOS rendering issues where Unicode colored circles appear
/// monochrome/outlined rather than filled.
Color _emojiToColor(String emoji) {
  switch (emoji) {
    case '\u{1F7E2}': // 🟢 green (perfect, no hints)
      return const Color(0xFF4CAF50);
    case '\u{1F7E1}': // 🟡 yellow (1-2 hints)
      return const Color(0xFFFFD700);
    case '\u{1F7E0}': // 🟠 orange (3+ hints)
      return const Color(0xFFFF9800);
    case '\u{1F534}': // 🔴 red (failed)
      return const Color(0xFFCC4444);
    default:
      return const Color(0xFF666666);
  }
}

/// Splits a round-emojis string into individual emoji characters.
List<String> _splitEmojis(String emojis) =>
    emojis.runes.map((r) => String.fromCharCode(r)).toList();

/// Rarity colors (shared with license_screen).
const Color _bronzeColor = Color(0xFFCD7F32);
const Color _silverColor = Color(0xFFC0C0C0);
const Color _goldColor = Color(0xFFFFD700);
const Color _diamondColor = Color(0xFFB9F2FF);

const List<Color> _perfectGradientColors = [
  Color(0xFFFF0000),
  Color(0xFFFF7F00),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF0000FF),
  Color(0xFF8B00FF),
  Color(0xFFFF0000),
];

Color _colorForRarity(String rarityTier) {
  switch (rarityTier) {
    case 'Bronze':
      return _bronzeColor;
    case 'Silver':
      return _silverColor;
    case 'Gold':
      return _goldColor;
    case 'Diamond':
      return _diamondColor;
    case 'Perfect':
      return _goldColor;
    default:
      return _bronzeColor;
  }
}

/// Leaderboard screen with two top-level mode tabs (Daily Scramble and Training
/// Flight), each with sub-tabs for Today / Last Month / All Time.
///
/// Rows show: rank, avatar, plane, username, date, emoji result, points, time.
/// Tapping avatar/plane/username opens a pilot card bottom sheet.
/// Tapping the emoji column shows a clue-round breakdown.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _modeTabController;
  TimeframeTab _timeframe = TimeframeTab.today;
  bool _loading = true;
  String? _errorMessage;
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _playerRank;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool get _isDailyScramble => _modeTabController.index == 0;

  @override
  void initState() {
    super.initState();
    _modeTabController = TabController(length: 2, vsync: this);
    _modeTabController.addListener(_onModeChanged);
    _loadData();
  }

  @override
  void dispose() {
    _modeTabController.removeListener(_onModeChanged);
    _modeTabController.dispose();
    super.dispose();
  }

  void _onModeChanged() {
    if (!_modeTabController.indexIsChanging) return;
    _loadData();
  }

  void _onTimeframeChanged(TimeframeTab tab) {
    setState(() => _timeframe = tab);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final entries = await LeaderboardService.instance.fetchModeLeaderboard(
        isDailyScramble: _isDailyScramble,
        timeframe: _timeframe,
      );

      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }

      // Load player rank in parallel (mode-aware).
      _loadPlayerRank();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Failed to load leaderboard. Tap to retry.';
        });
      }
    }
  }

  Future<void> _loadPlayerRank() async {
    final userId = _userId;
    if (userId == null) return;

    final rank = await LeaderboardService.instance.fetchPlayerRank(
      userId,
      isDailyScramble: _isDailyScramble,
    );
    if (mounted) {
      setState(() => _playerRank = rank);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.backgroundMid,
      title: const Text('Leaderboard'),
      centerTitle: true,
      bottom: TabBar(
        controller: _modeTabController,
        indicatorColor: FlitColors.accent,
        labelColor: FlitColors.textPrimary,
        unselectedLabelColor: FlitColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'DAILY SCRAMBLE'),
          Tab(text: 'TRAINING FLIGHT'),
        ],
      ),
    ),
    body: Column(
      children: [
        // Sub-tab chips: Today | Last Month | All Time
        _TimeframeChips(selected: _timeframe, onChanged: _onTimeframeChanged),
        const Divider(color: FlitColors.cardBorder, height: 1),
        // Player rank banner
        if (_playerRank != null) _PlayerRankBanner(entry: _playerRank!),
        // Leaderboard list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _ErrorState(message: _errorMessage!, onRetry: _loadData)
              : _entries.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) => _LeaderboardRow(
                    entry: _entries[index],
                    isCurrentPlayer: _entries[index].playerId == _userId,
                  ),
                ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Sub-tab chips
// =============================================================================

class _TimeframeChips extends StatelessWidget {
  const _TimeframeChips({required this.selected, required this.onChanged});

  final TimeframeTab selected;
  final ValueChanged<TimeframeTab> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    color: FlitColors.backgroundMid,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: TimeframeTab.values
          .map(
            (tab) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(tab.displayName),
                selected: tab == selected,
                onSelected: (_) => onChanged(tab),
                selectedColor: FlitColors.accent,
                backgroundColor: FlitColors.cardBackground,
                labelStyle: TextStyle(
                  color: tab == selected
                      ? FlitColors.textPrimary
                      : FlitColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

// =============================================================================
// Player rank banner
// =============================================================================

class _PlayerRankBanner extends StatelessWidget {
  const _PlayerRankBanner({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FlitColors.accent, FlitColors.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.playerName,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score} pts',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTime(entry.time),
                style: TextStyle(
                  color: FlitColors.textPrimary.withOpacity(0.8),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Leaderboard row
// =============================================================================

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, this.isCurrentPlayer = false});

  final LeaderboardEntry entry;
  final bool isCurrentPlayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? FlitColors.accent.withOpacity(0.15)
            : _rankColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlayer
              ? FlitColors.accent
              : entry.rank <= 3
              ? _rankColor.withOpacity(0.6)
              : FlitColors.cardBorder.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 30,
            child: entry.rank <= 3
                ? Text(
                    _rankEmoji,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamilyFallback: _emojiFontFallback,
                    ),
                  )
                : Text(
                    '#${entry.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _rankColor,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          // Tappable identity: avatar + plane + name/date
          Expanded(
            child: GestureDetector(
              onTap: () => _showPilotCard(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Avatar (offline composition preferred over URL fetch)
                  AvatarFromUrl(
                    avatarUrl: entry.avatarUrl,
                    name: entry.playerName,
                    avatarConfig: entry.avatarConfigJson != null
                        ? AvatarConfig.fromJson(entry.avatarConfigJson!)
                        : null,
                    size: 40,
                  ),
                  const SizedBox(width: 4),
                  // Tiny plane
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(
                      painter: PlanePainter(
                        planeId: entry.equippedPlaneId ?? 'plane_default',
                        wingSpan: 16.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.playerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentPlayer
                                ? FlitColors.accent
                                : FlitColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entry.timestamp != null)
                          Text(
                            _formatDate(entry.timestamp!),
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Tappable emoji result — painted circles avoid iOS rendering
          // issues with Unicode colored circles.
          GestureDetector(
            onTap: () => _showClueBreakdown(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: entry.roundEmojis != null && entry.roundEmojis!.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _splitEmojis(entry.roundEmojis!).map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _emojiToColor(emoji),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  : const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: FlitColors.textMuted,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          // Score + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: TextStyle(
                  color: isCurrentPlayer
                      ? FlitColors.accent
                      : FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTime(entry.time),
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPilotCard(BuildContext context) {
    final isMe =
        entry.playerId == Supabase.instance.client.auth.currentUser?.id;
    if (isMe) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LicenseScreen()));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlitColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PilotCardSheet(entry: entry),
    );
  }

  void _showClueBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlitColors.backgroundMid,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ClueBreakdownSheet(entry: entry),
    );
  }

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return FlitColors.textSecondary;
    }
  }

  String get _rankEmoji {
    switch (entry.rank) {
      case 1:
        return '\u{1F947}';
      case 2:
        return '\u{1F948}';
      case 3:
        return '\u{1F949}';
      default:
        return '#${entry.rank}';
    }
  }
}

// =============================================================================
// Pilot card bottom sheet
// =============================================================================

class _PilotCardSheet extends StatefulWidget {
  const _PilotCardSheet({required this.entry});

  final LeaderboardEntry entry;

  @override
  State<_PilotCardSheet> createState() => _PilotCardSheetState();
}

class _PilotCardSheetState extends State<_PilotCardSheet>
    with SingleTickerProviderStateMixin {
  PilotLicense? _license;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fetchLicense();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchLicense() async {
    try {
      final data = await Supabase.instance.client
          .from('account_state')
          .select('license_data')
          .eq('user_id', widget.entry.playerId)
          .maybeSingle();
      if (data != null && data['license_data'] != null && mounted) {
        setState(() {
          _license = PilotLicense.fromJson(
            data['license_data'] as Map<String, dynamic>,
          );
        });
      }
    } catch (_) {
      // License fetch is optional — fail silently.
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final planeId = entry.equippedPlaneId ?? 'plane_default';
    final level = entry.level ?? 1;
    final avatarConfig = entry.avatarConfigJson != null
        ? AvatarConfig.fromJson(entry.avatarConfigJson!)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: FlitColors.textMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Credit-card style license (matches LicenseScreen rendering)
          _buildLicenseCard(entry, planeId, level, avatarConfig),
          // Stats row
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(label: 'RANK', value: '#${entry.rank}'),
                Container(width: 1, height: 32, color: FlitColors.cardBorder),
                _StatColumn(label: 'SCORE', value: '${entry.score}'),
                Container(width: 1, height: 32, color: FlitColors.cardBorder),
                _StatColumn(label: 'TIME', value: _formatTime(entry.time)),
              ],
            ),
          ),
          // Round emojis — painted circles for iOS compatibility
          const SizedBox(height: 16),
          entry.roundEmojis != null && entry.roundEmojis!.isNotEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _splitEmojis(entry.roundEmojis!).map((emoji) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _emojiToColor(emoji),
                              _emojiToColor(emoji).withOpacity(0.6),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _emojiToColor(emoji).withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              : const Text(
                  'No round data',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
                ),
          // Milestone progression
          const SizedBox(height: 16),
          _MilestoneBar(score: entry.score),
          // Report button
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showReportDialog(entry),
            icon: const Icon(
              Icons.flag_outlined,
              size: 16,
              color: FlitColors.textMuted,
            ),
            label: const Text(
              'Report Player',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(LeaderboardEntry entry) {
    String? selectedReason;
    final detailsController = TextEditingController();
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
                  'Report @${entry.playerName}',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...ReportReason.all.map(
                  (reason) => RadioListTile<String>(
                    title: Text(
                      ReportReason.label(reason),
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
                if (selectedReason == ReportReason.other) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Additional details (optional)',
                      hintStyle: const TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: FlitColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: FlitColors.cardBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: FlitColors.cardBorder,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
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
                          ? () async {
                              final reason = selectedReason!;
                              final details =
                                  detailsController.text.trim().isEmpty
                                  ? null
                                  : detailsController.text.trim();
                              Navigator.of(dialogContext).pop();
                              try {
                                await ReportService.instance.submitReport(
                                  reportedUserId: entry.playerId,
                                  reason: reason,
                                  details: details,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Report submitted.'),
                                      backgroundColor: FlitColors.success,
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to submit report. Please try again.',
                                      ),
                                      backgroundColor: FlitColors.error,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.accent,
                        foregroundColor: FlitColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => detailsController.dispose());
  }

  /// Credit-card style license card matching the LicenseScreen design.
  Widget _buildLicenseCard(
    LeaderboardEntry entry,
    String planeId,
    int level,
    AvatarConfig? avatarConfig,
  ) {
    final rarity = _license?.rarityTier ?? 'Bronze';
    final rarityColor = _colorForRarity(rarity);
    final isPerfect = rarity == 'Perfect';

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final borderDecoration = isPerfect
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: SweepGradient(
                  center: Alignment.center,
                  startAngle: _shimmerController.value * 2 * math.pi,
                  colors: _perfectGradientColors,
                ),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: rarityColor,
              );

        return Container(
          decoration: borderDecoration,
          padding: const EdgeInsets.all(2.5),
          child: AspectRatio(
            aspectRatio: 85.6 / 54.0, // credit card ratio
            child: Container(
              decoration: BoxDecoration(
                color: FlitColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: title + rarity badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'FLIT PILOT LICENSE',
                          style: TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      if (_license != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rarityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: rarityColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            rarity.toUpperCase(),
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(flex: 1),
                  // Middle row: plane | name/rank/level | avatar
                  Row(
                    children: [
                      // Equipped plane (left)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: FlitColors.backgroundMid,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomPaint(
                          size: const Size(56, 56),
                          painter: PlanePainter(planeId: planeId),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name, rank, level (center)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.playerName,
                              style: const TextStyle(
                                color: FlitColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _aviationRankTitle(level),
                              style: const TextStyle(
                                color: FlitColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Level $level',
                              style: const TextStyle(
                                color: FlitColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Avatar (right)
                      AvatarFromUrl(
                        avatarUrl: entry.avatarUrl,
                        name: entry.playerName,
                        avatarConfig: avatarConfig,
                        size: 56,
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                  // Stat bars — matches LicenseScreen layout with icons,
                  // segmented bars, value/25, clue type, and total boost.
                  if (_license != null) ...[
                    _BottomSheetStatBar(
                      label: _license!.coinBoostLabel,
                      icon: Icons.monetization_on,
                      value: _license!.coinBoost,
                    ),
                    const SizedBox(height: 3),
                    _BottomSheetStatBar(
                      label: _license!.fuelBoostLabel,
                      icon: Icons.local_gas_station,
                      value: _license!.fuelBoost,
                    ),
                    const SizedBox(height: 3),
                    _BottomSheetStatBar(
                      label: _license!.clueChanceLabel,
                      icon: Icons.casino,
                      value: _license!.clueChance,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: FlitColors.accent,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Preferred: ${_license!.preferredClueType[0].toUpperCase()}${_license!.preferredClueType.substring(1)}',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Total: +${_license!.totalBoost}%',
                          style: TextStyle(
                            color: _colorForRarity(_license!.rarityTier),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Center(
                      child: Text(
                        'No pilot license yet',
                        style: TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: FlitColors.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

/// Stat bar for the license card on the pilot card bottom sheet.
///
/// Uses segmented 25-bar display with icon and value/25 text to match the
/// [LicenseScreen] design.
class _BottomSheetStatBar extends StatelessWidget {
  const _BottomSheetStatBar({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final color = _licenseStatColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            Text(
              '$value/25',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 6,
          child: Row(
            children: List.generate(25, (i) {
              final filled = i < value;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 24 ? 0.5 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: filled
                        ? color
                        : FlitColors.backgroundLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

Color _licenseStatColor(int value) {
  if (value >= 25) return const Color(0xFFFFD700);
  if (value >= 21) return const Color(0xFFFF8C00);
  if (value >= 16) return const Color(0xFF9B59B6);
  if (value >= 6) return const Color(0xFF4A90D9);
  return const Color(0xFF6AAB5C);
}

/// Shows score milestone progression on the pilot card.
class _MilestoneBar extends StatelessWidget {
  const _MilestoneBar({required this.score});

  final int score;

  static const List<int> _milestones = [
    1000,
    5000,
    10000,
    25000,
    50000,
    100000,
  ];
  static const List<String> _milestoneLabels = [
    'Novice',
    'Pathfinder',
    'Navigator',
    'Ace',
    'Legend',
    'Immortal',
  ];

  @override
  Widget build(BuildContext context) {
    // Find the current milestone bracket.
    int currentMilestone = 0;
    for (int i = 0; i < _milestones.length; i++) {
      if (score >= _milestones[i]) currentMilestone = i + 1;
    }

    final nextThreshold = currentMilestone < _milestones.length
        ? _milestones[currentMilestone]
        : _milestones.last;
    final prevThreshold = currentMilestone > 0
        ? _milestones[currentMilestone - 1]
        : 0;
    final progress = currentMilestone >= _milestones.length
        ? 1.0
        : ((score - prevThreshold) / (nextThreshold - prevThreshold)).clamp(
            0.0,
            1.0,
          );

    final label = currentMilestone > 0
        ? _milestoneLabels[currentMilestone - 1]
        : 'Rookie';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: FlitColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            if (currentMilestone < _milestones.length)
              Text(
                '${_formatScore(score)} / ${_formatScore(nextThreshold)}',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: FlitColors.cardBorder,
            valueColor: const AlwaysStoppedAnimation(FlitColors.gold),
          ),
        ),
      ],
    );
  }

  static String _formatScore(int s) {
    if (s >= 1000) {
      return '${(s / 1000).toStringAsFixed(s % 1000 == 0 ? 0 : 1)}k';
    }
    return '$s';
  }
}

// =============================================================================
// Clue breakdown bottom sheet
// =============================================================================

class _ClueBreakdownSheet extends StatelessWidget {
  const _ClueBreakdownSheet({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final emojis = entry.roundEmojis ?? '';
    final emojiRunes = emojis.runes.map((r) => String.fromCharCode(r)).toList();
    final details = entry.roundDetails;
    final hasDetails = details != null && details.isNotEmpty;

    // Count each emoji type for the legend.
    int perfect = 0, hinted = 0, heavy = 0, failed = 0;
    for (final r in emojiRunes) {
      switch (r) {
        case '\u{1F7E2}':
          perfect++;
          break;
        case '\u{1F7E1}':
          hinted++;
          break;
        case '\u{1F7E0}':
          heavy++;
          break;
        case '\u{1F534}':
          failed++;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: FlitColors.textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'ROUND BREAKDOWN',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            // Player name + score
            Text(
              entry.playerName,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${entry.score} pts  \u2022  ${_formatTime(entry.time)}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Detailed round cards (when per-round data is available).
            if (hasDetails)
              ...List.generate(details.length, (i) {
                final round = details[i] as Map<String, dynamic>;
                final countryName =
                    round['country_name'] as String? ?? 'Unknown';
                final clueType = round['clue_type'] as String? ?? '?';
                final timeMs = round['time_ms'] as int? ?? 0;
                final roundScore = round['score'] as int? ?? 0;
                final hintsUsed = round['hints_used'] as int? ?? 0;
                final completed = round['completed'] as bool? ?? false;

                final emoji = i < emojiRunes.length ? emojiRunes[i] : '';
                final roundTime = Duration(milliseconds: timeMs);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: completed
                          ? FlitColors.cardBorder
                          : const Color(0xFF8B0000).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Round number + painted circle
                      Column(
                        children: [
                          Text(
                            'R${i + 1}',
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _emojiToColor(emoji),
                                  _emojiToColor(emoji).withOpacity(0.6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _emojiToColor(emoji).withOpacity(0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Country + clue type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              countryName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlitColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _clueTypeLabel(clueType),
                                  style: const TextStyle(
                                    color: FlitColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (hintsUsed > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '$hintsUsed hint${hintsUsed == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      color: hintsUsed <= 2
                                          ? FlitColors.textMuted
                                          : const Color(0xFFCD7F32),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                if (!completed) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    'FAILED',
                                    style: TextStyle(
                                      color: Color(0xFF8B0000),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Score + time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+$roundScore',
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatTime(roundTime),
                            style: const TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              })
            // Fallback: painted circles (legacy scores without details).
            else if (emojiRunes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Detailed clue data is not available for this entry.',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: List.generate(emojiRunes.length, (i) {
                  final color = _emojiToColor(emojiRunes[i]);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R${i + 1}',
                        style: const TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [color, color.withOpacity(0.6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ]
            // No data at all.
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No round-by-round data available',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
                ),
              ),

            const SizedBox(height: 20),
            // Legend
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlitColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FlitColors.cardBorder),
              ),
              child: Column(
                children: [
                  _LegendRow(
                    emoji: '\u{1F7E2}',
                    label: 'Perfect (no hints)',
                    count: perfect,
                  ),
                  _LegendRow(
                    emoji: '\u{1F7E1}',
                    label: '1-2 hints used',
                    count: hinted,
                  ),
                  _LegendRow(
                    emoji: '\u{1F7E0}',
                    label: '3+ hints used',
                    count: heavy,
                  ),
                  _LegendRow(
                    emoji: '\u{1F534}',
                    label: 'Failed (fuel depleted)',
                    count: failed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clueTypeLabel(String clueType) {
    switch (clueType) {
      case 'flag':
        return 'Flag';
      case 'outline':
        return 'Outline';
      case 'borders':
        return 'Borders';
      case 'capital':
        return 'Capital';
      case 'stats':
        return 'Stats';
      default:
        return clueType[0].toUpperCase() + clueType.substring(1);
    }
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.emoji,
    required this.label,
    required this.count,
  });

  final String emoji;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _emojiToColor(emoji),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.leaderboard_outlined,
          size: 64,
          color: FlitColors.textMuted.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'No scores yet',
          style: TextStyle(color: FlitColors.textSecondary, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'Be the first to set a record!',
          style: TextStyle(color: FlitColors.textMuted, fontSize: 14),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: onRetry,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: FlitColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: FlitColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// Helpers
// =============================================================================

String _formatTime(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  final millis = (d.inMilliseconds % 1000) ~/ 10;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _aviationRankTitle(int level) {
  if (level >= 50) return 'Air Marshal';
  if (level >= 40) return 'Wing Commander';
  if (level >= 30) return 'Squadron Leader';
  if (level >= 20) return 'Flight Lieutenant';
  if (level >= 15) return 'Captain';
  if (level >= 10) return 'First Officer';
  if (level >= 5) return 'Pilot Officer';
  if (level >= 3) return 'Cadet';
  return 'Trainee';
}
