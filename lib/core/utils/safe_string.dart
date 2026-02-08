/// Utilities for sanitizing user-facing strings in Flit.
///
/// Handles two concerns:
/// 1. **Runtime input sanitization** – clean player-entered text (usernames,
///    chat, display names) before display or storage.
/// 2. **Safe Dart literal generation** – escape strings for code-gen pipelines
///    so they never produce unterminated literals.
class SafeString {
  const SafeString._();

  // ---------------------------------------------------------------------------
  // Runtime input sanitization
  // ---------------------------------------------------------------------------

  /// Sanitize arbitrary user input for safe display.
  ///
  /// - Strips ASCII control characters (U+0000–U+001F, U+007F) except newline.
  /// - Collapses multiple spaces/tabs into one space.
  /// - Trims leading/trailing whitespace.
  /// - Truncates to [maxLength] if provided.
  static String sanitize(String input, {int? maxLength}) {
    // Strip control characters except newline (\n = 0x0A).
    var result = input.replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]'), '');

    // Collapse runs of whitespace (spaces, tabs) into single space.
    result = result.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Trim.
    result = result.trim();

    // Truncate.
    if (maxLength != null && result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  /// Sanitize a username for safe use in-game.
  ///
  /// - Strips everything except alphanumeric, underscore, hyphen.
  /// - Enforces length between [minLength] (default 3) and [maxLength]
  ///   (default 20).
  /// - Returns null if the result is too short after sanitization.
  static String? sanitizeUsername(
    String input, {
    int minLength = 3,
    int maxLength = 20,
  }) {
    // Keep only safe characters.
    var result = input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');

    // Trim and truncate.
    result = result.trim();
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    // Too short after sanitization → invalid.
    if (result.length < minLength) return null;

    return result;
  }

  /// Sanitize a display name (more permissive than username).
  ///
  /// Allows letters, numbers, spaces, hyphens, apostrophes, and periods.
  /// Strips everything else.
  static String sanitizeDisplayName(String input, {int maxLength = 40}) {
    // Allow common name characters.
    var result = input.replaceAll(RegExp(r"[^a-zA-Z0-9 '\-.]"), '');

    // Collapse whitespace.
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Truncate.
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Dart literal safety (for code-gen / data pipelines)
  // ---------------------------------------------------------------------------

  /// Escape a string so it can be safely embedded in a single-quoted Dart
  /// string literal.
  ///
  /// Escapes: `\` → `\\`, `'` → `\'`, `$` → `\$`.
  static String escapeSingleQuoted(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');

  /// Escape a string so it can be safely embedded in a double-quoted Dart
  /// string literal.
  ///
  /// Escapes: `\` → `\\`, `"` → `\"`, `$` → `\$`.
  static String escapeDoubleQuoted(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$');

  /// Returns true if [value] can safely be placed inside single quotes
  /// without any escaping (i.e., it contains no `'`, `\`, or `$`).
  static bool isSafeSingleQuoted(String value) =>
      !value.contains("'") && !value.contains(r'\') && !value.contains(r'$');

  /// Wrap a string in the safest Dart literal form:
  /// - If it has no apostrophes → single-quoted with minimal escaping.
  /// - If it has apostrophes but no double quotes → double-quoted.
  /// - Otherwise → single-quoted with full escaping.
  static String toDartLiteral(String value) {
    if (isSafeSingleQuoted(value)) return "'$value'";
    if (!value.contains('"')) return '"${escapeDoubleQuoted(value)}"';
    return "'${escapeSingleQuoted(value)}'";
  }
}
