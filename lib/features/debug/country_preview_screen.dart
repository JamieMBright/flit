import 'dart:convert';
import 'dart:math' as math;

import 'package:flag/flag.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/map/country_data.dart';

/// Issue types that can be flagged on a country's data.
enum CountryIssue {
  flagMissing('Flag missing'),
  flagIncorrect('Flag incorrect'),
  outlineMissing('Outline missing'),
  outlineTooFewVertices('Too few vertices'),
  outlineIncorrect('Outline incorrect'),
  outlineDistorted('Outline distorted'),
  capitalMissing('Capital missing'),
  capitalIncorrect('Capital incorrect');

  const CountryIssue(this.label);
  final String label;
}

/// Admin preview screen showing every country's flag and outline.
///
/// Allows the admin to mark issues per-country with common problem types,
/// then export all flagged issues as a JSON blob for copy-pasting to a
/// developer.
class CountryPreviewScreen extends StatefulWidget {
  const CountryPreviewScreen({super.key});

  @override
  State<CountryPreviewScreen> createState() => _CountryPreviewScreenState();
}

class _CountryPreviewScreenState extends State<CountryPreviewScreen> {
  /// Country code → set of flagged issues.
  final Map<String, Set<CountryIssue>> _issues = {};

  /// Free-text notes per country code.
  final Map<String, String> _notes = {};

  /// Search filter text.
  String _search = '';

  /// Only show countries with issues.
  bool _showIssuesOnly = false;

  /// Codes known to be unsupported by the flag SVG package.
  static const _unsupportedFlagCodes = {
    'XK',
    'XC',
    'XS',
    'AN',
    'CS',
    'EH',
    'BQ',
    'SX',
    'CW',
    'MF',
    'BL',
    'SS',
    'TP',
  };

