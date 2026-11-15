# Plan: Japanese culture decks, sourcing list (batch 1)

Owner stream of 2026-11-13: one agent stream builds the culture, proverbs,
multi-word verbs and topics decks for the priority languages in this order:
Japanese, Spanish, French, Telugu, Marathi, Bengali, Assamese, Gujarati. This
page is **Japanese, batch 1: culture** (issues #1133, #1134, #1142). The data
model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md); the
rules for what may go in are the issues' (#1133, #1135): real works, the public
domain first with its basis recorded, a spread of eras, every item tagged with
the level it suits, short items first, no invented text, no picture unless its
licence is certain.

The deck built from this list is `decks/ja/ja-culture-1.yaml` with its English
layer `decks/ja/en/ja-en-culture-1.yaml`, the creators `decks/creators/ja.yaml`
and the topics `decks/ja/ja-topics.yaml`, on the branch `decks/ja-culture-1` of
`decks-live`. Card ids `ja-4308` to `ja-4325` (the highest Japanese id on
decks-live before this was `ja-4307`).

## Rules applied

- **Public-domain basis (jurisdiction JP).** Japan's term is the author's life
  plus 70 years (it was life plus 50 until 30 December 2018, and the change did
  not bring back works already free). The validator's floor is stricter than
  that and is the rule used here: `author_died` plus 70 must be before this year,
  so only authors who died in 1955 or earlier. All 16 named authors died
  between 770 and 1952. An anonymous work counts only if first published before
  1900 (Sakura, 1888). The floor catches typos; **the reviewer owns the legal
  opinion** (D10), and each row below says what to check.
- **No `quotation` items in batch 1.** Everything here is free by age, so no
  card relies on the quotation exception. For the record: in a Japanese deck
  the 25-word limit is counted in **characters** (the validator counts
  characters for a script written without spaces), so a quotation card would be
  25 characters at most, and 5 cards a deck.
- **Text is shown in modern kana, kanji left out** (owner: only basic kanji).
  Where a work is written with kanji, the card shows the same words in kana
  (`ja-4309` is in katakana, as Kenji wrote the poem). Historical spellings
  (かはづ) are shown in the modern spelling (かわず); each is a reviewer check.
  The source block says "shown in modern kana".
- **Dates are never guessed.** Where the year of writing is not known the
  `date` is the author's lifetime as a span (Buson, Ryokan, Dogen) and the row
  says so; an uncertain birth or death year is `circa` (Sei Shonagon, Kamo no
  Chomei). Every uncertain item is in `docs/review-queue/ja.md`.
- **Translations are the builder's own plain renderings**, not quotations of
  anyone's translation (so no rights are involved), each a reviewer check.
- **Creators:** a short bio at A2 level, dates, the era in the Japanese
  tradition (Nara, Heian, Kamakura, Edo, Meiji, Taisho), and a legacy line with
  one to two checkable items each with a source link. **No images**: none has
  a licence checked, so every creator is drawn with the placeholder.
