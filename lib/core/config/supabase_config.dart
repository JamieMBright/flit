/// Supabase project configuration.
///
/// The URL and anon key are public values — safe to embed in client code.
/// Override at build time with `--dart-define` if needed:
///   flutter run --dart-define=SUPABASE_URL=https://...
///   flutter run --dart-define=SUPABASE_ANON_KEY=...
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zrffgpkscdaybfhujioc.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_AnlV4Gngx7a5z3KwqV7F9w_-4rQYEJs',
  );

  /// The GitHub Pages URL users return to after an auth email callback.
  /// Override via `--dart-define=SITE_URL=https://your-app.com`.
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://jamiembright.github.io/flit/',
  );
}
