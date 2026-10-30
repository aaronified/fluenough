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
/// at. Keep it out of the layout when [hasNote] is false.
class OneNote extends StatefulWidget {
  const OneNote({super.key, required this.card});

  final Card card;

  /// Whether [card] has a note to show.
  static bool hasNote(Card card) => proseNoteList(card).isNotEmpty;

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

  void _choose() {
    final card = widget.card;
    if (_forCard == card.id) return;
    _forCard = card.id;
    _note = AppScope.read(context).noteRotation
        .next(card.id, proseNoteList(card));
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
