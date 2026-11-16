# Deck tools

Python, not Dart, so that deck contributors need no Flutter toolchain.
Requires Python 3.11+ and PyYAML (`pip install pyyaml`).

The tools check decks against schema 1, write the deck index, and import and
split decks. CI runs the validator on every pull request.

The full guide, with each tool and its options, is in the wiki:

- [Deck tools](https://github.com/aaronified/fluenough/wiki/Deck-Tools): every tool in this folder, with examples.
- [Deck building guide](https://github.com/aaronified/fluenough/wiki/Deck-Building-Guide): the decks these tools check.

The README's screenshots (`docs/screenshots/`: three phone-framed stills, the
learning-session GIF and four scrolling GIFs) are remade from the real app by
the **README media** workflow (Actions tab, run by hand on a branch; it
commits `Regenerate README media` to that branch). It runs, in order:
`tools/readme_fonts.py` (Roboto merged with Noto Sans Bengali, the Noto files
fetched from the official Noto repository), `README_GIFS=1 flutter test
tools/readme_gifs/readme_gifs_test.dart`, `tools/make_gif.py` and
`tools/phone_frame.py`. Details: [Deck tools, readme_fonts.py and
make_gif.py](https://github.com/aaronified/fluenough/wiki/Deck-Tools).
