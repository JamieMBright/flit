import 'dart:math' as math;

import 'package:flag/flag.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/services/clue_report_service.dart';
import '../../game/clues/clue_types.dart';
import '../../game/data/canada_clues.dart';
import '../../game/data/ireland_clues.dart';
import '../../game/data/uk_clues.dart';
import '../../game/data/us_state_clues.dart';
import '../../game/map/country_data.dart';
import '../../game/map/region.dart';

/// Player-facing screen showing all game clues across tabs.
///
/// Tabs: All World | Regions | Sub-national
/// Each tab shows the clue data used in-game for that category,
/// with a region filter dropdown where applicable.
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

  /// Continental/international regions (for the Regions tab).
  static const _continentalRegions = <({String label, GameRegion region})>[
    (label: 'Europe', region: GameRegion.europe),
    (label: 'Asia', region: GameRegion.asia),
    (label: 'Africa', region: GameRegion.africa),
    (label: 'Latin America', region: GameRegion.latinAmerica),
    (label: 'Oceania', region: GameRegion.oceania),
    (label: 'Caribbean', region: GameRegion.caribbean),
  ];

  /// Sub-national regions (for the Sub-national tab).
  static const _subNationalRegions = <({String label, GameRegion region})>[
    (label: 'US States', region: GameRegion.usStates),
    (label: 'UK Counties', region: GameRegion.ukCounties),
    (label: 'Ireland', region: GameRegion.ireland),
    (label: 'Canada', region: GameRegion.canadianProvinces),
  ];

  /// Currently selected region filter for the Regions tab.
  GameRegion? _selectedContinental;

  /// Currently selected region filter for the Sub-national tab.
  GameRegion? _selectedSubNational;

  List<CountryShape> get _filteredCountries {
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

  List<RegionalArea> _filteredAreas(GameRegion region) {
    var list = RegionalData.getAreas(region);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.code.toLowerCase().contains(q) ||
                (a.capital?.toLowerCase().contains(q) ?? false),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.cardBackground,
          title: const Text(
            'Clues',
            style: TextStyle(color: FlitColors.textPrimary),
          ),
          iconTheme: const IconThemeData(color: FlitColors.textPrimary),
          bottom: const TabBar(
            labelColor: FlitColors.accent,
            unselectedLabelColor: FlitColors.textMuted,
            indicatorColor: FlitColors.accent,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'All World'),
              Tab(text: 'Regions'),
              Tab(text: 'Sub-national'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search bar (shared across tabs)
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
                  hintText: 'Search…',
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

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  // All World tab
                  _CountriesTab(
                    countries: _filteredCountries,
                    unsupportedFlags: _unsupportedFlagCodes,
                  ),

                  // Regions tab (continental with filter)
                  _FilteredRegionalTab(
                    regions: _continentalRegions,
                    selectedRegion: _selectedContinental,
                    onRegionChanged: (r) =>
                        setState(() => _selectedContinental = r),
                    filteredAreas: _selectedContinental != null
                        ? _filteredAreas(_selectedContinental!)
                        : null,
                  ),

                  // Sub-national tab (with filter)
                  _FilteredRegionalTab(
                    regions: _subNationalRegions,
                    selectedRegion: _selectedSubNational,
                    onRegionChanged: (r) =>
                        setState(() => _selectedSubNational = r),
                    filteredAreas: _selectedSubNational != null
                        ? _filteredAreas(_selectedSubNational!)
                        : null,
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
// Countries tab
// ─────────────────────────────────────────────────────────────────────────────

class _CountriesTab extends StatelessWidget {
  const _CountriesTab({
    required this.countries,
    required this.unsupportedFlags,
  });

  final List<CountryShape> countries;
  final Set<String> unsupportedFlags;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary + outline quality legend
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
              const Spacer(),
              _LegendDot(color: FlitColors.accent, label: 'Good'),
              const SizedBox(width: 8),
              _LegendDot(color: FlitColors.warning, label: 'Fair'),
              const SizedBox(width: 8),
              _LegendDot(color: FlitColors.error, label: 'Poor'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Outline quality — based on polygon detail',
            style: TextStyle(
              color: FlitColors.textMuted.withOpacity(0.6),
              fontSize: 10,
            ),
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
              isUnsupportedFlag: unsupportedFlags.contains(
                countries[index].code,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Regional / flight school tab
// ─────────────────────────────────────────────────────────────────────────────

class _RegionalTab extends StatelessWidget {
  const _RegionalTab({required this.region, required this.areas});

  final GameRegion region;
  final List<RegionalArea> areas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary + outline quality legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${areas.length} areas',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _LegendDot(color: FlitColors.accent, label: 'Good'),
              const SizedBox(width: 8),
              _LegendDot(color: FlitColors.warning, label: 'Fair'),
              const SizedBox(width: 8),
              _LegendDot(color: FlitColors.error, label: 'Poor'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Outline quality — based on polygon detail',
            style: TextStyle(
              color: FlitColors.textMuted.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: areas.length,
            itemBuilder: (context, index) => _RegionalClueCard(
              area: areas[index],
              region: region,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtered regional tab (used by Regions and Sub-national tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _FilteredRegionalTab extends StatelessWidget {
  const _FilteredRegionalTab({
    required this.regions,
    required this.selectedRegion,
    required this.onRegionChanged,
    required this.filteredAreas,
  });

  final List<({String label, GameRegion region})> regions;
  final GameRegion? selectedRegion;
  final ValueChanged<GameRegion?> onRegionChanged;
  final List<RegionalArea>? filteredAreas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Region filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final r = regions[index];
                final isSelected = selectedRegion == r.region;
                return FilterChip(
                  label: Text(
                    r.label,
                    style: TextStyle(
                      color: isSelected
                          ? FlitColors.backgroundDark
                          : FlitColors.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    onRegionChanged(isSelected ? null : r.region);
                  },
                  selectedColor: FlitColors.accent,
                  backgroundColor: FlitColors.backgroundMid,
                  checkmarkColor: FlitColors.backgroundDark,
                  side: BorderSide(
                    color:
                        isSelected ? FlitColors.accent : FlitColors.cardBorder,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ),

        // Content: prompt or area list
        Expanded(
          child: selectedRegion == null
              ? _buildRegionGrid()
              : _RegionalTab(
                  region: selectedRegion!,
                  areas: filteredAreas ?? const [],
                ),
        ),
      ],
    );
  }

  /// Grid of region cards shown when no filter is selected.
  Widget _buildRegionGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: regions.length,
        itemBuilder: (context, index) {
          final r = regions[index];
          final areaCount = RegionalData.getAreas(r.region).length;
          return Material(
            color: FlitColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onRegionChanged(r.region),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FlitColors.cardBorder),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.label,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$areaCount areas',
                      style: const TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Regional area clue card
// ─────────────────────────────────────────────────────────────────────────────

class _RegionalClueCard extends StatefulWidget {
  const _RegionalClueCard({required this.area, required this.region});

  final RegionalArea area;
  final GameRegion region;

  @override
  State<_RegionalClueCard> createState() => _RegionalClueCardState();
}

class _RegionalClueCardState extends State<_RegionalClueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.area;

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
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Outline
                    SizedBox(
                      width: 56,
                      height: 42,
                      child: a.points.isNotEmpty
                          ? CustomPaint(
                              painter: _OutlinePainter(
                                [a.points],
                                quality: a.points.length >= 70
                                    ? _OutlineQuality.good
                                    : a.points.length >= 30
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (a.capital != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              a.capital!,
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
            if (_expanded) _buildRegionalDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalDetails(BuildContext context) {
    final code = widget.area.code;
    final rows = <Widget>[];

    switch (widget.region) {
      case GameRegion.usStates:
        final d = UsStateClues.data[code];
        if (d != null) {
          rows.add(_DetailRow(
            icon: Icons.badge,
            label: 'Nickname',
            value: d.nickname,
          ));
          if (d.sportsTeams.isNotEmpty) {
            rows.add(_DetailRow(
              icon: Icons.sports,
              label: 'Sports',
              value: d.sportsTeams.join(', '),
            ));
          }
          rows.add(_DetailRow(
            icon: Icons.landscape,
            label: 'Landmark',
            value: d.famousLandmark,
          ));
          rows.add(_DetailRow(
            icon: Icons.format_quote,
            label: 'Motto',
            value: d.motto,
          ));
          if (d.senators.isNotEmpty) {
            rows.add(_DetailRow(
              icon: Icons.account_balance,
              label: 'Senators',
              value: d.senators.join(', '),
            ));
          }
          rows.add(_DetailRow(
            icon: Icons.pets,
            label: 'State Bird',
            value: d.stateBird,
          ));
          rows.add(_DetailRow(
            icon: Icons.local_florist,
            label: 'State Flower',
            value: d.stateFlower,
          ));
          if (d.celebrities.isNotEmpty) {
            rows.add(_DetailRow(
              icon: Icons.star,
              label: 'Celebrities',
              value: d.celebrities.join(', '),
            ));
          }
        }
        break;
      case GameRegion.ukCounties:
        final d = UkClues.data[code];
        if (d != null) {
          rows.add(_DetailRow(
            icon: Icons.flag,
            label: 'Country',
            value: d.country,
          ));
          rows.add(_DetailRow(
            icon: Icons.badge,
            label: 'Nickname',
            value: d.nickname,
          ));
          rows.add(_DetailRow(
            icon: Icons.star,
            label: 'Famous Person',
            value: d.famousPerson,
          ));
          rows.add(_DetailRow(
            icon: Icons.landscape,
            label: 'Landmark',
            value: d.famousLandmark,
          ));
          rows.add(_DetailRow(
            icon: Icons.sports_soccer,
            label: 'Football',
            value: d.footballTeam,
          ));
        }
        break;
      case GameRegion.ireland:
        final d = IrelandClues.data[code];
        if (d != null) {
          rows.add(_DetailRow(
            icon: Icons.map,
            label: 'Province',
            value: d.province,
          ));
          rows.add(_DetailRow(
            icon: Icons.badge,
            label: 'Nickname',
            value: d.nickname,
          ));
          rows.add(_DetailRow(
            icon: Icons.star,
            label: 'Famous Person',
            value: d.famousPerson,
          ));
          rows.add(_DetailRow(
            icon: Icons.landscape,
            label: 'Landmark',
            value: d.famousLandmark,
          ));
          rows.add(_DetailRow(
            icon: Icons.sports,
            label: 'GAA Team',
            value: d.gaaTeam,
          ));
        }
        break;
      case GameRegion.canadianProvinces:
        final d = CanadaClues.data[code];
        if (d != null) {
          rows.add(_DetailRow(
            icon: Icons.badge,
            label: 'Nickname',
            value: d.nickname,
          ));
          rows.add(_DetailRow(
            icon: Icons.account_balance,
            label: 'Premier',
            value: d.premier,
          ));
          rows.add(_DetailRow(
            icon: Icons.landscape,
            label: 'Landmark',
            value: d.famousLandmark,
          ));
          if (d.sportsTeams.isNotEmpty) {
            rows.add(_DetailRow(
              icon: Icons.sports,
              label: 'Sports',
              value: d.sportsTeams.join(', '),
            ));
          }
        }
        break;
      default:
        break;
    }

    if (widget.area.population != null && widget.area.population! > 0) {
      final pop = widget.area.population!;
      final popStr = pop >= 1000000
          ? '${(pop / 1000000).toStringAsFixed(1)}M'
          : pop >= 1000
              ? '${(pop / 1000).toStringAsFixed(0)}K'
              : pop.toString();
      rows.add(_DetailRow(
        icon: Icons.people,
        label: 'Population',
        value: popStr,
      ));
    }

    if (widget.area.funFact != null) {
      rows.add(_DetailRow(
        icon: Icons.lightbulb_outline,
        label: 'Fun Fact',
        value: widget.area.funFact!,
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: FlitColors.cardBorder, height: 1),
          const SizedBox(height: 10),
          ...rows,
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
    'sport': 'Most Popular Sport',
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

  Future<void> _submitReport(
    BuildContext context,
    String issue,
    String notes,
  ) async {
    try {
      await ClueReportService.instance.submitReport(
        countryCode: country.code,
        countryName: country.name,
        issue: issue,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks! Report submitted for review.'),
          backgroundColor: FlitColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      // Fallback: copy to clipboard if submission fails (e.g. not logged in).
      final report = {
        'country': country.code,
        'name': country.name,
        'issue': issue,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
      Clipboard.setData(ClipboardData(text: report.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not submit online. Report copied to clipboard.',
          ),
          backgroundColor: FlitColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
    // Standard ISO codes can produce regional indicator emoji; custom codes
    // (XC, XS, etc.) produce unrecognisable symbols so show a map icon instead.
    if (code.length == 2 && !code.startsWith('X')) {
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
    return Container(
      width: 48,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flag, color: FlitColors.textMuted, size: 14),
          Text(
            code,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      );
}
