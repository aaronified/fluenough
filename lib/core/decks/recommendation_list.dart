/// What the culture list shows of a recommended work (wiki
/// Plan-Deck-Kinds-And-Topics.md, D13, T26; the approved mockup
/// `culture-in-decks`). Pure and free of Flutter.
library;

import '../models/recommendation.dart';

/// Whether [recommendation] carries the public-domain badge: its legal routes
/// say it is in the public domain, or a culture deck quotes it (only a work
/// whose rights allow it is quoted, D13).
bool isPublicDomainWork(Recommendation recommendation) =>
    recommendation.quotedIn != null ||
    recommendation.legal.any((route) => route.kind == 'public-domain');
