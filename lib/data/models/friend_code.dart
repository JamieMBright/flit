/// Helpers for the shareable per-player friend code (see the
/// `20260707_friend_codes.sql` migration).
///
/// Codes are 6 characters from a Crockford-style base32 alphabet
/// (`0-9A-Z` minus the visually ambiguous `I`, `L`, `O`, `U`). We normalise
/// user input generously — strip spaces/dashes, uppercase, and fold the
/// ambiguous letters onto their look-alikes — so a code a friend reads aloud
/// or types with a stray dash still resolves.
abstract final class FriendCode {
  /// The unambiguous alphabet codes are generated from.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Canonical code length.
  static const int length = 6;

  /// Normalise raw user input into the canonical stored form, or return null
  /// if it can't be a valid code.
  ///
  /// - Uppercases and drops anything that isn't alphanumeric (so `flit-d456`,
  ///   `D456 3D`, `d4563d` all collapse to `D4563D`).
  /// - Folds common misreads onto the canonical alphabet: `I`/`L`→`1`,
  ///   `O`→`0`, `U`→`V`.
  /// - Requires exactly [length] characters, all in [alphabet].
  static String? normalize(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
    final folded = cleaned
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0')
        .replaceAll('U', 'V');
    if (folded.length != length) return null;
    for (final unit in folded.codeUnits) {
      if (!alphabet.contains(String.fromCharCode(unit))) return null;
    }
    return folded;
  }

  /// Whether [raw] normalises to a valid code.
  static bool isValid(String raw) => normalize(raw) != null;

  /// Format a stored code for display, e.g. `D4563D` → `D45-63D`.
  /// Passes through anything that isn't a canonical 6-char code unchanged.
  static String format(String? code) {
    if (code == null) return '';
    final normalized = normalize(code);
    if (normalized == null) return code;
    return '${normalized.substring(0, 3)}-${normalized.substring(3)}';
  }
}