  List<CountryShape> get _filtered {
    var list = CountryData.countries;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.code.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_showIssuesOnly) {
      list = list.where((c) => _issues[c.code]?.isNotEmpty ?? false).toList();
    }
    return list;
  }

  int get _issueCount => _issues.values.fold(0, (sum, s) => sum + s.length);

  /// Build a JSON report of all flagged issues.
  String _buildJsonReport() {
    final entries = <Map<String, dynamic>>[];
    for (final entry in _issues.entries) {
      if (entry.value.isEmpty) continue;
      final country = CountryData.getCountry(entry.key);
      final item = <String, dynamic>{
        'code': entry.key,
        'name': country?.name ?? entry.key,
        'issues': entry.value.map((i) => i.label).toList(),
      };
      if (country != null) {
        item['vertexCount'] = country.allPoints.length;
      }
      final note = _notes[entry.key];
      if (note != null && note.isNotEmpty) {
        item['note'] = note;
      }
      entries.add(item);
    }
    entries.sort(
      (a, b) => (a['code'] as String).compareTo(b['code'] as String),
    );
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({'flaggedCountries': entries});
  }

  void _toggleIssue(String code, CountryIssue issue) {
    setState(() {
      final set = _issues.putIfAbsent(code, () => {});
      if (set.contains(issue)) {
        set.remove(issue);
      } else {
        set.add(issue);
      }
    });
  }

  void _showNoteDialog(String code) {
    final ctl = TextEditingController(text: _notes[code] ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: Text(
          'Note for ${CountryData.getCountry(code)?.name ?? code}',
          style: const TextStyle(color: FlitColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          style: const TextStyle(color: FlitColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Add a note…',
            hintStyle: const TextStyle(color: FlitColors.textMuted),
            filled: true,
            fillColor: FlitColors.backgroundMid,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
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
            onPressed: () {
              setState(() {
                final text = ctl.text.trim();
                if (text.isEmpty) {
                  _notes.remove(code);
                } else {
                  _notes[code] = text;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: FlitColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showJsonExport() {
    final json = _buildJsonReport();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: Row(
          children: [
            const Text(
              'Feedback JSON',
              style: TextStyle(color: FlitColors.textPrimary, fontSize: 16),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, color: FlitColors.accent, size: 20),
              tooltip: 'Copy to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    backgroundColor: FlitColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Stack(
            children: [
              SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _issues.clear();
      _notes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final countries = _filtered;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.cardBackground,
        title: const Text(
          'Country Preview',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        actions: [
          if (_issueCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_issueCount',
                    style: const TextStyle(
                      color: FlitColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear all issues',
            onPressed: _issueCount > 0 ? _clearAll : null,
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            tooltip: 'Export feedback JSON',
            onPressed: _issueCount > 0 ? _showJsonExport : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name or code…',
                      hintStyle: const TextStyle(color: FlitColors.textMuted),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: FlitColors.textMuted,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: FlitColors.backgroundMid,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Issues only'),
                  selected: _showIssuesOnly,
                  onSelected: (v) => setState(() => _showIssuesOnly = v),
                  selectedColor: FlitColors.warning.withOpacity(0.3),
                  backgroundColor: FlitColors.backgroundMid,
                  labelStyle: TextStyle(
                    color: _showIssuesOnly
                        ? FlitColors.warning
                        : FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: _showIssuesOnly
                        ? FlitColors.warning.withOpacity(0.5)
                        : FlitColors.cardBorder,
                  ),
                ),
              ],
            ),
          ),

          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${countries.length} countries',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (_issueCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· $_issueCount issues flagged',
                    style: const TextStyle(
                      color: FlitColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Country list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                return _CountryCard(
                  country: country,
                  issues: _issues[country.code] ?? {},
                  hasNote: _notes[country.code]?.isNotEmpty ?? false,
                  isUnsupportedFlag: _unsupportedFlagCodes.contains(
                    country.code,
                  ),
                  onToggleIssue: (issue) => _toggleIssue(country.code, issue),
                  onAddNote: () => _showNoteDialog(country.code),
                );
              },
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

class _CountryCard extends StatefulWidget {
  const _CountryCard({
    required this.country,
    required this.issues,
    required this.hasNote,
    required this.isUnsupportedFlag,
    required this.onToggleIssue,
    required this.onAddNote,
  });

  final CountryShape country;
  final Set<CountryIssue> issues;
  final bool hasNote;
  final bool isUnsupportedFlag;
  final ValueChanged<CountryIssue> onToggleIssue;
  final VoidCallback onAddNote;

  @override
  State<_CountryCard> createState() => _CountryCardState();
}

class _CountryCardState extends State<_CountryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    final vertexCount = c.allPoints.length;
    final hasIssues = widget.issues.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasIssues
                ? FlitColors.warning.withOpacity(0.6)
                : FlitColors.cardBorder,
            width: hasIssues ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Top row: flag + outline + info
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Flag
                    _FlagPreview(
                      code: c.code,
                      isUnsupported: widget.isUnsupportedFlag,
                    ),
                    const SizedBox(width: 12),

                    // Outline
                    SizedBox(
                      width: 80,
                      height: 60,
                      child: c.polygons.isNotEmpty
                          ? CustomPaint(painter: _OutlinePainter(c.polygons))
                          : const Center(
                              child: Text(
                                '—',
                                style: TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: FlitColors.accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c.code,
                                  style: const TextStyle(
                                    color: FlitColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(
                                    color: FlitColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _InfoChip(
                                label: '$vertexCount vertices',
                                color: vertexCount < 20
                                    ? FlitColors.error
                                    : vertexCount < 50
                                    ? FlitColors.warning
                                    : FlitColors.textMuted,
                              ),
                              if (c.capital != null) ...[
                                const SizedBox(width: 6),
                                _InfoChip(
                                  label: c.capital!,
                                  color: FlitColors.textMuted,
                                ),
                              ],
                              if (widget.isUnsupportedFlag) ...[
                                const SizedBox(width: 6),
                                const _InfoChip(
                                  label: 'emoji flag',
                                  color: FlitColors.oceanHighlight,
                                ),
                              ],
                            ],
                          ),
                          if (hasIssues)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: widget.issues
                                    .map(
                                      (i) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: FlitColors.warning.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          i.label,
                                          style: const TextStyle(
                                            color: FlitColors.warning,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Expand indicator
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

            // Expanded: issue checkboxes + note button
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: FlitColors.cardBorder, height: 1),
                    const SizedBox(height: 8),
                    const Text(
                      'FLAG ISSUES',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          [CountryIssue.flagMissing, CountryIssue.flagIncorrect]
                              .map(
                                (issue) => _IssueChip(
                                  issue: issue,
                                  selected: widget.issues.contains(issue),
                                  onTap: () => widget.onToggleIssue(issue),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'OUTLINE ISSUES',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          [
                                CountryIssue.outlineMissing,
                                CountryIssue.outlineTooFewVertices,
                                CountryIssue.outlineIncorrect,
                                CountryIssue.outlineDistorted,
                              ]
                              .map(
                                (issue) => _IssueChip(
                                  issue: issue,
                                  selected: widget.issues.contains(issue),
                                  onTap: () => widget.onToggleIssue(issue),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'OTHER ISSUES',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          [
                                CountryIssue.capitalMissing,
                                CountryIssue.capitalIncorrect,
                              ]
                              .map(
                                (issue) => _IssueChip(
                                  issue: issue,
                                  selected: widget.issues.contains(issue),
                                  onTap: () => widget.onToggleIssue(issue),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 8),
                    // Note button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onAddNote,
                        icon: Icon(
                          widget.hasNote ? Icons.edit_note : Icons.note_add,
                          size: 16,
                          color: widget.hasNote
                              ? FlitColors.accent
                              : FlitColors.textMuted,
                        ),
                        label: Text(
                          widget.hasNote ? 'Edit note' : 'Add note',
                          style: TextStyle(
                            color: widget.hasNote
                                ? FlitColors.accent
                                : FlitColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: widget.hasNote
                                ? FlitColors.accent.withOpacity(0.4)
                                : FlitColors.cardBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Renders an SVG flag or falls back to emoji.
class _FlagPreview extends StatelessWidget {
  const _FlagPreview({required this.code, required this.isUnsupported});

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
          height: 40,
          width: 60,
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
      width: 60,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }
}

/// Renders country outline polygons.
class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.polygons);

  final List<List<Vector2>> polygons;

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

    const padding = 3.0;
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

    canvas.drawPath(
      path,
      Paint()..color = FlitColors.landMass.withOpacity(0.5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = FlitColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) => false;
}

/// Issue toggle chip.
class _IssueChip extends StatelessWidget {
  const _IssueChip({
    required this.issue,
    required this.selected,
    required this.onTap,
  });

  final CountryIssue issue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? FlitColors.warning.withOpacity(0.2)
              : FlitColors.backgroundMid,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? FlitColors.warning.withOpacity(0.6)
                : FlitColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 14,
              color: selected ? FlitColors.warning : FlitColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              issue.label,
              style: TextStyle(
                color: selected ? FlitColors.warning : FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small info chip showing metadata.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: color, fontSize: 10),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
