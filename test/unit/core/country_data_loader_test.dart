import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/map/country_data.dart';

void main() {
  test('loads flattened polygon coordinate pairs', () {
    final firstPoint = CountryData.getCountry('AD')!.polygons.first.first;

    expect(firstPoint.x, closeTo(1.707006, 0.000001));
    expect(firstPoint.y, closeTo(42.502781, 0.000001));
  });
}