- **Not in this batch:** proverbs and kotowaza (#1135, a later batch, genre
  `proverbs`, `basis: oral-tradition`), multi-word verbs (#1136), recommendations
  (#1133's "works to find elsewhere": a later file `decks/recommendations/ja.yaml`),
  woven culture (#1134, needs the owner's mockup).

## The works in the deck (18 items, 16 creators, 7 eras)

Levels follow D2: the deck is A2 (its lowest), a card is A2 or B1. Order in the
deck is short items first. "Check" is what a bilingual reviewer should confirm.

| Card | Work | Creator (dates), era | Date | Basis | Level | Genre | Why it matters | Excerpt (as on the card) | Needs reviewer check |
|---|---|---|---|---|---|---|---|---|---|
| ja-4308 | Makura no Soshi (The Pillow Book), opening | Sei Shonagon (c. 966 to c. 1025), Heian | c. 1000 | PD, died c. 1025 | A2 | culture | The first of the season lists of a classic of Heian court prose | はるはあけぼの。 | Dates are circa; the modern-kana form |
| ja-4309 | Ame ni mo makezu | Miyazawa Kenji (1896 to 1933), Taisho and early Showa | 1931 | PD, died 1933 | A2 | culture | One of the best-known Japanese poems; written in katakana, which suits the script topic | アメニモマケズ カゼニモマケズ | Katakana only (the notebook has kanji for rain and wind) |
| ja-4310 | Wagahai wa Neko de aru, first lines | Natsume Soseki (1867 to 1916), Meiji | 1905 | PD, died 1916 | A2 | culture | The first novel of a major Meiji novelist; short, simple sentences | わがはいはねこである。なまえはまだない。 | Kana form; gloss of わがはい |
| ja-4311 | Furuike ya (hokku) | Matsuo Basho (1644 to 1694), Edo | 1686 | PD, died 1694 | A2 | culture | The poem that stands for haiku; first printed in Kawazu-awase, 1686 | ふるいけや かわずとびこむ みずのおと | かわず for かはづ; translation |
| ja-4312 | Kaki kueba (hokku) | Masaoka Shiki (1867 to 1902), Meiji | 1895 | PD, died 1902 | A2 | culture | The haiku that carries the name of Horyu-ji; the poet who modernised haiku | かきくえば かねがなるなり ほうりゅうじ | Year 1895; くえば for くへば |
| ja-4313 | Nanohana ya (hokku) | Yosa Buson (1716 to 1784), Edo | 1716-1784 (year unknown) | PD, died 1784 | A2 | culture | A painter's haiku; a spring image | なのはなや つきはひがしに ひはにしに | Is there a firm year; translation |
| ja-4314 | Yase gaeru (hokku) | Kobayashi Issa (1763 to 1828), Edo | c. 1816 | PD, died 1828 | A2 | culture | A well-loved haiku to a small frog; one of the best known | やせがえる まけるないっさ これにあり | 1816 or 1819; standard text |
| ja-4315 | Furusato (school song), first lines | Takano Tatsuyuki (1876 to 1947), Taisho | 1914 | PD, died 1947 | A2 | culture | A school song every Japanese child learns; the writers were named only in the 1960s | うさぎおいし かのやま こぶなつりし かのかわ | Takano's dates; modern-kana forms |
| ja-4316 | Honrai no Menmoku (waka) | Dogen (1200 to 1253), Kamakura | 1200-1253 (year unknown) | PD, died 1253 | A2 | culture | A Zen monk's poem of the four seasons, quoted by Kawabata | はるははな なつほととぎす あきはつき ふゆゆきさえて すずしかりけり | Attribution, source, date; すずしかりけり |
| ja-4317 | Waka of Ryokan | Ryokan (1758 to 1831), Edo | 1758-1831 (year unknown) | PD, died 1831 | A2 | culture | A monk who played with children; a gentle spring poem | このさとに てまりつきつつ こどもらと あそぶはるひは くれずともよし | Attribution, source, date; translation |
| ja-4318 | Sakura (Sakura sakura), the 1888 words | anonymous | 1888 | PD, anonymous, before 1900 | A2 | culture | The best-known traditional song; first printed in a collection of koto music in 1888 | さくらさくら やよいのそらは みわたすかぎり かすみかくもか においぞいずる いざやいざや みにゆかん | The 1888 text; writer unknown |
| ja-4319 | Kokin Wakashu, travel poems | Abe no Nakamaro (698 to 770), Nara | c. 905 | PD, died 770 | B1 | culture | A poem of homesickness by a student who never came home; also in the Hyakunin Isshu | あまのはら ふりさけみれば かすがなる みかさのやまに いでしつきかも | Attribution; glosses of なる, いでし, かも |
| ja-4320 | Kokin Wakashu | Ariwara no Narihira (825 to 880), Heian | c. 905 | PD, died 880 | B1 | culture | A Heian poem in the Hyakunin Isshu (no. 17) | ちはやぶる かみよもきかず たつたがわ からくれないに みずくくるとは | くくる (tie-dye); translation |
| ja-4321 | Kojo no Tsuki, first lines | Doi Bansui (1871 to 1952), Meiji | 1901 | PD, died 1952 | B1 | culture | The first Western-style song composed in Japan to become widely known | はるこうろうの はなのえん めぐるさかずき かげさして | Rendering of かげさして |
| ja-4322 | Oku no Hosomichi, opening | Matsuo Basho (1644 to 1694), Edo | 1702 (first printed) | PD, died 1694 | B1 | culture | The best-known travel diary; its opening is quoted everywhere | つきひははくたいのかかくにして、ゆきかうとしもまたたびびとなり。 | Kana form |
| ja-4323 | Hojoki, opening | Kamo no Chomei (c. 1155 to 1216), Kamakura | 1212 | PD, died 1216 | B1 | culture | A classic on how nothing lasts | ゆくかわのながれはたえずして、しかももとのみずにあらず。 | Kana form; birth year circa |
| ja-4324 | Midaregami | Yosano Akiko (1878 to 1942), Meiji | 1901 | PD, died 1942 | B1 | culture | A landmark of modern tanka by a woman poet | やわはだの あつきちしおに ふれもみで さびしからずや みちをとくきみ | Text; translation |
| ja-4325 | Rashomon, opening | Akutagawa Ryunosuke (1892 to 1927), Taisho | 1915 | PD, died 1927 | B1 | culture | A short story known abroad through a film; the opening sets a scene | あるひのくれがたのことである。ひとりのげにんが、らしょうもんのしたであまやみをまっていた。 | Year; kana form |

Eras covered (by creator, cards): Nara (1), Heian (2), Kamakura (2), Edo (5), Meiji (4), Taisho (3), and one anonymous song first printed in the Meiji era.
No Muromachi, Azuchi-Momoyama or Showa-after-1945 item: the first has few
well-known short texts of known authorship, and the last is not in the public
domain by the floor.

## Candidates for the next batches (not in the deck)

| Work | Creator, era | Why not in batch 1 | Basis if used |
|---|---|---|---|
| Heike Monogatari, opening | anonymous, Kamakura | The date of writing is only known as before 1240, which the date field cannot say honestly | PD, anonymous, before 1900 |
| Tsurezuregusa, opening | Yoshida Kenko, Kamakura to Muromachi | Birth and death years are uncertain; needs a reviewer first | PD |
| Tosa Nikki, opening | Ki no Tsurayuki, Heian | Birth year uncertain | PD |
| Ono no Komachi, a Kokin Wakashu waka | Ono no Komachi, Heian | Her dates are not known | PD |
| Ichiaku no Suna, a tanka | Ishikawa Takuboku (1886 to 1912), Meiji | A B1 text; a second batch with Takuboku's life | PD, died 1912 |
| Kumo no Ito, opening | Akutagawa Ryunosuke | A second Akutagawa item; a reading deck rather than a card | PD, died 1927 |
| Kaze no Matasaburo, opening | Miyazawa Kenji | Needs kanji-free text checked; a reading passage | PD, died 1933 |
| Akatombo and Kono michi, words | Miki Rofu (died 1964), Kitahara Hakushu (1885 to 1942) | Akatombo's writer died 1964: **not** public domain by the floor. Kono michi's words (Hakushu) are free; a quotation limit does not apply | Kono michi only: PD |
| Momotaro, Urashima Taro (school songs) | writers to be checked, 1910s | If the writer is not named the date is after 1900 and the floor refuses it; if named, the dates must be checked | to check |
| Kotowaza (proverbs) | anonymous | Genre `proverbs`, batch 2, `basis: oral-tradition` | oral tradition |
| Works to recommend, not to reproduce (Natsume Soseki's Kokoro, films, songs of living artists) | various | `decks/recommendations/ja.yaml` after the creators file is merged; no text is reproduced | n/a |

## Open questions for the owner

1. **Dates as spans.** Buson, Ryokan and Dogen have no known year of writing.
   The card gives their lifetime as a span and says so. Right, or leave the
   cards out until a reviewer finds a year?
2. **Circa lifespans.** Sei Shonagon (c. 966 to c. 1025) and Kamo no Chomei
   (c. 1155 to 1216) have a `circa` year. Acceptable?
3. **Kana only.** Every text is shown in kana, kanji left out, so a work's text
   is a rendering of the original. Is that the right reading of "only basic
   kanji", or should basic kanji (日月火 and so on) appear where a word is one?
4. **Wikipedia as a source link.** Source blocks and legacy items link to
   Japanese Wikipedia pages (the only pages reachable from the agent's
   environment, and the claims were checked there). Do the reviewers want a
   primary source (a library or archive link) added to each?
5. **Images.** None, as the rule says. Portraits of several of the creators
   may exist on Wikimedia Commons; each needs its licence page read by a person
   before it is used.

## Verification

The agent read the Japanese Wikipedia page of each work or creator for the
dates and each legacy claim, and for the text where the page quotes it: read
there were the texts of Basho's, Buson's, Issa's, Shiki's and Ryokan's poems,
Dogen's (as quoted by Kawabata), Narihira's, Nakamaro's, the openings of
Hojoki, Oku no Hosomichi, I Am a Cat and Ame ni mo makezu, and the words of
Furusato. The texts of Sei Shonagon's opening, Kojo no Tsuki, Yosano's poem,
Rashomon's opening and the 1888 Sakura (whose first line the page confirms) are
the builder's memory and are marked for the reviewer in
`docs/review-queue/ja.md`, as are Chomei's birth year, Takano's dates and the
years of Shiki's haiku and Rashomon. Nothing from memory is asserted as
checked. The validator and the tests run in CI on the pull request, not here.
