# Plan: Japanese B1 word lists

Source of truth: this wiki page.

Written 2026-11-06 (Sonnet, for the owner). Owner decision, 2026-11-06: "go with C", the re-plan of the Japanese B1 path so that planned units no longer repeat words that earlier units already teach, and so that the planned word counts are met with fresh words.

## What this page is

The Japanese path (`decks/ja/ja-path.yaml`, branch `decks/ja-b1`) gives every planned unit a theme, a size in words and a grammar or kanji marker, and leaves the choice of words to the builder. On the branch (head `51ded631`) the builders found that many of the words they would pick were already cards of earlier units, so shopping came out at 21 of 50 words, eating-out at 15 of 50, music at 14 of 40, and so on (table below).

This page fixes that for the units still to build: **every planned word unit has a list of candidate words, at least as long as its planned size, and every word in every list is fresh**: no card of the branch has the same kana target, and no word is in two lists. A word an earlier unit teaches is not a candidate; the new unit uses it by `ref` when it needs it. Builders take their words from the unit's table.

## How it was checked

A script read every core deck of `decks/ja/` on the branch (the vocabulary cards of 41 decks, leaving the phrasebook and the three script decks: 1,197 cards, 1,193 different kana targets) and rejected any candidate whose kana target equals one of them, equals another candidate, or is not kana. The candidate lists come from the writer's own knowledge of the vocabulary a learner needs at JLPT N5 to N3 level for each theme, written without a corpus, so they are a working list, not a frequency list. A homophone with another spelling (`かえる` to return and `かえる` frog) counts as taken: the course writes targets in kana, so two such words would be one card. Where a good word was lost to a collision, a neighbour was written in its place.

## Using the lists

