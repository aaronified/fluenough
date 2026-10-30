import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../decks/card_notes.dart';

/// One of [card]'s notes, chosen when it first shows and kept while it
/// stays on screen, so that a rebuild never changes it (#421). The choice
/// is [NoteRotation]'s: every note of the card once before any repeats.
///
/// Padded, not boxed, as the notes of the teach card and the answer reveal
/// always were: the drill's frame measures it at the width it is laid out
/// at.
class OneNote extends StatefulWidget {
  const OneNote({super.key, required this.card, required this.notes});

  final Card card;

  /// The notes to choose from: [proseNoteList] for the teach card, whose
  /// warnings carry the homograph and lookalike notes, and [shownNoteList]
  /// for the answer reveal. Keep this widget out of the layout when it is
  /// empty.
  final List<CardNote> notes;

  @override
  State<OneNote> createState() => _OneNoteState();
}

class _OneNoteState extends State<OneNote> {
  CardNote? _note;
  String? _forCard;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _choose();
  }

  @override
  void didUpdateWidget(OneNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    _choose();
  }

  /// Idempotent per card id: the rotation advances only when this State
  /// first shows a card, never on a rebuild or a repeated dependency change.
  void _choose() {
    final card = widget.card;
    if (_forCard == card.id) return;
    _forCard = card.id;
    _note = AppScope.read(context).noteRotation.next(card.id, widget.notes);
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    if (note == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 19),
      child: Text(
        note.text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge!.copyWith(
          fontSize: 15,
          height: 22 / 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
