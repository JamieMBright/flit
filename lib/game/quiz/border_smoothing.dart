import 'dart:ui';

/// Chaikin's corner-cutting algorithm for polygon smoothing.
///
/// Each iteration replaces sharp corners with smoother curves by inserting
/// 25% and 75% interpolation points between consecutive vertices.
/// Two iterations is sufficient for visually smooth borders without
/// excessive vertex count.
///
/// This is used by all map renderers (Uncharted, Flight School US,
/// Flight School regions) to ensure consistent border quality.
List<Offset> chaikinSmooth(List<Offset> points, [int iterations = 2]) {
  if (points.length < 3) return points;
  var current = points;
  for (var iter = 0; iter < iterations; iter++) {
    final next = <Offset>[];
    for (var i = 0; i < current.length; i++) {
      final p0 = current[i];
      final p1 = current[(i + 1) % current.length];
      // 25% and 75% interpolation points.
      next.add(Offset(
        p0.dx * 0.75 + p1.dx * 0.25,
        p0.dy * 0.75 + p1.dy * 0.25,
      ));
      next.add(Offset(
        p0.dx * 0.25 + p1.dx * 0.75,
        p0.dy * 0.25 + p1.dy * 0.75,
      ));
    }
    current = next;
  }
  return current;
}

/// Complete set of ISO codes for micro-states, small islands, and territories
/// that are always treated as "tiny" on map views regardless of zoom level.
///
/// Shared across all map renderers so that tiny-area handling is consistent.
const Set<String> alwaysTinyCodes = {
  // European micro-states
  'AD', // Andorra
  'GI', // Gibraltar
  'GG', // Guernsey
  'IM', // Isle of Man
  'JE', // Jersey
  'LI', // Liechtenstein
  'LU', // Luxembourg
  'MC', // Monaco
  'MT', // Malta
  'SM', // San Marino
  'VA', // Vatican City

  // Asian small states
  'BH', // Bahrain
  'BN', // Brunei
  'MV', // Maldives
  'QA', // Qatar
  'SG', // Singapore
  'TL', // Timor-Leste

  // African island nations / small states
  'CV', // Cape Verde
  'KM', // Comoros
  'DJ', // Djibouti
  'GQ', // Equatorial Guinea
  'GM', // Gambia
  'GW', // Guinea-Bissau
  'LS', // Lesotho
  'MU', // Mauritius
  'RW', // Rwanda
  'ST', // São Tomé and Príncipe
  'SC', // Seychelles
  'SZ', // Eswatini (Swaziland)

  // Pacific / Oceania island nations
  'FJ', // Fiji
  'FM', // Micronesia
  'KI', // Kiribati
  'MH', // Marshall Islands
  'NR', // Nauru
  'PW', // Palau
  'SB', // Solomon Islands
  'TO', // Tonga
  'TV', // Tuvalu
  'VU', // Vanuatu
  'WS', // Samoa

  // Caribbean island nations
  'AG', // Antigua and Barbuda
  'BB', // Barbados
  'DM', // Dominica
  'GD', // Grenada
  'KN', // Saint Kitts and Nevis
  'LC', // Saint Lucia
  'VC', // Saint Vincent and the Grenadines
  'TT', // Trinidad and Tobago

  // Middle East small states
  'KW', // Kuwait
  'LB', // Lebanon
  'PS', // Palestine

  // Other small states
  'BT', // Bhutan
  'SV', // El Salvador
  'BZ', // Belize
};
