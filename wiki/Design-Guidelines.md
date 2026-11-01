# Design guidelines

Source of truth: this wiki page.

## No superfluity (owner, 2026-10-26)

> There are a lot of this superfluity in the UI. Record this as a design
> guideline, avoid superfluity everywhere and write direct sentences.

Said on the "Not quite" banner after a spoken answer: it repeated the answer
that the card above it already showed, and did not say what was wrong.

- Show nothing the learner already sees on the same screen.
- Say what happened, in one direct sentence. No lead-in, no softening.
- A message tells the learner what was wrong, not what was right: the card
  already shows the right answer.
- Cut a line, a label or a word that changes nothing the learner does next.
- Where there are several scripts, show the one being learnt; where several are
  being learnt, the first.
- Review each screen with: "What would the learner miss if this went?" If
  nothing, remove it.

## A control without text has a hint (owner, 2026-10-30, #913)

> Build an app wide long press to show toast explaining the button. The
> toasts must not be large and must always be as short and to the point as
> possible. If a single word can suffice, that's what it will show.

Every tappable control that shows no text (icon buttons, icon-only pills,
round buttons) shows a small hint on a long press, and on
hover on web and desktop. An `IconButton` takes `tooltip:`; anything else is
wrapped in `Hint(message:, child:)` (`lib/ui/widgets/hint.dart`). Both are the
one `Tooltip` styled in `AppTheme`. The text is in `lib/l10n/app_en.arb`: one
word where one word is enough ("Info", "Close", "Speak"), never a sentence,
no full stop. The message is also the control's label for a screen reader.
`test/hint_test.dart` fails for an `IconButton` without `tooltip:` and for an
icon-only tap target in a file with no hint.
A pill that cycles on a tap (the Languages skill pills) is wrapped in `Hint` too: a
long press only shows the hint (the skill and its state), a tap still acts. A
button that repeats while held takes none, since the hint would pop up
mid-repeat, and the language bar takes none, since its long press cancelled the
bar's fold on touch. The minutes steppers (Settings and Today) do not repeat:
their `IconButton`s take `tooltip:`, "Less" and "More". A control that shows its
own text needs no hint.

- **One word, two at most (owner, 2026-11-01: "All buttons in the UI must
  have toast. That explains in natural english, but extremely concise. If one
  word can do it, never ever use 2. If it cannot be one word, try your best
  for 2").** Every icon-only button's tooltip is a plain word, "Back",
  "Close", "Edit", "Delete", "Copy", "Clear", "Sort", "More", never a phrase
  and never the app's own skill vocabulary. Where a screen reader needs the
  longer words (the pencil of one part in Suggest a change), the button is a
  `LabelledIconButton`: the label is the long text, the hint the short word.
  `test/button_tooltips_test.dart` walks the main screens and fails for an
  icon button, floating button or popup button whose tooltip is empty or
  longer than two words.
