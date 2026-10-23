# Deck tools

Python, not Dart, so that deck contributors need no Flutter toolchain.
Requires Python 3.11+ and PyYAML (`pip install pyyaml`).

The tools check decks against schema 1, write the deck index, and import and
split decks. CI runs the validator on every pull request.

The full guide, with each tool and its options, is in the wiki:

- [Deck tools](https://github.com/aaronified/fluenough/wiki/Deck-Tools): every tool in this folder, with examples.
- [Deck building guide](https://github.com/aaronified/fluenough/wiki/Deck-Building-Guide): the decks these tools check.