- **Spelling.** The course writes a target in kana (loanwords in katakana); the kanji column is for the reader and for the later kanji units, not a second target. The `reading` column is a guide (Hepburn, the course's style: long vowels as `ou`, `oo`, `ii`; `n'` before a vowel or y); confirm it with `python3 tools/transcribe.py ja "<word>"` as the build-deck skill says.
- **Part of speech.** `noun`, `verb`, `adj` (both i-adjectives and na-adjectives, as the course does), `adv`, `other`. A suru-noun (like 運動 undou) is a noun card; the rules tables get its verb row if the course has one.
- **Pick the size, skip the doubtful.** A unit takes its planned size. Every list holds a few more than that: skip a word that turns out unnatural, or one that does not make two good examples, and take the next. Words of the review queue (below) are the ones the writer is least sure of; a builder may skip them first.
- **No double teaching.** If a builder finds a candidate already a card by the time the unit is built (another unit got there first), drop it; never write a second card of the same kana target.
- **Homographs.** Where a candidate shares its kana with an earlier card of another spelling the writer has already dropped it, but a note kind `homograph` is still right where a word is also the stem of a common form.

## The audit: planned units

"Planned" is the size in the path; "words ready" is the length of the unit's table below; "taught nearby" are theme words earlier units already teach, listed so that a builder uses them by `ref` and does not rewrite them.

| unit | level | theme | planned | new count | words ready | margin | taught nearby (use by ref) |
|---|---|---|---|---|---|---|---|
| ja-sports | A2 | sports | 45 | 45 | 55 | +10 | やきゅう すいえい サッカー ボール しあい きょうそう かけっこ れんしゅう かつ うんどうじょう たいそう ぶかつ およぐ はしる とぶ つり ほめる |
| ja-illness | A2 | illness | 40 | 40 | 49 | +9 | びょうき びょういん くすり ねつ かぜ けが いたい かゆい ちゅうしゃ きゅうきゅうしゃ ぐあい つかれる ねむい げんき いしゃ はいしゃ かんごし おふろ |
| ja-chores | A2 | chores | 35 | 35 | 42 | +7 | そうじする せんたく せんたくき そうじき ほうき ごみ ごみばこ たたむ ほす かたづける あらう ちりとり ぞうきん ふとん ながし しょっき タオル |
| ja-appearance | A2 | appearance | 40 | 40 | 45 | +5 | からだ あたま かお みみ はな くち くび かた うで ゆび あし はだ ひげ くし けしょう きれい うつくしい おとな こども めがね ゆびわ ぼうし ネクタイ マフラー きる ぬぐ |
| ja-verbs-3 | A2 | verbs-3 | 60 | 60 | 73 | +13 | (all verbs of ja-everyday-verbs, ja-more-verbs, ja-cooking, ja-daily-life, ja-help, ja-school, ja-hobbies: たべる のむ みる いく くる かえる おきる ねる はいる かう あう まつ もつ あるく のる おりる あらう つくる わかる しる ならう おしえる つかう あける しめる あそぶ する ... 134 in all) |
| ja-phone | A2 | phone | 35 | 35 | 44 | +9 | でんわ ケータイ パソコン インターネット メール れんらく てがみ はがき じゅうしょ ばんごう だす テレビ ラジオ カメラ しゃしん ゲーム |
| ja-journey | A2 | journey | 55 | 55 | 59 | +4 | でんしゃ ちかてつ ひこうき ふね くるま じてんしゃ しんかんせん えき のりば きっぷ にもつ ちず りょこう くうこう ホーム かいさつ しゅっぱつ とうちゃく ふつう きゅうこう こうつう ホテル バス タクシー ロッカー いりぐち でぐち |
| ja-nature | A2 | nature | 40 | 40 | 56 | +16 | やま かわ うみ しま もり いけ おか はたけ たんぼ そら つき たいよう さくら もみじ ひまわり あめ にじ ひかり くうき こおり むし ちょう あり |
| ja-adjectives-2 | A2 | adjectives-2 | 50 | 50 | 59 | +9 | あたらしい ふるい いい わるい さむい あたたかい つめたい ひくい おいしい おもしろい むずかしい やさしい たのしい いそがしい しずか べんり きれい きたない あかるい ながい みじかい ちかい とおい おそい おもい かるい うつくしい しんせつ つよい よわい あまい からい すっぱい にがい かたい やわらかい まるい うすい こい くらい ひどい すごい たいへん かんたん ひま らく じょうぶ |
| ja-workplace | A2 | workplace | 45 | 45 | 52 | +7 | しごと かいしゃ かいしゃいん しゃいん ぶちょう かちょう しゃちょう かいぎ じむしょ きゅうりょう ざんぎょう しゅっきん つとめる はたらく けいけん ぎょうむ きぎょう しょうばい |
| ja-geography | A2 | geography | 40 | 40 | 56 | +16 | にほん とうきょう おおさか きょうと ぎんざ しんじゅく しぶや ちゅうごく かんこく いんど あめりか くに まち むら しま やま かわ うみ きた みなみ ひがし にし せかい こうえん |
| ja-health | B1 | health | 55 | 55 | 64 | +9 | からだ あたま ほね はだ のど ねつ かぜ けが くすり ちゅうしゃ びょうき びょういん いしゃ げんき ぐあい あんぜん あぶない おふろ はたらく |
| ja-feelings | B1 | feelings | 55 | 55 | 66 | +11 | すき きらい かなしい たのしい こまる いそがしい ねむい いたい かゆい まんぞく きぶん わらう さけぶ すてき おこる |
| ja-news | B1 | news | 55 | 55 | 65 | +10 | しんぶん ざっし テレビ ラジオ じこ かじ たいふう けいさつ ことば きのう きょう あした |
| ja-opinions | B1 | opinions | 50 | 50 | 62 | +12 | かんがえる わかる しる すき きらい たぶん きっと もちろん ほんとうに ぜひ けっこう とくに ぜんぜん あまり ちょうど もっと いちばん |
| ja-travel | B1 | travel | 55 | 55 | 62 | +7 | りょこう ホテル ちず きっぷ ひこうき くうこう しゅっぱつ とうちゃく あんない まよう のりば しんかんせん にもつ おおさか きょうと |
| ja-services | B1 | services | 45 | 45 | 49 | +4 | ゆうびんきょく ぎんこう でんわ じゅうしょ ばんごう よやく ちゅうもん おかんじょう りょうしゅうしょ ぜいきん せいひん びよういん せんたくや くすりや ほんや はなや ごみ やちん ねだん おかね おつり ふくろ |
| ja-government | B1 | government | 40 | 40 | 48 | +8 | ぜいきん けいさつ しょうぼう しごと ぎんこう じゅうしょ ばんごう ぶっか やくそく |
| ja-technology | B1 | technology | 50 | 50 | 61 | +11 | パソコン ケータイ インターネット メール ゲーム カメラ テレビ ラジオ せんぷうき エアコン れいぞうこ せんたくき そうじき |
| ja-careers | B1 | careers | 50 | 50 | 57 | +7 | しごと かいしゃ かいしゃいん いしゃ かんごし べんごし ぎんこういん けいさつかん うんてんしゅ のうか はいしゃ けんきゅうしゃ せんせい がくせい おまわりさん ぶちょう かちょう しゃちょう |
| ja-business | B1 | business | 50 | 50 | 55 | +5 | かいしゃ ぎんこう しょうばい きぎょう ぶちょう かちょう しゃちょう かいぎ じむしょ きゅうりょう ねだん おかね えん ぶっか ぜいきん ばいてん こうじょう せいひん うる はらう |
| ja-manners | B1 | manners | 45 | 45 | 51 | +6 | さん ちゃん くん さま せんぱい こうはい おきゃくさま おじょうさん やくそく ことば やさしい しんせつ |
| ja-environment | B1 | environment | 50 | 50 | 61 | +11 | やま かわ うみ もり そら くうき ごみ ごみばこ ガソリン ガス こおり きおん きこう たいよう きれい きたない ペットボトル かん |
| ja-cinema | B1 | cinema | 50 | 50 | 58 | +8 | えいが えいがかん げきじょう おんがく しゃしん テレビ ゲーム ピアノ ぼうけん おはなし うた かしゅ すてき |
| ja-arts | B1 | arts | 45 | 45 | 57 | +12 | えがく しょどう おりがみ ぼんさい びじゅつかん げきじょう おどり うた ふで かみ きもの ゆかた |
| ja-history | B1 | history | 45 | 45 | 49 | +4 | にほん ちゅうごく かんこく せかい じんじゃ おてら きょうと おおさか おしょうがつ おぼん |
| ja-religion | B1 | religion | 45 | 45 | 55 | +10 | じんじゃ おてら おしょうがつ おぼん まつり きもの |
| ja-festivals | B1 | festivals | 45 | 45 | 53 | +8 | まつり はなみ おしょうがつ おぼん ひなまつり たなばた せつぶん なつやすみ ゆかた きもの たいこ ふえ さくら もみじ たんじょうび しゅくじつ |
| ja-weddings | B1 | weddings | 40 | 40 | 47 | +7 | つま おっと ごしゅじん かぞく りょうしん ともだち きもの ゆびわ ケーキ ワイン ビール やくそく ごちそう |
| ja-relationships | B1 | relationships | 45 | 45 | 51 | +6 | ともだち かぞく きょうだい せんぱい こうはい なまえ ひと おたがい みんな やさしい しんせつ |
| ja-housing | B1 | housing | 45 | 45 | 53 | +8 | いえ へや まど ふとん たたみ げんかん ベランダ やちん すまい じゅうたく マンション アパート ひっこし ひっこす エアコン ストーブ だいどころ トイレ にわ かいだん かべ ゆか てんじょう |
| ja-emergencies | B1 | emergencies | 40 | 40 | 47 | +7 | けいさつ きゅうきゅうしゃ しょうぼう しょうぼうしゃ かじ じこ ちゅうい あぶない きけん あんぜん たすける たすかる よぶ まよう こまる ひとごみ おまわりさん ぐあい びょういん |
| ja-law | B1 | law | 35 | 35 | 39 | +4 | けいさつ けいさつしょ ぜいきん やくそく まもる ばんごう じこ きけん ちゅうい |
| ja-verbs-4 | B1 | verbs-4 | 60 | 60 | 72 | +12 | (the same 134 taught verbs, see verbs-3) |
| ja-onomatopoeia | B1 | onomatopoeia | 50 | 50 | 76 | +26 | ぴったり ぐっすり いっぱい ゆっくり ちょっと すぐ きっと もっと ずっと また たまに ときどき いつも (the 30 adverbs of ja-adverbs) |
| ja-abstract-words | B1 | abstract-words | 55 | 55 | 73 | +18 | もの とき じかん ばしょ けいけん せいかつ じゅんび ようじ やくそく きぶん ぐあい せいせき ふつう こたえ |
| ja-money | B1 | money | 45 | 45 | 53 | +8 | おかね えん ねだん おつり きゅうりょう やちん ぜいきん さいふ かいもの わりびき ひゃく せん まん おく (the big numbers) |
| ja-society | B1 | society | 50 | 50 | 54 | +4 | ひと みんな かぞく しごと がっこう くに |
| ja-university | B1 | university | 50 | 50 | 55 | +5 | だいがく がくせい せんせい けんきゅう しけん じゅぎょう しゅくだい ぶんぽう かんじ にほんご えいご せいせき じゅく ほん ざっし ノート ペン としょかん きょうしつ |
| ja-food-culture | B1 | food-culture | 50 | 50 | 58 | +8 | ごはん さしみ すし てんぷら すきやき みそしる ぎょうざ もち おちゃ こうちゃ さけ おさけ しょうゆ みそ のり うどん そば ラーメン おにぎり おかず だし あんこ ようかん とうふ なっとう つけもの たくあん さかな にく やさい くだもの しょくじ りょうり |
| ja-literature | B1 | literature | 50 | 50 | 58 | +8 | ほん ざっし しんぶん にっき さくぶん おはなし ことば ぶんぽう かんじ うた てがみ はがき ふで かみ えんぴつ としょかん ほんや どくしょ しょどう |
| ja-verbs-5 | B1 | verbs-5 | 50 | 50 | 88 | +38 | (the same 134 taught verbs, see verbs-3) |
| **total** | | | **1980** | **1980** | **2387** | **+407** | |

The planned sizes are kept: every theme has enough fresh words, so no unit is merged, renamed or lowered. Totals and levels of the path are therefore unchanged (A1 798, A2 899, B1 1,495 and 3,192 in all, within the validator's ranges). No theme is added to `decks/themes.yaml`: the seven themes the path names that it does not list yet (business, manners, religion, onomatopoeia, society, university, food-culture) are added with their first deck, as the path's header says.

Overlaps between neighbouring themes were settled so that no word is claimed twice:

- **journey** is the way there (trains, tickets, luggage, airport, lodging), **travel** is being there (tours, sights, sightseeing, customs, money exchange).
- **illness** is the symptoms and the remedies; **health** is the body, the clinic departments, habits and insurance. **emergencies** is disasters and crime; **law** is the court, rights and duties.
- **workplace** is the office and its rhythm; **careers** is the job market and the jobs; **business** is the company's dealings; **services** is the counters a customer uses.
- **feelings** is emotions; **opinions** is arguing and the connectives; **abstract-words** is the nouns of kind, degree and relation.
- **adjectives-2** holds the adjectives, i and na, that the A1 describing unit did not; the three **verbs** units hold the verbs by group of sense (change, move and handle in 3; force and state in 4; the longer tail in 5) and take no verb a theme unit already has.

## The audit: units already written (planned against written)

Cards counted from the branch; "planned" is the size the path gave the unit before the builder lowered it (read from the path's history). Sets and refs are not counted as words.

| unit | planned | written | short by | top-up words ready |
|---|---|---|---|---|
| ja-eating-out | 50 | 15 | 35 | 37 |
| ja-shopping | 50 | 21 | 29 | 31 |
| ja-music | 40 | 14 | 26 | 39 |
| ja-hobbies | 50 | 29 | 21 | 26 |
| ja-things | 50 | 31 | 19 | 30 |
| ja-cooking | 45 | 31 | 14 | 30 |
| ja-school | 50 | 36 | 14 | 28 |
| ja-groceries | 40 | 36 | 4 | 9 |
| ja-weather | 40 | 37 | 3 | 10 |
| ja-body | 30 | 28 | 2 | 6 |
| ja-describing | 35 | 33 | 2 | 5 |
| **total** | | | **169** | |

The other written units match their size (ja-first-words to ja-help and the A2 units ja-daily-life, ja-calendar, ja-seasons, ja-clothes and ja-animals: calendar, seasons, clothes and the numbers also hold sets, which the count leaves out).

### Recommendation

**B for the seven units short by 14 or more (about 160 words), A for the small ones.**

- **A: accept** the written sizes. The path already carries them (the builders lowered `words`), so nothing is warned of and no work is spent. The cost: A2 holds about 160 fewer words than planned, and the five thinnest units (eating-out 15, music 14, shopping 21, hobbies 29, things 31) are noticeably light for their themes, where a learner meets the situation (a menu, a shop, a song) and has too few words for it.
- **B: top up** each short unit later with extra fresh words from the last section of this page. For the units of 14 or more it is worth doing: eating-out +35, shopping +29, music +26, hobbies +21, things +19, cooking +14, school +14 (158 words). The lists below hold a few more than each shortfall, all fresh against the branch and against the planned units. Each top-up adds cards to the unit's existing core and layer (ids from `--next-id`), raises the unit's `words` in the path to the new size, and needs the new words' rows in the rules tables (nouns, verbs and adjectives, as every word of a rule's kind has its row). It needs no new sentence deck: the existing ones stay, and the new words get their own two examples.
- **Not worth a top-up:** weather (-3), groceries (-4), body (-2), describing (-2). Accept them as they are (11 words); the extra words are listed anyway.

Suggested order if B is chosen: after the planned units, since they carry the B1 milestone; the top-ups are small, mechanical changes to files that exist.

## Changes to the path

Only planned entries are touched, and only by a comment: a note above the first planned word unit (ja-sports) says that the planned word units take their words from this page. No planned unit is merged, renamed, reordered or resized, no theme is added to `decks/themes.yaml`, and no written unit or deck file changed. Reason: the check found enough fresh words for every planned theme, so the owner's option C is met without lowering any count.

## Review queue

The words the writer is not sure of (naturalness, register or level) have a row each in `docs/review-queue/ja.md` on the branch `decks/ja-b1`. They stay in the lists; a builder may skip them when it needs fewer words than a list holds.

## The word lists

One table per planned unit, in the path's teaching order. Then the top-up lists for the written units.

### ja-sports (sports, 45 words, 55 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | テニス |  | tenisu | tennis | noun |
| 2 | バスケットボール |  | basukettobooru | basketball | noun |
| 3 | バレーボール |  | bareebooru | volleyball | noun |
| 4 | ゴルフ |  | gorufu | golf | noun |
| 5 | スキー |  | sukii | skiing; ski | noun |
| 6 | スケート |  | sukeeto | skating | noun |
| 7 | マラソン |  | marason | marathon | noun |
| 8 | ジョギング |  | jogingu | jogging | noun |
| 9 | ダンス |  | dansu | dance (as a sport or class) | noun |
| 10 | すもう | 相撲 | sumou | sumo wrestling | noun |
| 11 | じゅうどう | 柔道 | juudou | judo | noun |
| 12 | けんどう | 剣道 | kendou | kendo | noun |
| 13 | からて | 空手 | karate | karate | noun |
| 14 | たっきゅう | 卓球 | takkyuu | table tennis | noun |
| 15 | バドミントン |  | badominton | badminton | noun |
| 16 | やまのぼり | 山登り | yamanobori | mountain climbing | noun |
| 17 | ハイキング |  | haikingu | hiking | noun |
| 18 | ヨガ |  | yoga | yoga | noun |
| 19 | スポーツ |  | supootsu | sport | noun |
| 20 | うんどう | 運動 | undou | exercise; movement | noun |
| 21 | チーム |  | chiimu | team | noun |
| 22 | せんしゅ | 選手 | senshu | player; athlete | noun |
| 23 | かんとく | 監督 | kantoku | manager; director | noun |
| 24 | コーチ |  | koochi | coach | noun |
| 25 | しんぱん | 審判 | shinpan | referee; umpire | noun |
| 26 | かんきゃく | 観客 | kankyaku | spectators; audience | noun |
| 27 | おうえん | 応援 | ouen | cheering; support | noun |
| 28 | スタジアム |  | sutajiamu | stadium | noun |
| 29 | プール |  | puuru | swimming pool | noun |
| 30 | たいいくかん | 体育館 | taiikukan | gymnasium | noun |
| 31 | ジム |  | jimu | gym | noun |
| 32 | ゴール |  | gooru | goal | noun |
| 33 | ルール |  | ruuru | rule (of a game) | noun |
| 34 | てん | 点 | ten | point; score | noun |
| 35 | ひきわけ | 引き分け | hikiwake | draw; tie | noun |
| 36 | ゆうしょう | 優勝 | yuushou | championship; victory | noun |
| 37 | きろく | 記録 | kiroku | record | noun |
| 38 | メダル |  | medaru | medal | noun |
| 39 | たいかい | 大会 | taikai | tournament; big event | noun |
| 40 | けっしょう | 決勝 | kesshou | final | noun |
| 41 | よせん | 予選 | yosen | qualifying round | noun |
| 42 | トレーニング |  | toreeningu | training | noun |
| 43 | ストレッチ |  | sutoretchi | stretching | noun |
| 44 | ラケット |  | raketto | racket | noun |
| 45 | バット |  | batto | bat | noun |
| 46 | ユニフォーム |  | yunifoomu | uniform; team kit | noun |
| 47 | なげる | 投げる | nageru | to throw | verb |
| 48 | うつ | 打つ | utsu | to hit; to strike | verb |
| 49 | ける | 蹴る | keru | to kick | verb |
| 50 | おいかける | 追いかける | oikakeru | to chase | verb |
| 51 | あきらめる | 諦める | akirameru | to give up | verb |
| 52 | きたえる | 鍛える | kitaeru | to train; to toughen | verb |
| 53 | ねらう | 狙う | nerau | to aim at | verb |
| 54 | さんか | 参加 | sanka | taking part | noun |
| 55 | あいて | 相手 | aite | opponent; partner | noun |

### ja-illness (illness, 40 words, 49 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ずつう | 頭痛 | zutsuu | headache | noun |
| 2 | はらいた | 腹痛 | haraita | stomachache | noun |
| 3 | せき | 咳 | seki | cough | noun |
| 4 | くしゃみ |  | kushami | sneeze | noun |
| 5 | はなみず | 鼻水 | hanamizu | runny nose | noun |
| 6 | げり | 下痢 | geri | diarrhoea | noun |
| 7 | はきけ | 吐き気 | hakike | nausea | noun |
| 8 | めまい |  | memai | dizziness | noun |
| 9 | さむけ | 寒気 | samuke | chill; shivers | noun |
| 10 | インフルエンザ |  | infuruenza | influenza | noun |
| 11 | かふんしょう | 花粉症 | kafunshou | hay fever | noun |
| 12 | しょくちゅうどく | 食中毒 | shokuchuudoku | food poisoning | noun |
| 13 | こっせつ | 骨折 | kossetsu | broken bone | noun |
| 14 | ねんざ | 捻挫 | nenza | sprained joint | noun |
| 15 | やけど | 火傷 | yakedo | burn | noun |
| 16 | きりきず | 切り傷 | kirikizu | cut | noun |
| 17 | あざ |  | aza | bruise | noun |
| 18 | しもやけ | 霜焼け | shimoyake | chilblains | noun |
| 19 | むしば | 虫歯 | mushiba | tooth decay | noun |
| 20 | じびょう | 持病 | jibyou | chronic illness | noun |
| 21 | アレルギー |  | arerugii | allergy | noun |
| 22 | かんせん | 感染 | kansen | infection | noun |
| 23 | うつる | 移る | utsuru | to be catching; to spread | verb |
| 24 | なおる | 治る | naoru | to get well; to heal | verb |
| 25 | なおす | 治す | naosu | to cure; to heal | verb |
| 26 | たおれる | 倒れる | taoreru | to collapse; to fall down | verb |
| 27 | はれる | 腫れる | hareru | to swell | verb |
| 28 | しびれる | 痺れる | shibireru | to go numb | verb |
| 29 | ふらふら |  | furafura | dizzily; unsteadily | adv |
| 30 | だるい |  | darui | sluggish; heavy-limbed | adj |
| 31 | きもちわるい | 気持ち悪い | kimochiwarui | feeling sick; unpleasant | adj |
| 32 | くるしい | 苦しい | kurushii | painful; hard to bear | adj |
| 33 | マスク |  | masuku | face mask | noun |
| 34 | たいおんけい | 体温計 | taionkei | thermometer | noun |
| 35 | しっぷ | 湿布 | shippu | compress; poultice | noun |
| 36 | ばんそうこう | 絆創膏 | bansoukou | sticking plaster | noun |
| 37 | ほうたい | 包帯 | houtai | bandage | noun |
| 38 | かぜぐすり | 風邪薬 | kazegusuri | cold medicine | noun |
| 39 | ちんつうざい | 鎮痛剤 | chintsuuzai | painkiller | noun |
| 40 | のみぐすり | 飲み薬 | nomigusuri | oral medicine | noun |
| 41 | めぐすり | 目薬 | megusuri | eye drops | noun |
| 42 | しょほうせん | 処方箋 | shohousen | prescription | noun |
| 43 | しんさつ | 診察 | shinsatsu | medical examination | noun |
| 44 | けんさ | 検査 | kensa | test; examination | noun |
| 45 | にゅういん | 入院 | nyuuin | being in hospital | noun |
| 46 | たいいん | 退院 | taiin | leaving hospital | noun |
| 47 | しんだん | 診断 | shindan | diagnosis | noun |
| 48 | かんびょう | 看病 | kanbyou | nursing a sick person | noun |
| 49 | ふくさよう | 副作用 | fukusayou | side effect | noun |

### ja-chores (chores, 35 words, 42 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | せんたくもの | 洗濯物 | sentakumono | laundry (clothes to be washed) | noun |
| 2 | せんざい | 洗剤 | senzai | detergent | noun |
| 3 | アイロン |  | airon | iron | noun |
| 4 | ぞうきんがけ | 雑巾がけ | zoukingake | wiping with a rag | noun |
| 5 | ふきそうじ | 拭き掃除 | fukisouji | wipe-cleaning | noun |
| 6 | ごみすて | ごみ捨て | gomisute | taking out the rubbish | noun |
| 7 | もえるごみ | 燃えるごみ | moerugomi | burnable rubbish | noun |
| 8 | もえないごみ | 燃えないごみ | moenaigomi | non-burnable rubbish | noun |
| 9 | しげんごみ | 資源ごみ | shigengomi | recyclable rubbish | noun |
| 10 | おさらあらい | お皿洗い | osaraarai | washing the dishes | noun |
| 11 | あとかたづけ | 後片付け | atokatazuke | clearing up afterwards | noun |
| 12 | したく | 支度 | shitaku | preparing; getting ready | noun |
| 13 | ようい | 用意 | youi | preparation | noun |
| 14 | てつだい | 手伝い | tetsudai | help; helper | noun |
| 15 | みがく | 磨く | migaku | to polish; to brush | verb |
| 16 | こする |  | kosuru | to rub; to scrub | verb |
| 17 | すすぐ |  | susugu | to rinse | verb |
| 18 | しぼる | 絞る | shiboru | to wring out | verb |
| 19 | かわかす | 乾かす | kawakasu | to dry (something) | verb |
| 20 | しまう |  | shimau | to put away | verb |
| 21 | そろえる | 揃える | soroeru | to line up; to put in order | verb |
| 22 | ならべる | 並べる | naraberu | to arrange; to line up | verb |
| 23 | かざる | 飾る | kazaru | to decorate | verb |
| 24 | とりかえる | 取り替える | torikaeru | to replace; to change | verb |
| 25 | つめる | 詰める | tsumeru | to pack; to stuff | verb |
| 26 | くばる | 配る | kubaru | to hand out | verb |
| 27 | こぼす |  | kobosu | to spill | verb |
| 28 | こぼれる |  | koboreru | to spill (of its own accord) | verb |
| 29 | よごれる | 汚れる | yogoreru | to get dirty | verb |
| 30 | よごす | 汚す | yogosu | to make dirty | verb |
| 31 | ちらかす | 散らかす | chirakasu | to scatter; to make a mess | verb |
| 32 | ちらかる | 散らかる | chirakaru | to be messy | verb |
| 33 | あみど | 網戸 | amido | window screen | noun |
| 34 | ほこり |  | hokori | dust | noun |
| 35 | よごれ | 汚れ | yogore | dirt; stain | noun |
| 36 | しみ |  | shimi | stain | noun |
| 37 | そうじどうぐ | 掃除道具 | soujidougu | cleaning tools | noun |
| 38 | たわし |  | tawashi | scrubbing brush | noun |
| 39 | スポンジ |  | suponji | sponge | noun |
| 40 | ゴミぶくろ | ゴミ袋 | gomibukuro | rubbish bag | noun |
| 41 | せんたくばさみ | 洗濯ばさみ | sentakubasami | clothes peg | noun |
| 42 | ものほし | 物干し | monohoshi | clothes-drying rack | noun |

### ja-appearance (appearance, 40 words, 45 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | かみのけ | 髪の毛 | kaminoke | hair (strands) | noun |
| 2 | かみがた | 髪型 | kamigata | hairstyle | noun |
| 3 | まゆげ | 眉毛 | mayuge | eyebrow | noun |
| 4 | まつげ |  | matsuge | eyelash | noun |
| 5 | ひとみ | 瞳 | hitomi | pupil; eye | noun |
| 6 | め | 目 | me | eye | noun |
| 7 | ほお | 頬 | hoo | cheek | noun |
| 8 | あご | 顎 | ago | chin; jaw | noun |
| 9 | くちびる | 唇 | kuchibiru | lip | noun |
| 10 | は | 歯 | ha | tooth | noun |
| 11 | てのひら | 手のひら | tenohira | palm | noun |
| 12 | つめ | 爪 | tsume | nail (finger) | noun |
| 13 | せい | 背 | sei | height; back | noun |
| 14 | ふとい | 太い | futoi | thick; fat | adj |
| 15 | ほそい | 細い | hosoi | thin; slender | adj |
| 16 | やせる | 痩せる | yaseru | to lose weight; to become thin | verb |
| 17 | ふとる | 太る | futoru | to put on weight | verb |
| 18 | かっこいい |  | kakkoii | good-looking; cool | adj |
| 19 | かわいい | 可愛い | kawaii | cute | adj |
| 20 | かわいらしい | 可愛らしい | kawairashii | lovely; sweet | adj |
| 21 | ハンサム |  | hansamu | handsome | adj |
| 22 | びじん | 美人 | bijin | beautiful woman | noun |
| 23 | おしゃれ |  | oshare | stylish; fashionable | adj |
| 24 | じみ | 地味 | jimi | plain; subdued | adj |
| 25 | はで | 派手 | hade | flashy; showy | adj |
| 26 | わかい | 若い | wakai | young | adj |
| 27 | としより | 年寄り | toshiyori | elderly person | noun |
| 28 | コンタクト |  | kontakuto | contact lenses | noun |
| 29 | サングラス |  | sangurasu | sunglasses | noun |
| 30 | ピアス |  | piasu | pierced earring | noun |
| 31 | イヤリング |  | iyaringu | earring | noun |
| 32 | ネックレス |  | nekkuresu | necklace | noun |
| 33 | くせげ | 癖毛 | kusege | curly hair | noun |
| 34 | ちぢれげ | 縮れ毛 | chijirege | frizzy hair | noun |
| 35 | そばかす |  | sobakasu | freckles | noun |
| 36 | えくぼ |  | ekubo | dimple | noun |
| 37 | しわ |  | shiwa | wrinkle | noun |
| 38 | にきび |  | nikibi | pimple | noun |
| 39 | ほくろ |  | hokuro | mole (on the skin) | noun |
| 40 | きんぱつ | 金髪 | kinpatsu | blond hair | noun |
| 41 | くろかみ | 黒髪 | kurokami | black hair | noun |
| 42 | はくはつ | 白髪 | hakuhatsu | white hair | noun |
| 43 | おとなしい |  | otonashii | quiet; well-behaved | adj |
| 44 | ふんいき | 雰囲気 | fun'iki | atmosphere; impression | noun |
| 45 | せいかく | 性格 | seikaku | personality | noun |

### ja-verbs-3 (verbs-3, 60 words, 73 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | かわる | 変わる | kawaru | to change (intransitive) | verb |
| 2 | きまる | 決まる | kimaru | to be decided | verb |
| 3 | きめる | 決める | kimeru | to decide | verb |
| 4 | なる |  | naru | to become | verb |
| 5 | なれる | 慣れる | nareru | to get used to | verb |
| 6 | つく | 着く | tsuku | to arrive | verb |
| 7 | つける | 付ける | tsukeru | to attach; to turn on | verb |
| 8 | けす | 消す | kesu | to turn off; to erase | verb |
| 9 | きえる | 消える | kieru | to go out; to disappear | verb |
| 10 | あく | 開く | aku | to open (intransitive) | verb |
| 11 | しまる | 閉まる | shimaru | to close (intransitive) | verb |
| 12 | つかまえる | 捕まえる | tsukamaeru | to catch | verb |
| 13 | つかむ | 掴む | tsukamu | to grab | verb |
| 14 | おす | 押す | osu | to push; to press | verb |
| 15 | ひっぱる | 引っ張る | hipparu | to pull | verb |
| 16 | おとす | 落とす | otosu | to drop | verb |
| 17 | おちる | 落ちる | ochiru | to fall | verb |
| 18 | ひらく | 開く | hiraku | to open; to hold (an event) | verb |
| 19 | とじる | 閉じる | tojiru | to close | verb |
| 20 | わたす | 渡す | watasu | to hand over | verb |
| 21 | うける | 受ける | ukeru | to receive; to take (an exam) | verb |
| 22 | つたえる | 伝える | tsutaeru | to convey; to tell | verb |
| 23 | つたわる | 伝わる | tsutawaru | to be conveyed | verb |
| 24 | むかえる | 迎える | mukaeru | to welcome; to meet | verb |
| 25 | おくる | 送る | okuru | to send; to see off | verb |
| 26 | とどく | 届く | todoku | to arrive; to reach | verb |
| 27 | とどける | 届ける | todokeru | to deliver; to report | verb |
| 28 | たずねる | 尋ねる | tazuneru | to ask | verb |
| 29 | まちがう | 間違う | machigau | to be wrong | verb |
| 30 | あやまる | 謝る | ayamaru | to apologise | verb |
| 31 | ゆるす | 許す | yurusu | to forgive; to permit | verb |
| 32 | ことわる | 断る | kotowaru | to refuse | verb |
| 33 | さそう | 誘う | sasou | to invite | verb |
| 34 | かよう | 通う | kayou | to commute; to attend regularly | verb |
| 35 | とおる | 通る | tooru | to pass through | verb |
| 36 | すぎる | 過ぎる | sugiru | to pass; to exceed | verb |
| 37 | こえる | 越える | koeru | to cross over | verb |
| 38 | まわる | 回る | mawaru | to turn; to go around | verb |
| 39 | まわす | 回す | mawasu | to turn (something) | verb |
| 40 | うごく | 動く | ugoku | to move | verb |
| 41 | うごかす | 動かす | ugokasu | to move (something) | verb |
| 42 | のこる | 残る | nokoru | to remain | verb |
| 43 | のこす | 残す | nokosu | to leave behind | verb |
| 44 | あつまる | 集まる | atsumaru | to gather | verb |
| 45 | あつめる | 集める | atsumeru | to collect | verb |
| 46 | わかれる | 別れる | wakareru | to part; to split up | verb |
| 47 | わける | 分ける | wakeru | to divide | verb |
| 48 | くらべる | 比べる | kuraberu | to compare | verb |
| 49 | かくれる | 隠れる | kakureru | to hide (oneself) | verb |
| 50 | かくす | 隠す | kakusu | to hide (something) | verb |
| 51 | みつかる | 見つかる | mitsukaru | to be found | verb |
| 52 | みつける | 見つける | mitsukeru | to find | verb |
| 53 | たりる | 足りる | tariru | to be enough | verb |
| 54 | ふえる | 増える | fueru | to increase | verb |
| 55 | へる | 減る | heru | to decrease | verb |
| 56 | そだてる | 育てる | sodateru | to raise; to grow | verb |
| 57 | そだつ | 育つ | sodatsu | to grow up | verb |
| 58 | うまれる | 生まれる | umareru | to be born | verb |
| 59 | いきる | 生きる | ikiru | to live | verb |
| 60 | しぬ | 死ぬ | shinu | to die | verb |
| 61 | さわる | 触る | sawaru | to touch | verb |
| 62 | ふれる | 触れる | fureru | to touch lightly; to come into contact | verb |
| 63 | たのしむ | 楽しむ | tanoshimu | to enjoy | verb |
| 64 | もちいる | 用いる | mochiiru | to use | verb |
| 65 | あたえる | 与える | ataeru | to give; to provide | verb |
| 66 | あたる | 当たる | ataru | to hit; to be correct | verb |
| 67 | あてる | 当てる | ateru | to hit; to apply | verb |
| 68 | いたる | 至る | itaru | to reach; to lead to | verb |
| 69 | おこなう | 行う | okonau | to carry out | verb |
| 70 | おえる | 終える | oeru | to finish | verb |
| 71 | はじまる | 始まる | hajimaru | to begin (intransitive) | verb |
| 72 | あらわれる | 現れる | arawareru | to appear | verb |
| 73 | あらわす | 表す | arawasu | to express | verb |

### ja-phone (phone, 35 words, 44 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | スマホ |  | sumaho | smartphone | noun |
| 2 | けいたい | 携帯 | keitai | mobile phone (short form) | noun |
| 3 | でんわばんごう | 電話番号 | denwabangou | telephone number | noun |
| 4 | メールアドレス |  | meeruadoresu | email address | noun |
| 5 | アドレス |  | adoresu | address (online) | noun |
| 6 | アプリ |  | apuri | app | noun |
| 7 | がめん | 画面 | gamen | screen | noun |
| 8 | じゅうでん | 充電 | juuden | charging | noun |
| 9 | じゅうでんき | 充電器 | juudenki | charger | noun |
| 10 | でんち | 電池 | denchi | battery | noun |
| 11 | でんげん | 電源 | dengen | power (switch) | noun |
| 12 | おんりょう | 音量 | onryou | volume | noun |
| 13 | きどう | 起動 | kidou | start-up | noun |
| 14 | めいわくメール | 迷惑メール | meiwakumeeru | spam email | noun |
| 15 | メッセージ |  | messeeji | message | noun |
| 16 | スタンプ |  | sutanpu | sticker (in chat apps) | noun |
| 17 | つうわ | 通話 | tsuuwa | phone call | noun |
| 18 | ちゃくしん | 着信 | chakushin | incoming call | noun |
| 19 | るすばんでんわ | 留守番電話 | rusubandenwa | answering machine | noun |
| 20 | こうしゅうでんわ | 公衆電話 | koushuudenwa | public telephone | noun |
| 21 | でんぱ | 電波 | denpa | radio signal | noun |
| 22 | けんがい | 圏外 | kengai | out of range | noun |
| 23 | つながる | 繋がる | tsunagaru | to be connected | verb |
| 24 | つなぐ | 繋ぐ | tsunagu | to connect | verb |
| 25 | かける | 掛ける | kakeru | to make (a call) | verb |
| 26 | うけとる | 受け取る | uketoru | to receive | verb |
| 27 | へんしん | 返信 | henshin | reply | noun |
| 28 | でんごん | 伝言 | dengon | message (left for someone) | noun |
| 29 | とうろく | 登録 | touroku | registration | noun |
| 30 | ダウンロード |  | daunroodo | download | noun |
| 31 | アップロード |  | appuroodo | upload | noun |
| 32 | パスワード |  | pasuwaado | password | noun |
| 33 | ログイン |  | roguin | login | noun |
| 34 | ホームページ |  | hoomupeeji | website; home page | noun |
| 35 | ウェブサイト |  | webusaito | website | noun |
| 36 | けんさく | 検索 | kensaku | search (online) | noun |
| 37 | クリック |  | kurikku | click | noun |
| 38 | タップ |  | tappu | tap | noun |
| 39 | スクリーンショット |  | sukuriinshotto | screenshot | noun |
| 40 | ビデオつうわ | ビデオ通話 | bideotsuuwa | video call | noun |
| 41 | かいせん | 回線 | kaisen | line; connection | noun |
| 42 | ネット |  | netto | the net; online | noun |
| 43 | ワイファイ |  | waifai | Wi-Fi | noun |
| 44 | つかいかた | 使い方 | tsukaikata | way of using | noun |

### ja-journey (journey, 55 words, 59 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | たび | 旅 | tabi | journey; trip | noun |
| 2 | たびびと | 旅人 | tabibito | traveller | noun |
| 3 | ていしゃ | 停車 | teisha | stopping (of a vehicle) | noun |
| 4 | のりかえ | 乗り換え | norikae | change (of trains) | noun |
| 5 | のりこし | 乗り越し | norikoshi | riding past one's stop | noun |
| 6 | のりおくれる | 乗り遅れる | noriokureru | to miss (a train) | verb |
| 7 | のりかえる | 乗り換える | norikaeru | to change (trains) | verb |
| 8 | おうふく | 往復 | oufuku | round trip | noun |
| 9 | かたみち | 片道 | katamichi | one-way | noun |
| 10 | じこくひょう | 時刻表 | jikokuhyou | timetable | noun |
| 11 | ざせき | 座席 | zaseki | seat | noun |
| 12 | していせき | 指定席 | shiteiseki | reserved seat | noun |
| 13 | じゆうせき | 自由席 | jiyuuseki | unreserved seat | noun |
| 14 | まどがわ | 窓側 | madogawa | window side | noun |
| 15 | つうろがわ | 通路側 | tsuurogawa | aisle side | noun |
| 16 | うんちん | 運賃 | unchin | fare | noun |
| 17 | りょうきん | 料金 | ryoukin | charge; fee | noun |
| 18 | ていきけん | 定期券 | teikiken | commuter pass | noun |
| 19 | かいすうけん | 回数券 | kaisuuken | coupon ticket | noun |
| 20 | とっきゅう | 特急 | tokkyuu | limited express | noun |
| 21 | かくえきていしゃ | 各駅停車 | kakuekiteisha | local train (stops at every station) | noun |
| 22 | しゃしょう | 車掌 | shashou | conductor | noun |
| 23 | うんてん | 運転 | unten | driving | noun |
| 24 | こうそくどうろ | 高速道路 | kousokudouro | expressway | noun |
| 25 | バスてい | バス停 | basutei | bus stop | noun |
| 26 | タクシーのりば | タクシー乗り場 | takushiinoriba | taxi rank | noun |
| 27 | じゅうたい | 渋滞 | juutai | traffic jam | noun |
| 28 | ちこく | 遅刻 | chikoku | being late | noun |
| 29 | おくれ | 遅れ | okure | delay | noun |
| 30 | うんきゅう | 運休 | unkyuu | cancellation (of service) | noun |
| 31 | ひこうじょう | 飛行場 | hikoujou | airfield | noun |
| 32 | とうじょう | 搭乗 | toujou | boarding (a plane) | noun |
| 33 | とうじょうけん | 搭乗券 | toujouken | boarding pass | noun |
| 34 | パスポート |  | pasupooto | passport | noun |
| 35 | ビザ |  | biza | visa | noun |
| 36 | にもつあずかりじょ | 荷物預かり所 | nimotsuazukarijo | left-luggage office | noun |
| 37 | スーツケース |  | suutsukeesu | suitcase | noun |
| 38 | リュック |  | ryukku | rucksack | noun |
| 39 | てにもつ | 手荷物 | tenimotsu | hand luggage | noun |
| 40 | めんぜい | 免税 | menzei | duty-free | noun |
| 41 | りょかん | 旅館 | ryokan | Japanese inn | noun |
| 42 | みんしゅく | 民宿 | minshuku | guesthouse | noun |
| 43 | チェックイン |  | chekkuin | check-in | noun |
| 44 | チェックアウト |  | chekkuauto | check-out | noun |
| 45 | おみやげ | お土産 | omiyage | souvenir | noun |
| 46 | ガイド |  | gaido | guide | noun |
| 47 | かんこう | 観光 | kankou | sightseeing | noun |
| 48 | めいしょ | 名所 | meisho | famous place | noun |
| 49 | けしき | 景色 | keshiki | scenery; view | noun |
| 50 | いどう | 移動 | idou | movement; travel | noun |
| 51 | たちよる | 立ち寄る | tachiyoru | to drop in | verb |
| 52 | じょうしゃ | 乗車 | jousha | boarding (a train) | noun |
| 53 | げしゃ | 下車 | gesha | getting off (a train) | noun |
| 54 | しゅくはく | 宿泊 | shukuhaku | lodging; overnight stay | noun |
| 55 | こうくうけん | 航空券 | koukuuken | air ticket | noun |
| 56 | しゅっこく | 出国 | shukkoku | leaving a country | noun |
| 57 | にゅうこく | 入国 | nyuukoku | entering a country | noun |
| 58 | ふなびん | 船便 | funabin | sea mail; ship service | noun |
| 59 | きゅうけいじょ | 休憩所 | kyuukeijo | rest area | noun |

### ja-nature (nature, 40 words, 56 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | しぜん | 自然 | shizen | nature | noun |
| 2 | たいりく | 大陸 | tairiku | continent | noun |
| 3 | さばく | 砂漠 | sabaku | desert | noun |
| 4 | たに | 谷 | tani | valley | noun |
| 5 | がけ | 崖 | gake | cliff | noun |
| 6 | たき | 滝 | taki | waterfall | noun |
| 7 | みずうみ | 湖 | mizuumi | lake | noun |
| 8 | かわら | 河原 | kawara | riverbank | noun |
| 9 | はま | 浜 | hama | beach | noun |
| 10 | すなはま | 砂浜 | sunahama | sandy beach | noun |
| 11 | いわ | 岩 | iwa | rock | noun |
| 12 | いし | 石 | ishi | stone | noun |
| 13 | すな | 砂 | suna | sand | noun |
| 14 | つち | 土 | tsuchi | soil; earth | noun |
| 15 | はっぱ | 葉っぱ | happa | leaf | noun |
| 16 | えだ | 枝 | eda | branch | noun |
| 17 | みき | 幹 | miki | trunk | noun |
| 18 | ね | 根 | ne | root | noun |
| 19 | たね | 種 | tane | seed | noun |
| 20 | つぼみ |  | tsubomi | bud | noun |
| 21 | くさ | 草 | kusa | grass | noun |
| 22 | き | 木 | ki | tree | noun |
| 23 | すぎ | 杉 | sugi | Japanese cedar | noun |
| 24 | たけ | 竹 | take | bamboo | noun |
| 25 | うめ | 梅 | ume | plum tree | noun |
| 26 | ばら | 薔薇 | bara | rose | noun |
| 27 | チューリップ |  | chuurippu | tulip | noun |
| 28 | こけ | 苔 | koke | moss | noun |
| 29 | とんぼ |  | tonbo | dragonfly | noun |
| 30 | せみ | 蝉 | semi | cicada | noun |
| 31 | ほたる | 蛍 | hotaru | firefly | noun |
| 32 | かぶとむし | 兜虫 | kabutomushi | rhinoceros beetle | noun |
| 33 | か | 蚊 | ka | mosquito | noun |
| 34 | はえ | 蝿 | hae | fly | noun |
| 35 | くも | 蜘蛛 | kumo | spider | noun |
| 36 | ほし | 星 | hoshi | star | noun |
| 37 | ちきゅう | 地球 | chikyuu | earth; the globe | noun |
| 38 | うちゅう | 宇宙 | uchuu | universe; space | noun |
| 39 | さく | 咲く | saku | to bloom | verb |
| 40 | ちる | 散る | chiru | to fall (of petals) | verb |
| 41 | しげる | 茂る | shigeru | to grow thickly | verb |
| 42 | かれる | 枯れる | kareru | to wither | verb |
| 43 | あじさい | 紫陽花 | ajisai | hydrangea | noun |
| 44 | ひだまり | 日溜まり | hidamari | sunny spot | noun |
| 45 | あさつゆ | 朝露 | asatsuyu | morning dew | noun |
| 46 | しも | 霜 | shimo | frost | noun |
| 47 | つらら |  | tsurara | icicle | noun |
| 48 | しおかぜ | 潮風 | shiokaze | sea breeze | noun |
| 49 | なみうちぎわ | 波打ち際 | namiuchigiwa | water's edge | noun |
| 50 | こもれび | 木漏れ日 | komorebi | sunlight through leaves | noun |
| 51 | はやし | 林 | hayashi | grove | noun |
| 52 | のはら | 野原 | nohara | open field | noun |
| 53 | ざっそう | 雑草 | zassou | weeds | noun |
| 54 | どんぐり |  | donguri | acorn | noun |
| 55 | きのみ | 木の実 | kinomi | nut; berry | noun |
| 56 | すみれ | 菫 | sumire | violet | noun |

### ja-adjectives-2 (adjectives-2, 50 words, 59 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | うれしい | 嬉しい | ureshii | glad; happy | adj |
| 2 | さびしい | 寂しい | sabishii | lonely | adj |
| 3 | こわい | 怖い | kowai | scary; afraid | adj |
| 4 | はずかしい | 恥ずかしい | hazukashii | embarrassing; shy | adj |
| 5 | くやしい | 悔しい | kuyashii | frustrating; vexing | adj |
| 6 | なつかしい | 懐かしい | natsukashii | nostalgic; missed | adj |
| 7 | めずらしい | 珍しい | mezurashii | rare; unusual | adj |
| 8 | ずるい |  | zurui | sly; unfair | adj |
| 9 | しつこい |  | shitsukoi | persistent; clingy | adj |
| 10 | うらやましい | 羨ましい | urayamashii | enviable | adj |
| 11 | ありがたい | 有難い | arigatai | grateful; welcome | adj |
| 12 | もったいない |  | mottainai | wasteful | adj |
| 13 | こまかい | 細かい | komakai | fine; detailed | adj |
| 14 | あらい | 粗い | arai | rough; coarse | adj |
| 15 | ふかい | 深い | fukai | deep | adj |
| 16 | あさい | 浅い | asai | shallow | adj |
| 17 | けむい | 煙い | kemui | smoky | adj |
| 18 | くさい | 臭い | kusai | smelly | adj |
| 19 | するどい | 鋭い | surudoi | sharp | adj |
| 20 | にぶい | 鈍い | nibui | dull; slow | adj |
| 21 | かしこい | 賢い | kashikoi | clever; wise | adj |
| 22 | えらい | 偉い | erai | great; admirable | adj |
| 23 | やかましい |  | yakamashii | noisy; fussy | adj |
| 24 | にぎやか | 賑やか | nigiyaka | lively; bustling | adj |
| 25 | ゆうめい | 有名 | yuumei | famous | adj |
| 26 | ていねい | 丁寧 | teinei | polite; careful | adj |
| 27 | ざんねん | 残念 | zannen | regrettable; a pity | adj |
| 28 | しんぱい | 心配 | shinpai | worried; anxious | adj |
| 29 | ふべん | 不便 | fuben | inconvenient | adj |
| 30 | ふくざつ | 複雑 | fukuzatsu | complicated | adj |
| 31 | じゅうよう | 重要 | juuyou | important | adj |
| 32 | たいせつ | 大切 | taisetsu | precious; important | adj |
| 33 | だいじ | 大事 | daiji | important | adj |
| 34 | とくべつ | 特別 | tokubetsu | special | adj |
| 35 | べつ | 別 | betsu | different; separate | adj |
| 36 | むだ | 無駄 | muda | wasteful; useless | adj |
| 37 | ひつよう | 必要 | hitsuyou | necessary | adj |
| 38 | ふあん | 不安 | fuan | uneasy; worried | adj |
| 39 | かんぺき | 完璧 | kanpeki | perfect | adj |
| 40 | ざんこく | 残酷 | zankoku | cruel | adj |
| 41 | きびしい | 厳しい | kibishii | strict; severe | adj |
| 42 | あやしい | 怪しい | ayashii | suspicious | adj |
| 43 | ぜいたく | 贅沢 | zeitaku | luxurious; extravagant | adj |
| 44 | しんせん | 新鮮 | shinsen | fresh | adj |
| 45 | せいけつ | 清潔 | seiketsu | clean; hygienic | adj |
| 46 | ふけつ | 不潔 | fuketsu | unclean | adj |
| 47 | ゆたか | 豊か | yutaka | rich; abundant | adj |
| 48 | まずしい | 貧しい | mazushii | poor | adj |
| 49 | きらく | 気楽 | kiraku | easygoing; carefree | adj |
| 50 | しょうじき | 正直 | shoujiki | honest | adj |
| 51 | まじめ | 真面目 | majime | serious; diligent | adj |
| 52 | なまいき | 生意気 | namaiki | cheeky | adj |
| 53 | わがまま | 我儘 | wagamama | selfish | adj |
| 54 | けち |  | kechi | stingy | adj |
| 55 | おそろしい | 恐ろしい | osoroshii | terrifying | adj |
| 56 | ねむたい | 眠たい | nemutai | drowsy | adj |
| 57 | さわがしい | 騒がしい | sawagashii | noisy; boisterous | adj |
| 58 | みにくい | 醜い | minikui | ugly | adj |
| 59 | ふしぎ | 不思議 | fushigi | mysterious; strange | adj |

### ja-workplace (workplace, 45 words, 52 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | しょくば | 職場 | shokuba | workplace | noun |
| 2 | オフィス |  | ofisu | office | noun |
| 3 | ぶか | 部下 | buka | subordinate | noun |
| 4 | じょうし | 上司 | joushi | boss; superior | noun |
| 5 | どうりょう | 同僚 | douryou | colleague | noun |
| 6 | かかりちょう | 係長 | kakarichou | section head | noun |
| 7 | しゅにん | 主任 | shunin | chief; head | noun |
| 8 | ほうこく | 報告 | houkoku | report | noun |
| 9 | そうだん | 相談 | soudan | consultation; advice | noun |
| 10 | うちあわせ | 打ち合わせ | uchiawase | preliminary meeting | noun |
| 11 | しりょう | 資料 | shiryou | materials; document | noun |
| 12 | きかく | 企画 | kikaku | plan; project | noun |
| 13 | しめきり | 締め切り | shimekiri | deadline | noun |
| 14 | かいぎしつ | 会議室 | kaigishitsu | meeting room | noun |
| 15 | でんたく | 電卓 | dentaku | calculator | noun |
| 16 | コピー |  | kopii | photocopy | noun |
| 17 | コピーき | コピー機 | kopiiki | photocopier | noun |
| 18 | プリンター |  | purintaa | printer | noun |
| 19 | ファイル |  | fairu | file | noun |
| 20 | ホチキス |  | hochikisu | stapler | noun |
| 21 | しゅっちょう | 出張 | shutchou | business trip | noun |
| 22 | がいしゅつ | 外出 | gaishutsu | going out | noun |
| 23 | ざいたく | 在宅 | zaitaku | being at home (working from home) | noun |
| 24 | たいしゃ | 退社 | taisha | leaving work | noun |
| 25 | にゅうしゃ | 入社 | nyuusha | joining a company | noun |
| 26 | きんむ | 勤務 | kinmu | duty; service | noun |
| 27 | きんむじかん | 勤務時間 | kinmujikan | working hours | noun |
| 28 | きゅうじつ | 休日 | kyuujitsu | day off | noun |
| 29 | ゆうきゅう | 有給 | yuukyuu | paid leave | noun |
| 30 | ボーナス |  | boonasu | bonus | noun |
| 31 | きゅうよ | 給与 | kyuuyo | pay; wages | noun |
| 32 | てあて | 手当 | teate | allowance | noun |
| 33 | しゅうにゅう | 収入 | shuunyuu | income | noun |
| 34 | こうたい | 交代 | koutai | shift; taking turns | noun |
| 35 | シフト |  | shifuto | shift | noun |
| 36 | ひるやすみ | 昼休み | hiruyasumi | lunch break | noun |
| 37 | こうじ | 工事 | kouji | construction work | noun |
| 38 | さぎょう | 作業 | sagyou | task; operation | noun |
| 39 | まかせる | 任せる | makaseru | to entrust | verb |
| 40 | ひきうける | 引き受ける | hikiukeru | to undertake | verb |
| 41 | こなす |  | konasu | to manage; to get through | verb |
| 42 | はげむ | 励む | hagemu | to strive | verb |
| 43 | てがける | 手掛ける | tegakeru | to handle; to work on | verb |
| 44 | しめきる | 締め切る | shimekiru | to close (applications) | verb |
| 45 | まにあわせる | 間に合わせる | maniawaseru | to make it in time | verb |
| 46 | しゅっしゃ | 出社 | shussha | going in to work | noun |
| 47 | ひとで | 人手 | hitode | manpower; hands | noun |
| 48 | ほうしゅう | 報酬 | houshuu | remuneration | noun |
| 49 | うけもつ | 受け持つ | ukemotsu | to take charge of | verb |
| 50 | にんむ | 任務 | ninmu | duty; mission | noun |
| 51 | ふにん | 赴任 | funin | taking up a post | noun |
| 52 | たんしんふにん | 単身赴任 | tanshinfunin | posting away from one's family | noun |

### ja-geography (geography, 40 words, 56 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ちり | 地理 | chiri | geography | noun |
| 2 | ちほう | 地方 | chihou | region | noun |
| 3 | とどうふけん | 都道府県 | todoufuken | prefectures | noun |
| 4 | けん | 県 | ken | prefecture | noun |
| 5 | く | 区 | ku | ward | noun |
| 6 | そん | 村 | son | village (admin unit) | noun |
| 7 | しゅと | 首都 | shuto | capital city | noun |
| 8 | とかい | 都会 | tokai | city; urban area | noun |
| 9 | いなか | 田舎 | inaka | countryside | noun |
| 10 | ほくぶ | 北部 | hokubu | northern part | noun |
| 11 | なんぶ | 南部 | nanbu | southern part | noun |
| 12 | とうぶ | 東部 | toubu | eastern part | noun |
| 13 | せいぶ | 西部 | seibu | western part | noun |
| 14 | ちゅうおう | 中央 | chuuou | centre | noun |
| 15 | ほっかいどう | 北海道 | hokkaidou | Hokkaido | noun |
| 16 | ほんしゅう | 本州 | honshuu | Honshu | noun |
| 17 | しこく | 四国 | shikoku | Shikoku | noun |
| 18 | きゅうしゅう | 九州 | kyuushuu | Kyushu | noun |
| 19 | おきなわ | 沖縄 | okinawa | Okinawa | noun |
| 20 | ふじさん | 富士山 | fujisan | Mount Fuji | noun |
| 21 | ひろしま | 広島 | hiroshima | Hiroshima | noun |
| 22 | なごや | 名古屋 | nagoya | Nagoya | noun |
| 23 | さっぽろ | 札幌 | sapporo | Sapporo | noun |
| 24 | ふくおか | 福岡 | fukuoka | Fukuoka | noun |
| 25 | こうべ | 神戸 | koube | Kobe | noun |
| 26 | よこはま | 横浜 | yokohama | Yokohama | noun |
| 27 | アジア |  | ajia | Asia | noun |
| 28 | ヨーロッパ |  | yooroppa | Europe | noun |
| 29 | アフリカ |  | afurika | Africa | noun |
| 30 | オーストラリア |  | oosutoraria | Australia | noun |
| 31 | イギリス |  | igirisu | Britain | noun |
| 32 | フランス |  | furansu | France | noun |
| 33 | ドイツ |  | doitsu | Germany | noun |
| 34 | イタリア |  | itaria | Italy | noun |
| 35 | スペイン |  | supein | Spain | noun |
| 36 | ロシア |  | roshia | Russia | noun |
| 37 | ブラジル |  | burajiru | Brazil | noun |
| 38 | カナダ |  | kanada | Canada | noun |
| 39 | たいへいよう | 太平洋 | taiheiyou | Pacific Ocean | noun |
| 40 | たいせいよう | 大西洋 | taiseiyou | Atlantic Ocean | noun |
| 41 | ほっきょく | 北極 | hokkyoku | North Pole | noun |
| 42 | なんきょく | 南極 | nankyoku | South Pole | noun |
| 43 | せきどう | 赤道 | sekidou | equator | noun |
| 44 | こくさい | 国際 | kokusai | international | noun |
| 45 | がいこく | 外国 | gaikoku | foreign country | noun |
| 46 | がいこくじん | 外国人 | gaikokujin | foreigner | noun |
| 47 | りょうど | 領土 | ryoudo | territory | noun |
| 48 | こっきょう | 国境 | kokkyou | national border | noun |
| 49 | めんせき | 面積 | menseki | area (size) | noun |
| 50 | じんこう | 人口 | jinkou | population | noun |
| 51 | かいがん | 海岸 | kaigan | coast | noun |
| 52 | はんとう | 半島 | hantou | peninsula | noun |
| 53 | へいや | 平野 | heiya | plain | noun |
| 54 | ぼんち | 盆地 | bonchi | basin | noun |
| 55 | かざん | 火山 | kazan | volcano | noun |
| 56 | おんせん | 温泉 | onsen | hot spring | noun |

### ja-health (health, 55 words, 64 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | けんこう | 健康 | kenkou | health | noun |
| 2 | けんこうしんだん | 健康診断 | kenkoushindan | health check-up | noun |
| 3 | たいじゅう | 体重 | taijuu | body weight | noun |
| 4 | しんちょう | 身長 | shinchou | height (of a person) | noun |
| 5 | たいりょく | 体力 | tairyoku | physical strength; stamina | noun |
| 6 | きんにく | 筋肉 | kinniku | muscle | noun |
| 7 | けつえき | 血液 | ketsueki | blood | noun |
| 8 | ち | 血 | chi | blood | noun |
| 9 | けつあつ | 血圧 | ketsuatsu | blood pressure | noun |
| 10 | みゃく | 脈 | myaku | pulse | noun |
| 11 | しんぞう | 心臓 | shinzou | heart (organ) | noun |
| 12 | い | 胃 | i | stomach (organ) | noun |
| 13 | のう | 脳 | nou | brain | noun |
| 14 | かんぞう | 肝臓 | kanzou | liver (organ) | noun |
| 15 | じんぞう | 腎臓 | jinzou | kidney | noun |
| 16 | ひふ | 皮膚 | hifu | skin | noun |
| 17 | ないか | 内科 | naika | internal medicine | noun |
| 18 | げか | 外科 | geka | surgery | noun |
| 19 | しか | 歯科 | shika | dentistry | noun |
| 20 | がんか | 眼科 | ganka | eye clinic | noun |
| 21 | ひふか | 皮膚科 | hifuka | dermatology | noun |
| 22 | しょうにか | 小児科 | shounika | paediatrics | noun |
| 23 | さんふじんか | 産婦人科 | sanfujinka | obstetrics and gynaecology | noun |
| 24 | せいけいげか | 整形外科 | seikeigeka | orthopaedics | noun |
| 25 | しゅじゅつ | 手術 | shujutsu | surgery; operation | noun |
| 26 | ちりょう | 治療 | chiryou | medical treatment | noun |
| 27 | よぼう | 予防 | yobou | prevention | noun |
| 28 | ワクチン |  | wakuchin | vaccine | noun |
| 29 | ぼしてちょう | 母子手帳 | boshitechou | maternal and child health handbook | noun |
| 30 | えいよう | 栄養 | eiyou | nutrition | noun |
| 31 | ビタミン |  | bitamin | vitamin | noun |
| 32 | カロリー |  | karorii | calorie | noun |
| 33 | ダイエット |  | daietto | diet; dieting | noun |
| 34 | バランス |  | baransu | balance | noun |
| 35 | かたよる | 偏る | katayoru | to be lopsided; to be unbalanced | verb |
| 36 | しょくせいかつ | 食生活 | shokuseikatsu | eating habits | noun |
| 37 | すいみん | 睡眠 | suimin | sleep | noun |
| 38 | ふみん | 不眠 | fumin | insomnia | noun |
| 39 | ねぶそく | 寝不足 | nebusoku | lack of sleep | noun |
| 40 | ストレス |  | sutoresu | stress | noun |
| 41 | かろう | 過労 | karou | overwork | noun |
| 42 | きゅうよう | 休養 | kyuuyou | rest; recuperation | noun |
| 43 | せいかつしゅうかん | 生活習慣 | seikatsushuukan | lifestyle habits | noun |
| 44 | きんえん | 禁煙 | kin'en | no smoking; quitting smoking | noun |
| 45 | たばこ |  | tabako | cigarette; tobacco | noun |
| 46 | いんしゅ | 飲酒 | inshu | drinking alcohol | noun |
| 47 | しんりょうじょ | 診療所 | shinryoujo | clinic | noun |
| 48 | かんじゃ | 患者 | kanja | patient | noun |
| 49 | かんご | 看護 | kango | nursing | noun |
| 50 | すこやか | 健やか | sukoyaka | healthy; sound | adj |
| 51 | ほけん | 保険 | hoken | insurance | noun |
| 52 | ほけんしょう | 保険証 | hokenshou | health insurance card | noun |
| 53 | けんこうほけん | 健康保険 | kenkouhoken | health insurance | noun |
| 54 | こきゅう | 呼吸 | kokyuu | breathing | noun |
| 55 | うんどうぶそく | 運動不足 | undoubusoku | lack of exercise | noun |
| 56 | たいちょう | 体調 | taichou | physical condition | noun |
| 57 | びょうれき | 病歴 | byoureki | medical history | noun |
| 58 | かいふく | 回復 | kaifuku | recovery | noun |
| 59 | けんこうてき | 健康的 | kenkouteki | healthy-looking; wholesome | adj |
| 60 | ふけんこう | 不健康 | fukenkou | unhealthy | adj |
| 61 | すいぶん | 水分 | suibun | moisture; fluids | noun |
| 62 | たんぱくしつ | 蛋白質 | tanpakushitsu | protein | noun |
| 63 | めんえき | 免疫 | men'eki | immunity | noun |
| 64 | しんたい | 身体 | shintai | body (formal) | noun |

### ja-feelings (feelings, 55 words, 66 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | きもち | 気持ち | kimochi | feeling | noun |
| 2 | こころ | 心 | kokoro | heart; mind | noun |
| 3 | しあわせ | 幸せ | shiawase | happy | adj |
| 4 | ふしあわせ | 不幸せ | fushiawase | unhappy | adj |
| 5 | ふこう | 不幸 | fukou | unfortunate | adj |
| 6 | こうふく | 幸福 | koufuku | happiness | noun |
| 7 | よろこび | 喜び | yorokobi | joy | noun |
| 8 | かなしみ | 悲しみ | kanashimi | sadness | noun |
| 9 | いかり | 怒り | ikari | anger | noun |
| 10 | おどろき | 驚き | odoroki | surprise | noun |
| 11 | おどろく | 驚く | odoroku | to be surprised | verb |
| 12 | よろこぶ | 喜ぶ | yorokobu | to be glad | verb |
| 13 | かなしむ | 悲しむ | kanashimu | to grieve | verb |
| 14 | なやむ | 悩む | nayamu | to worry; to be troubled | verb |
| 15 | あわてる | 慌てる | awateru | to panic; to be flustered | verb |
| 16 | あせる | 焦る | aseru | to be impatient; to rush | verb |
| 17 | おちつく | 落ち着く | ochitsuku | to calm down | verb |
| 18 | きんちょう | 緊張 | kinchou | nervousness; tension | noun |
| 19 | どきどき |  | dokidoki | heart pounding | adv |
| 20 | わくわく |  | wakuwaku | excited; thrilled | adv |
| 21 | いらいら |  | iraira | irritated | adv |
| 22 | はらはら |  | harahara | on edge; anxious | adv |
| 23 | ほっと |  | hotto | relieved | adv |
| 24 | がっかり |  | gakkari | disappointed | adv |
| 25 | びっくり |  | bikkuri | startled | adv |
| 26 | うっとり |  | uttori | enchanted | adv |
| 27 | しょんぼり |  | shonbori | dejected | adv |
| 28 | くよくよ |  | kuyokuyo | brooding; fretting | adv |
| 29 | のんびり |  | nonbiri | relaxed; leisurely | adv |
| 30 | きたい | 期待 | kitai | expectation; hope | noun |
| 31 | ふまん | 不満 | fuman | dissatisfaction | noun |
| 32 | こうかい | 後悔 | koukai | regret | noun |
| 33 | しんらい | 信頼 | shinrai | trust | noun |
| 34 | かんしゃ | 感謝 | kansha | gratitude | noun |
| 35 | あいじょう | 愛情 | aijou | affection | noun |
| 36 | あい | 愛 | ai | love | noun |
| 37 | きらう | 嫌う | kirau | to dislike; to hate | verb |
| 38 | あいする | 愛する | aisuru | to love | verb |
| 39 | にくむ | 憎む | nikumu | to hate | verb |
| 40 | ねたむ | 妬む | netamu | to envy | verb |
| 41 | うらむ | 恨む | uramu | to resent | verb |
| 42 | なつかしむ | 懐かしむ | natsukashimu | to feel nostalgic for | verb |
| 43 | いやがる | 嫌がる | iyagaru | to dislike; to be reluctant | verb |
| 44 | こらえる |  | koraeru | to endure; to hold back | verb |
| 45 | がまん | 我慢 | gaman | patience; endurance | noun |
| 46 | はずかしがる | 恥ずかしがる | hazukashigaru | to be shy | verb |
| 47 | きょうみ | 興味 | kyoumi | interest | noun |
| 48 | かんどう | 感動 | kandou | deep emotion; being moved | noun |
| 49 | かんじる | 感じる | kanjiru | to feel | verb |
| 50 | おもいやり | 思いやり | omoiyari | consideration; kindness | noun |
| 51 | ゆううつ | 憂鬱 | yuuutsu | gloomy; depressed | adj |
| 52 | ふゆかい | 不愉快 | fuyukai | unpleasant | adj |
| 53 | ゆかい | 愉快 | yukai | pleasant; merry | adj |
| 54 | かなしげ | 悲しげ | kanashige | sorrowful-looking | adj |
| 55 | たのもしい | 頼もしい | tanomoshii | reliable; reassuring | adj |
| 56 | さびしがる | 寂しがる | sabishigaru | to feel lonely | verb |
| 57 | こうふん | 興奮 | koufun | excitement | noun |
| 58 | いらだち | 苛立ち | iradachi | irritation | noun |
| 59 | ためらう | 躊躇う | tamerau | to hesitate | verb |
| 60 | こわがる | 怖がる | kowagaru | to be afraid | verb |
| 61 | ふんがい | 憤慨 | fungai | indignation | noun |
| 62 | もどかしい |  | modokashii | frustrating; impatient | adj |
| 63 | せつない | 切ない | setsunai | painfully moving; heart-wrenching | adj |
| 64 | いとしい | 愛しい | itoshii | dear; beloved | adj |
| 65 | しんぼう | 辛抱 | shinbou | patience; perseverance | noun |
| 66 | ひとめぼれ | 一目惚れ | hitomebore | love at first sight | noun |

### ja-news (news, 55 words, 65 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ニュース |  | nyuusu | news | noun |
| 2 | きじ | 記事 | kiji | article | noun |
| 3 | ほうどう | 報道 | houdou | news report | noun |
| 4 | しゅざい | 取材 | shuzai | news gathering | noun |
| 5 | きしゃ | 記者 | kisha | reporter | noun |
| 6 | ほうそう | 放送 | housou | broadcast | noun |
| 7 | ばんぐみ | 番組 | bangumi | programme | noun |
| 8 | てんきよほう | 天気予報 | tenkiyohou | weather forecast | noun |
| 9 | よほう | 予報 | yohou | forecast | noun |
| 10 | ほうそうきょく | 放送局 | housoukyoku | broadcasting station | noun |
| 11 | じょうほう | 情報 | jouhou | information | noun |
| 12 | はっぴょう | 発表 | happyou | announcement | noun |
| 13 | はっせい | 発生 | hassei | occurrence; outbreak | noun |
| 14 | じけん | 事件 | jiken | incident; case | noun |
| 15 | さいがい | 災害 | saigai | disaster | noun |
| 16 | じしん | 地震 | jishin | earthquake | noun |
| 17 | つなみ | 津波 | tsunami | tsunami | noun |
| 18 | こうずい | 洪水 | kouzui | flood | noun |
| 19 | せんそう | 戦争 | sensou | war | noun |
| 20 | へいわ | 平和 | heiwa | peace | noun |
| 21 | せんきょ | 選挙 | senkyo | election | noun |
| 22 | とうひょう | 投票 | touhyou | vote | noun |
| 23 | ほうあん | 法案 | houan | bill (legislation) | noun |
| 24 | けいざい | 経済 | keizai | economy | noun |
| 25 | ふけいき | 不景気 | fukeiki | recession | noun |
| 26 | けいき | 景気 | keiki | business conditions | noun |
| 27 | ねあがり | 値上がり | neagari | price rise | noun |
| 28 | ねさがり | 値下がり | nesagari | price fall | noun |
| 29 | ねあげ | 値上げ | neage | raising prices | noun |
| 30 | しゅしょう | 首相 | shushou | prime minister | noun |
| 31 | だいとうりょう | 大統領 | daitouryou | president | noun |
| 32 | せいじ | 政治 | seiji | politics | noun |
| 33 | せいじか | 政治家 | seijika | politician | noun |
| 34 | かいけん | 会見 | kaiken | press conference | noun |
| 35 | ぎいん | 議員 | giin | member of parliament | noun |
| 36 | はんにん | 犯人 | hannin | criminal | noun |
| 37 | ごうとう | 強盗 | goutou | robbery; robber | noun |
| 38 | どろぼう | 泥棒 | dorobou | thief | noun |
| 39 | さつじん | 殺人 | satsujin | murder | noun |
| 40 | ほご | 保護 | hogo | protection | noun |
| 41 | ひがい | 被害 | higai | damage; harm | noun |
| 42 | ひがいしゃ | 被害者 | higaisha | victim | noun |
| 43 | インタビュー |  | intabyuu | interview | noun |
| 44 | とくだね | 特ダネ | tokudane | scoop | noun |
| 45 | ごほう | 誤報 | gohou | false report | noun |
| 46 | かたる | 語る | kataru | to tell; to narrate | verb |
| 47 | ほうじる | 報じる | houjiru | to report | verb |
| 48 | ひろまる | 広まる | hiromaru | to spread | verb |
| 49 | うわさ | 噂 | uwasa | rumour | noun |
| 50 | しゅうかんし | 週刊誌 | shuukanshi | weekly magazine | noun |
| 51 | しんぶんしゃ | 新聞社 | shinbunsha | newspaper company | noun |
| 52 | けいさい | 掲載 | keisai | publication (in print) | noun |
| 53 | はっこう | 発行 | hakkou | publishing; issue | noun |
| 54 | こうどく | 購読 | koudoku | subscription (to a paper) | noun |
| 55 | きょうこう | 強行 | kyoukou | forcible action | noun |
| 56 | ちょうさ | 調査 | chousa | investigation; survey | noun |
| 57 | いちめん | 一面 | ichimen | front page | noun |
| 58 | しゃせつ | 社説 | shasetsu | editorial | noun |
| 59 | ちょうかん | 朝刊 | choukan | morning edition | noun |
| 60 | ゆうかん | 夕刊 | yuukan | evening edition | noun |
| 61 | ごうがい | 号外 | gougai | extra edition | noun |
| 62 | そくほう | 速報 | sokuhou | news flash | noun |
| 63 | ちゅうけい | 中継 | chuukei | live relay | noun |
| 64 | なまほうそう | 生放送 | namahousou | live broadcast | noun |
| 65 | さいほうそう | 再放送 | saihousou | rerun | noun |

### ja-opinions (opinions, 50 words, 62 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | いけん | 意見 | iken | opinion | noun |
| 2 | かんがえ | 考え | kangae | idea; thought | noun |
| 3 | かんがえかた | 考え方 | kangaekata | way of thinking | noun |
| 4 | さんせい | 賛成 | sansei | agreement; approval | noun |
| 5 | ひはん | 批判 | hihan | criticism | noun |
| 6 | ていあん | 提案 | teian | proposal | noun |
| 7 | ふへい | 不平 | fuhei | complaint | noun |
| 8 | もんく | 文句 | monku | complaint | noun |
| 9 | ほんね | 本音 | honne | real intention; true feelings | noun |
| 10 | たてまえ | 建前 | tatemae | official stance | noun |
| 11 | りゆう | 理由 | riyuu | reason | noun |
| 12 | げんいん | 原因 | gen'in | cause | noun |
| 13 | けっか | 結果 | kekka | result | noun |
| 14 | もんだい | 問題 | mondai | problem; question | noun |
| 15 | かいけつ | 解決 | kaiketsu | solution | noun |
| 16 | ほうほう | 方法 | houhou | method | noun |
| 17 | せつめい | 説明 | setsumei | explanation | noun |
| 18 | ひてい | 否定 | hitei | denial | noun |
| 19 | みとめる | 認める | mitomeru | to admit; to recognise | verb |
| 20 | うたがう | 疑う | utagau | to doubt; to suspect | verb |
| 21 | しんじる | 信じる | shinjiru | to believe | verb |
| 22 | そうぞう | 想像 | souzou | imagination | noun |
| 23 | よそう | 予想 | yosou | expectation; forecast | noun |
| 24 | かくしん | 確信 | kakushin | conviction | noun |
| 25 | はんだん | 判断 | handan | judgement | noun |
| 26 | ろんじる | 論じる | ronjiru | to discuss; to argue | verb |
| 27 | ろんぶん | 論文 | ronbun | thesis; essay | noun |
| 28 | ぎろん | 議論 | giron | argument; debate | noun |
| 29 | はんろん | 反論 | hanron | counterargument | noun |
| 30 | どうい | 同意 | doui | agreement; consent | noun |
| 31 | いみ | 意味 | imi | meaning | noun |
| 32 | ちがい | 違い | chigai | difference | noun |
| 33 | おなじ | 同じ | onaji | same | adj |
| 34 | たしか | 確か | tashika | certain; sure | adj |
| 35 | あきらか | 明らか | akiraka | obvious; clear | adj |
| 36 | はっきり |  | hakkiri | clearly | adv |
| 37 | きっぱり |  | kippari | flatly; decisively | adv |
| 38 | むしろ |  | mushiro | rather; on the contrary | adv |
| 39 | たしかに | 確かに | tashikani | certainly; indeed | adv |
| 40 | おそらく | 恐らく | osoraku | probably; perhaps | adv |
| 41 | かならず | 必ず | kanarazu | without fail | adv |
| 42 | かならずしも | 必ずしも | kanarazushimo | not necessarily | adv |
| 43 | いちおう | 一応 | ichiou | for the time being; just in case | adv |
| 44 | やはり |  | yahari | as expected; after all | adv |
| 45 | さすが |  | sasuga | as one would expect | adv |
| 46 | つまり |  | tsumari | in other words | other |
| 47 | たとえば | 例えば | tatoeba | for example | other |
| 48 | けれども |  | keredomo | however | other |
| 49 | しかし |  | shikashi | but; however | other |
| 50 | だから |  | dakara | therefore; so | other |
| 51 | ところが |  | tokoroga | however; but then | other |
| 52 | もしかしたら |  | moshikashitara | perhaps; maybe | adv |
| 53 | どちらかといえば | どちらかと言えば | dochirakatoieba | if anything; on the whole | other |
| 54 | けいこう | 傾向 | keikou | tendency; trend | noun |
| 55 | とうぜん | 当然 | touzen | naturally; of course | adv |
| 56 | はんめん | 反面 | hanmen | on the other hand | noun |
| 57 | いちがいに | 一概に | ichigaini | categorically; without exception | adv |
| 58 | せめて |  | semete | at least | adv |
| 59 | どうやら |  | douyara | apparently | adv |
| 60 | まさか |  | masaka | surely not | adv |
| 61 | ともかく |  | tomokaku | anyway; at any rate | adv |
| 62 | かえって | 却って | kaette | on the contrary | adv |

### ja-travel (travel, 55 words, 62 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | りょこうしゃ | 旅行者 | ryokousha | traveller; tourist | noun |
| 2 | かいがいりょこう | 海外旅行 | kaigairyokou | overseas travel | noun |
| 3 | こくないりょこう | 国内旅行 | kokunairyokou | domestic travel | noun |
| 4 | しゅうがくりょこう | 修学旅行 | shuugakuryokou | school trip | noun |
| 5 | ツアー |  | tsuaa | tour | noun |
| 6 | パンフレット |  | panfuretto | brochure | noun |
| 7 | りょこうがいしゃ | 旅行会社 | ryokougaisha | travel agency | noun |
| 8 | よていひょう | 予定表 | yoteihyou | itinerary | noun |
| 9 | にってい | 日程 | nittei | schedule; itinerary | noun |
| 10 | シングル |  | shinguru | single room | noun |
| 11 | ツイン |  | tsuin | twin room | noun |
| 12 | ダブル |  | daburu | double room | noun |
| 13 | ちょうしょく | 朝食 | choushoku | breakfast (formal) | noun |
| 14 | ゆうしょく | 夕食 | yuushoku | evening meal (formal) | noun |
| 15 | だいよくじょう | 大浴場 | daiyokujou | large public bath | noun |
| 16 | ろてんぶろ | 露天風呂 | rotenburo | open-air bath | noun |
| 17 | フロント |  | furonto | front desk | noun |
| 18 | あずける | 預ける | azukeru | to leave in someone's care | verb |
| 19 | あずかる | 預かる | azukaru | to look after | verb |
| 20 | きにゅう | 記入 | kinyuu | filling in (a form) | noun |
| 21 | しょめい | 署名 | shomei | signature | noun |
| 22 | しんこく | 申告 | shinkoku | declaration (customs) | noun |
| 23 | ぜいかん | 税関 | zeikan | customs | noun |
| 24 | にゅうこくしんさ | 入国審査 | nyuukokushinsa | immigration check | noun |
| 25 | こうかん | 交換 | koukan | exchange | noun |
| 26 | りょうがえ | 両替 | ryougae | currency exchange | noun |
| 27 | かわせ | 為替 | kawase | exchange rate | noun |
| 28 | つうやく | 通訳 | tsuuyaku | interpreter | noun |
| 29 | ほんやく | 翻訳 | hon'yaku | translation | noun |
| 30 | もくてき | 目的 | mokuteki | purpose | noun |
| 31 | もくてきち | 目的地 | mokutekichi | destination | noun |
| 32 | けいゆ | 経由 | keiyu | via | noun |
| 33 | とうちゃくじこく | 到着時刻 | touchakujikoku | arrival time | noun |
| 34 | はっちゃく | 発着 | hatchaku | departure and arrival | noun |
| 35 | きねん | 記念 | kinen | souvenir; commemoration | noun |
| 36 | きねんしゃしん | 記念写真 | kinenshashin | commemorative photo | noun |
| 37 | めぐる | 巡る | meguru | to go around | verb |
| 38 | おとずれる | 訪れる | otozureru | to visit | verb |
| 39 | ひがえり | 日帰り | higaeri | day trip | noun |
| 40 | いせき | 遺跡 | iseki | ruins; historic site | noun |
| 41 | きゅうでん | 宮殿 | kyuuden | palace | noun |
| 42 | はくぶつかん | 博物館 | hakubutsukan | museum | noun |
| 43 | きょうかい | 教会 | kyoukai | church | noun |
| 44 | とう | 塔 | tou | tower; pagoda | noun |
| 45 | きねんひ | 記念碑 | kinenhi | monument | noun |
| 46 | でんとう | 伝統 | dentou | tradition | noun |
| 47 | ガイドブック |  | gaidobukku | guidebook | noun |
| 48 | まいご | 迷子 | maigo | lost child | noun |
| 49 | おくりもの | 贈り物 | okurimono | gift | noun |
| 50 | こんざつ | 混雑 | konzatsu | congestion; crowd | noun |
| 51 | けいかく | 計画 | keikaku | plan | noun |
| 52 | はっけん | 発見 | hakken | discovery | noun |
| 53 | たいざい | 滞在 | taizai | stay | noun |
| 54 | ゆうらんせん | 遊覧船 | yuuransen | sightseeing boat | noun |
| 55 | ロープウェー |  | roopuwee | cable car | noun |
| 56 | ケーブルカー |  | keeburukaa | funicular | noun |
| 57 | たいけん | 体験 | taiken | hands-on experience | noun |
| 58 | じょうりく | 上陸 | jouriku | landing | noun |
| 59 | のどか | 長閑 | nodoka | peaceful; tranquil | adj |
| 60 | ほうもん | 訪問 | houmon | visit | noun |
| 61 | しゅうゆう | 周遊 | shuuyuu | round trip tour | noun |
| 62 | ひとりたび | 一人旅 | hitoritabi | solo travel | noun |

### ja-services (services, 45 words, 49 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | サービス |  | saabisu | service | noun |
| 2 | うけつけ | 受付 | uketsuke | reception; counter | noun |
| 3 | まどぐち | 窓口 | madoguchi | counter; window | noun |
| 4 | もうしこみ | 申し込み | moushikomi | application | noun |
| 5 | もうしこむ | 申し込む | moushikomu | to apply for | verb |
| 6 | てつづき | 手続き | tetsuzuki | procedure; formalities | noun |
| 7 | しょるい | 書類 | shorui | documents | noun |
| 8 | ようし | 用紙 | youshi | form (paper) | noun |
| 9 | かいやく | 解約 | kaiyaku | cancellation of a contract | noun |
| 10 | けいやく | 契約 | keiyaku | contract | noun |
| 11 | かいいん | 会員 | kaiin | member | noun |
| 12 | かいひ | 会費 | kaihi | membership fee | noun |
| 13 | ポイント |  | pointo | points (loyalty) | noun |
| 14 | ポイントカード |  | pointokaado | loyalty card | noun |
| 15 | クーポン |  | kuupon | coupon | noun |
| 16 | こうにゅう | 購入 | kounyuu | purchase | noun |
| 17 | はいたつ | 配達 | haitatsu | delivery | noun |
| 18 | たくはいびん | 宅配便 | takuhaibin | home delivery service | noun |
| 19 | ゆうそう | 郵送 | yuusou | sending by post | noun |
| 20 | ゆうびん | 郵便 | yuubin | mail; post | noun |
| 21 | ゆうびんばんごう | 郵便番号 | yuubinbangou | postcode | noun |
| 22 | こづつみ | 小包 | kozutsumi | parcel | noun |
| 23 | そくたつ | 速達 | sokutatsu | express mail | noun |
| 24 | かきとめ | 書留 | kakitome | registered mail | noun |
| 25 | ふりこみ | 振り込み | furikomi | bank transfer | noun |
| 26 | こうざ | 口座 | kouza | bank account | noun |
| 27 | つうちょう | 通帳 | tsuuchou | bankbook | noun |
| 28 | ざんだか | 残高 | zandaka | balance (of an account) | noun |
| 29 | ひきだし | 引き出し | hikidashi | withdrawal; drawer | noun |
| 30 | あずけいれ | 預け入れ | azukeire | deposit | noun |
| 31 | クレジットカード |  | kurejittokaado | credit card | noun |
| 32 | げんきん | 現金 | genkin | cash | noun |
| 33 | てすうりょう | 手数料 | tesuuryou | handling fee | noun |
| 34 | しはらい | 支払い | shiharai | payment | noun |
| 35 | せいきゅうしょ | 請求書 | seikyuusho | invoice; bill | noun |
| 36 | しゅうり | 修理 | shuuri | repair | noun |
| 37 | てんけん | 点検 | tenken | inspection | noun |
| 38 | たいおう | 対応 | taiou | handling; response | noun |
| 39 | ていきょう | 提供 | teikyou | providing; offer | noun |
| 40 | りよう | 利用 | riyou | use | noun |
| 41 | りようしゃ | 利用者 | riyousha | user | noun |
| 42 | ていきゅうび | 定休日 | teikyuubi | regular closing day | noun |
| 43 | えいぎょう | 営業 | eigyou | business operation | noun |
| 44 | えいぎょうじかん | 営業時間 | eigyoujikan | business hours | noun |
| 45 | うけとりにん | 受取人 | uketorinin | recipient | noun |
| 46 | さしだしにん | 差出人 | sashidashinin | sender | noun |
| 47 | クリーニング |  | kuriiningu | dry cleaning | noun |
| 48 | とこや | 床屋 | tokoya | barber | noun |
| 49 | びようしつ | 美容室 | biyoushitsu | beauty salon | noun |

### ja-government (government, 40 words, 48 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | せいふ | 政府 | seifu | government | noun |
| 2 | こっかい | 国会 | kokkai | the Diet; parliament | noun |
| 3 | ないかく | 内閣 | naikaku | cabinet | noun |
| 4 | やくしょ | 役所 | yakusho | government office | noun |
| 5 | しやくしょ | 市役所 | shiyakusho | city hall | noun |
| 6 | くやくしょ | 区役所 | kuyakusho | ward office | noun |
| 7 | やくば | 役場 | yakuba | town hall | noun |
| 8 | こうむいん | 公務員 | koumuin | public servant | noun |
| 9 | ぜいむしょ | 税務署 | zeimusho | tax office | noun |
| 10 | ぜい | 税 | zei | tax | noun |
| 11 | しょうひぜい | 消費税 | shouhizei | consumption tax | noun |
| 12 | しょとくぜい | 所得税 | shotokuzei | income tax | noun |
| 13 | じゅうみんぜい | 住民税 | juuminzei | residence tax | noun |
| 14 | ねんきん | 年金 | nenkin | pension | noun |
| 15 | こせき | 戸籍 | koseki | family register | noun |
| 16 | じゅうみんひょう | 住民票 | juuminhyou | residence certificate | noun |
| 17 | しょうめいしょ | 証明書 | shoumeisho | certificate | noun |
| 18 | めんきょ | 免許 | menkyo | licence | noun |
| 19 | めんきょしょう | 免許証 | menkyoshou | driver's licence | noun |
| 20 | ざいりゅうカード | 在留カード | zairyuukaado | residence card | noun |
| 21 | ざいりゅう | 在留 | zairyuu | residence (of a foreigner) | noun |
| 22 | きょか | 許可 | kyoka | permission | noun |
| 23 | しんせい | 申請 | shinsei | application (formal) | noun |
| 24 | とどけで | 届け出 | todokede | notification; report | noun |
| 25 | とどけでる | 届け出る | todokederu | to report; to notify | verb |
| 26 | せいど | 制度 | seido | system; institution | noun |
| 27 | きまり | 決まり | kimari | rule; regulation | noun |
| 28 | きそく | 規則 | kisoku | rules | noun |
| 29 | せいさく | 政策 | seisaku | policy | noun |
| 30 | しゃかいほしょう | 社会保障 | shakaihoshou | social security | noun |
| 31 | ふくし | 福祉 | fukushi | welfare | noun |
| 32 | ぎかい | 議会 | gikai | assembly | noun |
| 33 | ちじ | 知事 | chiji | governor | noun |
| 34 | しちょう | 市長 | shichou | mayor | noun |
| 35 | とうひょうじょ | 投票所 | touhyoujo | polling station | noun |
| 36 | せんきょけん | 選挙権 | senkyoken | right to vote | noun |
| 37 | こくみん | 国民 | kokumin | the people; citizens | noun |
| 38 | しみん | 市民 | shimin | citizen | noun |
| 39 | じゅうみん | 住民 | juumin | resident | noun |
| 40 | こくせき | 国籍 | kokuseki | nationality | noun |
| 41 | けんぽう | 憲法 | kenpou | constitution | noun |
| 42 | ほうりつ | 法律 | houritsu | law | noun |
| 43 | しゅうぎいん | 衆議院 | shuugiin | House of Representatives | noun |
| 44 | さんぎいん | 参議院 | sangiin | House of Councillors | noun |
| 45 | よとう | 与党 | yotou | ruling party | noun |
| 46 | やとう | 野党 | yatou | opposition party | noun |
| 47 | かんちょう | 官庁 | kanchou | government office | noun |
| 48 | しょうちょう | 省庁 | shouchou | ministries and agencies | noun |

### ja-technology (technology, 50 words, 61 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ぎじゅつ | 技術 | gijutsu | technology; skill | noun |
| 2 | かがく | 科学 | kagaku | science | noun |
| 3 | かがくしゃ | 科学者 | kagakusha | scientist | noun |
| 4 | はつめい | 発明 | hatsumei | invention | noun |
| 5 | かいはつ | 開発 | kaihatsu | development | noun |
| 6 | しんぽ | 進歩 | shinpo | progress | noun |
| 7 | じどう | 自動 | jidou | automatic | noun |
| 8 | ロボット |  | robotto | robot | noun |
| 9 | コンピューター |  | konpyuutaa | computer | noun |
| 10 | ソフト |  | sofuto | software | noun |
| 11 | ソフトウェア |  | sofutowea | software | noun |
| 12 | ハードディスク |  | haadodisuku | hard disk | noun |
| 13 | メモリ |  | memori | memory | noun |
| 14 | キーボード |  | kiiboodo | keyboard | noun |
| 15 | マウス |  | mausu | mouse (computer) | noun |
| 16 | モニター |  | monitaa | monitor | noun |
| 17 | ケーブル |  | keeburu | cable | noun |
| 18 | データ |  | deeta | data | noun |
| 19 | システム |  | shisutemu | system | noun |
| 20 | プログラム |  | puroguramu | program | noun |
| 21 | プログラマー |  | puroguramaa | programmer | noun |
| 22 | エンジニア |  | enjinia | engineer | noun |
| 23 | ネットワーク |  | nettowaaku | network | noun |
| 24 | セキュリティ |  | sekyuriti | security | noun |
| 25 | ウイルス |  | uirusu | virus | noun |
| 26 | バックアップ |  | bakkuappu | backup | noun |
| 27 | インストール |  | insutooru | installation | noun |
| 28 | アップデート |  | appudeeto | update | noun |
| 29 | クラウド |  | kuraudo | cloud | noun |
| 30 | じんこうちのう | 人工知能 | jinkouchinou | artificial intelligence | noun |
| 31 | ブログ |  | burogu | blog | noun |
| 32 | ドローン |  | doroon | drone | noun |
| 33 | でんし | 電子 | denshi | electron; electronic | noun |
| 34 | でんしレンジ | 電子レンジ | denshirenji | microwave oven | noun |
| 35 | でんしメール | 電子メール | denshimeeru | electronic mail | noun |
| 36 | じどうしゃ | 自動車 | jidousha | motor vehicle | noun |
| 37 | じどうドア | 自動ドア | jidoudoa | automatic door | noun |
| 38 | じどうはんばいき | 自動販売機 | jidouhanbaiki | vending machine | noun |
| 39 | そうさ | 操作 | sousa | operation (of a device) | noun |
| 40 | せつぞく | 接続 | setsuzoku | connection | noun |
| 41 | つうしん | 通信 | tsuushin | communication | noun |
| 42 | ふきゅう | 普及 | fukyuu | spread; popularisation | noun |
| 43 | きかい | 機械 | kikai | machine | noun |
| 44 | そうち | 装置 | souchi | device; equipment | noun |
| 45 | せいのう | 性能 | seinou | performance | noun |
| 46 | こうせいのう | 高性能 | kouseinou | high performance | noun |
| 47 | かいりょう | 改良 | kairyou | improvement | noun |
| 48 | しくみ | 仕組み | shikumi | mechanism | noun |
| 49 | つくりだす | 作り出す | tsukuridasu | to create; to produce | verb |
| 50 | でんしじしょ | 電子辞書 | denshijisho | electronic dictionary | noun |
| 51 | でんしマネー | 電子マネー | denshimanee | electronic money | noun |
| 52 | スキャナー |  | sukyanaa | scanner | noun |
| 53 | テクノロジー |  | tekunorojii | technology | noun |
| 54 | オンライン |  | onrain | online | noun |
| 55 | デジタル |  | dejitaru | digital | noun |
| 56 | アナログ |  | anarogu | analogue | noun |
| 57 | ぎじゅつしゃ | 技術者 | gijutsusha | technician | noun |
| 58 | じどううんてん | 自動運転 | jidouunten | self-driving | noun |
| 59 | データベース |  | deetabeesu | database | noun |
| 60 | アカウント |  | akaunto | account (online) | noun |
| 61 | ログアウト |  | roguauto | logout | noun |

### ja-careers (careers, 50 words, 57 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | しょくぎょう | 職業 | shokugyou | occupation | noun |
| 2 | しゅうしょく | 就職 | shuushoku | finding employment | noun |
| 3 | しゅうしょくかつどう | 就職活動 | shuushokukatsudou | job hunting | noun |
| 4 | てんしょく | 転職 | tenshoku | changing jobs | noun |
| 5 | たいしょく | 退職 | taishoku | retirement; resigning | noun |
| 6 | さいよう | 採用 | saiyou | hiring | noun |
| 7 | めんせつ | 面接 | mensetsu | interview (for a job) | noun |
| 8 | りれきしょ | 履歴書 | rirekisho | CV; résumé | noun |
| 9 | おうぼ | 応募 | oubo | application (for a job) | noun |
| 10 | ぼしゅう | 募集 | boshuu | recruitment | noun |
| 11 | きゅうじん | 求人 | kyuujin | job opening | noun |
| 12 | しかく | 資格 | shikaku | qualification | noun |
| 13 | けいけんしゃ | 経験者 | keikensha | experienced person | noun |
| 14 | しんにゅうしゃいん | 新入社員 | shinnyuushain | new employee | noun |
| 15 | せいしゃいん | 正社員 | seishain | full-time employee | noun |
| 16 | アルバイト |  | arubaito | part-time job | noun |
| 17 | パート |  | paato | part-time work | noun |
| 18 | はけん | 派遣 | haken | dispatch (temp work) | noun |
| 19 | フリーター |  | furiitaa | freeter; casual worker | noun |
| 20 | しゅふ | 主婦 | shufu | housewife | noun |
| 21 | きょうし | 教師 | kyoushi | teacher (profession) | noun |
| 22 | こうし | 講師 | koushi | lecturer | noun |
| 23 | きょうじゅ | 教授 | kyouju | professor | noun |
| 24 | ほいくし | 保育士 | hoikushi | nursery teacher | noun |
| 25 | かいごし | 介護士 | kaigoshi | care worker | noun |
| 26 | やくざいし | 薬剤師 | yakuzaishi | pharmacist | noun |
| 27 | けんちくか | 建築家 | kenchikuka | architect | noun |
| 28 | だいく | 大工 | daiku | carpenter | noun |
| 29 | りょうし | 漁師 | ryoushi | fisherman | noun |
| 30 | はいゆう | 俳優 | haiyuu | actor | noun |
| 31 | かいけいし | 会計士 | kaikeishi | accountant | noun |
| 32 | うりこ | 売り子 | uriko | salesperson | noun |
| 33 | はいたついん | 配達員 | haitatsuin | delivery person | noun |
| 34 | かんりしょく | 管理職 | kanrishoku | managerial position | noun |
| 35 | しょうしん | 昇進 | shoushin | promotion | noun |
| 36 | てきせい | 適性 | tekisei | aptitude | noun |
| 37 | しょうらい | 将来 | shourai | future | noun |
| 38 | ゆめ | 夢 | yume | dream | noun |
| 39 | もくひょう | 目標 | mokuhyou | goal; target | noun |
| 40 | めざす | 目指す | mezasu | to aim for | verb |
| 41 | しぼう | 志望 | shibou | aspiration; desire | noun |
| 42 | しぼうどうき | 志望動機 | shiboudouki | motivation for applying | noun |
| 43 | はたらきかた | 働き方 | hatarakikata | way of working | noun |
| 44 | やりがい |  | yarigai | worth; sense of fulfilment | noun |
| 45 | どりょく | 努力 | doryoku | effort | noun |
| 46 | せいび | 整備 | seibi | maintenance; servicing | noun |
| 47 | せいびし | 整備士 | seibishi | mechanic | noun |
| 48 | しょくにん | 職人 | shokunin | craftsman | noun |
| 49 | かんりにん | 管理人 | kanrinin | caretaker; manager | noun |
| 50 | しょうぎょう | 商業 | shougyou | commerce | noun |
| 51 | のうぎょう | 農業 | nougyou | agriculture | noun |
| 52 | ぎょぎょう | 漁業 | gyogyou | fishing industry | noun |
| 53 | こうぎょう | 工業 | kougyou | manufacturing industry | noun |
| 54 | しょくぎょうくんれん | 職業訓練 | shokugyoukunren | vocational training | noun |
| 55 | しゅうぎょう | 就業 | shuugyou | employment | noun |
| 56 | しっぎょう | 失業 | shiggyou | unemployment | noun |
| 57 | きぼう | 希望 | kibou | hope; wish | noun |

### ja-business (business, 50 words, 55 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ビジネス |  | bijinesu | business | noun |
| 2 | けいえい | 経営 | keiei | management | noun |
| 3 | けいえいしゃ | 経営者 | keieisha | manager; owner | noun |
| 4 | かぶしきがいしゃ | 株式会社 | kabushikigaisha | corporation | noun |
| 5 | しほんきん | 資本金 | shihonkin | capital | noun |
| 6 | かぶ | 株 | kabu | stock; share | noun |
| 7 | とりひき | 取引 | torihiki | transaction; dealings | noun |
| 8 | とりひきさき | 取引先 | torihikisaki | business partner | noun |
| 9 | こきゃく | 顧客 | kokyaku | client; customer | noun |
| 10 | じゅちゅう | 受注 | juchuu | receiving an order | noun |
| 11 | はっちゅう | 発注 | hatchuu | placing an order | noun |
| 12 | のうひん | 納品 | nouhin | delivery of goods | noun |
| 13 | のうき | 納期 | nouki | delivery date | noun |
| 14 | みつもり | 見積もり | mitsumori | estimate; quotation | noun |
| 15 | かかく | 価格 | kakaku | price | noun |
| 16 | げんか | 原価 | genka | cost price | noun |
| 17 | りえき | 利益 | rieki | profit | noun |
| 18 | そんしつ | 損失 | sonshitsu | loss | noun |
| 19 | うりあげ | 売り上げ | uriage | sales; revenue | noun |
| 20 | しゅうえき | 収益 | shuueki | earnings | noun |
| 21 | しゅっぴ | 出費 | shuppi | expenditure | noun |
| 22 | よさん | 予算 | yosan | budget | noun |
| 23 | けっさん | 決算 | kessan | settlement of accounts | noun |
| 24 | あかじ | 赤字 | akaji | deficit | noun |
| 25 | くろじ | 黒字 | kuroji | surplus | noun |
| 26 | ざいむ | 財務 | zaimu | finance | noun |
| 27 | かいけい | 会計 | kaikei | accounting | noun |
| 28 | けいり | 経理 | keiri | accounting department | noun |
| 29 | じんじ | 人事 | jinji | personnel affairs | noun |
| 30 | そうむ | 総務 | soumu | general affairs | noun |
| 31 | えいぎょうぶ | 営業部 | eigyoubu | sales department | noun |
| 32 | きかくぶ | 企画部 | kikakubu | planning department | noun |
| 33 | ほんしゃ | 本社 | honsha | head office | noun |
| 34 | ししゃ | 支社 | shisha | branch office | noun |
| 35 | してん | 支店 | shiten | branch | noun |
| 36 | こうじょうちょう | 工場長 | koujouchou | factory manager | noun |
| 37 | せいさん | 生産 | seisan | production | noun |
| 38 | せいぞう | 製造 | seizou | manufacturing | noun |
| 39 | せいぞうぎょう | 製造業 | seizougyou | manufacturing industry | noun |
| 40 | さんぎょう | 産業 | sangyou | industry | noun |
| 41 | ゆしゅつ | 輸出 | yushutsu | export | noun |
| 42 | ゆにゅう | 輸入 | yunyuu | import | noun |
| 43 | ぼうえき | 貿易 | boueki | trade | noun |
| 44 | しじょう | 市場 | shijou | market (economic) | noun |
| 45 | きょうごう | 競合 | kyougou | competition | noun |
| 46 | せんりゃく | 戦略 | senryaku | strategy | noun |
| 47 | こうしょう | 交渉 | koushou | negotiation | noun |
| 48 | めいし | 名刺 | meishi | business card | noun |
| 49 | めいしこうかん | 名刺交換 | meishikoukan | exchange of business cards | noun |
| 50 | あいさつまわり | 挨拶回り | aisatsumawari | round of courtesy calls | noun |
| 51 | ていけい | 提携 | teikei | partnership; tie-up | noun |
| 52 | ごうべん | 合弁 | gouben | joint venture | noun |
| 53 | ごうどう | 合同 | goudou | joint | noun |
| 54 | とうさん | 倒産 | tousan | bankruptcy | noun |
| 55 | ふさい | 負債 | fusai | debt; liability | noun |

### ja-manners (manners, 45 words, 51 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | マナー |  | manaa | manners | noun |
| 2 | れいぎ | 礼儀 | reigi | etiquette; courtesy | noun |
| 3 | あいさつ | 挨拶 | aisatsu | greeting | noun |
| 4 | おじぎ | お辞儀 | ojigi | bow | noun |
| 5 | おれい | お礼 | orei | thanks; thank-you gift | noun |
| 6 | おわび | お詫び | owabi | apology | noun |
| 7 | えんりょ | 遠慮 | enryo | reserve; holding back | noun |
| 8 | しつれい | 失礼 | shitsurei | rudeness; excuse me | noun |
| 9 | ぶしつけ | 不躾 | bushitsuke | rude; impolite | adj |
| 10 | めいわく | 迷惑 | meiwaku | trouble; nuisance | noun |
| 11 | きをつかう | 気を使う | kiwotsukau | to be considerate | verb |
| 12 | きづかい | 気遣い | kizukai | consideration | noun |
| 13 | きくばり | 気配り | kikubari | attentiveness | noun |
| 14 | けいご | 敬語 | keigo | honorific language | noun |
| 15 | くちょう | 口調 | kuchou | tone of voice | noun |
| 16 | ことばづかい | 言葉遣い | kotobazukai | choice of words | noun |
| 17 | ふるまい | 振る舞い | furumai | behaviour | noun |
| 18 | たいど | 態度 | taido | attitude | noun |
| 19 | こうどう | 行動 | koudou | action | noun |
| 20 | しゅうかん | 習慣 | shuukan | custom; habit | noun |
| 21 | ならわし | 習わし | narawashi | custom | noun |
| 22 | ぎょうぎ | 行儀 | gyougi | manners; behaviour | noun |
| 23 | じょうしき | 常識 | joushiki | common sense | noun |
| 24 | ひじょうしき | 非常識 | hijoushiki | lacking common sense | adj |
| 25 | のぞましい | 望ましい | nozomashii | desirable | adj |
| 26 | ゆずる | 譲る | yuzuru | to give up; to yield | verb |
| 27 | ゆずりあう | 譲り合う | yuzuriau | to give way to each other | verb |
| 28 | ならぶ | 並ぶ | narabu | to line up | verb |
| 29 | れつ | 列 | retsu | queue; line | noun |
| 30 | じゅんばん | 順番 | junban | turn; order | noun |
| 31 | じゅんじょ | 順序 | junjo | order; sequence | noun |
| 32 | おもてなし |  | omotenashi | hospitality | noun |
| 33 | せっきゃく | 接客 | sekkyaku | serving customers | noun |
| 34 | しょうたい | 招待 | shoutai | invitation | noun |
| 35 | しょうたいじょう | 招待状 | shoutaijou | invitation card | noun |
| 36 | もてなす |  | motenasu | to entertain; to treat | verb |
| 37 | まねく | 招く | maneku | to invite | verb |
| 38 | つつしむ | 慎む | tsutsushimu | to refrain; to be discreet | verb |
| 39 | いましめる | 戒める | imashimeru | to admonish | verb |
| 40 | こころづかい | 心遣い | kokorozukai | thoughtfulness | noun |
| 41 | おせじ | お世辞 | oseji | flattery | noun |
| 42 | じょうだん | 冗談 | joudan | joke | noun |
| 43 | ひにく | 皮肉 | hiniku | sarcasm | noun |
| 44 | ぐち | 愚痴 | guchi | grumbling | noun |
| 45 | いやみ | 嫌み | iyami | sarcastic remark | noun |
| 46 | かげぐち | 陰口 | kageguchi | backbiting | noun |
| 47 | けいい | 敬意 | keii | respect | noun |
| 48 | そんけい | 尊敬 | sonkei | respect; esteem | noun |
| 49 | そんちょう | 尊重 | sonchou | respecting | noun |
| 50 | けんきょ | 謙虚 | kenkyo | humble; modest | adj |
| 51 | ごうまん | 傲慢 | gouman | arrogant | adj |

### ja-environment (environment, 50 words, 61 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | かんきょう | 環境 | kankyou | environment | noun |
| 2 | かんきょうもんだい | 環境問題 | kankyoumondai | environmental problem | noun |
| 3 | おせん | 汚染 | osen | pollution | noun |
| 4 | たいきおせん | 大気汚染 | taikiosen | air pollution | noun |
| 5 | はいき | 排気 | haiki | exhaust | noun |
| 6 | はいきガス | 排気ガス | haikigasu | exhaust gas | noun |
| 7 | ちきゅうおんだんか | 地球温暖化 | chikyuuondanka | global warming | noun |
| 8 | おんだんか | 温暖化 | ondanka | warming | noun |
| 9 | おんしつ | 温室 | onshitsu | greenhouse | noun |
| 10 | にさんかたんそ | 二酸化炭素 | nisankatanso | carbon dioxide | noun |
| 11 | たんそ | 炭素 | tanso | carbon | noun |
| 12 | さんそ | 酸素 | sanso | oxygen | noun |
| 13 | オゾン |  | ozon | ozone | noun |
| 14 | エネルギー |  | enerugii | energy | noun |
| 15 | たいようこうはつでん | 太陽光発電 | taiyoukouhatsuden | solar power generation | noun |
| 16 | はつでん | 発電 | hatsuden | power generation | noun |
| 17 | げんしりょく | 原子力 | genshiryoku | nuclear power | noun |
| 18 | せきゆ | 石油 | sekiyu | oil; petroleum | noun |
| 19 | せきたん | 石炭 | sekitan | coal | noun |
| 20 | しげん | 資源 | shigen | resources | noun |
| 21 | さいせい | 再生 | saisei | recycling; regeneration | noun |
| 22 | リサイクル |  | risaikuru | recycling | noun |
| 23 | かいしゅう | 回収 | kaishuu | collection | noun |
| 24 | はいすい | 排水 | haisui | drainage; waste water | noun |
| 25 | はいきぶつ | 廃棄物 | haikibutsu | waste matter | noun |
| 26 | せつやく | 節約 | setsuyaku | saving; economy | noun |
| 27 | せつでん | 節電 | setsuden | saving electricity | noun |
| 28 | せっすい | 節水 | sessui | saving water | noun |
| 29 | エコ |  | eko | eco | noun |
| 30 | かんきょうほご | 環境保護 | kankyouhogo | environmental protection | noun |
| 31 | しぜんほご | 自然保護 | shizenhogo | nature conservation | noun |
| 32 | ぜつめつ | 絶滅 | zetsumetsu | extinction | noun |
| 33 | せいたいけい | 生態系 | seitaikei | ecosystem | noun |
| 34 | どうしょくぶつ | 動植物 | doushokubutsu | flora and fauna | noun |
| 35 | しんりん | 森林 | shinrin | forest | noun |
| 36 | ばっさい | 伐採 | bassai | logging | noun |
| 37 | さばくか | 砂漠化 | sabakuka | desertification | noun |
| 38 | かんばつ | 干ばつ | kanbatsu | drought | noun |
| 39 | きこうへんどう | 気候変動 | kikouhendou | climate change | noun |
| 40 | ぼうさい | 防災 | bousai | disaster prevention | noun |
| 41 | へらす | 減らす | herasu | to reduce | verb |
| 42 | ふやす | 増やす | fuyasu | to increase (something) | verb |
| 43 | こわす | 壊す | kowasu | to break; to destroy | verb |
| 44 | こわれる | 壊れる | kowareru | to break (intransitive) | verb |
| 45 | はかい | 破壊 | hakai | destruction | noun |
| 46 | ほぜん | 保全 | hozen | preservation | noun |
| 47 | たもつ | 保つ | tamotsu | to keep; to maintain | verb |
| 48 | さける | 避ける | sakeru | to avoid | verb |
| 49 | つながり | 繋がり | tsunagari | connection; link | noun |
| 50 | えいきょう | 影響 | eikyou | influence; effect | noun |
| 51 | ちいき | 地域 | chiiki | region; community | noun |
| 52 | こうがい | 公害 | kougai | environmental pollution | noun |
| 53 | ほうしゃのう | 放射能 | houshanou | radioactivity | noun |
| 54 | たいき | 大気 | taiki | atmosphere | noun |
| 55 | かいよう | 海洋 | kaiyou | ocean | noun |
| 56 | ふうりょく | 風力 | fuuryoku | wind power | noun |
| 57 | すいりょく | 水力 | suiryoku | hydropower | noun |
| 58 | ちねつ | 地熱 | chinetsu | geothermal heat | noun |
| 59 | ゆうがい | 有害 | yuugai | harmful | adj |
| 60 | むがい | 無害 | mugai | harmless | adj |
| 61 | しょうエネ | 省エネ | shouene | energy saving | noun |

### ja-cinema (cinema, 50 words, 58 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | スクリーン |  | sukuriin | screen (cinema) | noun |
| 2 | じょうえい | 上映 | jouei | screening | noun |
| 3 | さくひん | 作品 | sakuhin | work; production | noun |
| 4 | ていばん | 定番 | teiban | standard; classic | noun |
| 5 | ひげき | 悲劇 | higeki | tragedy | noun |
| 6 | きげき | 喜劇 | kigeki | comedy | noun |
| 7 | コメディー |  | komedii | comedy | noun |
| 8 | ホラー |  | horaa | horror | noun |
| 9 | アクション |  | akushon | action film | noun |
| 10 | サスペンス |  | sasupensu | suspense | noun |
| 11 | ミュージカル |  | myuujikaru | musical | noun |
| 12 | アニメ |  | anime | anime | noun |
| 13 | ドキュメンタリー |  | dokyumentarii | documentary | noun |
| 14 | ドラマ |  | dorama | drama | noun |
| 15 | シリーズ |  | shiriizu | series | noun |
| 16 | ストーリー |  | sutoorii | story | noun |
| 17 | ものがたり | 物語 | monogatari | tale; story | noun |
| 18 | あらすじ |  | arasuji | plot summary | noun |
| 19 | けつまつ | 結末 | ketsumatsu | ending | noun |
| 20 | クライマックス |  | kuraimakkusu | climax | noun |
| 21 | しゅえん | 主演 | shuen | starring role | noun |
| 22 | しゅじんこう | 主人公 | shujinkou | protagonist | noun |
| 23 | ヒーロー |  | hiiroo | hero | noun |
| 24 | ヒロイン |  | hiroin | heroine | noun |
| 25 | やくしゃ | 役者 | yakusha | actor | noun |
| 26 | じょゆう | 女優 | joyuu | actress | noun |
| 27 | えんぎ | 演技 | engi | acting | noun |
| 28 | えんじる | 演じる | enjiru | to perform; to play (a role) | verb |
| 29 | せりふ | 台詞 | serifu | lines; dialogue | noun |
| 30 | さつえい | 撮影 | satsuei | filming; shooting | noun |
| 31 | さつえいじょ | 撮影所 | satsueijo | film studio | noun |
| 32 | プロデューサー |  | purodyuusaa | producer | noun |
| 33 | じまく | 字幕 | jimaku | subtitles | noun |
| 34 | ふきかえ | 吹き替え | fukikae | dubbing | noun |
| 35 | サウンドトラック |  | saundotorakku | soundtrack | noun |
| 36 | ひょうばん | 評判 | hyouban | reputation; popularity | noun |
| 37 | ひょうか | 評価 | hyouka | evaluation; rating | noun |
| 38 | かんそう | 感想 | kansou | impressions; thoughts | noun |
| 39 | はくりょく | 迫力 | hakuryoku | power; impact | noun |
| 40 | ほうが | 邦画 | houga | Japanese film | noun |
| 41 | ようが | 洋画 | youga | foreign film | noun |
| 42 | えいがさい | 映画祭 | eigasai | film festival | noun |
| 43 | ポスター |  | posutaa | poster | noun |
| 44 | チケット |  | chiketto | ticket (for an event) | noun |
| 45 | なみだ | 涙 | namida | tear | noun |
| 46 | なく | 泣く | naku | to cry | verb |
| 47 | かんげき | 感激 | kangeki | deep emotion | noun |
| 48 | ぞくへん | 続編 | zokuhen | sequel | noun |
| 49 | リメイク |  | rimeiku | remake | noun |
| 50 | きょうえん | 共演 | kyouen | co-starring | noun |
| 51 | えいぞう | 映像 | eizou | image; footage | noun |
| 52 | ぜんさく | 前作 | zensaku | previous work | noun |
| 53 | しんさく | 新作 | shinsaku | new work | noun |
| 54 | だいひょうさく | 代表作 | daihyousaku | representative work | noun |
| 55 | もりあがる | 盛り上がる | moriagaru | to get lively | verb |
| 56 | ざんしん | 斬新 | zanshin | novel; fresh | adj |
| 57 | ひきこまれる | 引き込まれる | hikikomareru | to be drawn in | verb |
| 58 | きょうかん | 共感 | kyoukan | sympathy; empathy | noun |

### ja-arts (arts, 45 words, 57 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | げいじゅつ | 芸術 | geijutsu | art | noun |
| 2 | びじゅつ | 美術 | bijutsu | fine art | noun |
| 3 | かいが | 絵画 | kaiga | painting (art) | noun |
| 4 | え | 絵 | e | picture; painting | noun |
| 5 | えかき | 絵描き | ekaki | painter | noun |
| 6 | がか | 画家 | gaka | painter (artist) | noun |
| 7 | ちょうこく | 彫刻 | choukoku | sculpture | noun |
| 8 | けんちく | 建築 | kenchiku | architecture | noun |
| 9 | しゃしんか | 写真家 | shashinka | photographer | noun |
| 10 | てんらんかい | 展覧会 | tenrankai | exhibition | noun |
| 11 | てんじ | 展示 | tenji | display | noun |
| 12 | ギャラリー |  | gyararii | gallery | noun |
| 13 | さくひんてん | 作品展 | sakuhinten | exhibition of works | noun |
| 14 | けっさく | 傑作 | kessaku | masterpiece | noun |
| 15 | めいさく | 名作 | meisaku | famous work | noun |
| 16 | ふうけいが | 風景画 | fuukeiga | landscape painting | noun |
| 17 | じんぶつが | 人物画 | jinbutsuga | portrait | noun |
| 18 | あぶらえ | 油絵 | aburae | oil painting | noun |
| 19 | すいさいが | 水彩画 | suisaiga | watercolour | noun |
| 20 | すみえ | 墨絵 | sumie | ink painting | noun |
| 21 | うきよえ | 浮世絵 | ukiyoe | ukiyo-e print | noun |
| 22 | びょうぶ | 屏風 | byoubu | folding screen | noun |
| 23 | やきもの | 焼き物 | yakimono | pottery; ceramics | noun |
| 24 | とうき | 陶器 | touki | pottery | noun |
| 25 | じき | 磁器 | jiki | porcelain | noun |
| 26 | うるし | 漆 | urushi | lacquer | noun |
| 27 | せんす | 扇子 | sensu | folding fan | noun |
| 28 | いけばな | 生け花 | ikebana | flower arrangement | noun |
| 29 | さどう | 茶道 | sadou | tea ceremony | noun |
| 30 | かどう | 華道 | kadou | ikebana | noun |
| 31 | かぶき | 歌舞伎 | kabuki | kabuki | noun |
| 32 | らくご | 落語 | rakugo | rakugo storytelling | noun |
| 33 | ぶんらく | 文楽 | bunraku | bunraku puppet theatre | noun |
| 34 | しばい | 芝居 | shibai | play; drama | noun |
| 35 | ぶたい | 舞台 | butai | stage | noun |
| 36 | げき | 劇 | geki | play; drama | noun |
| 37 | オーケストラ |  | ookesutora | orchestra | noun |
| 38 | がっき | 楽器 | gakki | musical instrument | noun |
| 39 | クラシック |  | kurashikku | classical music | noun |
| 40 | ジャズ |  | jazu | jazz | noun |
| 41 | コンサート |  | konsaato | concert | noun |
| 42 | ひょうげん | 表現 | hyougen | expression | noun |
| 43 | そうぞうりょく | 想像力 | souzouryoku | imagination | noun |
| 44 | こせい | 個性 | kosei | individuality | noun |
| 45 | さいのう | 才能 | sainou | talent | noun |
| 46 | さくしゃ | 作者 | sakusha | author; creator | noun |
| 47 | そうさく | 創作 | sousaku | creation; original work | noun |
| 48 | しゅげい | 手芸 | shugei | handicraft | noun |
| 49 | こうげい | 工芸 | kougei | crafts | noun |
| 50 | とうげい | 陶芸 | tougei | ceramic art | noun |
| 51 | しゅうじ | 習字 | shuuji | penmanship | noun |
| 52 | げいじゅつか | 芸術家 | geijutsuka | artist | noun |
| 53 | えんそうか | 演奏家 | ensouka | performer | noun |
| 54 | さっきょくか | 作曲家 | sakkyokuka | composer | noun |
| 55 | ぶよう | 舞踊 | buyou | dance (art) | noun |
| 56 | げいのう | 芸能 | geinou | entertainment arts | noun |
| 57 | にんぎょうげき | 人形劇 | ningyougeki | puppet show | noun |

### ja-history (history, 45 words, 49 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | れきし | 歴史 | rekishi | history | noun |
| 2 | じだい | 時代 | jidai | period; era | noun |
| 3 | むかし | 昔 | mukashi | long ago | noun |
| 4 | こだい | 古代 | kodai | ancient times | noun |
| 5 | ちゅうせい | 中世 | chuusei | Middle Ages | noun |
| 6 | きんだい | 近代 | kindai | modern period | noun |
| 7 | げんだい | 現代 | gendai | present day | noun |
| 8 | せいき | 世紀 | seiki | century | noun |
| 9 | ねんだい | 年代 | nendai | age; era | noun |
| 10 | じょうもん | 縄文 | joumon | Jomon period | noun |
| 11 | やよい | 弥生 | yayoi | Yayoi period | noun |
| 12 | へいあん | 平安 | heian | Heian period | noun |
| 13 | かまくら | 鎌倉 | kamakura | Kamakura | noun |
| 14 | えど | 江戸 | edo | Edo | noun |
| 15 | めいじ | 明治 | meiji | Meiji era | noun |
| 16 | たいしょう | 大正 | taishou | Taisho era | noun |
| 17 | しょうわ | 昭和 | shouwa | Showa era | noun |
| 18 | へいせい | 平成 | heisei | Heisei era | noun |
| 19 | れいわ | 令和 | reiwa | Reiwa era | noun |
| 20 | てんのう | 天皇 | tennou | emperor | noun |
| 21 | しょうぐん | 将軍 | shougun | shogun | noun |
| 22 | さむらい | 侍 | samurai | samurai | noun |
| 23 | ぶし | 武士 | bushi | warrior | noun |
| 24 | にんじゃ | 忍者 | ninja | ninja | noun |
| 25 | だいみょう | 大名 | daimyou | feudal lord | noun |
| 26 | おうさま | 王様 | ousama | king | noun |
| 27 | じょおう | 女王 | joou | queen | noun |
| 28 | おうじ | 王子 | ouji | prince | noun |
| 29 | おひめさま | お姫様 | ohimesama | princess | noun |
| 30 | ぶき | 武器 | buki | weapon | noun |
| 31 | かたな | 刀 | katana | sword | noun |
| 32 | ゆみ | 弓 | yumi | bow (archery) | noun |
| 33 | よろい | 鎧 | yoroi | armour | noun |
| 34 | たたかい | 戦い | tatakai | battle; fight | noun |
| 35 | たたかう | 戦う | tatakau | to fight | verb |
| 36 | かつやく | 活躍 | katsuyaku | activity; success | noun |
| 37 | かくめい | 革命 | kakumei | revolution | noun |
| 38 | とうち | 統治 | touchi | rule; governance | noun |
| 39 | ほろびる | 滅びる | horobiru | to perish | verb |
| 40 | ほろぼす | 滅ぼす | horobosu | to destroy | verb |
| 41 | はんえい | 繁栄 | han'ei | prosperity | noun |
| 42 | さかえる | 栄える | sakaeru | to prosper | verb |
| 43 | うつりかわり | 移り変わり | utsurikawari | change; transition | noun |
| 44 | じんぶつ | 人物 | jinbutsu | person; figure | noun |
| 45 | でんせつ | 伝説 | densetsu | legend | noun |
| 46 | しりょうかん | 資料館 | shiryoukan | archive hall | noun |
| 47 | きおく | 記憶 | kioku | memory | noun |
| 48 | きねんび | 記念日 | kinenbi | anniversary | noun |
| 49 | しせき | 史跡 | shiseki | historic site | noun |

### ja-religion (religion, 45 words, 55 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | しゅうきょう | 宗教 | shuukyou | religion | noun |
| 2 | しんこう | 信仰 | shinkou | faith | noun |
| 3 | かみさま | 神様 | kamisama | god (polite) | noun |
| 4 | ほとけ | 仏 | hotoke | Buddha | noun |
| 5 | ぶっきょう | 仏教 | bukkyou | Buddhism | noun |
| 6 | しんとう | 神道 | shintou | Shinto | noun |
| 7 | キリストきょう | キリスト教 | kirisutokyou | Christianity | noun |
| 8 | イスラムきょう | イスラム教 | isuramukyou | Islam | noun |
| 9 | ユダヤきょう | ユダヤ教 | yudayakyou | Judaism | noun |
| 10 | ヒンドゥーきょう | ヒンドゥー教 | hinduukyou | Hinduism | noun |
| 11 | おぼうさん | お坊さん | obousan | Buddhist priest | noun |
| 12 | そう | 僧 | sou | monk | noun |
| 13 | かんぬし | 神主 | kannushi | Shinto priest | noun |
| 14 | みこ | 巫女 | miko | shrine maiden | noun |
| 15 | しんぷ | 神父 | shinpu | Catholic priest | noun |
| 16 | ぼくし | 牧師 | bokushi | pastor | noun |
| 17 | おまいり | お参り | omairi | visiting a shrine or temple | noun |
| 18 | さんぱい | 参拝 | sanpai | worship; visit to a shrine | noun |
| 19 | はつもうで | 初詣 | hatsumoude | first shrine visit of the year | noun |
| 20 | さいせん | 賽銭 | saisen | money offering | noun |
| 21 | さいせんばこ | 賽銭箱 | saisenbako | offertory box | noun |
| 22 | いのり | 祈り | inori | prayer | noun |
| 23 | いのる | 祈る | inoru | to pray | verb |
| 24 | おがむ | 拝む | ogamu | to worship; to pray to | verb |
| 25 | ねがいごと | 願い事 | negaigoto | wish | noun |
| 26 | おふだ | お札 | ofuda | talisman | noun |
| 27 | おまもり | お守り | omamori | charm; amulet | noun |
| 28 | おみくじ |  | omikuji | fortune slip | noun |
| 29 | えま | 絵馬 | ema | votive wooden plaque | noun |
| 30 | とりい | 鳥居 | torii | torii gate | noun |
| 31 | ほんでん | 本殿 | honden | main shrine building | noun |
| 32 | おはか | お墓 | ohaka | grave | noun |
| 33 | はかまいり | 墓参り | hakamairi | visiting a grave | noun |
| 34 | ぶつだん | 仏壇 | butsudan | household Buddhist altar | noun |
| 35 | かみだな | 神棚 | kamidana | household Shinto altar | noun |
| 36 | そうしき | 葬式 | soushiki | funeral | noun |
| 37 | おそうしき | お葬式 | osoushiki | funeral (polite) | noun |
| 38 | おきょう | お経 | okyou | sutra | noun |
| 39 | しゅぎょう | 修行 | shugyou | ascetic training | noun |
| 40 | ざぜん | 座禅 | zazen | Zen meditation | noun |
| 41 | ぜん | 禅 | zen | Zen | noun |
| 42 | たましい | 魂 | tamashii | soul | noun |
| 43 | れいこん | 霊魂 | reikon | spirit | noun |
| 44 | てんごく | 天国 | tengoku | heaven | noun |
| 45 | じごく | 地獄 | jigoku | hell | noun |
| 46 | ごりやく | ご利益 | goriyaku | divine blessing | noun |
| 47 | ばち | 罰 | bachi | divine punishment | noun |
| 48 | うらない | 占い | uranai | fortune-telling | noun |
| 49 | しんじゃ | 信者 | shinja | believer | noun |
| 50 | むしんろん | 無神論 | mushinron | atheism | noun |
| 51 | きよい | 清い | kiyoi | pure; clean | adj |
| 52 | ほうじ | 法事 | houji | memorial service | noun |
| 53 | いはい | 位牌 | ihai | memorial tablet | noun |
| 54 | せんぞ | 先祖 | senzo | ancestors | noun |
| 55 | くよう | 供養 | kuyou | memorial offering | noun |

### ja-festivals (festivals, 45 words, 53 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | おまつり | お祭り | omatsuri | festival | noun |
| 2 | ぼんおどり | 盆踊り | bon'odori | Bon dance | noun |
| 3 | はなび | 花火 | hanabi | fireworks | noun |
| 4 | はなびたいかい | 花火大会 | hanabitaikai | fireworks display | noun |
| 5 | みこし | 神輿 | mikoshi | portable shrine | noun |
| 6 | やたい | 屋台 | yatai | food stall | noun |
| 7 | ちょうちん | 提灯 | chouchin | paper lantern | noun |
| 8 | はっぴ | 法被 | happi | festival coat | noun |
| 9 | うちわ | 団扇 | uchiwa | paper fan | noun |
| 10 | かきごおり | かき氷 | kakigoori | shaved ice | noun |
| 11 | わたあめ | 綿あめ | wataame | cotton candy | noun |
| 12 | きんぎょすくい | 金魚すくい | kingyosukui | goldfish scooping | noun |
| 13 | りんごあめ | りんご飴 | ringoame | candy apple | noun |
| 14 | たこやき | たこ焼き | takoyaki | takoyaki | noun |
| 15 | ぎおん | 祇園 | gion | Gion | noun |
| 16 | ねぶた |  | nebuta | Nebuta festival | noun |
| 17 | ゆきまつり | 雪祭り | yukimatsuri | snow festival | noun |
| 18 | こどものひ | 子供の日 | kodomonohi | Children's Day | noun |
| 19 | こいのぼり | 鯉のぼり | koinobori | carp streamer | noun |
| 20 | かぶと | 兜 | kabuto | helmet | noun |
| 21 | ひなにんぎょう | 雛人形 | hinaningyou | Hina doll | noun |
| 22 | ななごさん | 七五三 | nanagosan | Shichi-Go-San festival | noun |
| 23 | せいじんのひ | 成人の日 | seijinnohi | Coming of Age Day | noun |
| 24 | せいじんしき | 成人式 | seijinshiki | coming-of-age ceremony | noun |
| 25 | そつぎょうしき | 卒業式 | sotsugyoushiki | graduation ceremony | noun |
| 26 | にゅうがくしき | 入学式 | nyuugakushiki | entrance ceremony | noun |
| 27 | ぶんかさい | 文化祭 | bunkasai | school culture festival | noun |
| 28 | うんどうかい | 運動会 | undoukai | sports day | noun |
| 29 | おおみそか | 大晦日 | oomisoka | New Year's Eve | noun |
| 30 | がんじつ | 元日 | ganjitsu | New Year's Day | noun |
| 31 | おせちりょうり | おせち料理 | osechiryouri | New Year dishes | noun |
| 32 | おぞうに | お雑煮 | ozouni | New Year soup with rice cake | noun |
| 33 | おとしだま | お年玉 | otoshidama | New Year's money gift | noun |
| 34 | ねんがじょう | 年賀状 | nengajou | New Year's card | noun |
| 35 | かどまつ | 門松 | kadomatsu | New Year pine decoration | noun |
| 36 | かがみもち | 鏡餅 | kagamimochi | mirror rice cake | noun |
| 37 | じょやのかね | 除夜の鐘 | joyanokane | New Year's Eve bell | noun |
| 38 | クリスマス |  | kurisumasu | Christmas | noun |
| 39 | バレンタインデー |  | barentaindee | Valentine's Day | noun |
| 40 | ホワイトデー |  | howaitodee | White Day | noun |
| 41 | ハロウィン |  | harowin | Halloween | noun |
| 42 | おいわい | お祝い | oiwai | celebration | noun |
| 43 | いわう | 祝う | iwau | to celebrate | verb |
| 44 | にぎわう | 賑わう | nigiwau | to be crowded; to flourish | verb |
| 45 | もちつき | 餅つき | mochitsuki | rice-cake pounding | noun |
| 46 | とりのいち | 酉の市 | torinoichi | Tori-no-Ichi fair | noun |
| 47 | たなばたかざり | 七夕飾り | tanabatakazari | Tanabata decoration | noun |
| 48 | たんざく | 短冊 | tanzaku | wish strip of paper | noun |
| 49 | ぎょうれつ | 行列 | gyouretsu | procession; line | noun |
| 50 | にぎわい | 賑わい | nigiwai | bustle; liveliness | noun |
| 51 | ひとだかり | 人だかり | hitodakari | crowd of onlookers | noun |
| 52 | さいてん | 祭典 | saiten | festival; celebration | noun |
| 53 | さいじつ | 祭日 | saijitsu | holiday; festival day | noun |

### ja-weddings (weddings, 40 words, 47 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | けっこん | 結婚 | kekkon | marriage | noun |
| 2 | けっこんしき | 結婚式 | kekkonshiki | wedding ceremony | noun |
| 3 | ひろうえん | 披露宴 | hirouen | wedding reception | noun |
| 4 | しきじょう | 式場 | shikijou | ceremony hall | noun |
| 5 | こんやく | 婚約 | kon'yaku | engagement | noun |
| 6 | こんやくゆびわ | 婚約指輪 | kon'yakuyubiwa | engagement ring | noun |
| 7 | けっこんゆびわ | 結婚指輪 | kekkon'yubiwa | wedding ring | noun |
| 8 | プロポーズ |  | puropoozu | proposal (of marriage) | noun |
| 9 | しんろう | 新郎 | shinrou | bridegroom | noun |
| 10 | はなよめ | 花嫁 | hanayome | bride | noun |
| 11 | はなむこ | 花婿 | hanamuko | bridegroom | noun |
| 12 | ウエディングドレス |  | uedingudoresu | wedding dress | noun |
| 13 | ドレス |  | doresu | dress (formal) | noun |
| 14 | しろむく | 白無垢 | shiromuku | white wedding kimono | noun |
| 15 | もんつき | 紋付 | montsuki | crested formal kimono | noun |
| 16 | ブーケ |  | buuke | bouquet | noun |
| 17 | なこうど | 仲人 | nakoudo | matchmaker; go-between | noun |
| 18 | しゅひん | 主賓 | shuhin | guest of honour | noun |
| 19 | しょうたいきゃく | 招待客 | shoutaikyaku | invited guest | noun |
| 20 | ごしゅうぎ | ご祝儀 | goshuugi | wedding gift money | noun |
| 21 | しゅくじ | 祝辞 | shukuji | congratulatory speech | noun |
| 22 | かんぱい | 乾杯 | kanpai | toast | noun |
| 23 | ケーキにゅうとう | ケーキ入刀 | keekinyuutou | cake cutting | noun |
| 24 | ひきでもの | 引き出物 | hikidemono | gift for guests | noun |
| 25 | にじかい | 二次会 | nijikai | after-party | noun |
| 26 | しんこんりょこう | 新婚旅行 | shinkonryokou | honeymoon | noun |
| 27 | しんこん | 新婚 | shinkon | newlywed | noun |
| 28 | ふうふ | 夫婦 | fuufu | married couple | noun |
| 29 | おむこさん | お婿さん | omukosan | bridegroom (polite) | noun |
| 30 | およめさん | お嫁さん | oyomesan | bride; daughter-in-law | noun |
| 31 | みあい | 見合い | miai | arranged meeting for marriage | noun |
| 32 | れんあい | 恋愛 | ren'ai | romantic love | noun |
| 33 | れんあいけっこん | 恋愛結婚 | ren'aikekkon | love marriage | noun |
| 34 | こいびと | 恋人 | koibito | lover; sweetheart | noun |
| 35 | かれし | 彼氏 | kareshi | boyfriend | noun |
| 36 | こうさい | 交際 | kousai | dating; association | noun |
| 37 | りこん | 離婚 | rikon | divorce | noun |
| 38 | さいこん | 再婚 | saikon | remarriage | noun |
| 39 | どくしん | 独身 | dokushin | single; unmarried | noun |
| 40 | みこん | 未婚 | mikon | unmarried | noun |
| 41 | きこん | 既婚 | kikon | married | noun |
| 42 | ぎりのおや | 義理の親 | girinooya | parents-in-law | noun |
| 43 | ぎふ | 義父 | gifu | father-in-law | noun |
| 44 | ぎぼ | 義母 | gibo | mother-in-law | noun |
| 45 | つきあう | 付き合う | tsukiau | to go out with; to associate with | verb |
| 46 | ちかう | 誓う | chikau | to vow | verb |
| 47 | むすばれる | 結ばれる | musubareru | to be united | verb |

### ja-relationships (relationships, 45 words, 51 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | かんけい | 関係 | kankei | relationship | noun |
| 2 | にんげんかんけい | 人間関係 | ningenkankei | human relations | noun |
| 3 | ゆうじょう | 友情 | yuujou | friendship | noun |
| 4 | しんゆう | 親友 | shin'yuu | close friend | noun |
| 5 | なかま | 仲間 | nakama | companion; colleague | noun |
| 6 | どうきゅうせい | 同級生 | doukyuusei | classmate | noun |
| 7 | きゅうゆう | 旧友 | kyuuyuu | old friend | noun |
| 8 | おさななじみ | 幼なじみ | osananajimi | childhood friend | noun |
| 9 | しりあい | 知り合い | shiriai | acquaintance | noun |
| 10 | ごきんじょ | ご近所 | gokinjo | neighbours | noun |
| 11 | きんじょ | 近所 | kinjo | neighbourhood | noun |
| 12 | りんじん | 隣人 | rinjin | neighbour | noun |
| 13 | あいぼう | 相棒 | aibou | partner; buddy | noun |
| 14 | ライバル |  | raibaru | rival | noun |
| 15 | てき | 敵 | teki | enemy | noun |
| 16 | みかた | 味方 | mikata | ally; supporter | noun |
| 17 | けんか | 喧嘩 | kenka | quarrel | noun |
| 18 | なかなおり | 仲直り | nakanaori | making up | noun |
| 19 | うちとける | 打ち解ける | uchitokeru | to open up; to relax with others | verb |
| 20 | しんじあう | 信じ合う | shinjiau | to trust each other | verb |
| 21 | たよる | 頼る | tayoru | to rely on | verb |
| 22 | はげます | 励ます | hagemasu | to encourage | verb |
| 23 | なぐさめる | 慰める | nagusameru | to comfort | verb |
| 24 | かばう | 庇う | kabau | to protect; to stand up for | verb |
| 25 | ささえる | 支える | sasaeru | to support | verb |
| 26 | たすけあう | 助け合う | tasukeau | to help each other | verb |
| 27 | ゆうこう | 友好 | yuukou | friendship; amity | noun |
| 28 | こうりゅう | 交流 | kouryuu | exchange; interaction | noun |
| 29 | つきあい | 付き合い | tsukiai | association; social relations | noun |
| 30 | しりあう | 知り合う | shiriau | to get to know | verb |
| 31 | であう | 出会う | deau | to meet; to come across | verb |
| 32 | でいり | 出入り | deiri | coming and going | noun |
| 33 | ひとづきあい | 人付き合い | hitozukiai | dealing with people | noun |
| 34 | きずな | 絆 | kizuna | bond | noun |
| 35 | ごえん | ご縁 | goen | connection (polite) | noun |
| 36 | しんせき | 親戚 | shinseki | relative | noun |
| 37 | おやこ | 親子 | oyako | parent and child | noun |
| 38 | しんるい | 親類 | shinrui | relatives | noun |
| 39 | ちゅうじつ | 忠実 | chuujitsu | loyal; faithful | adj |
| 40 | きょうりょく | 協力 | kyouryoku | cooperation | noun |
| 41 | たいりつ | 対立 | tairitsu | opposition; conflict | noun |
| 42 | ぎゃくに | 逆に | gyakuni | conversely | adv |
| 43 | ひとりぼっち |  | hitoribotchi | all alone | noun |
| 44 | こどく | 孤独 | kodoku | solitude; loneliness | noun |
| 45 | しんぼく | 親睦 | shinboku | friendship; getting acquainted | noun |
| 46 | おんじん | 恩人 | onjin | benefactor | noun |
| 47 | ゆうじん | 友人 | yuujin | friend (formal) | noun |
| 48 | ひとがら | 人柄 | hitogara | character; personality | noun |
| 49 | うらぎる | 裏切る | uragiru | to betray | verb |
| 50 | ひきょう | 卑怯 | hikyou | cowardly; unfair | adj |
| 51 | うちあける | 打ち明ける | uchiakeru | to confide | verb |

### ja-housing (housing, 45 words, 53 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ふどうさん | 不動産 | fudousan | real estate | noun |
| 2 | ふどうさんや | 不動産屋 | fudousan'ya | real estate agent | noun |
| 3 | ぶっけん | 物件 | bukken | property | noun |
| 4 | かしや | 貸家 | kashiya | house for rent | noun |
| 5 | ちんたい | 賃貸 | chintai | renting | noun |
| 6 | ちんたいマンション | 賃貸マンション | chintaimanshon | rental apartment | noun |
| 7 | しききん | 敷金 | shikikin | deposit | noun |
| 8 | れいきん | 礼金 | reikin | key money | noun |
| 9 | かんりひ | 管理費 | kanrihi | management fee | noun |
| 10 | けいやくしょ | 契約書 | keiyakusho | contract document | noun |
| 11 | ほしょうにん | 保証人 | hoshounin | guarantor | noun |
| 12 | あきや | 空き家 | akiya | vacant house | noun |
| 13 | ひとりぐらし | 一人暮らし | hitorigurashi | living alone | noun |
| 14 | くらす | 暮らす | kurasu | to live; to get by | verb |
| 15 | くらし | 暮らし | kurashi | living; life | noun |
| 16 | ワンルーム |  | wanruumu | studio flat | noun |
| 17 | けんちくねんすう | 建築年数 | kenchikunensuu | age of the building | noun |
| 18 | ひあたり | 日当たり | hiatari | sunlight exposure | noun |
| 19 | ひろさ | 広さ | hirosa | floor area; spaciousness | noun |
| 20 | まどり | 間取り | madori | floor plan | noun |
| 21 | わしつ | 和室 | washitsu | Japanese-style room | noun |
| 22 | ようしつ | 洋室 | youshitsu | Western-style room | noun |
| 23 | おしいれ | 押し入れ | oshiire | closet | noun |
| 24 | げたばこ | 下駄箱 | getabako | shoe cabinet | noun |
| 25 | れいぼう | 冷房 | reibou | air conditioning | noun |
| 26 | だんぼう | 暖房 | danbou | heating | noun |
| 27 | こたつ | 炬燵 | kotatsu | kotatsu | noun |
| 28 | ゆかだんぼう | 床暖房 | yukadanbou | underfloor heating | noun |
| 29 | ふろば | 風呂場 | furoba | bathroom | noun |
| 30 | よくしつ | 浴室 | yokushitsu | bathroom (formal) | noun |
| 31 | せんめんじょ | 洗面所 | senmenjo | washroom | noun |
| 32 | おてあらい | お手洗い | otearai | toilet (polite) | noun |
| 33 | しんしつ | 寝室 | shinshitsu | bedroom | noun |
| 34 | ようま | 洋間 | youma | Western-style room | noun |
| 35 | きゃくま | 客間 | kyakuma | guest room | noun |
| 36 | にかい | 二階 | nikai | second floor | noun |
| 37 | いっこだて | 一戸建て | ikkodate | detached house | noun |
| 38 | かす | 貸す | kasu | to lend; to rent out | verb |
| 39 | やねうら | 屋根裏 | yaneura | attic | noun |
| 40 | やね | 屋根 | yane | roof | noun |
| 41 | かべがみ | 壁紙 | kabegami | wallpaper | noun |
| 42 | しんちく | 新築 | shinchiku | newly built | noun |
| 43 | ちくねん | 築年 | chikunen | building age | noun |
| 44 | おうせつま | 応接間 | ousetsuma | reception room | noun |
| 45 | しょさい | 書斎 | shosai | study | noun |
| 46 | ものおき | 物置 | monooki | storeroom | noun |
| 47 | ひっこしや | 引っ越し屋 | hikkoshiya | removal company | noun |
| 48 | しゅうのう | 収納 | shuunou | storage | noun |
| 49 | ぼうおん | 防音 | bouon | soundproofing | noun |
| 50 | オートロック |  | ootorokku | auto-lock entrance | noun |
| 51 | エレベーター |  | erebeetaa | lift; elevator | noun |
| 52 | ゆうびんうけ | 郵便受け | yuubin'uke | letterbox | noun |
| 53 | じゅうきょ | 住居 | juukyo | dwelling | noun |

### ja-emergencies (emergencies, 40 words, 47 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | きんきゅう | 緊急 | kinkyuu | emergency | noun |
| 2 | ひじょう | 非常 | hijou | emergency | noun |
| 3 | ひじょうぐち | 非常口 | hijouguchi | emergency exit | noun |
| 4 | ひなん | 避難 | hinan | evacuation | noun |
| 5 | ひなんじょ | 避難所 | hinanjo | evacuation shelter | noun |
| 6 | ひなんくんれん | 避難訓練 | hinankunren | evacuation drill | noun |
| 7 | たいひ | 退避 | taihi | taking shelter | noun |
| 8 | ゆれ | 揺れ | yure | shaking; tremor | noun |
| 9 | ゆれる | 揺れる | yureru | to shake; to sway | verb |
| 10 | よしん | 余震 | yoshin | aftershock | noun |
| 11 | しんど | 震度 | shindo | seismic intensity | noun |
| 12 | けいほう | 警報 | keihou | warning | noun |
| 13 | ちゅういほう | 注意報 | chuuihou | advisory | noun |
| 14 | けいかい | 警戒 | keikai | vigilance; alert | noun |
| 15 | ぼうさいグッズ | 防災グッズ | bousaiguzzu | disaster supplies | noun |
| 16 | ひじょうしょく | 非常食 | hijoushoku | emergency food | noun |
| 17 | かいちゅうでんとう | 懐中電灯 | kaichuudentou | flashlight | noun |
| 18 | ていでん | 停電 | teiden | power outage | noun |
| 19 | だんすい | 断水 | dansui | water outage | noun |
| 20 | すくう | 救う | sukuu | to rescue | verb |
| 21 | きゅうじょ | 救助 | kyuujo | rescue | noun |
| 22 | きゅうめい | 救命 | kyuumei | lifesaving | noun |
| 23 | きゅうきゅう | 救急 | kyuukyuu | first aid; emergency care | noun |
| 24 | きゅうきゅうばこ | 救急箱 | kyuukyuubako | first-aid kit | noun |
| 25 | おうきゅう | 応急 | oukyuu | emergency measure | noun |
| 26 | おうきゅうしょち | 応急処置 | oukyuushochi | first aid treatment | noun |
| 27 | しょち | 処置 | shochi | measures; treatment | noun |
| 28 | ぼうはん | 防犯 | bouhan | crime prevention | noun |
| 29 | とうなん | 盗難 | tounan | theft | noun |
| 30 | ひったくり |  | hittakuri | bag snatching | noun |
| 31 | すり |  | suri | pickpocket | noun |
| 32 | さぎ | 詐欺 | sagi | fraud | noun |
| 33 | ふしんしゃ | 不審者 | fushinsha | suspicious person | noun |
| 34 | たいほ | 逮捕 | taiho | arrest | noun |
| 35 | つうほう | 通報 | tsuuhou | report (to authorities) | noun |
| 36 | にげる | 逃げる | nigeru | to flee; to escape | verb |
| 37 | にがす | 逃がす | nigasu | to let escape | verb |
| 38 | たいさく | 対策 | taisaku | countermeasure | noun |
| 39 | たちいりきんし | 立入禁止 | tachiirikinshi | no entry | noun |
| 40 | きけんぶつ | 危険物 | kikenbutsu | dangerous goods | noun |
| 41 | ひのよじん | 火の用心 | hinoyojin | fire precautions | noun |
| 42 | かさい | 火災 | kasai | fire (disaster) | noun |
| 43 | しょうか | 消火 | shouka | fire fighting | noun |
| 44 | しょうかき | 消火器 | shoukaki | fire extinguisher | noun |
| 45 | けむり | 煙 | kemuri | smoke | noun |
| 46 | もえる | 燃える | moeru | to burn (intransitive) | verb |
| 47 | もやす | 燃やす | moyasu | to burn (something) | verb |

### ja-law (law, 35 words, 39 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ほう | 法 | hou | law | noun |
| 2 | ほうてい | 法廷 | houtei | court (of law) | noun |
| 3 | さいばん | 裁判 | saiban | trial | noun |
| 4 | さいばんしょ | 裁判所 | saibansho | court | noun |
| 5 | さいばんかん | 裁判官 | saibankan | judge | noun |
| 6 | けんさつかん | 検察官 | kensatsukan | prosecutor | noun |
| 7 | べんごにん | 弁護人 | bengonin | defence counsel | noun |
| 8 | こうそ | 控訴 | kouso | appeal | noun |
| 9 | ひこく | 被告 | hikoku | defendant | noun |
| 10 | げんこく | 原告 | genkoku | plaintiff | noun |
| 11 | しょうこ | 証拠 | shouko | evidence | noun |
| 12 | しょうにん | 証人 | shounin | witness | noun |
| 13 | しょうげん | 証言 | shougen | testimony | noun |
| 14 | ざい | 罪 | zai | crime; sin | noun |
| 15 | はんざい | 犯罪 | hanzai | crime | noun |
| 16 | いはん | 違反 | ihan | violation | noun |
| 17 | ほうりついはん | 法律違反 | houritsuihan | breaking the law | noun |
| 18 | こうつういはん | 交通違反 | koutsuuihan | traffic violation | noun |
| 19 | ばっきん | 罰金 | bakkin | fine | noun |
| 20 | けいむしょ | 刑務所 | keimusho | prison | noun |
| 21 | けいばつ | 刑罰 | keibatsu | punishment | noun |
| 22 | ゆうざい | 有罪 | yuuzai | guilty | noun |
| 23 | むざい | 無罪 | muzai | not guilty | noun |
| 24 | はんけつ | 判決 | hanketsu | verdict | noun |
| 25 | けんり | 権利 | kenri | right | noun |
| 26 | ぎむ | 義務 | gimu | duty; obligation | noun |
| 27 | じゆう | 自由 | jiyuu | freedom | noun |
| 28 | びょうどう | 平等 | byoudou | equality | noun |
| 29 | じんけん | 人権 | jinken | human rights | noun |
| 30 | せきにん | 責任 | sekinin | responsibility | noun |
| 31 | きんじる | 禁じる | kinjiru | to forbid | verb |
| 32 | きんし | 禁止 | kinshi | prohibition | noun |
| 33 | うったえる | 訴える | uttaeru | to sue; to appeal | verb |
| 34 | だいりにん | 代理人 | dairinin | agent; proxy | noun |
| 35 | ほうむしょう | 法務省 | houmushou | Ministry of Justice | noun |
| 36 | ぼうりょく | 暴力 | bouryoku | violence | noun |
| 37 | めいよ | 名誉 | meiyo | honour | noun |
| 38 | めいよきそん | 名誉毀損 | meiyokison | defamation | noun |
| 39 | ちょさくけん | 著作権 | chosakuken | copyright | noun |

### ja-verbs-4 (verbs-4, 60 words, 72 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | おそう | 襲う | osou | to attack | verb |
| 2 | おさえる | 押さえる | osaeru | to hold down; to press | verb |
| 3 | おさまる | 収まる | osamaru | to settle down; to fit in | verb |
| 4 | おさめる | 納める | osameru | to pay; to store | verb |
| 5 | おぼれる | 溺れる | oboreru | to drown | verb |
| 6 | おもいだす | 思い出す | omoidasu | to recall | verb |
| 7 | おもいつく | 思いつく | omoitsuku | to think of | verb |
| 8 | かかえる | 抱える | kakaeru | to hold in one's arms; to have (a problem) | verb |
| 9 | かさなる | 重なる | kasanaru | to overlap; to pile up | verb |
| 10 | かさねる | 重ねる | kasaneru | to pile up; to repeat | verb |
| 11 | かたむく | 傾く | katamuku | to lean; to tilt | verb |
| 12 | かなう | 叶う | kanau | to come true | verb |
| 13 | かぶせる | 被せる | kabuseru | to cover with | verb |
| 14 | きづく | 気づく | kizuku | to notice | verb |
| 15 | くずれる | 崩れる | kuzureru | to crumble; to collapse | verb |
| 16 | くたびれる |  | kutabireru | to get tired out | verb |
| 17 | くっつく |  | kuttsuku | to stick to | verb |
| 18 | くっつける |  | kuttsukeru | to stick on | verb |
| 19 | ころがる | 転がる | korogaru | to roll | verb |
| 20 | ころす | 殺す | korosu | to kill | verb |
| 21 | こめる | 込める | komeru | to put into; to load | verb |
| 22 | さからう | 逆らう | sakarau | to go against | verb |
| 23 | さす | 指す | sasu | to point at | verb |
| 24 | さびる | 錆びる | sabiru | to rust | verb |
| 25 | しずむ | 沈む | shizumu | to sink; to set | verb |
| 26 | しずめる | 沈める | shizumeru | to sink (something) | verb |
| 27 | したがう | 従う | shitagau | to follow; to obey | verb |
| 28 | しばる | 縛る | shibaru | to tie up | verb |
| 29 | しめす | 示す | shimesu | to show; to indicate | verb |
| 30 | すべる | 滑る | suberu | to slip; to slide | verb |
| 31 | すませる | 済ませる | sumaseru | to finish; to get over with | verb |
| 32 | すむ | 済む | sumu | to be finished | verb |
| 33 | ずれる |  | zureru | to shift; to slip out of position | verb |
| 34 | せまる | 迫る | semaru | to draw near; to press | verb |
| 35 | そなえる | 備える | sonaeru | to prepare for | verb |
| 36 | そまる | 染まる | somaru | to be dyed | verb |
| 37 | そめる | 染める | someru | to dye | verb |
| 38 | たえる | 耐える | taeru | to endure | verb |
| 39 | たしかめる | 確かめる | tashikameru | to make sure; to check | verb |
| 40 | たまる | 溜まる | tamaru | to accumulate | verb |
| 41 | ためす | 試す | tamesu | to try; to test | verb |
| 42 | ちぢむ | 縮む | chijimu | to shrink | verb |
| 43 | ちぢめる | 縮める | chijimeru | to shorten | verb |
| 44 | つぐ | 注ぐ | tsugu | to pour | verb |
| 45 | つづく | 続く | tsuzuku | to continue | verb |
| 46 | つぶす | 潰す | tsubusu | to crush | verb |
| 47 | つぶれる | 潰れる | tsubureru | to be crushed; to go bankrupt | verb |
| 48 | てらす | 照らす | terasu | to illuminate | verb |
| 49 | とおす | 通す | toosu | to let through; to pass | verb |
| 50 | とかす | 溶かす | tokasu | to dissolve; to melt | verb |
| 51 | とける | 溶ける | tokeru | to melt; to dissolve | verb |
| 52 | ととのう | 整う | totonou | to be in order | verb |
| 53 | ととのえる | 整える | totonoeru | to put in order | verb |
| 54 | とびこむ | 飛び込む | tobikomu | to jump in | verb |
| 55 | ともなう | 伴う | tomonau | to accompany | verb |
| 56 | とらえる | 捉える | toraeru | to grasp; to capture | verb |
| 57 | とりあげる | 取り上げる | toriageru | to take up; to take away | verb |
| 58 | とりだす | 取り出す | toridasu | to take out | verb |
| 59 | とりのぞく | 取り除く | torinozoku | to remove | verb |
| 60 | ながす | 流す | nagasu | to let flow; to wash away | verb |
| 61 | ながれる | 流れる | nagareru | to flow | verb |
| 62 | なげく | 嘆く | nageku | to lament | verb |
| 63 | にぎる | 握る | nigiru | to grip; to grasp | verb |
| 64 | ぬすむ | 盗む | nusumu | to steal | verb |
| 65 | ぬれる | 濡れる | nureru | to get wet | verb |
| 66 | ぬらす | 濡らす | nurasu | to wet | verb |
| 67 | ねむる | 眠る | nemuru | to sleep | verb |
| 68 | のぞく | 覗く | nozoku | to peek | verb |
| 69 | のぞむ | 望む | nozomu | to wish for | verb |
| 70 | のばす | 伸ばす | nobasu | to stretch; to extend | verb |
| 71 | のびる | 伸びる | nobiru | to stretch; to grow | verb |
| 72 | のべる | 述べる | noberu | to state | verb |

### ja-onomatopoeia (onomatopoeia, 50 words, 76 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ぺらぺら |  | perapera | fluently (of speech) | adv |
| 2 | すらすら |  | surasura | smoothly; fluently | adv |
| 3 | ぐるぐる |  | guruguru | round and round | adv |
| 4 | ぴかぴか |  | pikapika | shiny; sparkling | adv |
| 5 | きらきら |  | kirakira | twinkling; glittering | adv |
| 6 | ざあざあ |  | zaazaa | pouring (rain) | adv |
| 7 | しとしと |  | shitoshito | drizzling softly | adv |
| 8 | ぽつぽつ |  | potsupotsu | in drops; a few at a time | adv |
| 9 | ごろごろ |  | gorogoro | rumbling; lazing about | adv |
| 10 | ふわふわ |  | fuwafuwa | fluffy; floating | adv |
| 11 | もちもち |  | mochimochi | chewy; springy | adv |
| 12 | さらさら |  | sarasara | silky; smoothly flowing | adv |
| 13 | つるつる |  | tsurutsuru | smooth; slippery | adv |
| 14 | ざらざら |  | zarazara | rough; gritty | adv |
| 15 | べたべた |  | betabeta | sticky | adv |
| 16 | ぬるぬる |  | nurunuru | slimy; slippery | adv |
| 17 | ふかふか |  | fukafuka | soft and fluffy | adv |
| 18 | ぶらぶら |  | burabura | strolling; dangling | adv |
| 19 | うろうろ |  | urouro | wandering about | adv |
| 20 | ぐずぐず |  | guzuguzu | dawdling | adv |
| 21 | てきぱき |  | tekipaki | briskly; efficiently | adv |
| 22 | のろのろ |  | noronoro | slowly; sluggishly | adv |
| 23 | ぺこぺこ |  | pekopeko | very hungry; bowing repeatedly | adv |
| 24 | すやすや |  | suyasuya | sleeping peacefully | adv |
| 25 | がやがや |  | gayagaya | noisily (of a crowd) | adv |
| 26 | ざわざわ |  | zawazawa | rustling; murmuring | adv |
| 27 | ぺちゃくちゃ |  | pechakucha | chattering | adv |
| 28 | ぼそぼそ |  | bosoboso | in a mumble | adv |
| 29 | ひそひそ |  | hisohiso | in whispers | adv |
| 30 | ぶつぶつ |  | butsubutsu | grumbling; muttering | adv |
| 31 | げらげら |  | geragera | laughing loudly | adv |
| 32 | にこにこ |  | nikoniko | smiling | adv |
| 33 | にやにや |  | niyaniya | grinning | adv |
| 34 | くすくす |  | kusukusu | giggling | adv |
| 35 | めそめそ |  | mesomeso | weeping softly | adv |
| 36 | ぼろぼろ |  | boroboro | in tatters; tearfully | adv |
| 37 | びしょびしょ |  | bishobisho | soaking wet | adv |
| 38 | ぐしゃぐしゃ |  | gushagusha | crumpled; messy | adv |
| 39 | ばたばた |  | batabata | bustling; flapping | adv |
| 40 | どたどた |  | dotadota | stomping | adv |
| 41 | こそこそ |  | kosokoso | sneakily | adv |
| 42 | きょろきょろ |  | kyorokyoro | looking around restlessly | adv |
| 43 | じろじろ |  | jirojiro | staring | adv |
| 44 | ちらちら |  | chirachira | flickering; glancing | adv |
| 45 | ぼんやり |  | bon'yari | vaguely; absent-mindedly | adv |
| 46 | くっきり |  | kukkiri | distinctly; clear-cut | adv |
| 47 | すっきり |  | sukkiri | refreshed; neat | adv |
| 48 | さっぱり |  | sappari | refreshed; not at all | adv |
| 49 | しっかり |  | shikkari | firmly; reliably | adv |
| 50 | ゆったり |  | yuttari | loosely; relaxed | adv |
| 51 | ぎっしり |  | gisshiri | packed tight | adv |
| 52 | こっそり |  | kossori | secretly | adv |
| 53 | そっと |  | sotto | softly; gently | adv |
| 54 | じっと |  | jitto | steadily; motionlessly | adv |
| 55 | ぐんぐん |  | gungun | rapidly; steadily | adv |
| 56 | どんどん |  | dondon | rapidly; one after another | adv |
| 57 | だんだん |  | dandan | gradually | adv |
| 58 | ますます |  | masumasu | more and more | adv |
| 59 | ころころ |  | korokoro | rolling | adv |
| 60 | ごくごく |  | gokugoku | gulping | adv |
| 61 | ぱくぱく |  | pakupaku | munching; gaping | adv |
| 62 | むしゃむしゃ |  | mushamusha | munching noisily | adv |
| 63 | ぺこり |  | pekori | bowing quickly | adv |
| 64 | がらがら |  | garagara | empty; rattling | adv |
| 65 | ぎゅうぎゅう |  | gyuugyuu | crammed; squeezing | adv |
| 66 | ぴりぴり |  | piripiri | tingling; tense | adv |
| 67 | ちくちく |  | chikuchiku | prickling | adv |
| 68 | ずきずき |  | zukizuki | throbbing | adv |
| 69 | きりきり |  | kirikiri | sharp (pain); grinding | adv |
| 70 | かんかん |  | kankan | blazing; clanging | adv |
| 71 | じりじり |  | jirijiri | scorching; inching | adv |
| 72 | ぐっと |  | gutto | firmly; much more | adv |
| 73 | ぽかぽか |  | pokapoka | nice and warm | adv |
| 74 | ひんやり |  | hin'yari | pleasantly cool | adv |
| 75 | からっと |  | karatto | crisp; dry | adv |
| 76 | じめじめ |  | jimejime | damp; humid | adv |

### ja-abstract-words (abstract-words, 55 words, 73 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | こと | 事 | koto | thing; matter | noun |
| 2 | わけ | 訳 | wake | reason; meaning | noun |
| 3 | はず | 筈 | hazu | expectation; supposed to | noun |
| 4 | つもり |  | tsumori | intention | noun |
| 5 | ため | 為 | tame | sake; purpose | noun |
| 6 | よう | 様 | you | manner; appearance | noun |
| 7 | ところ | 所 | tokoro | place; point | noun |
| 8 | おかげ | お陰 | okage | thanks to | noun |
| 9 | かわり | 代わり | kawari | substitute; instead | noun |
| 10 | ふり | 振り | furi | pretence | noun |
| 11 | うち | 内 | uchi | inside; within | noun |
| 12 | ほか | 他 | hoka | other; besides | noun |
| 13 | ばあい | 場合 | baai | case; occasion | noun |
| 14 | こんど | 今度 | kondo | this time; next time | noun |
| 15 | すべて | 全て | subete | all; everything | noun |
| 16 | ぜんたい | 全体 | zentai | whole | noun |
| 17 | ぶぶん | 部分 | bubun | part | noun |
| 18 | かてい | 過程 | katei | process | noun |
| 19 | しゅだん | 手段 | shudan | means | noun |
| 20 | じょうたい | 状態 | joutai | state; condition | noun |
| 21 | じょうきょう | 状況 | joukyou | situation | noun |
| 22 | じじつ | 事実 | jijitsu | fact | noun |
| 23 | しんじつ | 真実 | shinjitsu | truth | noun |
| 24 | ほんとう | 本当 | hontou | truth; real | noun |
| 25 | しゅるい | 種類 | shurui | kind; type | noun |
| 26 | せいしつ | 性質 | seishitsu | nature; property | noun |
| 27 | とくちょう | 特徴 | tokuchou | feature; characteristic | noun |
| 28 | かたち | 形 | katachi | shape; form | noun |
| 29 | ようす | 様子 | yousu | state; appearance | noun |
| 30 | ちから | 力 | chikara | power; strength | noun |
| 31 | のうりょく | 能力 | nouryoku | ability | noun |
| 32 | かのうせい | 可能性 | kanousei | possibility | noun |
| 33 | チャンス |  | chansu | chance | noun |
| 34 | じんせい | 人生 | jinsei | life (one's lifetime) | noun |
| 35 | げんじつ | 現実 | genjitsu | reality | noun |
| 36 | りそう | 理想 | risou | ideal | noun |
| 37 | しそう | 思想 | shisou | thought; ideology | noun |
| 38 | かち | 価値 | kachi | value; worth | noun |
| 39 | いぎ | 意義 | igi | significance | noun |
| 40 | げんど | 限度 | gendo | limit | noun |
| 41 | はんい | 範囲 | han'i | range; scope | noun |
| 42 | ていど | 程度 | teido | degree; extent | noun |
| 43 | すいじゅん | 水準 | suijun | level; standard | noun |
| 44 | わりあい | 割合 | wariai | proportion | noun |
| 45 | そんざい | 存在 | sonzai | existence | noun |
| 46 | ぎもん | 疑問 | gimon | question; doubt | noun |
| 47 | かくりつ | 確率 | kakuritsu | probability | noun |
| 48 | ぜんてい | 前提 | zentei | premise | noun |
| 49 | けってい | 決定 | kettei | decision | noun |
| 50 | へんか | 変化 | henka | change | noun |
| 51 | はってん | 発展 | hatten | development | noun |
| 52 | せいちょう | 成長 | seichou | growth | noun |
| 53 | じっこう | 実行 | jikkou | execution; carrying out | noun |
| 54 | めんどう | 面倒 | mendou | trouble; care | noun |
| 55 | きほん | 基本 | kihon | basics | noun |
| 56 | きじゅん | 基準 | kijun | standard | noun |
| 57 | ようそ | 要素 | youso | element | noun |
| 58 | ようてん | 要点 | youten | main point | noun |
| 59 | おもて | 表 | omote | front; surface | noun |
| 60 | うら | 裏 | ura | back; reverse | noun |
| 61 | ぜったい | 絶対 | zettai | absolute | noun |
| 62 | さいしょ | 最初 | saisho | the first | noun |
| 63 | さいてい | 最低 | saitei | the lowest | noun |
| 64 | さいこう | 最高 | saikou | the highest | noun |
| 65 | しゅよう | 主要 | shuyou | main; chief | noun |
| 66 | たんじゅん | 単純 | tanjun | simple | noun |
| 67 | いっぱん | 一般 | ippan | general | noun |
| 68 | ぐたいてき | 具体的 | gutaiteki | concrete | adj |
| 69 | ちゅうしょうてき | 抽象的 | chuushouteki | abstract | adj |
| 70 | きほんてき | 基本的 | kihonteki | basic | adj |
| 71 | かんぜん | 完全 | kanzen | complete | adj |
| 72 | ふかのう | 不可能 | fukanou | impossible | adj |
| 73 | かのう | 可能 | kanou | possible | adj |

### ja-money (money, 45 words, 53 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | かね | 金 | kane | money; gold | noun |
| 2 | こぜに | 小銭 | kozeni | small change | noun |
| 3 | さつ | 札 | satsu | banknote | noun |
| 4 | しへい | 紙幣 | shihei | paper money | noun |
| 5 | こうか | 硬貨 | kouka | coin | noun |
| 6 | きんがく | 金額 | kingaku | amount of money | noun |
| 7 | だいきん | 代金 | daikin | price; payment | noun |
| 8 | ひよう | 費用 | hiyou | expense; cost | noun |
| 9 | けいひ | 経費 | keihi | expenses | noun |
| 10 | せいかつひ | 生活費 | seikatsuhi | living costs | noun |
| 11 | こうねつひ | 光熱費 | kounetsuhi | utilities | noun |
| 12 | でんきだい | 電気代 | denkidai | electricity bill | noun |
| 13 | ガスだい | ガス代 | gasudai | gas bill | noun |
| 14 | すいどうだい | 水道代 | suidoudai | water bill | noun |
| 15 | しょくひ | 食費 | shokuhi | food expenses | noun |
| 16 | ちょきん | 貯金 | chokin | savings | noun |
| 17 | よきん | 預金 | yokin | bank deposit | noun |
| 18 | ローン |  | roon | loan | noun |
| 19 | しゃっきん | 借金 | shakkin | debt | noun |
| 20 | りし | 利子 | rishi | interest | noun |
| 21 | ざいさん | 財産 | zaisan | property; fortune | noun |
| 22 | おかねもち | お金持ち | okanemochi | rich person | noun |
| 23 | びんぼう | 貧乏 | binbou | poverty | noun |
| 24 | こぜにいれ | 小銭入れ | kozeniire | coin purse | noun |
| 25 | ちょちく | 貯蓄 | chochiku | savings (formal) | noun |
| 26 | とうし | 投資 | toushi | investment | noun |
| 27 | しんよう | 信用 | shin'you | trust; credit | noun |
| 28 | こぎって | 小切手 | kogitte | cheque | noun |
| 29 | かけい | 家計 | kakei | household budget | noun |
| 30 | かけいぼ | 家計簿 | kakeibo | household account book | noun |
| 31 | ねぎる | 値切る | negiru | to haggle | verb |
| 32 | はらいもどし | 払い戻し | haraimodoshi | refund | noun |
| 33 | ぜいこみ | 税込み | zeikomi | tax included | noun |
| 34 | ぜいぬき | 税抜き | zeinuki | tax excluded | noun |
| 35 | わりかん | 割り勘 | warikan | splitting the bill | noun |
| 36 | おごり | 奢り | ogori | treat | noun |
| 37 | はんがく | 半額 | hangaku | half price | noun |
| 38 | ていか | 定価 | teika | list price | noun |
| 39 | ねびき | 値引き | nebiki | discount | noun |
| 40 | そうば | 相場 | souba | market price | noun |
| 41 | ほしょうきん | 保証金 | hoshoukin | deposit; security | noun |
| 42 | たかね | 高値 | takane | high price | noun |
| 43 | やすね | 安値 | yasune | low price | noun |
| 44 | かせぐ | 稼ぐ | kasegu | to earn | verb |
| 45 | ためる | 貯める | tameru | to save up | verb |
| 46 | つかいすぎ | 使いすぎ | tsukaisugi | overspending | noun |
| 47 | むだづかい | 無駄遣い | mudazukai | waste of money | noun |
| 48 | ゆうりょう | 有料 | yuuryou | charged; paid | noun |
| 49 | むりょう | 無料 | muryou | free of charge | noun |
| 50 | きんゆう | 金融 | kin'yuu | finance | noun |
| 51 | ぞうぜい | 増税 | zouzei | tax increase | noun |
| 52 | きゅうふ | 給付 | kyuufu | benefit payment | noun |
| 53 | しきゅう | 支給 | shikyuu | payment; allowance | noun |

### ja-society (society, 50 words, 54 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | こうきょう | 公共 | koukyou | public | noun |
| 2 | だんたい | 団体 | dantai | group; organisation | noun |
| 3 | そしき | 組織 | soshiki | organisation | noun |
| 4 | しゅうだん | 集団 | shuudan | group; mass | noun |
| 5 | せだい | 世代 | sedai | generation | noun |
| 6 | わかもの | 若者 | wakamono | young people | noun |
| 7 | ろうじん | 老人 | roujin | elderly person | noun |
| 8 | こうれいしゃ | 高齢者 | koureisha | senior citizen | noun |
| 9 | こうれいか | 高齢化 | koureika | ageing of society | noun |
| 10 | しょうしか | 少子化 | shoushika | declining birthrate | noun |
| 11 | ひとびと | 人々 | hitobito | people | noun |
| 12 | せけん | 世間 | seken | the public; the world | noun |
| 13 | よろん | 世論 | yoron | public opinion | noun |
| 14 | しょうがいしゃ | 障害者 | shougaisha | disabled person | noun |
| 15 | ろうどう | 労働 | roudou | labour | noun |
| 16 | ろうどうしゃ | 労働者 | roudousha | worker | noun |
| 17 | かくさ | 格差 | kakusa | gap; disparity | noun |
| 18 | ひんこん | 貧困 | hinkon | poverty | noun |
| 19 | ボランティア |  | borantia | volunteer | noun |
| 20 | ぼきん | 募金 | bokin | fund-raising | noun |
| 21 | きふ | 寄付 | kifu | donation | noun |
| 22 | ちょうないかい | 町内会 | chounaikai | neighbourhood association | noun |
| 23 | じちたい | 自治体 | jichitai | local government | noun |
| 24 | たようせい | 多様性 | tayousei | diversity | noun |
| 25 | こじん | 個人 | kojin | individual | noun |
| 26 | きょうつう | 共通 | kyoutsuu | common | noun |
| 27 | じょせい | 女性 | josei | woman; female | noun |
| 28 | だんせい | 男性 | dansei | man; male | noun |
| 29 | だんじょ | 男女 | danjo | men and women | noun |
| 30 | ぎょうせい | 行政 | gyousei | administration | noun |
| 31 | いじめ |  | ijime | bullying | noun |
| 32 | ひきこもり |  | hikikomori | shut-in | noun |
| 33 | ふとうこう | 不登校 | futoukou | school refusal | noun |
| 34 | しゃかいじん | 社会人 | shakaijin | working adult | noun |
| 35 | かいごほけん | 介護保険 | kaigohoken | long-term care insurance | noun |
| 36 | ねんれい | 年齢 | nenrei | age | noun |
| 37 | せいべつ | 性別 | seibetsu | gender; sex | noun |
| 38 | いみん | 移民 | imin | immigrant | noun |
| 39 | じんしゅ | 人種 | jinshu | race | noun |
| 40 | みんぞく | 民族 | minzoku | ethnic group | noun |
| 41 | ぶんか | 文化 | bunka | culture | noun |
| 42 | ぶんめい | 文明 | bunmei | civilisation | noun |
| 43 | ふうぞく | 風俗 | fuuzoku | customs; manners | noun |
| 44 | ふうしゅう | 風習 | fuushuu | custom | noun |
| 45 | ちいきしゃかい | 地域社会 | chiikishakai | local community | noun |
| 46 | せいしょうねん | 青少年 | seishounen | young people | noun |
| 47 | ろうご | 老後 | rougo | old age | noun |
| 48 | こうれい | 高齢 | kourei | old age (advanced) | noun |
| 49 | じょうほうしゃかい | 情報社会 | jouhoushakai | information society | noun |
| 50 | しゃかいもんだい | 社会問題 | shakaimondai | social problem | noun |
| 51 | かこ | 過去 | kako | the past | noun |
| 52 | みらい | 未来 | mirai | the future | noun |
| 53 | げんざい | 現在 | genzai | the present | noun |
| 54 | こんご | 今後 | kongo | from now on | noun |

### ja-university (university, 50 words, 55 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | だいがくいん | 大学院 | daigakuin | graduate school | noun |
| 2 | がくぶ | 学部 | gakubu | faculty; undergraduate school | noun |
| 3 | がっか | 学科 | gakka | department; subject | noun |
| 4 | せんこう | 専攻 | senkou | major; specialisation | noun |
| 5 | りけい | 理系 | rikei | science stream | noun |
| 6 | ぶんけい | 文系 | bunkei | humanities stream | noun |
| 7 | だいがくせい | 大学生 | daigakusei | university student | noun |
| 8 | りゅうがくせい | 留学生 | ryuugakusei | international student | noun |
| 9 | りゅうがく | 留学 | ryuugaku | studying abroad | noun |
| 10 | がくひ | 学費 | gakuhi | tuition fees | noun |
| 11 | しょうがくきん | 奨学金 | shougakukin | scholarship | noun |
| 12 | じゅぎょうりょう | 授業料 | jugyouryou | tuition | noun |
| 13 | にゅうがく | 入学 | nyuugaku | entering school | noun |
| 14 | そつぎょう | 卒業 | sotsugyou | graduation | noun |
| 15 | そつぎょうろんぶん | 卒業論文 | sotsugyouronbun | graduation thesis | noun |
| 16 | レポート |  | repooto | report; paper | noun |
| 17 | ゼミ |  | zemi | seminar | noun |
| 18 | けんきゅうしつ | 研究室 | kenkyuushitsu | laboratory; professor's office | noun |
| 19 | じっけん | 実験 | jikken | experiment | noun |
| 20 | じっしゅう | 実習 | jisshuu | practical training | noun |
| 21 | こうぎ | 講義 | kougi | lecture | noun |
| 22 | こうぎしつ | 講義室 | kougishitsu | lecture room | noun |
| 23 | がくしょく | 学食 | gakushoku | university canteen | noun |
| 24 | きょうむか | 教務課 | kyoumuka | academic affairs office | noun |
| 25 | たんい | 単位 | tan'i | credit; unit | noun |
| 26 | ひっしゅう | 必修 | hisshuu | compulsory subject | noun |
| 27 | しゅっせき | 出席 | shusseki | attendance | noun |
| 28 | けっせき | 欠席 | kesseki | absence | noun |
| 29 | きょうざい | 教材 | kyouzai | teaching materials | noun |
| 30 | じしょ | 辞書 | jisho | dictionary | noun |
| 31 | さんこうしょ | 参考書 | sankousho | reference book | noun |
| 32 | もんだいしゅう | 問題集 | mondaishuu | workbook | noun |
| 33 | プリント |  | purinto | handout | noun |
| 34 | じゅけん | 受験 | juken | taking an entrance exam | noun |
| 35 | じゅけんせい | 受験生 | jukensei | exam candidate | noun |
| 36 | ごうかく | 合格 | goukaku | passing (an exam) | noun |
| 37 | ふごうかく | 不合格 | fugoukaku | failing (an exam) | noun |
| 38 | にゅうし | 入試 | nyuushi | entrance examination | noun |
| 39 | ねんど | 年度 | nendo | academic or fiscal year | noun |
| 40 | ぜんき | 前期 | zenki | first semester | noun |
| 41 | こうき | 後期 | kouki | second semester | noun |
| 42 | ほしゅう | 補習 | hoshuu | supplementary lessons | noun |
| 43 | サークル |  | saakuru | club; circle | noun |
| 44 | がくせいしょう | 学生証 | gakuseishou | student ID | noun |
| 45 | がくせいりょう | 学生寮 | gakuseiryou | student dormitory | noun |
| 46 | げしゅく | 下宿 | geshuku | lodging | noun |
| 47 | インターンシップ |  | intaanshippu | internship | noun |
| 48 | がくい | 学位 | gakui | academic degree | noun |
| 49 | はかせ | 博士 | hakase | doctor (PhD); expert | noun |
| 50 | しゅうし | 修士 | shuushi | master's degree | noun |
| 51 | がくしゃ | 学者 | gakusha | scholar | noun |
| 52 | しんろ | 進路 | shinro | career path | noun |
| 53 | しんがく | 進学 | shingaku | going on to higher education | noun |
| 54 | たんき | 短期 | tanki | short term | noun |
| 55 | ちょうき | 長期 | chouki | long term | noun |

### ja-food-culture (food-culture, 50 words, 58 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | わしょく | 和食 | washoku | Japanese food | noun |
| 2 | ようしょく | 洋食 | youshoku | Western food | noun |
| 3 | ちゅうかりょうり | 中華料理 | chuukaryouri | Chinese food | noun |
| 4 | しょくぶんか | 食文化 | shokubunka | food culture | noun |
| 5 | しょくざい | 食材 | shokuzai | ingredients | noun |
| 6 | ゆどうふ | 湯豆腐 | yudoufu | boiled tofu | noun |
| 7 | おでん |  | oden | oden | noun |
| 8 | おこのみやき | お好み焼き | okonomiyaki | okonomiyaki | noun |
| 9 | もんじゃやき | もんじゃ焼き | monjayaki | monjayaki | noun |
| 10 | ぞうすい | 雑炊 | zousui | rice soup | noun |
| 11 | おちゃづけ | お茶漬け | ochazuke | tea over rice | noun |
| 12 | いなりずし | 稲荷寿司 | inarizushi | inari sushi | noun |
| 13 | まきずし | 巻き寿司 | makizushi | rolled sushi | noun |
| 14 | ちらしずし | ちらし寿司 | chirashizushi | scattered sushi | noun |
| 15 | かいせきりょうり | 懐石料理 | kaisekiryouri | kaiseki cuisine | noun |
| 16 | しょうじんりょうり | 精進料理 | shoujinryouri | vegetarian temple cuisine | noun |
| 17 | べんとう | 弁当 | bentou | boxed lunch | noun |
| 18 | えきべん | 駅弁 | ekiben | station boxed lunch | noun |
| 19 | わがし | 和菓子 | wagashi | Japanese sweets | noun |
| 20 | だんご | 団子 | dango | dumpling (sweet) | noun |
| 21 | だいふく | 大福 | daifuku | daifuku rice cake | noun |
| 22 | どらやき | どら焼き | dorayaki | dorayaki | noun |
| 23 | せんべい | 煎餅 | senbei | rice cracker | noun |
| 24 | まんじゅう | 饅頭 | manjuu | steamed bun | noun |
| 25 | ようがし | 洋菓子 | yougashi | Western sweets | noun |
| 26 | まっちゃ | 抹茶 | matcha | powdered green tea | noun |
| 27 | ほうじちゃ | ほうじ茶 | houjicha | roasted green tea | noun |
| 28 | むぎちゃ | 麦茶 | mugicha | barley tea | noun |
| 29 | ばんちゃ | 番茶 | bancha | coarse green tea | noun |
| 30 | にほんしゅ | 日本酒 | nihonshu | sake | noun |
| 31 | しょうちゅう | 焼酎 | shouchuu | shochu | noun |
| 32 | うめぼし | 梅干し | umeboshi | pickled plum | noun |
| 33 | みりん |  | mirin | mirin | noun |
| 34 | ぬかづけ | 糠漬け | nukazuke | rice-bran pickles | noun |
| 35 | じもと | 地元 | jimoto | local area | noun |
| 36 | めいぶつ | 名物 | meibutsu | local speciality | noun |
| 37 | きょうどりょうり | 郷土料理 | kyoudoryouri | regional dish | noun |
| 38 | しゅん | 旬 | shun | season (of food) | noun |
| 39 | はしおき | 箸置き | hashioki | chopstick rest | noun |
| 40 | グルメ |  | gurume | gourmet | noun |
| 41 | たべあるき | 食べ歩き | tabearuki | eating one's way around | noun |
| 42 | くいしんぼう | 食いしん坊 | kuishinbou | glutton | noun |
| 43 | ひとくち | 一口 | hitokuchi | one bite | noun |
| 44 | あじわう | 味わう | ajiwau | to taste; to savour | verb |
| 45 | かおり | 香り | kaori | fragrance | noun |
| 46 | こうばしい | 香ばしい | koubashii | savoury; aromatic | adj |
| 47 | こってり |  | kotteri | rich; heavy (of flavour) | adv |
| 48 | あっさり |  | assari | light; plain (of flavour) | adv |
| 49 | しょくよく | 食欲 | shokuyoku | appetite | noun |
| 50 | にもの | 煮物 | nimono | simmered dish | noun |
| 51 | あげもの | 揚げ物 | agemono | fried food | noun |
| 52 | むしもの | 蒸し物 | mushimono | steamed dish | noun |
| 53 | あえもの | 和え物 | aemono | dressed salad | noun |
| 54 | すのもの | 酢の物 | sunomono | vinegared dish | noun |
| 55 | しるもの | 汁物 | shirumono | soup dish | noun |
| 56 | ちゃのま | 茶の間 | chanoma | family living room | noun |
| 57 | ちゃわんむし | 茶碗蒸し | chawanmushi | savoury steamed egg custard | noun |
| 58 | つくだに | 佃煮 | tsukudani | food simmered in soy sauce | noun |

### ja-literature (literature, 50 words, 58 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ぶんがく | 文学 | bungaku | literature | noun |
| 2 | しょうせつ | 小説 | shousetsu | novel | noun |
| 3 | しょうせつか | 小説家 | shousetsuka | novelist | noun |
| 4 | しじん | 詩人 | shijin | poet | noun |
| 5 | し | 詩 | shi | poem | noun |
| 6 | はいく | 俳句 | haiku | haiku | noun |
| 7 | たんか | 短歌 | tanka | tanka | noun |
| 8 | せんりゅう | 川柳 | senryuu | senryu | noun |
| 9 | ずいひつ | 随筆 | zuihitsu | essay | noun |
| 10 | ぶんしょう | 文章 | bunshou | text; writing | noun |
| 11 | ぶんたい | 文体 | buntai | style | noun |
| 12 | ぶん | 文 | bun | sentence | noun |
| 13 | ちょしゃ | 著者 | chosha | author | noun |
| 14 | ちょしょ | 著書 | chosho | book written by someone | noun |
| 15 | ちょさく | 著作 | chosaku | literary work | noun |
| 16 | しゅっぱん | 出版 | shuppan | publication | noun |
| 17 | しゅっぱんしゃ | 出版社 | shuppansha | publisher | noun |
| 18 | へんしゅう | 編集 | henshuu | editing | noun |
| 19 | へんしゅうしゃ | 編集者 | henshuusha | editor | noun |
| 20 | はつばい | 発売 | hatsubai | release (for sale) | noun |
| 21 | しんかん | 新刊 | shinkan | new publication | noun |
| 22 | ぞうしょ | 蔵書 | zousho | book collection | noun |
| 23 | ほんだな | 本棚 | hondana | bookshelf | noun |
| 24 | げんさく | 原作 | gensaku | original work | noun |
| 25 | げんぶん | 原文 | genbun | original text | noun |
| 26 | だいめい | 題名 | daimei | title | noun |
| 27 | もくじ | 目次 | mokuji | table of contents | noun |
| 28 | ページ |  | peeji | page | noun |
| 29 | しょせき | 書籍 | shoseki | books | noun |
| 30 | ぶんこぼん | 文庫本 | bunkobon | paperback | noun |
| 31 | ぜんしゅう | 全集 | zenshuu | complete works | noun |
| 32 | めいちょ | 名著 | meicho | great book | noun |
| 33 | ベストセラー |  | besutoseraa | bestseller | noun |
| 34 | ぶんごう | 文豪 | bungou | literary master | noun |
| 35 | こてん | 古典 | koten | classic | noun |
| 36 | ことわざ | 諺 | kotowaza | proverb | noun |
| 37 | めいげん | 名言 | meigen | famous saying | noun |
| 38 | とうじょうじんぶつ | 登場人物 | toujoujinbutsu | character (in a story) | noun |
| 39 | はいけい | 背景 | haikei | background | noun |
| 40 | ふくせん | 伏線 | fukusen | foreshadowing | noun |
| 41 | ひゆ | 比喩 | hiyu | metaphor | noun |
| 42 | くとうてん | 句読点 | kutouten | punctuation | noun |
| 43 | よみもの | 読み物 | yomimono | reading matter | noun |
| 44 | どくしゃ | 読者 | dokusha | reader | noun |
| 45 | どくは | 読破 | dokuha | reading through | noun |
| 46 | よみおわる | 読み終わる | yomiowaru | to finish reading | verb |
| 47 | まんが | 漫画 | manga | comic; manga | noun |
| 48 | えほん | 絵本 | ehon | picture book | noun |
| 49 | どうわ | 童話 | douwa | fairy tale | noun |
| 50 | むかしばなし | 昔話 | mukashibanashi | folk tale | noun |
| 51 | ふみ | 文 | fumi | letter (literary) | noun |
| 52 | かんし | 漢詩 | kanshi | Chinese-style poem | noun |
| 53 | わか | 和歌 | waka | waka poem | noun |
| 54 | きご | 季語 | kigo | season word (in haiku) | noun |
| 55 | ひょうろん | 評論 | hyouron | criticism; review | noun |
| 56 | ひょうろんか | 評論家 | hyouronka | critic | noun |
| 57 | ししゅう | 詩集 | shishuu | collection of poems | noun |
| 58 | さくひんしゅう | 作品集 | sakuhinshuu | collection of works | noun |

### ja-verbs-5 (verbs-5, 50 words, 88 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | のりこえる | 乗り越える | norikoeru | to overcome | verb |
| 2 | はずす | 外す | hazusu | to remove; to take off | verb |
| 3 | はずれる | 外れる | hazureru | to come off; to miss | verb |
| 4 | はなれる | 離れる | hanareru | to leave; to be apart | verb |
| 5 | はぶく | 省く | habuku | to omit; to save | verb |
| 6 | はやる | 流行る | hayaru | to be popular; to spread | verb |
| 7 | ひかる | 光る | hikaru | to shine | verb |
| 8 | ひろがる | 広がる | hirogaru | to spread out | verb |
| 9 | ひろげる | 広げる | hirogeru | to spread; to widen | verb |
| 10 | ふくむ | 含む | fukumu | to include; to contain | verb |
| 11 | ふさぐ | 塞ぐ | fusagu | to block; to close | verb |
| 12 | ふせぐ | 防ぐ | fusegu | to prevent | verb |
| 13 | ふるえる | 震える | furueru | to tremble | verb |
| 14 | まいる | 参る | mairu | to go; to come (humble) | verb |
| 15 | まかなう | 賄う | makanau | to provide; to cover costs | verb |
| 16 | まじる | 混じる | majiru | to be mixed | verb |
| 17 | まとめる | 纏める | matomeru | to put together; to summarise | verb |
| 18 | まとまる | 纏まる | matomaru | to come together; to be settled | verb |
| 19 | まねる | 真似る | maneru | to imitate | verb |
| 20 | みちる | 満ちる | michiru | to be full; to rise (of the tide) | verb |
| 21 | みたす | 満たす | mitasu | to fill; to satisfy | verb |
| 22 | むすぶ | 結ぶ | musubu | to tie; to conclude | verb |
| 23 | もうける | 設ける | moukeru | to set up; to establish | verb |
| 24 | もたれる |  | motareru | to lean against | verb |
| 25 | もどす | 戻す | modosu | to put back | verb |
| 26 | もよおす | 催す | moyoosu | to hold (an event) | verb |
| 27 | やぶる | 破る | yaburu | to tear; to break | verb |
| 28 | やぶれる | 破れる | yabureru | to be torn; to be defeated | verb |
| 29 | うかぶ | 浮かぶ | ukabu | to float; to come to mind | verb |
| 30 | うかべる | 浮かべる | ukaberu | to float (something) | verb |
| 31 | うく | 浮く | uku | to float | verb |
| 32 | うつす | 写す | utsusu | to copy; to photograph | verb |
| 33 | うめる | 埋める | umeru | to bury; to fill in | verb |
| 34 | うもれる | 埋もれる | umoreru | to be buried | verb |
| 35 | おぎなう | 補う | oginau | to make up for | verb |
| 36 | おどかす | 脅かす | odokasu | to threaten; to startle | verb |
| 37 | おびる | 帯びる | obiru | to carry; to have | verb |
| 38 | おもう | 思う | omou | to think | verb |
| 39 | きずく | 築く | kizuku | to build; to construct | verb |
| 40 | きわめる | 極める | kiwameru | to master; to carry to the extreme | verb |
| 41 | くいる | 悔いる | kuiru | to regret | verb |
| 42 | くむ | 組む | kumu | to put together; to cross (arms) | verb |
| 43 | くらう | 食らう | kurau | to eat; to receive (a blow) | verb |
| 44 | けずる | 削る | kezuru | to shave; to cut down | verb |
| 45 | こす | 越す | kosu | to cross over; to move | verb |
| 46 | こらす | 凝らす | korasu | to concentrate; to strain | verb |
| 47 | さぐる | 探る | saguru | to search; to feel for | verb |
| 48 | さずける | 授ける | sazukeru | to grant; to bestow | verb |
| 49 | さとる | 悟る | satoru | to realise | verb |
| 50 | しいる | 強いる | shiiru | to force; to compel | verb |
| 51 | しかる | 叱る | shikaru | to scold | verb |
| 52 | しく | 敷く | shiku | to spread; to lay | verb |
| 53 | しずまる | 静まる | shizumaru | to quieten down | verb |
| 54 | しみる | 染みる | shimiru | to soak in; to sting | verb |
| 55 | しゃべる | 喋る | shaberu | to chat; to talk | verb |
| 56 | しらべる | 調べる | shiraberu | to look into; to investigate | verb |
| 57 | しりぞく | 退く | shirizoku | to retreat | verb |
| 58 | すすめる | 勧める | susumeru | to recommend | verb |
| 59 | すます | 澄ます | sumasu | to make clear; to put on airs | verb |
| 60 | すれちがう | すれ違う | surechigau | to pass each other | verb |
| 61 | そろう | 揃う | sorou | to be complete; to be gathered | verb |
| 62 | たがやす | 耕す | tagayasu | to plough | verb |
| 63 | たくわえる | 蓄える | takuwaeru | to store; to save | verb |
| 64 | たちあがる | 立ち上がる | tachiagaru | to stand up | verb |
| 65 | たちどまる | 立ち止まる | tachidomaru | to stop (walking) | verb |
| 66 | たてる | 立てる | tateru | to stand (something) up; to make (a plan) | verb |
| 67 | ちかづく | 近づく | chikazuku | to approach | verb |
| 68 | ちかづける | 近づける | chikazukeru | to bring close | verb |
| 69 | つかいこなす | 使いこなす | tsukaikonasu | to master (a tool) | verb |
| 70 | つかえる | 仕える | tsukaeru | to serve | verb |
| 71 | つきあたる | 突き当たる | tsukiataru | to run into | verb |
| 72 | つとまる | 勤まる | tsutomaru | to be fit for a post | verb |
| 73 | つなげる | 繋げる | tsunageru | to connect; to link | verb |
| 74 | つぶやく | 呟く | tsubuyaku | to mutter | verb |
| 75 | つむ | 積む | tsumu | to pile up; to load | verb |
| 76 | つもる | 積もる | tsumoru | to pile up (of snow) | verb |
| 77 | つらなる | 連なる | tsuranaru | to stretch in a line | verb |
| 78 | とく | 解く | toku | to untie; to solve | verb |
| 79 | とぐ | 研ぐ | togu | to sharpen; to wash (rice) | verb |
| 80 | とじこめる | 閉じ込める | tojikomeru | to shut in | verb |
| 81 | とどまる | 留まる | todomaru | to remain; to stay | verb |
| 82 | とめる | 止める | tomeru | to stop (something) | verb |
| 83 | とりあつかう | 取り扱う | toriatsukau | to handle; to treat | verb |
| 84 | とりいれる | 取り入れる | toriireru | to adopt; to harvest | verb |
| 85 | とりかかる | 取りかかる | torikakaru | to set about | verb |
| 86 | とりくむ | 取り組む | torikumu | to tackle | verb |
| 87 | とりけす | 取り消す | torikesu | to cancel | verb |
| 88 | とりもどす | 取り戻す | torimodosu | to take back; to recover | verb |

## Top-up lists for the written units

Fresh against the branch, against the planned lists above and against each other. Only used if the owner chooses B.

### ja-eating-out (short by 35, 37 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | いざかや | 居酒屋 | izakaya | izakaya pub | noun |
| 2 | ていしょく | 定食 | teishoku | set meal | noun |
| 3 | ランチ |  | ranchi | lunch (menu) | noun |
| 4 | ディナー |  | dinaa | dinner (menu) | noun |
| 5 | モーニング |  | mooningu | breakfast set | noun |
| 6 | ドリンク |  | dorinku | drink | noun |
| 7 | なまビール | 生ビール | namabiiru | draught beer | noun |
| 8 | ぜんさい | 前菜 | zensai | appetiser | noun |
| 9 | デザート |  | dezaato | dessert | noun |
| 10 | カウンター |  | kauntaa | counter seat | noun |
| 11 | ざしき | 座敷 | zashiki | tatami seating | noun |
| 12 | ウェイター |  | weitaa | waiter | noun |
| 13 | ウェイトレス |  | weitoresu | waitress | noun |
| 14 | おすすめ | お勧め | osusume | recommendation | noun |
| 15 | だいもり | 大盛り | daimori | large portion | noun |
| 16 | ひとりまえ | 一人前 | hitorimae | one serving | noun |
| 17 | とりざら | 取り皿 | torizara | small serving plate | noun |
| 18 | わりばし | 割り箸 | waribashi | disposable chopsticks | noun |
| 19 | つまようじ | 爪楊枝 | tsumayouji | toothpick | noun |
| 20 | ナプキン |  | napukin | napkin | noun |
| 21 | おひや | お冷や | ohiya | cold water (in a restaurant) | noun |
| 22 | のみほうだい | 飲み放題 | nomihoudai | all-you-can-drink | noun |
| 23 | たべほうだい | 食べ放題 | tabehoudai | all-you-can-eat | noun |
| 24 | バイキング |  | baikingu | buffet | noun |
| 25 | おあいそ | お愛想 | oaiso | the bill (restaurant slang) | noun |
| 26 | べつべつ | 別々 | betsubetsu | separately | noun |
| 27 | ラーメンや | ラーメン屋 | raamen'ya | ramen shop | noun |
| 28 | そばや | 蕎麦屋 | sobaya | soba shop | noun |
| 29 | すしや | 寿司屋 | sushiya | sushi restaurant | noun |
| 30 | ファストフード |  | fasutofuudo | fast food | noun |
| 31 | ファミレス |  | famiresu | family restaurant | noun |
| 32 | ちゅうぼう | 厨房 | chuubou | kitchen (of a restaurant) | noun |
| 33 | しょくけん | 食券 | shokuken | meal ticket | noun |
| 34 | しょくけんき | 食券機 | shokukenki | ticket vending machine | noun |
| 35 | もちかえり | 持ち帰り | mochikaeri | takeaway | noun |
| 36 | テイクアウト |  | teikuauto | takeout | noun |
| 37 | でまえ | 出前 | demae | food delivery | noun |

### ja-shopping (short by 29, 31 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | デパート |  | depaato | department store | noun |
| 2 | しょうてんがい | 商店街 | shoutengai | shopping street | noun |
| 3 | ショッピング |  | shoppingu | shopping | noun |
| 4 | ショッピングセンター |  | shoppingusentaa | shopping centre | noun |
| 5 | コンビニ |  | konbini | convenience store | noun |
| 6 | ドラッグストア |  | doraggusutoa | drugstore | noun |
| 7 | ひゃくえんショップ | 百円ショップ | hyakuenshoppu | 100-yen shop | noun |
| 8 | うりば | 売り場 | uriba | sales floor | noun |
| 9 | しなもの | 品物 | shinamono | goods | noun |
| 10 | しょうひん | 商品 | shouhin | merchandise | noun |
| 11 | しなぎれ | 品切れ | shinagire | out of stock | noun |
| 12 | ざいこ | 在庫 | zaiko | stock; inventory | noun |
| 13 | セール |  | seeru | sale | noun |
| 14 | とくばい | 特売 | tokubai | special sale | noun |
| 15 | レジ |  | reji | cash register | noun |
| 16 | ふくびき | 福引 | fukubiki | lottery draw | noun |
| 17 | うりきれ | 売り切れ | urikire | sold out | noun |
| 18 | しちゃく | 試着 | shichaku | trying on | noun |
| 19 | しちゃくしつ | 試着室 | shichakushitsu | fitting room | noun |
| 20 | へんぴん | 返品 | henpin | returning goods | noun |
| 21 | ほしょうしょ | 保証書 | hoshousho | warranty card | noun |
| 22 | ラッピング |  | rappingu | gift wrapping | noun |
| 23 | プレゼント |  | purezento | present | noun |
| 24 | ギフト |  | gifuto | gift | noun |
| 25 | かんばん | 看板 | kanban | signboard | noun |
| 26 | てんちょう | 店長 | tenchou | shop manager | noun |
| 27 | はんばい | 販売 | hanbai | sales | noun |
| 28 | しいれ | 仕入れ | shiire | stocking up | noun |
| 29 | ちんれつ | 陳列 | chinretsu | display | noun |
| 30 | ショーウィンドウ |  | shoowindou | shop window | noun |
| 31 | おとく | お得 | otoku | good value | adj |

### ja-music (short by 26, 39 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | バイオリン |  | baiorin | violin | noun |
| 2 | フルート |  | furuuto | flute | noun |
| 3 | トランペット |  | toranpetto | trumpet | noun |
| 4 | ドラム |  | doramu | drum kit | noun |
| 5 | しゃみせん | 三味線 | shamisen | shamisen | noun |
| 6 | ハーモニカ |  | haamonika | harmonica | noun |
| 7 | オルガン |  | orugan | organ | noun |
| 8 | リコーダー |  | rikoodaa | recorder | noun |
| 9 | ベース |  | beesu | bass | noun |
| 10 | カラオケ |  | karaoke | karaoke | noun |
| 11 | うたごえ | 歌声 | utagoe | singing voice | noun |
| 12 | くちぶえ | 口笛 | kuchibue | whistle | noun |
| 13 | はくしゅ | 拍手 | hakushu | applause | noun |
| 14 | リズム |  | rizumu | rhythm | noun |
| 15 | メロディー |  | merodii | melody | noun |
| 16 | ハーモニー |  | haamonii | harmony | noun |
| 17 | おんぷ | 音符 | onpu | musical note | noun |
| 18 | かし | 歌詞 | kashi | lyrics | noun |
| 19 | さくし | 作詞 | sakushi | writing lyrics | noun |
| 20 | さっきょく | 作曲 | sakkyoku | composing | noun |
| 21 | バンド |  | bando | band | noun |
| 22 | ボーカル |  | bookaru | vocalist | noun |
| 23 | ライブ |  | raibu | live show | noun |
| 24 | ステージ |  | suteeji | stage | noun |
| 25 | ファン |  | fan | fan | noun |
| 26 | アイドル |  | aidoru | idol | noun |
| 27 | ヒット |  | hitto | hit | noun |
| 28 | ねいろ | 音色 | neiro | tone | noun |
| 29 | おんかい | 音階 | onkai | musical scale | noun |
| 30 | がっしょう | 合唱 | gasshou | chorus | noun |
| 31 | がっしょうだん | 合唱団 | gasshoudan | choir | noun |
| 32 | レコード |  | rekoodo | record | noun |
| 33 | ヘッドホン |  | heddohon | headphones | noun |
| 34 | イヤホン |  | iyahon | earphones | noun |
| 35 | スピーカー |  | supiikaa | speaker | noun |
| 36 | おんがくかい | 音楽会 | ongakukai | concert recital | noun |
| 37 | リサイタル |  | risaitaru | recital | noun |
| 38 | ひきがたり | 弾き語り | hikigatari | singing to one's own accompaniment | noun |
| 39 | おんち | 音痴 | onchi | tone-deaf person | noun |

### ja-hobbies (short by 21, 26 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | さいしゅう | 採集 | saishuu | collecting (specimens) | noun |
| 2 | ガーデニング |  | gaadeningu | gardening | noun |
| 3 | えんげい | 園芸 | engei | horticulture | noun |
| 4 | ペット |  | petto | pet | noun |
| 5 | ドライブ |  | doraibu | drive | noun |
| 6 | キャンプ |  | kyanpu | camping | noun |
| 7 | バーベキュー |  | baabekyuu | barbecue | noun |
| 8 | ダイビング |  | daibingu | diving | noun |
| 9 | サーフィン |  | saafin | surfing | noun |
| 10 | ヨット |  | yotto | yacht | noun |
| 11 | パズル |  | pazuru | puzzle | noun |
| 12 | しょうぎ | 将棋 | shougi | shogi | noun |
| 13 | いご | 囲碁 | igo | go (board game) | noun |
| 14 | オセロ |  | osero | Othello | noun |
| 15 | カードゲーム |  | kaadogeemu | card game | noun |
| 16 | マジック |  | majikku | magic tricks | noun |
| 17 | ゲームセンター |  | geemusentaa | arcade | noun |
| 18 | コレクション |  | korekushon | collection | noun |
| 19 | しゅうしゅう | 収集 | shuushuu | collecting | noun |
| 20 | てづくり | 手作り | tezukuri | handmade | noun |
| 21 | あみもの | 編み物 | amimono | knitting | noun |
| 22 | やまあるき | 山歩き | yamaaruki | hill walking | noun |
| 23 | にっこうよく | 日光浴 | nikkouyoku | sunbathing | noun |
| 24 | てんたいかんそく | 天体観測 | tentaikansoku | stargazing | noun |
| 25 | ぼうえんきょう | 望遠鏡 | bouenkyou | telescope | noun |
| 26 | バードウォッチング |  | baadowotchingu | birdwatching | noun |

### ja-things (short by 19, 30 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ボールペン |  | boorupen | ballpoint pen | noun |
| 2 | シャープペンシル |  | shaapupenshiru | mechanical pencil | noun |
| 3 | えんぴつけずり | 鉛筆削り | enpitsukezuri | pencil sharpener | noun |
| 4 | テープ |  | teepu | tape | noun |
| 5 | セロハンテープ |  | serohanteepu | sticky tape | noun |
| 6 | ガムテープ |  | gamuteepu | packing tape | noun |
| 7 | ゴム |  | gomu | rubber; elastic | noun |
| 8 | はり | 針 | hari | needle | noun |
| 9 | ハンマー |  | hanmaa | hammer | noun |
| 10 | かなづち | 金槌 | kanazuchi | hammer (tool) | noun |
| 11 | ドライバー |  | doraibaa | screwdriver | noun |
| 12 | のこぎり | 鋸 | nokogiri | saw | noun |
| 13 | ペンチ |  | penchi | pliers | noun |
| 14 | はしご | 梯子 | hashigo | ladder | noun |
| 15 | ロープ |  | roopu | rope | noun |
| 16 | てぬぐい | 手ぬぐい | tenugui | hand towel | noun |
| 17 | ハンガー |  | hangaa | coat hanger | noun |
| 18 | ライター |  | raitaa | lighter | noun |
| 19 | マッチ |  | matchi | match | noun |
| 20 | ろうそく | 蝋燭 | rousoku | candle | noun |
| 21 | でんきゅう | 電球 | denkyuu | light bulb | noun |
| 22 | ふうせん | 風船 | fuusen | balloon | noun |
| 23 | ふきん | 布巾 | fukin | dishcloth | noun |
| 24 | ぬいぐるみ |  | nuigurumi | stuffed toy | noun |
| 25 | おもちゃ |  | omocha | toy | noun |
| 26 | つみき | 積み木 | tsumiki | building blocks | noun |
| 27 | トランプ |  | toranpu | playing cards | noun |
| 28 | うきわ | 浮き輪 | ukiwa | swim ring | noun |
| 29 | つえ | 杖 | tsue | walking stick | noun |
| 30 | くるまいす | 車椅子 | kurumaisu | wheelchair | noun |

### ja-cooking (short by 14, 30 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | レシピ |  | reshipi | recipe | noun |
| 2 | フライパン |  | furaipan | frying pan | noun |
| 3 | おたま |  | otama | ladle | noun |
| 4 | しゃもじ | 杓文字 | shamoji | rice paddle | noun |
| 5 | へら |  | hera | spatula | noun |
| 6 | すりばち | 擂り鉢 | suribachi | mortar | noun |
| 7 | みじんぎり | みじん切り | mijingiri | mincing | noun |
| 8 | せんぎり | 千切り | sengiri | julienne | noun |
| 9 | うすぎり | 薄切り | usugiri | thin slicing | noun |
| 10 | かくぎり | 角切り | kakugiri | dicing | noun |
| 11 | こさじ | 小さじ | kosaji | teaspoon | noun |
| 12 | おおさじ | 大さじ | oosaji | tablespoon | noun |
| 13 | カップ |  | kappu | measuring cup | noun |
| 14 | ひとつまみ | 一つまみ | hitotsumami | a pinch | noun |
| 15 | てきりょう | 適量 | tekiryou | a suitable amount | noun |
| 16 | したごしらえ | 下ごしらえ | shitagoshirae | preparation | noun |
| 17 | あじつけ | 味付け | ajitsuke | seasoning | noun |
| 18 | あじみ | 味見 | ajimi | tasting | noun |
| 19 | ふっとう | 沸騰 | futtou | boiling | noun |
| 20 | とろび | とろ火 | torobi | low heat | noun |
| 21 | ちゅうび | 中火 | chuubi | medium heat | noun |
| 22 | つよび | 強火 | tsuyobi | high heat | noun |
| 23 | むす | 蒸す | musu | to steam | verb |
| 24 | いる | 炒る | iru | to roast; to parch | verb |
| 25 | あぶる | 炙る | aburu | to broil lightly | verb |
| 26 | すりおろす | 摺り下ろす | suriorosu | to grate | verb |
| 27 | ほぐす |  | hogusu | to loosen; to flake | verb |
| 28 | のせる | 載せる | noseru | to put on top | verb |
| 29 | ふりかける | 振り掛ける | furikakeru | to sprinkle | verb |
| 30 | ひたす | 浸す | hitasu | to soak | verb |

### ja-school (short by 14, 28 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ちゅうがっこう | 中学校 | chuugakkou | junior high school | noun |
| 2 | こうこう | 高校 | koukou | high school | noun |
| 3 | ようちえん | 幼稚園 | youchien | kindergarten | noun |
| 4 | ほいくえん | 保育園 | hoikuen | nursery | noun |
| 5 | しんにゅうせい | 新入生 | shinnyuusei | new student | noun |
| 6 | せいと | 生徒 | seito | pupil | noun |
| 7 | クラス |  | kurasu | class | noun |
| 8 | クラスメート |  | kurasumeeto | classmate | noun |
| 9 | たんにん | 担任 | tannin | homeroom teacher | noun |
| 10 | ぎょうじ | 行事 | gyouji | event | noun |
| 11 | えんそく | 遠足 | ensoku | school trip | noun |
| 12 | ちょうれい | 朝礼 | chourei | morning assembly | noun |
| 13 | テスト |  | tesuto | test | noun |
| 14 | りかしつ | 理科室 | rikashitsu | science room | noun |
| 15 | としょしつ | 図書室 | toshoshitsu | school library | noun |
| 16 | しょくいんしつ | 職員室 | shokuinshitsu | staff room | noun |
| 17 | ランドセル |  | randoseru | school backpack | noun |
| 18 | うわばき | 上履き | uwabaki | indoor shoes | noun |
| 19 | ひっきようぐ | 筆記用具 | hikkiyougu | writing materials | noun |
| 20 | ぶんぼうぐ | 文房具 | bunbougu | stationery | noun |
| 21 | つうがくろ | 通学路 | tsuugakuro | route to school | noun |
| 22 | つうがく | 通学 | tsuugaku | commuting to school | noun |
| 23 | ふくしゅう | 復習 | fukushuu | review | noun |
| 24 | よしゅう | 予習 | yoshuu | preparation (before class) | noun |
| 25 | しつもん | 質問 | shitsumon | question | noun |
| 26 | くりかえす | 繰り返す | kurikaesu | to repeat | verb |
| 27 | かきとり | 書き取り | kakitori | dictation | noun |
| 28 | あんき | 暗記 | anki | memorising | noun |

### ja-groceries (short by 4, 9 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | れいとうしょくひん | 冷凍食品 | reitoushokuhin | frozen food | noun |
| 2 | ベーコン |  | beekon | bacon | noun |
| 3 | ツナ |  | tsuna | tuna (canned) | noun |
| 4 | ケチャップ |  | kechappu | ketchup | noun |
| 5 | マヨネーズ |  | mayoneezu | mayonnaise | noun |
| 6 | ドレッシング |  | doresshingu | dressing | noun |
| 7 | ソース |  | soosu | sauce | noun |
| 8 | こむぎこ | 小麦粉 | komugiko | wheat flour | noun |
| 9 | しょくパン | 食パン | shokupan | sliced bread | noun |

### ja-weather (short by 3, 10 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | てんこう | 天候 | tenkou | weather conditions | noun |
| 2 | くもる | 曇る | kumoru | to become cloudy | verb |
| 3 | ふる | 降る | furu | to fall (rain or snow) | verb |
| 4 | やむ | 止む | yamu | to stop (of rain) | verb |
| 5 | こごえる | 凍える | kogoeru | to freeze; to be numb with cold | verb |
| 6 | しっけ | 湿気 | shikke | humidity; dampness | noun |
| 7 | きり | 霧 | kiri | fog | noun |
| 8 | ひなた | 日向 | hinata | sunny place | noun |
| 9 | ひかげ | 日陰 | hikage | shade | noun |
| 10 | あまやどり | 雨宿り | amayadori | sheltering from the rain | noun |

### ja-body (short by 2, 6 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | ひじ | 肘 | hiji | elbow | noun |
| 2 | かかと | 踵 | kakato | heel | noun |
| 3 | つまさき | 爪先 | tsumasaki | tiptoe | noun |
| 4 | てくび | 手首 | tekubi | wrist | noun |
| 5 | あしくび | 足首 | ashikubi | ankle | noun |
| 6 | ひたい | 額 | hitai | forehead | noun |

### ja-describing (short by 2, 5 ready)

| # | word | kanji (reference) | reading | gloss | pos |
|---|---|---|---|---|---|
| 1 | りっぱ | 立派 | rippa | splendid; fine | adj |
| 2 | あざやか | 鮮やか | azayaka | vivid | adj |
| 3 | だめ | 駄目 | dame | useless; no good | adj |
| 4 | へん | 変 | hen | strange; odd | adj |
| 5 | ふさわしい | 相応しい | fusawashii | suitable | adj |
