import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/country_data_loader.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await CountryDataLoader().load();
  await testMain();
}
