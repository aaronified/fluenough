import '../core/private/private_ids.dart';

/// The core id `te-home` of the deck `te-en-home` of [language] taught from
/// [native], or null for a deck id that does not follow that form.
String? coreIdOf(String deckId, String language, String native) {
  final lead = idLanguagePrefix(deckId, language);
  final prefix = '$lead-$native-';
  if (!deckId.startsWith(prefix) || deckId.length == prefix.length) {
    return null;
  }
  return '$lead-${deckId.substring(prefix.length)}';
}
