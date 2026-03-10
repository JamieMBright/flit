/// Integrates language-based country name translations with the alias system.
///
/// When a user selects a non-English language, this service registers the
/// translated country and capital names as aliases so they are accepted as
/// valid answers in the quiz. Translations are loaded from the compile-time
/// [countryTranslations] and [capitalTranslations] maps.
library;

import '../../core/services/game_settings.dart';
import '../data/country_translations.dart';
import 'alias_service.dart';

/// Manages automatic alias registration based on the user's language preference.
///
/// Call [syncLanguageAliases] whenever the language setting changes. This will
/// remove aliases from the previous language and add aliases for the new one.
class LanguageAliasService {
  LanguageAliasService._();
  static final LanguageAliasService instance = LanguageAliasService._();

  /// The language whose aliases are currently registered.
  GameLanguage? _currentLanguage;

  /// Aliases we've added for the current language, so we can remove them later.
  /// Maps canonical name → list of translated aliases we added.
  final Map<String, List<String>> _registeredAliases = {};

  /// Sync aliases for the given language. Removes old language aliases and adds
  /// new ones. Safe to call multiple times with the same language (no-op).
  Future<void> syncLanguageAliases(GameLanguage language) async {
    if (language == _currentLanguage) return;

    // Remove aliases from previous language.
    await _removeCurrentAliases();

    _currentLanguage = language;

    // English is the default — no translation aliases needed.
    if (language == GameLanguage.english) return;

    final langCode = language.code;
    final aliasService = AliasService.instance;

    // Register country name translations.
    for (final entry in countryTranslations.entries) {
      final canonicalName = entry.key;
      final translations = entry.value;
      final translated = translations[langCode];
      if (translated == null) continue;

      // Skip if the translation is the same as the English canonical name.
      final normalized = translated.toLowerCase().trim();
      if (normalized == canonicalName) continue;

      await aliasService.addAlias(canonicalName, normalized);
      _registeredAliases.putIfAbsent(canonicalName, () => []);
      _registeredAliases[canonicalName]!.add(normalized);
    }

    // Register capital name translations.
    for (final entry in capitalTranslations.entries) {
      final capitalName = entry.key;
      final translations = entry.value;
      final translated = translations[langCode];
      if (translated == null) continue;

      final normalized = translated.toLowerCase().trim();
      if (normalized == capitalName) continue;

      // Capital names are registered under their own canonical name
      // since they may be quiz targets too.
      await aliasService.addAlias(capitalName, normalized);
      _registeredAliases.putIfAbsent(capitalName, () => []);
      _registeredAliases[capitalName]!.add(normalized);
    }
  }

  /// Remove all aliases that were registered for the current language.
  Future<void> _removeCurrentAliases() async {
    if (_registeredAliases.isEmpty) return;

    final aliasService = AliasService.instance;
    for (final entry in _registeredAliases.entries) {
      for (final alias in entry.value) {
        await aliasService.removeAlias(entry.key, alias);
      }
    }
    _registeredAliases.clear();
  }

  /// Get the translated country name for display purposes.
  ///
  /// Returns the translation for [language] if available, otherwise returns
  /// null (caller should fall back to the English name).
  static String? translatedCountryName(
    String canonicalName,
    GameLanguage language,
  ) {
    if (language == GameLanguage.english) return null;
    final translations = countryTranslations[canonicalName.toLowerCase()];
    if (translations == null) return null;
    final translated = translations[language.code];
    if (translated == null) return null;
    // Capitalize first letter of each word for display.
    return _titleCase(translated);
  }

  /// Get the translated capital name for display purposes.
  static String? translatedCapitalName(
    String capitalName,
    GameLanguage language,
  ) {
    if (language == GameLanguage.english) return null;
    final translations = capitalTranslations[capitalName.toLowerCase()];
    if (translations == null) return null;
    final translated = translations[language.code];
    if (translated == null) return null;
    return _titleCase(translated);
  }

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Don't capitalize articles/prepositions in some languages.
      const lowerWords = {
        'du', 'de', 'des', 'le', 'la', 'les', 'et', // French
        'del', 'el', 'las', 'los', 'y', // Spanish
        'und', 'der', 'die', 'das', // German
        'ed', 'il', 'e', // Italian
        'do', 'da', 'dos', // Portuguese (das already in German)
        'en', 'het', 'van', // Dutch
      };
      if (lowerWords.contains(word)) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
