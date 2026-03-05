/// A smart profanity filter for usernames and text content in Flit.
///
/// Uses word-boundary detection, leetspeak normalization, and a curated
/// whitelist to avoid false positives on innocent words like "Lasse",
/// "Assassin", or "Scunthorpe".
class ProfanityFilter {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static final ProfanityFilter instance = ProfanityFilter._();
  ProfanityFilter._();

  // ---------------------------------------------------------------------------
  // Username validation constants
  // ---------------------------------------------------------------------------
  static const int _minUsernameLength = 3;
  static const int _maxUsernameLength = 20;
  static final RegExp _validUsernameChars = RegExp(r'^[a-zA-Z0-9_\-]+$');

  // ---------------------------------------------------------------------------
  // Role / impersonation terms
  // ---------------------------------------------------------------------------
  static const List<String> _impersonationTerms = [
    'admin',
    'administrator',
    'moderator',
    'mod',
    'official',
    'staff',
    'developer',
    'dev',
    'system',
    'sysadmin',
    'gamemaster',
    'gm',
    'support',
    'helpdesk',
    'owner',
    'founder',
    'ceo',
    'flit_team',
    'flitofficial',
    'flitadmin',
    'flitmod',
  ];

  // ---------------------------------------------------------------------------
  // Whitelist - innocent words that contain profane substrings
  // ---------------------------------------------------------------------------
  static const List<String> _whitelist = [
    'assassin',
    'class',
    'classic',
    'pass',
    'passage',
    'passenger',
    'compass',
    'grass',
    'brass',
    'glass',
    'lasse',
    'bass',
    'mass',
    'cockpit',
    'cocktail',
    'cockatoo',
    'hancock',
    'peacock',
    'woodcock',
    'scunthorpe',
    'penistone',
    'sussex',
    'essex',
    'middlesex',
    'buttress',
    'button',
    'butter',
    'butterscotch',
    'analyst',
    'therapist',
    'shitake',
    'flicker',
    'assume',
    'assumption',
    'assist',
    'assistant',
    'assembly',
    'assess',
    'assessment',
    'asset',
    'assign',
    'associate',
    'basement',
    'cassette',
    'embassy',
    'harass',
    'hassle',
    'lasso',
    'massage',
    'massive',
    'passive',
    'sassy',
    'trespass',
    'vassal',
    'cocktails',
    'cockade',
    'cockleshell',
    'cocked',
    'cocker',
    'cocket',
    'cockle',
    'cocksure',
    'coccyx',
    'coconut',
    'penile',
    'peninsula',
    'penitent',
    'pennies',
    'penny',
    'pencil',
    'pendant',
    'penetrate',
    'penguin',
    'buttercup',
    'butterfly',
    'buttermilk',
    'butternut',
    'buttery',
    'buttoned',
    'buttoning',
    'rebuttal',
    'scrapbook',
    'scrappy',
    'escript',
    'hotdog',
    'title',
    'titled',
    'titillate',
    'titan',
    'titanium',
    'dickens',
    'dickensian',
    'medic',
    'medical',
    'edictal',
    'predict',
    'dictate',
    'diction',
    'dictionary',
    'benedict',
    'verdict',
    'contradict',
    'indicate',
    'syndicate',
    'dedicate',
    'educate',
    'index',
    'snigger',
    'bigger',
    'digger',
    'trigger',
    'niggle',
    'stinker',
    'thinker',
    'winkle',
    'twinkle',
    'wrinkle',
    'sprinkle',
    'tinker',
    'exchange',
    'exchequer',
    'execute',
    'exclaim',
    'exclude',
    'excuse',
    'exhale',
    'exhaust',
    'exhibit',
    'sextant',
    'sexton',
    'textile',
    'context',
    'next',
    'dextrous',
    'anagram',
    'canal',
    'analysis',
    'analogue',
    'analog',
    'analytical',
    'canary',
    'candidate',
    'cannabis',
    'canape',
    'cancan',
    'cancel',
    'hooligan',
    'began',
    'michigan',
    'tobagan',
    'rattan',
    'spice',
    'spicy',
    'spider',
    'spike',
    'spinach',
    'spine',
    'spiral',
    'spirit',
    'spit',
    'splash',
    'spokesman',
    'species',
    'specimen',
    'spectrum',
    'speed',
    'grape',
    'drape',
    'scrape',
    'shape',
    'escape',
    'landscape',
    'grapefruit',
    'skyscraper',
    'wholesale',
    'wholemeal',
    'wholesome',
    'whoever',
    'whose',
  ];

