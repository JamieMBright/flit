import 'dart:io' show ProcessInfo;

/// Native implementation — uses dart:io ProcessInfo.
int getNativeRss() => ProcessInfo.currentRss;
