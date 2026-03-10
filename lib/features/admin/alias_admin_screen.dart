import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/data/country_aliases.dart';
import '../../game/map/country_data.dart';
import '../../game/map/region.dart';
import '../../game/quiz/alias_service.dart';

/// Admin screen for viewing and editing country/area name aliases.
///
/// Shows every area (countries, US states, UK counties) with all accepted
/// spellings. Baseline aliases can be removed (struck through) and restored.
/// Runtime overrides (stored in SharedPreferences) can be added or removed.
/// All changes flow through [AliasService] and are picked up by the game's
/// [FuzzyMatcher] immediately.
class AliasAdminScreen extends StatefulWidget {
  const AliasAdminScreen({super.key});

  @override
  State<AliasAdminScreen> createState() => _AliasAdminScreenState();
}

class _AliasAdminScreenState extends State<AliasAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showRemoved = false;

  late List<_AliasEntry> _allEntries;

  @override
  void initState() {
    super.initState();
    _buildEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Build the master list of all areas with their aliases.
  void _buildEntries() {
    final entries = <String, _AliasEntry>{};

    // Collect all areas from all regions.
    for (final country in CountryData.countries) {
      final normalized = country.name.toLowerCase().trim();
      entries[normalized] = _AliasEntry(
        canonicalName: country.name,
        normalizedName: normalized,
        code: country.code,
      );
    }

    // US States.
    for (final area in RegionalData.getAreas(GameRegion.usStates)) {
      final normalized = area.name.toLowerCase().trim();
      entries.putIfAbsent(
        normalized,
        () => _AliasEntry(
          canonicalName: area.name,
          normalizedName: normalized,
          code: area.code,
        ),
      );
    }

    // UK Counties.
    for (final area in RegionalData.getAreas(GameRegion.ukCounties)) {
      final normalized = area.name.toLowerCase().trim();
      entries.putIfAbsent(
        normalized,
        () => _AliasEntry(
          canonicalName: area.name,
          normalizedName: normalized,
          code: area.code,
        ),
      );
    }

    // Also add any canonical names from the alias map that aren't
    // already in our entries (edge case: alias keys not matching any area).
    for (final key in AliasService.instance.allCanonicalNames) {
      entries.putIfAbsent(
        key,
        () => _AliasEntry(
          canonicalName: key,
          normalizedName: key,
          code: '??',
        ),
      );
    }

    _allEntries = entries.values.toList()
      ..sort((a, b) => a.canonicalName.compareTo(b.canonicalName));
  }

  List<_AliasEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _allEntries;
    final q = _searchQuery.toLowerCase();
    return _allEntries.where((e) {
      if (e.normalizedName.contains(q)) return true;
      if (e.code.toLowerCase().contains(q)) return true;
      // Also search within aliases.
      final aliases = AliasService.instance.getAliases(e.normalizedName);
      if (aliases.any((a) => a.contains(q))) return true;
      // Also search removed baseline aliases.
      final removed =
          AliasService.instance.getRemovedBaseline(e.normalizedName);
      if (removed.any((a) => a.contains(q))) return true;
      return false;
    }).toList();
  }

  void _showAddAliasDialog(_AliasEntry entry) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.backgroundMid,
        title: Text(
          'Add alias for ${entry.canonicalName}',
          style: const TextStyle(color: FlitColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: FlitColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. drc',
            hintStyle: TextStyle(
                color: FlitColors.textSecondary.withValues(alpha: 0.5)),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: FlitColors.accent.withValues(alpha: 0.4)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: FlitColors.accent, width: 2),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              await AliasService.instance
                  .addAlias(entry.normalizedName, value.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: FlitColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                await AliasService.instance
                    .addAlias(entry.normalizedName, value);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              }
            },
            child:
                const Text('Add', style: TextStyle(color: FlitColors.accent)),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _removeAlias(_AliasEntry entry, String alias) async {
    await AliasService.instance.removeAlias(entry.normalizedName, alias);
    setState(() {});
  }

  Future<void> _restoreBaselineAlias(_AliasEntry entry, String alias) async {
    await AliasService.instance
        .restoreBaselineAlias(entry.normalizedName, alias);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Country Aliases',
            style: TextStyle(color: FlitColors.textPrimary)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(
              _showRemoved
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _showRemoved ? FlitColors.error : FlitColors.textSecondary,
              size: 20,
            ),
            tooltip:
                _showRemoved ? 'Hide removed aliases' : 'Show removed aliases',
            onPressed: () => setState(() => _showRemoved = !_showRemoved),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: FlitColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search countries or aliases...',
                hintStyle: TextStyle(
                    color: FlitColors.textSecondary.withValues(alpha: 0.5)),
                prefixIcon:
                    const Icon(Icons.search, color: FlitColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: FlitColors.accent.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: FlitColors.accent, width: 2),
                ),
                filled: true,
                fillColor: FlitColors.backgroundMid,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          // Count.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filtered.length} areas',
                  style: const TextStyle(
                      color: FlitColors.textSecondary, fontSize: 13),
                ),
                const Spacer(),
                if (_showRemoved)
                  Text(
                    'Showing removed',
                    style: TextStyle(
                      color: FlitColors.error.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // List.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                return _AliasCard(
                  entry: entry,
                  showRemoved: _showRemoved,
                  onAdd: () => _showAddAliasDialog(entry),
                  onRemove: (alias) => _removeAlias(entry, alias),
                  onRestore: (alias) => _restoreBaselineAlias(entry, alias),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AliasEntry {
  const _AliasEntry({
    required this.canonicalName,
    required this.normalizedName,
    required this.code,
  });

  final String canonicalName;
  final String normalizedName;
  final String code;
}

class _AliasCard extends StatelessWidget {
  const _AliasCard({
    required this.entry,
    required this.showRemoved,
    required this.onAdd,
    required this.onRemove,
    required this.onRestore,
  });

  final _AliasEntry entry;
  final bool showRemoved;
  final VoidCallback onAdd;
  final void Function(String alias) onRemove;
  final void Function(String alias) onRestore;

  @override
  Widget build(BuildContext context) {
    final service = AliasService.instance;
    final aliases = service.getAliases(entry.normalizedName);
    final removedBaseline = service.getRemovedBaseline(entry.normalizedName);
    final hasAliases = aliases.isNotEmpty;
    final hasRemoved = removedBaseline.isNotEmpty;

    // Skip entries with no active or removed aliases when not searching.
    if (!hasAliases && !hasRemoved && !showRemoved) {
      // Still show the card for adding.
    }

    return Card(
      color: FlitColors.backgroundMid,
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: country name + code + add button.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.canonicalName}  ',
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  entry.code,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlitColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: FlitColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: FlitColors.accent),
                        SizedBox(width: 2),
                        Text('Add',
                            style: TextStyle(
                                color: FlitColors.accent, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (hasAliases) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: aliases.map((alias) {
                  final isOverride =
                      service.isOverride(entry.normalizedName, alias);
                  final isBaseline =
                      service.isBaseline(entry.normalizedName, alias);
                  return _AliasChip(
                    alias: alias,
                    isOverride: isOverride,
                    isBaseline: isBaseline,
                    isRemoved: false,
                    onRemove: () => onRemove(alias),
                  );
                }).toList(),
              ),
            ],
            // Show removed baseline aliases when toggled.
            if (showRemoved && hasRemoved) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: removedBaseline.map((alias) {
                  return _AliasChip(
                    alias: alias,
                    isOverride: false,
                    isBaseline: true,
                    isRemoved: true,
                    onRestore: () => onRestore(alias),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AliasChip extends StatelessWidget {
  const _AliasChip({
    required this.alias,
    required this.isOverride,
    required this.isBaseline,
    required this.isRemoved,
    this.onRemove,
    this.onRestore,
  });

  final String alias;
  final bool isOverride;
  final bool isBaseline;
  final bool isRemoved;
  final VoidCallback? onRemove;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    if (isRemoved) {
      // Removed baseline — strike-through, muted, with restore button.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: FlitColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: FlitColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_circle_outline,
                size: 11, color: FlitColors.error.withValues(alpha: 0.5)),
            const SizedBox(width: 3),
            Text(
              alias,
              style: TextStyle(
                color: FlitColors.error.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            if (onRestore != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRestore,
                child: Icon(Icons.undo_rounded,
                    size: 14, color: FlitColors.success.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      );
    }

    final chipColor = isOverride ? FlitColors.gold : FlitColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBaseline && !isOverride)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(Icons.lock_open_rounded,
                  size: 10,
                  color: FlitColors.textSecondary.withValues(alpha: 0.6)),
            ),
          Text(
            alias,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 13, color: chipColor),
            ),
          ],
        ],
      ),
    );
  }
}