  // ---------------------------------------------------------------------------
  // Leetspeak substitution map
  // ---------------------------------------------------------------------------
  static const Map<String, String> _leetMap = {
    '@': 'a',
    '4': 'a',
    '8': 'b',
    '(': 'c',
    '3': 'e',
    '6': 'g',
    '#': 'h',
    '!': 'i',
    '1': 'i',
    '|': 'l',
    '0': 'o',
    '5': 's',
    '\$': 's',
    '7': 't',
    '+': 't',
    '%': 'x',
    '2': 'z',
  };

  // ---------------------------------------------------------------------------
  // Profanity blocklist
  //
  // Organised by category. Every entry is lowercase; matching is always done
  // against normalised (lowercased + leet-decoded) text.
  // ---------------------------------------------------------------------------
  static const List<String> _profanityList = [
    // -- Major English profanity --
    'fuck',
    'fucker',
    'fucking',
    'fucked',
    'fucks',
    'motherfucker',
    'motherfucking',
    'shit',
    'shits',
    'shitty',
    'shitting',
    'bullshit',
    'horseshit',
    'dipshit',
    'shithead',
    'ass',
    'asshole',
    'arsehole',
    'arse',
    'damn',
    'damnit',
    'goddamn',
    'goddamnit',
    'bitch',
    'bitches',
    'bitchy',
    'sonofabitch',
    'bastard',
    'bastards',
    'crap',
    'crappy',
    'hell',
    'piss',
    'pissed',
    'pissing',
    'cock',
    'cocks',
    'dick',
    'dicks',
    'dickhead',
    'penis',
    'vagina',
    'pussy',
    'pussies',
    'cunt',
    'cunts',
    'tit',
    'tits',
    'titty',
    'titties',
    'boob',
    'boobs',
    'wanker',
    'wanking',
    'wank',
    'tosser',
    'twat',
    'twats',
    'bollocks',
    'bellend',
    'knob',
    'knobhead',
    'prick',
    'pricks',
    'slut',
    'sluts',
    'slutty',
    'whore',
    'whores',

    // -- Slurs and hate speech --
    'nigger',
    'niggers',
    'nigga',
    'niggas',
    'faggot',
    'faggots',
    'fag',
    'fags',
    'dyke',
    'dykes',
    'tranny',
    'trannies',
    'retard',
    'retarded',
    'retards',
    'spastic',
    'spaz',
    'coon',
    'coons',
    'chink',
    'chinks',
    'gook',
    'gooks',
    'kike',
    'kikes',
    'wetback',
    'wetbacks',
    'beaner',
    'beaners',
    'spic',
    'spick',
    'wop',
    'wops',
    'dago',
    'raghead',
    'towelhead',
    'camel jockey',
    'sandnigger',
    'zipperhead',
    'cracker',
    'honky',
    'gringo',
    'halfbreed',

    // -- Common insults --
    'idiot',
    'moron',
    'imbecile',
    'dumbass',
    'jackass',
    'douche',
    'douchebag',
    'scumbag',
    'loser',
    'creep',
    'pervert',
    'sicko',
    'freak',
    'degenerate',
    'incel',
    'nonce',
    'paedo',
    'pedo',
    'pedophile',
    'rapist',

    // -- Sexual / explicit terms --
    'blowjob',
    'handjob',
    'rimjob',
    'dildo',
    'vibrator',
    'cumshot',
    'cum',
    'jizz',
    'orgasm',
    'boner',
    'erection',
    'masturbate',
    'masturbation',
    'fellatio',
    'cunnilingus',
    'anal',
    'anus',
    'buttplug',
    'bondage',
    'fetish',
    'hentai',
    'porn',
    'porno',
    'pornography',
    'xxx',
    'nude',
    'nudes',
    'naked',
    'stripper',

    // -- Drug references --
    'cocaine',
    'heroin',
    'meth',
    'methamphetamine',
    'crack',
    'weed',
    'marijuana',
    'ecstasy',

    // -- Violence / threats --
    'kill',
    'murder',
    'suicide',
    'terrorist',
    'terrorism',
    'bomb',
    'genocide',
    'holocaust',
    'massacre',

    // -- Well-known criminals (first-last or surname) --
    'hitler',
    'adolf hitler',
    'stalin',
    'mussolini',
    'bin laden',
    'osama',
    'saddam',
    'gaddafi',
    'pol pot',
    'ted bundy',
    'bundy',
    'dahmer',
    'jeffrey dahmer',
    'gacy',
    'john wayne gacy',
    'manson',
    'charles manson',
    'escobar',
    'pablo escobar',
    'el chapo',
    'al capone',
    'capone',
    'zodiac killer',
    'unabomber',
    'BTK',
    'jack the ripper',
    'ripper',
    'mengele',
    'eichmann',
    'himmler',
    'goebbels',
    'goering',
    'franco',
    'pinochet',
    'idi amin',
    'mugabe',
    'milosevic',
    'radovan karadzic',
    'ratko mladic',
    'ivan the terrible',
  ];

