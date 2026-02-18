/// Seasonal events that can override the default vehicle graphic and styling.
enum SeasonalEvent {
  christmas,
  halloween,
  easter,
  summer,
  valentines,
  stPatricks,
  none,
}

/// A seasonal theme that provides a festive vehicle and colour scheme.
///
/// Each theme is active for a fixed calendar window (month/day boundaries).
/// Use [SeasonalTheme.current] or [SeasonalTheme.forDate] to resolve the
/// active theme for a given moment in time.
class SeasonalTheme {
  const SeasonalTheme({
    required this.event,
    required this.vehicleName,
    required this.vehicleDescription,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.accentColor,
    required this.vehicleColorScheme,
  });

  final SeasonalEvent event;
  final String vehicleName;
  final String vehicleDescription;

  /// Inclusive start date (month and day).
  final int startMonth;
  final int startDay;

  /// Inclusive end date (month and day).
  final int endMonth;
  final int endDay;

  /// Primary accent colour as a 32-bit ARGB hex value.
  final int accentColor;

  /// Vehicle colour scheme with keys: `primary`, `secondary`, `detail`.
  final Map<String, int> vehicleColorScheme;

  // ── Predefined seasonal themes ──────────────────────────────────────

  static const List<SeasonalTheme> allThemes = [
    SeasonalTheme(
      event: SeasonalEvent.christmas,
      vehicleName: "Santa's Sleigh",
      vehicleDescription:
          'A jolly red sleigh soaring through the winter skies.',
      startMonth: 12,
      startDay: 13,
      endMonth: 12,
      endDay: 25,
      accentColor: 0xFFCC0000, // red
      vehicleColorScheme: {
        'primary': 0xFFCC0000, // red
        'secondary': 0xFFFFD700, // gold
        'detail': 0xFFFFFFFF, // white
      },
    ),
    SeasonalTheme(
      event: SeasonalEvent.halloween,
      vehicleName: "Witch's Broom",
      vehicleDescription: 'A creaky broomstick trailing wisps of purple smoke.',
      startMonth: 10,
      startDay: 24,
      endMonth: 10,
      endDay: 31,
      accentColor: 0xFF800080, // purple
      vehicleColorScheme: {
        'primary': 0xFF800080, // purple
        'secondary': 0xFFFF8C00, // orange
        'detail': 0xFF1A1A1A, // near-black
      },
    ),
    SeasonalTheme(
      event: SeasonalEvent.easter,
      vehicleName: 'Easter Egg Express',
      vehicleDescription:
          'A pastel-painted carriage overflowing with painted eggs.',
      startMonth: 3,
      startDay: 28,
      endMonth: 4,
      endDay: 10,
      accentColor: 0xFFFFB6C1, // pastel pink
      vehicleColorScheme: {
        'primary': 0xFFFFB6C1, // pastel pink
        'secondary': 0xFFADD8E6, // pastel blue
        'detail': 0xFFFFFACD, // pastel yellow
      },
    ),
    SeasonalTheme(
      event: SeasonalEvent.summer,
      vehicleName: 'Beach Glider',
      vehicleDescription:
          'A sun-kissed hang glider riding warm coastal thermals.',
      startMonth: 6,
      startDay: 21,
      endMonth: 7,
      endDay: 4,
      accentColor: 0xFF00CED1, // cyan
      vehicleColorScheme: {
        'primary': 0xFF00CED1, // cyan
        'secondary': 0xFFFFD700, // yellow
        'detail': 0xFFFFFFFF, // white
      },
    ),
    SeasonalTheme(
      event: SeasonalEvent.valentines,
      vehicleName: "Cupid's Arrow",
      vehicleDescription:
          'A heart-tipped arrow gliding on a trail of rose petals.',
      startMonth: 2,
      startDay: 10,
      endMonth: 2,
      endDay: 14,
      accentColor: 0xFFFF69B4, // pink
      vehicleColorScheme: {
        'primary': 0xFFFF69B4, // pink
        'secondary': 0xFFDC143C, // crimson red
        'detail': 0xFFFFFFFF, // white
      },
    ),
    SeasonalTheme(
      event: SeasonalEvent.stPatricks,
      vehicleName: 'Lucky Clover Copter',
      vehicleDescription:
          'A four-leaf clover spinning its way across emerald hills.',
      startMonth: 3,
      startDay: 14,
      endMonth: 3,
      endDay: 17,
      accentColor: 0xFF228B22, // green
      vehicleColorScheme: {
        'primary': 0xFF228B22, // green
        'secondary': 0xFFFFD700, // gold
        'detail': 0xFFFFFFFF, // white
      },
    ),
  ];

  // ── Lookup helpers ──────────────────────────────────────────────────

  /// Returns the seasonal theme active today (UTC), or `null` if none applies.
  static SeasonalTheme? current() {
    return forDate(DateTime.now().toUtc());
  }

  /// Returns the seasonal theme active on [date], or `null` if none applies.
  ///
  /// Only the month and day of [date] are considered; the year is ignored so
  /// that the same calendar windows apply every year.
  static SeasonalTheme? forDate(DateTime date) {
    final md = date.month * 100 + date.day;

    for (final theme in allThemes) {
      final start = theme.startMonth * 100 + theme.startDay;
      final end = theme.endMonth * 100 + theme.endDay;

      if (start <= end) {
        // Normal range within a single calendar year segment.
        if (md >= start && md <= end) {
          return theme;
        }
      } else {
        // Wraps around year boundary (e.g. Dec 25 -> Jan 5).
        if (md >= start || md <= end) {
          return theme;
        }
      }
    }

    return null;
  }

  // ── Serialisation ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'event': event.name,
    'vehicle_name': vehicleName,
    'vehicle_description': vehicleDescription,
    'start_month': startMonth,
    'start_day': startDay,
    'end_month': endMonth,
    'end_day': endDay,
    'accent_color': accentColor,
    'vehicle_color_scheme': vehicleColorScheme,
  };

  factory SeasonalTheme.fromJson(Map<String, dynamic> json) => SeasonalTheme(
    event: SeasonalEvent.values.firstWhere((e) => e.name == json['event']),
    vehicleName: json['vehicle_name'] as String,
    vehicleDescription: json['vehicle_description'] as String,
    startMonth: json['start_month'] as int,
    startDay: json['start_day'] as int,
    endMonth: json['end_month'] as int,
    endDay: json['end_day'] as int,
    accentColor: json['accent_color'] as int,
    vehicleColorScheme: (json['vehicle_color_scheme'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as int)),
  );
}
