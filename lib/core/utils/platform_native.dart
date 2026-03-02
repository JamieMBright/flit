import 'dart:io' as io;

/// Native implementation — exports dart:io Platform.
class Platform {
  static bool get isIOS => io.Platform.isIOS;
  static bool get isAndroid => io.Platform.isAndroid;
}