  // ---------------------------------------------------------------------------
  // Pre-compiled state (built lazily on first access)
  // ---------------------------------------------------------------------------
  late final Set<String> _whitelistLower =
      _whitelist.map((w) => w.toLowerCase()).toSet();

  late final Set<String> _impersonationLower =
      _impersonationTerms.map((t) => t.toLowerCase()).toSet();

  /// Profanity entries split into two buckets:
  ///  1. Single-word terms  -> matched with word-boundary regex
  ///  2. Multi-word phrases -> matched with flexible whitespace regex
  late final List<_ProfanityEntry> _entries = _buildEntries();

  List<_ProfanityEntry> _buildEntries() {
    final entries = <_ProfanityEntry>[];
    for (final term in _profanityList) {
      final lower = term.toLowerCase().trim();
      if (lower.isEmpty) continue;

      if (lower.contains(' ')) {
        // Multi-word: build a pattern that allows flexible whitespace /
        // separators between words.
        final parts = lower.split(RegExp(r'\s+'));
        final pattern = parts.map(RegExp.escape).join(r'[\s_\-\.]*');
        entries.add(
          _ProfanityEntry(
            term: lower,
            pattern: RegExp(pattern, caseSensitive: false),
            isMultiWord: true,
          ),
        );
      } else {
        // Single word: use word-boundary markers.
        entries.add(
          _ProfanityEntry(
            term: lower,
            pattern: RegExp(
              r'(?<![a-zA-Z])' + RegExp.escape(lower) + r'(?![a-zA-Z])',
              caseSensitive: false,
            ),
            isMultiWord: false,
          ),
        );
      }
    }

    // Sort longest terms first so greedy replacements work correctly.
    entries.sort((a, b) => b.term.length.compareTo(a.term.length));
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Leetspeak normalisation
  // ---------------------------------------------------------------------------

  /// Normalise a string by replacing common leetspeak characters with their
  /// alphabetic equivalents and lowercasing.
  String _normaliseLeet(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final replacement = _leetMap[char];
      if (replacement != null) {
        buffer.write(replacement);
      } else {
        buffer.write(char.toLowerCase());
      }
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Whitelist check
  // ---------------------------------------------------------------------------

  /// Returns `true` if [text] (already lowered) is wholly explained by one or
  /// more whitelisted words. We check whether every character in [text] is
  /// covered by a whitelisted substring.
  bool _isWhitelisted(String textLower) {
    if (_whitelistLower.contains(textLower)) return true;

    // For each whitelisted word, mark the character positions it covers.
    final covered = List<bool>.filled(textLower.length, false);
    for (final word in _whitelistLower) {
      var start = 0;
      while (true) {
        final idx = textLower.indexOf(word, start);
        if (idx == -1) break;
        for (var i = idx; i < idx + word.length; i++) {
          covered[i] = true;
        }
        start = idx + 1;
      }
    }
    return covered.every((c) => c);
  }

  /// Returns `true` if the profanity match at [matchStart]..[matchEnd] inside
  /// [fullText] is actually part of a whitelisted word.
  bool _matchIsPartOfWhitelistedWord(
    String fullTextLower,
    int matchStart,
    int matchEnd,
  ) {
    for (final word in _whitelistLower) {
      // Find every occurrence of the whitelisted word in the full text.
      var searchFrom = 0;
      while (true) {
        final idx = fullTextLower.indexOf(word, searchFrom);
        if (idx == -1) break;
        final wordEnd = idx + word.length;
        // If the profanity match is fully contained within this whitelisted
        // word occurrence, it is a false positive.
        if (matchStart >= idx && matchEnd <= wordEnd) {
          return true;
        }
        searchFrom = idx + 1;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Core detection
  // ---------------------------------------------------------------------------

  /// Finds all profanity matches in [text], returning their positions.
  /// The search is performed on both the raw text and a leet-normalised copy.
  List<_MatchResult> _findMatches(String text) {
    final results = <_MatchResult>[];
    final lower = text.toLowerCase();
    final normalised = _normaliseLeet(text);

    // Quick exit: if the entire input is a whitelisted word, no matches.
    if (_isWhitelisted(lower) || _isWhitelisted(normalised)) {
      return results;
    }

    // We track which character ranges have already been flagged so that
    // overlapping shorter terms don't double-count.
    final flagged = List<bool>.filled(text.length, false);

    for (final entry in _entries) {
      // Search in both raw-lowercase and leet-normalised forms.
      for (final haystack in [lower, normalised]) {
        for (final match in entry.pattern.allMatches(haystack)) {
          final mStart = match.start;
          final mEnd = match.end;

          // Skip if already covered by a longer match.
          if (_rangeFullyCovered(flagged, mStart, mEnd)) continue;

          // Skip if this match sits inside a whitelisted word.
          if (_matchIsPartOfWhitelistedWord(haystack, mStart, mEnd)) continue;

          // Mark range.
          for (var i = mStart; i < mEnd && i < flagged.length; i++) {
            flagged[i] = true;
          }
          results.add(_MatchResult(start: mStart, end: mEnd));
        }
      }
    }

    return results;
  }

  bool _rangeFullyCovered(List<bool> flagged, int start, int end) {
    for (var i = start; i < end && i < flagged.length; i++) {
      if (!flagged[i]) return false;
    }
    return start < end;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns `true` if [text] contains any profanity after normalisation and
  /// whitelist checks.
  bool containsProfanity(String text) {
    if (text.isEmpty) return false;
    return _findMatches(text).isNotEmpty;
  }

  /// Returns a copy of [text] with profane words replaced by asterisks of the
  /// same length. Non-profane content is left intact.
  String censor(String text) {
    if (text.isEmpty) return text;

    final matches = _findMatches(text);
    if (matches.isEmpty) return text;

    // Build a coverage map over the *original* text.
    final chars = text.split('');
    for (final m in matches) {
      for (var i = m.start; i < m.end && i < chars.length; i++) {
        chars[i] = '*';
      }
    }
    return chars.join();
  }

  /// Validates whether [username] is appropriate for use in-game.
  ///
  /// Checks:
  ///  1. Length between 3 and 20 characters.
  ///  2. Only alphanumeric characters, underscores, and hyphens.
  ///  3. No profanity (including leetspeak variants).
  ///  4. No impersonation of admin / moderator / official roles.
  bool isInappropriateUsername(String username) {
    // Length check.
    if (username.length < _minUsernameLength ||
        username.length > _maxUsernameLength) {
      return true;
    }

    // Allowed characters check.
    if (!_validUsernameChars.hasMatch(username)) {
      return true;
    }

    // Profanity check.
    if (containsProfanity(username)) {
      return true;
    }

    // Impersonation check - compare against normalised (no separators) form.
    final stripped = username.toLowerCase().replaceAll(RegExp(r'[_\-\.]'), '');
    final normalised = _normaliseLeet(stripped);

    for (final term in _impersonationLower) {
      if (normalised == term ||
          normalised.startsWith(term) ||
          normalised.endsWith(term) ||
          normalised.contains(term)) {
        return true;
      }
    }

    return false;
  }
}

// ---------------------------------------------------------------------------
// Internal helper types
// ---------------------------------------------------------------------------

class _ProfanityEntry {
  final String term;
  final RegExp pattern;
  final bool isMultiWord;

  const _ProfanityEntry({
    required this.term,
    required this.pattern,
    required this.isMultiWord,
  });
}

class _MatchResult {
  final int start;
  final int end;

  const _MatchResult({required this.start, required this.end});
}
