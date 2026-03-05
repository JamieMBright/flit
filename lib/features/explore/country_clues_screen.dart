import 'dart:math' as math;

import 'package:flag/flag.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/clues/clue_types.dart';
import '../../game/map/country_data.dart';

/// Player-facing screen showing all country game clues.
///
/// Each country is shown as a compact card (flag + outline + name) that
/// expands to reveal stats, capital, borders, and a "report" button so
/// players can flag incorrect data.
class CountryCluesScreen extends StatefulWidget {
  const CountryCluesScreen({super.key});

  @override
  State<CountryCluesScreen> createState() => _CountryCluesScreenState();
}

class _CountryCluesScreenState extends State<CountryCluesScreen> {
  String _search = '';
  final TextEditingController _searchCtl = TextEditingController();

  /// Codes known to be unsupported by the flag SVG package.
  static const _unsupportedFlagCodes = {'XC', 'XS', 'AN', 'CS', 'TP'};

  List<CountryShape> get _filtered {
    var list = CountryData.countries;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.code.toLowerCase().contains(q) ||
                (c.capital?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countries = _filtered;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.cardBackground,
        title: const Text(
          'Country Clues',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _search = v.trim()),
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search countries, capitals…',
                hintStyle: const TextStyle(color: FlitColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: FlitColors.textMuted,
                  size: 20,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: FlitColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: FlitColors.backgroundMid,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${countries.length} countries',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Country list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: countries.length,
              itemBuilder: (context, index) => _CountryClueCard(
                country: countries[index],
                isUnsupportedFlag: _unsupportedFlagCodes.contains(
                  countries[index].code,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Country card
// ─────────────────────────────────────────────────────────────────────────────

class _CountryClueCard extends StatefulWidget {
  const _CountryClueCard({
    required this.country,
    required this.isUnsupportedFlag,
  });

  final CountryShape country;
  final bool isUnsupportedFlag;

  @override
  State<_CountryClueCard> createState() => _CountryClueCardState();
}

class _CountryClueCardState extends State<_CountryClueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    final vertexCount = c.allPoints.length;
    final stats = Clue.getAllCountryStats(c.code);
    final neighbors = Clue.getNeighbors(c.code);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            // Collapsed row: flag + outline + name
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Flag
                    _FlagWidget(
                      code: c.code,
                      isUnsupported: widget.isUnsupportedFlag,
                    ),
                    const SizedBox(width: 10),

                    // Outline
                    SizedBox(
                      width: 56,
                      height: 42,
                      child: c.polygons.isNotEmpty
                          ? CustomPaint(
                              painter: _OutlinePainter(
                                c.polygons,
                                quality: vertexCount >= 70
                                    ? _OutlineQuality.good
                                    : vertexCount >= 30
                                    ? _OutlineQuality.fair
                                    : _OutlineQuality.poor,
                              ),
                            )
                          : const Center(
                              child: Text(
                                '—',
                                style: TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),

                    // Name + capital preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (c.capital != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              c.capital!,
                              style: const TextStyle(
                                color: FlitColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Expand arrow
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: FlitColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded details
            if (_expanded)
              _ExpandedDetails(
                country: c,
                stats: stats,
                neighbors: neighbors,
                vertexCount: vertexCount,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded details panel
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({
    required this.country,
    required this.stats,
    required this.neighbors,
    required this.vertexCount,
  });

  final CountryShape country;
  final Map<String, String> stats;
  final List<String> neighbors;
  final int vertexCount;

  static const _statLabels = <String, String>{
    'population': 'Population',
    'continent': 'Continent',
    'currency': 'Currency',
    'religion': 'Religion',
    'headOfState': 'Head of State',
    'sport': 'Popular Sport',
    'language': 'Language',
    'celebrity': 'Famous Person',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: FlitColors.cardBorder, height: 1),
          const SizedBox(height: 10),

          // Capital
          if (country.capital != null)
            _DetailRow(
              icon: Icons.location_city,
              label: 'Capital',
              value: country.capital!,
            ),

          // Borders / neighbors
          if (neighbors.isNotEmpty)
            _DetailRow(
              icon: Icons.share_location,
              label: 'Borders',
              value: neighbors.join(', '),
            ),

          // Stats
          ...stats.entries.map((e) {
            final label = _statLabels[e.key] ?? e.key;
            return _DetailRow(
              icon: _iconForStat(e.key),
              label: label,
              value: e.value,
            );
          }),

          // Outline quality
          _DetailRow(
            icon: Icons.pentagon_outlined,
            label: 'Outline Detail',
            value: '$vertexCount vertices',
            valueColor: vertexCount >= 70
                ? FlitColors.success
                : vertexCount >= 30
                ? FlitColors.warning
                : FlitColors.error,
          ),

          const SizedBox(height: 8),

          // Report button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showReportDialog(context),
              icon: const Icon(
                Icons.flag_outlined,
                size: 16,
                color: FlitColors.textMuted,
              ),
              label: const Text(
                'Report Issue',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForStat(String key) {
    switch (key) {
      case 'population':
        return Icons.people;
      case 'continent':
        return Icons.public;
      case 'currency':
        return Icons.payments;
      case 'religion':
        return Icons.church;
      case 'headOfState':
        return Icons.account_balance;
      case 'sport':
        return Icons.sports_soccer;
      case 'language':
        return Icons.translate;
      case 'celebrity':
        return Icons.star;
      default:
        return Icons.info_outline;
    }
  }

  void _showReportDialog(BuildContext context) {
    final issueTypes = [
      'Flag is incorrect',
      'Outline is wrong',
      'Capital is incorrect',
      'Border countries are wrong',
      'Stats are inaccurate',
      'Other',
    ];
    String? selectedIssue;
    final notesCtl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FlitColors.cardBackground,
          title: Text(
            'Report: ${country.name}',
            style: const TextStyle(color: FlitColors.textPrimary, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What seems wrong?',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ...issueTypes.map(
                  (issue) => RadioListTile<String>(
                    title: Text(
                      issue,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    value: issue,
                    groupValue: selectedIssue,
                    activeColor: FlitColors.accent,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => setDialogState(() => selectedIssue = v),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtl,
                  maxLines: 2,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Details (optional)…',
                    hintStyle: const TextStyle(color: FlitColors.textMuted),
                    filled: true,
                    fillColor: FlitColors.backgroundMid,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: FlitColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: selectedIssue == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _submitReport(context, selectedIssue!, notesCtl.text);
                    },
              child: const Text(
                'Submit',
                style: TextStyle(color: FlitColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport(BuildContext context, String issue, String notes) {
    // Copy the report to clipboard for now — when a backend endpoint exists
    // this can POST instead.
    final report = {
      'country': country.code,
      'name': country.name,
      'issue': issue,
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    Clipboard.setData(ClipboardData(text: report.toString()));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks! Report submitted for review.'),
        backgroundColor: FlitColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail row widget
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: FlitColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? FlitColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flag widget
// ─────────────────────────────────────────────────────────────────────────────

class _FlagWidget extends StatelessWidget {
  const _FlagWidget({required this.code, required this.isUnsupported});

  final String code;
  final bool isUnsupported;

  @override
  Widget build(BuildContext context) {
    if (code.length != 2 || isUnsupported) {
      return _emojiFallback();
    }
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Flag.fromString(
          code,
          height: 32,
          width: 48,
          fit: BoxFit.contain,
          borderRadius: 4,
        ),
      );
    } catch (_) {
      return _emojiFallback();
    }
  }

  Widget _emojiFallback() {
    final codeUnits = code.toUpperCase().codeUnits;
    final emoji = String.fromCharCodes(codeUnits.map((c) => c + 127397));
    return Container(
      width: 48,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outline painter
// ─────────────────────────────────────────────────────────────────────────────

enum _OutlineQuality { good, fair, poor }

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.polygons, {this.quality = _OutlineQuality.good});

  final List<List<Vector2>> polygons;
  final _OutlineQuality quality;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty || size.isEmpty) return;

    final firstPt = polygons.first.first;
    var minX = firstPt.x;
    var maxX = firstPt.x;
    var minY = firstPt.y;
    var maxY = firstPt.y;
    for (final poly in polygons) {
      for (final p in poly) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    if (rangeX == 0 || rangeY == 0) return;

    const padding = 2.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;
    final scale = math.min(drawW / rangeX, drawH / rangeY);
    final offsetX = padding + (drawW - rangeX * scale) / 2;
    final offsetY = padding + (drawH - rangeY * scale) / 2;

    final path = Path();
    for (final poly in polygons) {
      for (var i = 0; i < poly.length; i++) {
        final x = offsetX + (poly[i].x - minX) * scale;
        final y = offsetY + (maxY - poly[i].y) * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    final fillColor = quality == _OutlineQuality.good
        ? FlitColors.landMass.withOpacity(0.5)
        : quality == _OutlineQuality.fair
        ? FlitColors.warning.withOpacity(0.25)
        : FlitColors.error.withOpacity(0.2);

    final strokeColor = quality == _OutlineQuality.good
        ? FlitColors.accent
        : quality == _OutlineQuality.fair
        ? FlitColors.warning
        : FlitColors.error;

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      polygons != old.polygons || quality != old.quality;
}
