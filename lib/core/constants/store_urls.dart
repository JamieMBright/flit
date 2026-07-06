/// Central place for external store / policy URLs.
///
/// Keep every hardcoded external URL here so there is a single source of truth
/// for app-store review and so placeholders are easy to find and replace.
class StoreUrls {
  StoreUrls._();

  /// Android Play Store listing. The package name is correct and final, so this
  /// URL works today (the listing resolves once the app is published).
  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.jamiembright.flit';

  /// iOS App Store listing.
  ///
  /// TODO(store): real IDs — replace `id0000000000` with the real numeric
  /// App Store ID once the app is registered in App Store Connect.
  static const String appStore = 'https://apps.apple.com/app/flit/id0000000000';

  /// Public privacy policy (hosted on Vercel alongside the error endpoint).
  static const String privacy = 'https://flit-olive.vercel.app/privacy';

  /// Public terms of service.
  static const String terms = 'https://flit-olive.vercel.app/terms';

  /// Support contact used by the banned/appeal screen.
  static const String supportEmail = 'support@flit.app';
}
