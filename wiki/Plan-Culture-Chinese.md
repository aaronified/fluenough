# Plan: Mandarin Chinese genre decks, verified sourcing list (culture, proverbs and chengyu, multi-word families, recommendations, creators)

Task ZH-001 of [Deck-Work-Queue-ZH](Deck-Work-Queue-ZH.md), written 2026-11-15 under the Chinese override of rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md), in the shape of [Plan-Culture-Japanese](Plan-Culture-Japanese.md), [Plan-Culture-French](Plan-Culture-French.md) and [Plan-Culture-Kannada](Plan-Culture-Kannada.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, for the tasks ZH-010 to ZH-013 (culture), ZH-025 to ZH-027 (proverbs and chengyu), ZH-030 to ZH-032 (multi-word) and ZH-060 (recommendations and creators). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md). If this page and a task row of the queue differ, this page wins. No Chinese speaker reviews the decks (owner, 2026-11-13): everything ships `unreviewed` and doubts go to `docs/review-queue/zh.md`.

**Unlike the French page, this one has been read.** Every row says what the author of this page read on a named page on 2026-11-15, and the Status column says how much:

- **V (verified)**: the text of the item (or, for a chengyu, a proverb or a family member, its dictionary entry) and the creator's two lifespan endpoints were both read on the cited page. A builder may write the card.
- **P (partly read)**: the text was read, but the creator's lifespan is only a century or a tradition, or one endpoint is missing. The card can be written only if the validator takes the creator without the missing field, or the reviewer fills it.
- **C (candidate)**: a page exists but its text, author or date was not read. A builder reads it first or drops it. **Nothing is filled in from memory.**
- **F (flagged)**: a recommendation whose year or creator was read only in part, or where two pages disagree.

The texts were read as raw wikitext of zh.wikisource.org (the pages are traditional script; the one hand-made step is the simplified rendering of each excerpt, which a builder repeats for itself and a reviewer checks). The lifespans were read on en.wikipedia. The dictionary entries were read on en.wiktionary.org and zh.wiktionary.org. Reads were one request every 2 to 3 seconds; the API of the sites answered 429 more than once and every item below was read through plain page fetches.

## Counts

| Kind | Verified (V) | Partly read (P) | Candidate (C) or flagged (F) | Dropped (could not read) |
|---|---|---|---|---|
| Culture, `zh-culture-1` (poems) | 17 | 1 | 0 | 3 titles |
| Culture, `zh-culture-2` (philosophy) | 13 | 4 | 1 | 2 titles |
| Culture, `zh-culture-3` (chengyu with their source line) | 17 | 1 | 0 | 3 titles (+ 2 reserve texts read) |
| Culture, `zh-culture-4` (festivals, folk song, prose) | 13 | 0 | 3 | 5 titles |
| Chengyu, `zh-proverbs-1` and `-2` (2 x 20) | 40 (every entry read) | 0 | 0 | 1 |
| Sayings, `zh-proverbs-3` (20) | 20 (every entry read) | 0 | 0 | 7 |
| Multi-word: separable verb-object (20) | 20 | 0 | 0 | 0 |
| Multi-word: resultative (20 of 23 listed) | 19 of the 23 have an entry; 4 are compositional | 0 | 0 | 0 |
| Multi-word: directional (20 of 24 listed) | 10 of the 24 have an entry; 14 are compositional | 0 | 0 | 0 |
| Multi-word: idiomatic verb phrases (20) | 20 | 0 | 0 | 1 |
| Recommendations (21 listed) | 18 | 0 | 3 flagged | 0 |
| Creators (35 listed) | 32 | 2 (Laozi, Zhuang Zhou: no years) | 1 (Li Shen: no birth year) | 0 |

Culture deck sizes are 18, 18, 18 and 16: **`zh-culture-4` ships short** (16 listed, of which 3 are candidates), and the deck is never padded.

## Rights rule for Chinese texts

What the validator enforces (read from `tools/validate_decks.py` on main, 2026-11-15; nothing was run):

| Rule | Value in the code |
|---|---|
| Table | `PD_TERMS = {"IN": 60, "BD": 60, "ES": 70, "FR": 70, "JP": 70, "CN": 50}`; any other jurisdiction takes 70 |
| Named author | `public_domain_problem` fails a source when `author_died + term >= this year`; the owner's floor (CLAUDE.md, rights floor for culture) is stricter than the `CN` table and is the rule used here: **died 1955 or earlier**. A negative (BCE) `author_died` passes the sum |
| Anonymous work | `author: "anonymous"` needs a `date` that `parse_years` accepts, whose first year is before 1900 |
| `source.date` | `parse_years` takes an integer 1 to 9999, `"c. 1750"` or `"1892-1909"`. **It does not accept a BCE year** (first = 1 at the earliest) |
| Creator `born` and `died` | `_year_of` accepts a year, **negative for BCE**, or `{ year, circa: true }` |
| Quotation | `basis: "quotation"` is limited to 25 words and 5 cards a deck. This plan uses no `quotation` items |

All named creators below died between c. 479 BCE (Confucius) and 1948 (Zhu Ziqing), so every item is far inside the floor. Zhu Ziqing (died 12 August 1948) is the latest; Lu Xun (died 1936) is a recommendation only. **The legal opinion belongs to the reviewer** (D10): the floor catches typos, and this page does not claim the PRC, Taiwan or Hong Kong terms.

## Rules applied

- **Public domain only for culture**: `basis: "public-domain"`, `jurisdiction: "CN"`, `rights_checked: 2026-11-15`. Anything not public domain is a recommendation (source-it-yourself, below), never a culture card.
- **Excerpts**: one line, couplet or sentence, at most 25 words; in Chinese the unit is the **hanzi** (the tool counts characters for a script written without spaces). The longest excerpt on this page is 20 hanzi (the cell "Hanzi / untaught" gives the count). A 28-hanzi quatrain is cut to one couplet; a 20-hanzi quatrain is kept whole, which is 24 characters with punctuation.
- **Script**: the course is simplified (`han_simplified`, with `han_traditional` as the second script). Wikisource shows traditional, so each excerpt here is the builder's own simplified rendering of the traditional text that was read; the `source` block says "shown in simplified characters".
- **Basic hanzi only**: the column "Hanzi / untaught" counts the hanzi of the excerpt that are not in any core deck of the course (**1,834 distinct hanzi are taught, read from every `decks/zh/zh-*.yaml` on decks-live, `09e2a6d6`**). The characters in `zh-characters-1` to `-7` alone are only 70, which is too few to write any classical text, so "taught" here means "a hanzi of some taught word", as the queue's rule for example words reads. Every untaught hanzi must have its reading and meaning in the card's note; items with 0 to 2 untaught hanzi are the safe ones.
- **Dates are never guessed.** A poem's year is usually unknown, so `date` takes the creator's lifetime as a span, as batch 1 of the Japanese deck does for Buson, Ryokan and Dogen; the row says so. Where the page read gives a year (Zhu Ziqing's *Spring*, 1933; Fan Zhongyan's *Yueyang Tower*, 1046) it is used.
- **Text as on the page**: variants that Wikisource marks (`另`) are listed in the row; the excerpt avoids a marked variant where it can and says so where it cannot.
- **Translations** are the builder's own plain renderings, never a quotation of anyone's translation.
- **Readings**: pinyin as said, from Wiktionary for each new word (queue, section 2); no `ipa` or `phonetic` (ZH-110 to ZH-113 write them).
- **Creators** go in `decks/creators/zh.yaml` (created by ZH-010, extended by ZH-011 to ZH-013 and ZH-060): short A2-level English bio, `born` and `died` as in the creators table below, an era, `legacy` with one to two checkable items each with a source link, no image.
- **Ids**: culture `zh-6000` to `zh-6199` (50 per deck), proverbs and chengyu `zh-6200` to `zh-6399` (50 per deck), multi-word `zh-6400` to `zh-6599` (50 per family), inside the queue's reserved genre range 6000 to 6999.
- **Order of work**: ZH-010 to ZH-013 run one after another on one shared branch because they share `creators/zh.yaml`; ZH-060 follows. Proverbs and multi-word decks are independent.

## Culture decks (ZH-010 to ZH-013)

### zh-culture-1: Tang and Song short poems (ids zh-6000 to 6049)

| # | Work | Creator, lifespan as read | Status | Date for `source.date` | Wikisource page | Excerpt (simplified; builder converts from the traditional text read) | Hanzi / untaught | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | 咏鹅 (Ode to the Goose) | Luo Binwang; c. 619 to 684? (en) | V | 7th c. (year unknown); creator span | [詠鵝](https://zh.wikisource.org/wiki/%E8%A9%A0%E9%B5%9D) | 鹅，鹅，鹅，曲项向天歌。白毛浮绿水，红掌拨清波。 | 18 / 3 掌波浮 | Wikisource note: written at age seven. Lifespan has a question mark on en.wikipedia: circa both ends |
| 2 | 春晓 (Spring Dawn) | Meng Haoran; 689/691 to 740 | V | 689-740 (year unknown) | [春曉 (孟浩然)](https://zh.wikisource.org/wiki/%E6%98%A5%E6%9B%89_%28%E5%AD%9F%E6%B5%A9%E7%84%B6%29) | 春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。 | 20 / 2 啼晓 | Birth year uncertain (689 or 691): circa |
| 3 | 静夜思 (Quiet Night Thought) | Li Bai; 701 to 762 | V | 701-762 (year unknown) | [靜夜思](https://zh.wikisource.org/wiki/%E9%9D%9C%E5%A4%9C%E6%80%9D) | 床前明月光，疑是地上霜。举头望明月，低头思故乡。 | 20 / 0 | Wikisource records two texts: the Collected Works has 看月光 and 望山月, the Three Hundred Tang Poems (the common school text) has 明月光 and 望明月. The card uses the second and says so |
| 4 | 登鹳雀楼 (Climbing Stork Tower) | Wang Zhihuan; c. 688 to 742 | V | 688-742 (year unknown) | [登鸛雀樓 (王之渙)](https://zh.wikisource.org/wiki/%E7%99%BB%E9%B8%9B%E9%9B%80%E6%A8%93_%28%E7%8E%8B%E4%B9%8B%E6%B8%99%29) | 白日依山尽，黄河入海流。欲穷千里目，更上一层楼。 | 20 / 1 欲 | Wikisource variant 層/重 for the last line: 层 used |
| 5 | 悯农 (锄禾日当午) (Pity the Farmers) | Li Shen; died 846; birth not read | P | c. 800s (year unknown); span not available | [憫農 (鋤禾日當午)](https://zh.wikisource.org/wiki/%E6%86%AB%E8%BE%B2_%28%E9%8B%A4%E7%A6%BE%E6%97%A5%E7%95%B6%E5%8D%88%29) | 锄禾日当午，汗滴禾下土。谁知盘中餐，粒粒皆辛苦。 | 20 / 5 滴皆禾粒锄 | `born` could not be read: either read it on zh.wikipedia first or leave `born` out if the validator allows |
| 6 | 江雪 (River Snow) | Liu Zongyuan; 773 to 819 | V | 773-819 (year unknown) | [江雪](https://zh.wikisource.org/wiki/%E6%B1%9F%E9%9B%AA) | 千山鸟飞绝，万径人踪灭。孤舟蓑笠翁，独钓寒江雪。 | 20 / 4 径江笠蓑 |  |
| 7 | 游子吟 (Song of the Wandering Son) | Meng Jiao; 751 to 814 | V | 751-814 (year unknown) | [遊子吟 (孟郊)](https://zh.wikisource.org/wiki/%E9%81%8A%E5%AD%90%E5%90%9F_%28%E5%AD%9F%E9%83%8A%29) | 慈母手中线，游子身上衣。 | 10 / 0 | First couplet only (14 hanzi); the whole poem is 30 hanzi |
| 8 | 梅花 (Plum Blossom) | Wang Anshi; 1021 to 1086 | V | 1021-1086 (year unknown) | [梅花 (王安石)](https://zh.wikisource.org/wiki/%E6%A2%85%E8%8A%B1_%28%E7%8E%8B%E5%AE%89%E7%9F%B3%29) | 墙角数枝梅，凌寒独自开。遥知不是雪，为有暗香来。 | 20 / 2 凌遥 | Northern Song |
| 9 | 枫桥夜泊 (Night Mooring at Maple Bridge) | Zhang Ji; fl. 715 to 779 (born 712-715) | V | c. 750s-779 (year unknown); circa lifespan | [楓橋夜泊](https://zh.wikisource.org/wiki/%E6%A5%93%E6%A9%8B%E5%A4%9C%E6%B3%8A) | 姑苏城外寒山寺，夜半钟声到客船。 | 14 / 1 苏 | Second couplet only. `zh.wikisource` author 張繼; en.wikipedia disambiguates the Tang poet from Hubei |
| 10 | 赠汪伦 (To Wang Lun) | Li Bai; 701 to 762 | V | 701-762 (year unknown) | [贈汪倫](https://zh.wikisource.org/wiki/%E8%B4%88%E6%B1%AA%E5%80%AB) | 桃花潭水深千尺，不及汪伦送我情。 | 14 / 3 伦汪潭 | Second couplet only |
| 11 | 绝句 (两个黄鹂鸣翠柳) (Quatrain) | Du Fu; 712 to 770 | V | 712-770 (year unknown) | [絕句 (兩個黃鸝鳴翠柳)](https://zh.wikisource.org/wiki/%E7%B5%95%E5%8F%A5_%28%E5%85%A9%E5%80%8B%E9%BB%83%E9%B8%9D%E9%B3%B4%E7%BF%A0%E6%9F%B3%29) | 窗含西岭千秋雪，门泊东吴万里船。 | 14 / 2 吴岭 | Second couplet only |
| 12 | 回乡偶书 (其一) (Coming Home) | He Zhizhang; c. 659 to 744 | V | 659-744 (year unknown) | [回鄉偶書 (少小離家老大回)](https://zh.wikisource.org/wiki/%E5%9B%9E%E9%84%89%E5%81%B6%E6%9B%B8_%28%E5%B0%91%E5%B0%8F%E9%9B%A2%E5%AE%B6%E8%80%81%E5%A4%A7%E5%9B%9E%29) | 儿童相见不相识，笑问客从何处来。 | 14 / 1 何 | Second couplet only; Wikisource lists variants 無/未/難 and 笑/借/卻 in the first lines, which this excerpt avoids |
| 13 | 登幽州台歌 (Song on Climbing Youzhou Terrace) | Chen Zi'ang; 661 or 656 to 702 | V | 656-702 (year unknown) | [登幽州臺歌](https://zh.wikisource.org/wiki/%E7%99%BB%E5%B9%BD%E5%B7%9E%E8%87%BA%E6%AD%8C) | 前不见古人，后不见来者。念天地之悠悠，独怆然而涕下。 | 22 / 2 怆悠 | Birth year uncertain: circa |
| 14 | 夜雨寄北 (Sent North on a Rainy Night) | Li Shangyin; c. 813 to c. 858 | V | 813-858 (year unknown); circa lifespan | [夜雨寄北](https://zh.wikisource.org/wiki/%E5%A4%9C%E9%9B%A8%E5%AF%84%E5%8C%97) | 何当共剪西窗烛，却话巴山夜雨时。 | 14 / 2 何巴 | Second couplet only |
| 15 | 春夜喜雨 (Welcome Rain on a Spring Night) | Du Fu; 712 to 770 | V | 712-770 (year unknown) | [春夜喜雨](https://zh.wikisource.org/wiki/%E6%98%A5%E5%A4%9C%E5%96%9C%E9%9B%A8) | 随风潜入夜，润物细无声。 | 10 / 2 潜随 | Second couplet only. Wikisource gives the variant 乃/及 in line 2, which this excerpt avoids |
| 16 | 早发白帝城 (Leaving Baidi at Dawn) | Li Bai; 701 to 762 | V | 701-762 (year unknown) | [早發白帝城](https://zh.wikisource.org/wiki/%E6%97%A9%E7%99%BC%E7%99%BD%E5%B8%9D%E5%9F%8E) | 朝辞白帝彩云间，千里江陵一日还。 | 14 / 2 江陵 | First couplet only. Variants 盡/住 and 輕舟已過/須臾過卻 are in the second couplet, which is avoided |
| 17 | 鹿柴 (Deer Park) | Wang Wei; 699 to 761 | V | 699-761 (year unknown) | [鹿柴 (王維)](https://zh.wikisource.org/wiki/%E9%B9%BF%E6%9F%B4_%28%E7%8E%8B%E7%B6%AD%29) | 空山不见人，但闻人语响。返景入深林，复照青苔上。 | 20 / 2 苔返 | Wang Wei's page on en.wikipedia is a plain 'Wang Wei' title |
| 18 | 题西林壁 (Written on the Wall of West Forest Temple) | Su Shi; 1037 to 1101 | V | 1037-1101 (year unknown) | [題西林壁 (蘇軾)](https://zh.wikisource.org/wiki/%E9%A1%8C%E8%A5%BF%E6%9E%97%E5%A3%81_%28%E8%98%87%E8%BB%BE%29) | 不识庐山真面目，只缘身在此山中。 | 14 / 3 庐此缘 | Second couplet only; variants in line 2 of the first couplet are avoided |

### zh-culture-2: Philosophy: sayings of the Warring States and Han masters (ids zh-6050 to 6099). Every item is BCE, so the whole deck waits for the date question in the open questions

| # | Work | Creator, lifespan as read | Status | Date for `source.date` | Wikisource page | Excerpt (simplified; builder converts from the traditional text read) | Hanzi / untaught | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | 论语 1.1 (Analects 1.1) | Confucius (the Analects were gathered by his disciples); c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/學而第一](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%AD%B8%E8%80%8C%E7%AC%AC%E4%B8%80) | 学而时习之，不亦说乎？有朋自远方来，不亦乐乎？ | 19 / 2 乎亦 | Wikisource edition cites the Zhu Xi text; 說/悦 and 樂 forms read |
| 2 | 论语 1.8 (Analects 1.8) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/學而第一](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%AD%B8%E8%80%8C%E7%AC%AC%E4%B8%80) | 过则勿惮改。 | 5 / 2 勿惮 | Excerpt is the last clause of the sentence |
| 3 | 论语 2.11 (Analects 2.11) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/爲政第二](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E7%88%B2%E6%94%BF%E7%AC%AC%E4%BA%8C) | 温故而知新，可以为师矣。 | 10 / 1 矣 |  |
| 4 | 论语 2.15 (Analects 2.15) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/爲政第二](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E7%88%B2%E6%94%BF%E7%AC%AC%E4%BA%8C) | 学而不思则罔，思而不学则殆。 | 12 / 2 殆罔 |  |
| 5 | 论语 2.17 (Analects 2.17) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/爲政第二](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E7%88%B2%E6%94%BF%E7%AC%AC%E4%BA%8C) | 知之为知之，不知为不知，是知也。 | 13 / 0 | All 13 hanzi are taught |
| 6 | 论语 4.16 (Analects 4.16) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/里仁第四](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E9%87%8C%E4%BB%81%E7%AC%AC%E5%9B%9B) | 君子喻于义，小人喻于利。 | 10 / 1 君 |  |
| 7 | 论语 7.22 (Analects 7.22) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/述而第七](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E8%BF%B0%E8%80%8C%E7%AC%AC%E4%B8%83) | 三人行，必有我师焉。 | 8 / 1 焉 |  |
| 8 | 论语 9.28 (Analects 9.28) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/子罕第九](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%AD%90%E7%BD%95%E7%AC%AC%E4%B9%9D) | 岁寒，然后知松柏之后凋也。 | 11 / 2 凋柏 |  |
| 9 | 论语 15.24 (Analects 15.24) | Confucius; c. 551 to c. 479 BCE | V | BCE (blocked) | [論語/衞靈公第十五](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E8%A1%9E%E9%9D%88%E5%85%AC%E7%AC%AC%E5%8D%81%E4%BA%94) | 己所不欲，勿施于人。 | 8 / 2 勿欲 | Wikisource title uses 衞 |
| 10 | 道德经 8 (Dao De Jing ch. 8) | Laozi; traditionally 6th century BCE (no year) | P | BCE (blocked) | [道德經 (王弼本)](https://zh.wikisource.org/wiki/%E9%81%93%E5%BE%B7%E7%B6%93_%28%E7%8E%8B%E5%BC%BC%E6%9C%AC%29) | 上善若水。水善利万物而不争。 | 12 / 1 若 | Wang Bi edition; lifespan is traditional only, so `born`/`died` cannot be written |
| 11 | 道德经 33 (Dao De Jing ch. 33) | Laozi; traditionally 6th century BCE (no year) | P | BCE (blocked) | [道德經 (王弼本)](https://zh.wikisource.org/wiki/%E9%81%93%E5%BE%B7%E7%B6%93_%28%E7%8E%8B%E5%BC%BC%E6%9C%AC%29) | 知人者智，自知者明。 | 8 / 0 | All 8 hanzi taught |
| 12 | 道德经 64 (Dao De Jing ch. 64) | Laozi; traditionally 6th century BCE (no year) | P | BCE (blocked) | [道德經 (王弼本)](https://zh.wikisource.org/wiki/%E9%81%93%E5%BE%B7%E7%B6%93_%28%E7%8E%8B%E5%BC%BC%E6%9C%AC%29) | 千里之行，始于足下。 | 8 / 0 | All 8 hanzi taught; also the proverb in zh-proverbs-3 |
| 13 | 荀子 劝学 (Xunzi, Encouraging Learning) | Xunzi; c. 310 to after 238 BCE | V | BCE (blocked) | [荀子/勸學篇](https://zh.wikisource.org/wiki/%E8%8D%80%E5%AD%90/%E5%8B%B8%E5%AD%B8%E7%AF%87) | 不积跬步，无以至千里；不积小流，无以成江海。 | 18 / 2 江跬 | Wikisource has a variant 至/致 in the first clause |
| 14 | 孙子兵法 谋攻 (The Art of War, ch. 3) | Sun Tzu; 544 to 496 BCE (traditional) | V | BCE (blocked) | [孫子兵法](https://zh.wikisource.org/wiki/%E5%AD%AB%E5%AD%90%E5%85%B5%E6%B3%95) | 知彼知己，百战不殆。 | 8 / 1 殆 | The deck zh-idioms already has 知己知彼; cross-link in the note |
| 15 | 庄子 齐物论 (Zhuangzi, 'Discussing Things Equally') | Zhuang Zhou; 4th century BCE (no years read) | P | BCE (blocked) | [莊子/齊物論](https://zh.wikisource.org/wiki/%E8%8E%8A%E5%AD%90/%E9%BD%8A%E7%89%A9%E8%AB%96) | 昔者庄周梦为胡蝶，栩栩然胡蝶也。 | 14 / 2 昔栩 | The butterfly dream. Century only |
| 16 | 孟子 梁惠王上 (Mencius 1A) | Mencius; c. 371 to c. 289 BCE | V | BCE (blocked) | [孟子/梁惠王上](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E6%A2%81%E6%83%A0%E7%8E%8B%E4%B8%8A) | 老吾老，以及人之老；幼吾幼，以及人之幼。 | 16 / 1 吾 |  |
| 17 | 孟子 公孙丑下 (Mencius 2B) | Mencius; c. 371 to c. 289 BCE | V | BCE (blocked) | [孟子/公孫丑下](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E5%85%AC%E5%AD%AB%E4%B8%91%E4%B8%8B) | 天时不如地利，地利不如人和。 | 12 / 0 | All 12 hanzi taught; also a saying in zh-proverbs-3 |
| 18 | 礼记 学记 (Book of Rites, 'On Teaching and Learning') | anonymous (compiled in the Han; not read); not read | C | not read | [禮記/學記](https://zh.wikisource.org/wiki/%E7%A6%AE%E8%A8%98/%E5%AD%B8%E8%A8%98) | 学然后知不足，教然后知困。 | 11 / 0 | Wikisource shows no author; date of compilation was not read on a page, so this item is a candidate until it is |

### zh-culture-3: Chengyu with their classical source line (ids zh-6100 to 6149). Mostly BCE: the same date question applies, except 三顾茅庐 (Zhuge Liang, CE)

| # | Work | Creator, lifespan as read | Status | Date for `source.date` | Wikisource page | Excerpt (simplified; builder converts from the traditional text read) | Hanzi / untaught | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | 守株待兔 (Waiting by the Stump for a Hare) | Han Fei (the Han Feizi); c. 280 to 233 BCE | V | BCE (blocked) | [韓非子/五蠹](https://zh.wikisource.org/wiki/%E9%9F%93%E9%9D%9E%E5%AD%90/%E4%BA%94%E8%A0%B9) | 宋人有耕田者，田中有株，兔走触株，折颈而死。 | 18 / 1 耕 | Card already exists as a word in zh-idioms; the culture card tells the story |
| 2 | 自相矛盾 (Contradicting Oneself) | Han Fei; c. 280 to 233 BCE | V | BCE (blocked) | [韓非子/難一](https://zh.wikisource.org/wiki/%E9%9F%93%E9%9D%9E%E5%AD%90/%E9%9B%A3%E4%B8%80) | 楚人有鬻楯与矛者，誉之曰：吾楯之坚，物莫能陷也。 | 20 / 6 吾曰楯莫陷鬻 | Wikisource writes 楯 for the shield; 6 untaught hanzi: the builder may cut it to the first clause 楚人有鬻楯与矛者 |
| 3 | 滥竽充数 (Filling a Place in the Band) | Han Fei; c. 280 to 233 BCE | V | BCE (blocked) | [韓非子/內儲說上七術](https://zh.wikisource.org/wiki/%E9%9F%93%E9%9D%9E%E5%AD%90/%E5%85%A7%E5%84%B2%E8%AA%AA%E4%B8%8A%E4%B8%83%E8%A1%93) | 齐宣王使人吹竽，必三百人。 | 11 / 0 | The sentence that names the 300 players; the man who pretends comes in the next sentence (南郭处士请为王吹竽) |
| 4 | 买椟还珠 (Buying the Box, Returning the Pearl) | Han Fei; c. 280 to 233 BCE | V | BCE (blocked) | [韓非子/外儲說左上](https://zh.wikisource.org/wiki/%E9%9F%93%E9%9D%9E%E5%AD%90/%E5%A4%96%E5%84%B2%E8%AA%AA%E5%B7%A6%E4%B8%8A) | 郑人买其椟而还其珠。 | 9 / 3 椟珠郑 | Source text read: 鄭人買其櫝而還其珠 |
| 5 | 画蛇添足 (Drawing Feet on a Snake) | Liu Xiang (compiler of the Zhan Guo Ce); 77 to 6 BCE | V | BCE (blocked) | [戰國策 (士禮居叢書本)/齊/二](https://zh.wikisource.org/wiki/%E6%88%B0%E5%9C%8B%E7%AD%96_%28%E5%A3%AB%E7%A6%AE%E5%B1%85%E5%8F%A2%E6%9B%B8%E6%9C%AC%29/%E9%BD%8A/%E4%BA%8C) | 为蛇足者，终亡其酒。 | 8 / 0 | Wikisource: Shiliju Congshu edition. The tale itself is Warring States, the compiler is Han |
| 6 | 狐假虎威 (The Fox Borrows the Tiger's Might) | Liu Xiang (compiler); 77 to 6 BCE | V | BCE (blocked) | [戰國策 (士禮居叢書本)/楚/一](https://zh.wikisource.org/wiki/%E6%88%B0%E5%9C%8B%E7%AD%96_%28%E5%A3%AB%E7%A6%AE%E5%B1%85%E5%8F%A2%E6%9B%B8%E6%9C%AC%29/%E6%A5%9A/%E4%B8%80) | 虎求百兽而食之，得狐。 | 9 / 1 兽 | Page text 虎求百獸而食之，得狐 |
| 7 | 亡羊补牢 (Mend the Pen After the Sheep Are Lost) | Liu Xiang (compiler); 77 to 6 BCE | V | BCE (blocked) | [戰國策 (士禮居叢書本)/楚/四](https://zh.wikisource.org/wiki/%E6%88%B0%E5%9C%8B%E7%AD%96_%28%E5%A3%AB%E7%A6%AE%E5%B1%85%E5%8F%A2%E6%9B%B8%E6%9C%AC%29/%E6%A5%9A/%E5%9B%9B) | 亡羊而补牢，未为迟也。 | 9 / 0 | Spoken as a 'common saying' by Zhuang Xin in the text |
| 8 | 鹬蚌相争 (The Snipe and the Clam) | Liu Xiang (compiler); 77 to 6 BCE | V | BCE (blocked) | [戰國策 (士禮居叢書本)/燕/二](https://zh.wikisource.org/wiki/%E6%88%B0%E5%9C%8B%E7%AD%96_%28%E5%A3%AB%E7%A6%AE%E5%B1%85%E5%8F%A2%E6%9B%B8%E6%9C%AC%29/%E7%87%95/%E4%BA%8C) | 两者不肯相舍，渔者得而并禽之。 | 13 / 3 并渔禽 |  |
| 9 | 三人成虎 (Three Men Make a Tiger) | Liu Xiang (compiler); 77 to 6 BCE | V | BCE (blocked) | [戰國策 (士禮居叢書本)/魏/二](https://zh.wikisource.org/wiki/%E6%88%B0%E5%9C%8B%E7%AD%96_%28%E5%A3%AB%E7%A6%AE%E5%B1%85%E5%8F%A2%E6%9B%B8%E6%9C%AC%29/%E9%AD%8F/%E4%BA%8C) | 三人言而成虎。 | 6 / 0 | 6 hanzi, all taught |
| 10 | 揠苗助长 (Pulling Up the Seedlings) | Mencius; c. 371 to c. 289 BCE | V | BCE (blocked) | [孟子/公孫丑上](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E5%85%AC%E5%AD%AB%E4%B8%91%E4%B8%8A) | 宋人有闵其苗之不长而揠之者 | 13 / 2 揠闵 | Fragment, not a full sentence; the sentence continues 芒芒然归 |
| 11 | 井底之蛙 (The Frog in the Well) | Zhuang Zhou; 4th century BCE (no years read) | P | BCE (blocked) | [莊子/秋水](https://zh.wikisource.org/wiki/%E8%8E%8A%E5%AD%90/%E7%A7%8B%E6%B0%B4) | 井蛙不可以语于海者，拘于墟也。 | 13 / 1 墟 | The text has 井蛙 (variant 鼃); the chengyu is the later 井底之蛙 |
| 12 | 塞翁失马 (The Old Man Lost His Horse) | Liu An (the Huainanzi); c. 179 to 122 BCE | V | BCE (blocked) | [淮南子/人間訓](https://zh.wikisource.org/wiki/%E6%B7%AE%E5%8D%97%E5%AD%90/%E4%BA%BA%E9%96%93%E8%A8%93) | 近塞上之人有善术者，马无故亡而入胡。 | 16 / 0 | All 16 hanzi taught |
| 13 | 负荆请罪 (Carrying Thorns to Beg Pardon) | Sima Qian (Shiji); c. 145 to c. 86 BCE | V | BCE (blocked) | [史記/卷081](https://zh.wikisource.org/wiki/%E5%8F%B2%E8%A8%98/%E5%8D%B7081) | 廉颇闻之，肉袒负荆，因宾客至蔺相如门谢罪。 | 18 / 4 荆蔺袒颇 | 4 untaught hanzi (荆蔺袒颇) |
| 14 | 破釜沉舟 (Smash the Cauldrons, Sink the Boats) | Sima Qian; c. 145 to c. 86 BCE | V | BCE (blocked) | [史記/卷007](https://zh.wikisource.org/wiki/%E5%8F%B2%E8%A8%98/%E5%8D%B7007) | 皆沉船，破釜甑，烧庐舍，持三日粮。 | 13 / 4 庐甑皆粮 | Wikisource: 皆沈船 |
| 15 | 卧薪尝胆 (Sleeping on Brushwood, Tasting Gall) | Sima Qian; c. 145 to c. 86 BCE | V | BCE (blocked) | [史記/卷041](https://zh.wikisource.org/wiki/%E5%8F%B2%E8%A8%98/%E5%8D%B7041) | 越王句践反国，乃苦身焦思，置胆于坐。 | 15 / 2 乃胆 | The Shiji passage has the gall (胆) but not the brushwood (薪): the card says so |
| 16 | 纸上谈兵 (Fighting on Paper) | Sima Qian; c. 145 to c. 86 BCE | V | BCE (blocked) | [史記/卷081](https://zh.wikisource.org/wiki/%E5%8F%B2%E8%A8%98/%E5%8D%B7081) | 括徒能读其父书传，不知合变也。 | 13 / 0 |  |
| 17 | 完璧归赵 (Returning the Jade Intact to Zhao) | Sima Qian; c. 145 to c. 86 BCE | V | BCE (blocked) | [史記/卷081](https://zh.wikisource.org/wiki/%E5%8F%B2%E8%A8%98/%E5%8D%B7081) | 臣请完璧归赵。 | 6 / 4 归璧臣赵 |  |
| 18 | 三顾茅庐 (Three Visits to the Thatched Hut) | Zhuge Liang (the Chu Shi Biao); 181 to 234 | V | 181-234 (creator span, CE, so not blocked; the year of the memorial was not read) | [前出師表](https://zh.wikisource.org/wiki/%E5%89%8D%E5%87%BA%E5%B8%AB%E8%A1%A8) | 三顾臣于草庐之中，咨臣以当世之事。 | 15 / 2 庐臣 | The only CE item of the deck; the Wikisource page names the author, not the year |

### zh-culture-4: Festivals, folk songs and prose (ids zh-6150 to 6199). The plan expects 16 or fewer to pass

| # | Work | Creator, lifespan as read | Status | Date for `source.date` | Wikisource page | Excerpt (simplified; builder converts from the traditional text read) | Hanzi / untaught | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | 元日 (New Year's Day) | Wang Anshi; 1021 to 1086 | V | 1021-1086 (year unknown) | [元日 (王安石)](https://zh.wikisource.org/wiki/%E5%85%83%E6%97%A5_%28%E7%8E%8B%E5%AE%89%E7%9F%B3%29) | 爆竹声中一岁除，春风送暖入屠苏。 | 14 / 2 屠苏 | Spring Festival. Wikisource variants 春/東 and 總把/爭插 are marked; the excerpt takes the first line pair's main text |
| 2 | 清明 (Qingming) | Du Mu; 803 to 852 | V | 803-852 (year unknown) | [清明 (杜牧)](https://zh.wikisource.org/wiki/%E6%B8%85%E6%98%8E_%28%E6%9D%9C%E7%89%A7%29) | 清明时节雨纷纷，路上行人欲断魂。 | 14 / 3 欲纷魂 | Qingming festival |
| 3 | 七夕 / 秋夕 (Qixi (Autumn Night)) | Du Mu; 803 to 852 | V | 803-852 (year unknown) | [七夕 (杜牧)](https://zh.wikisource.org/wiki/%E4%B8%83%E5%A4%95_%28%E6%9D%9C%E7%89%A7%29) | 银烛秋光冷画屏，轻罗小扇扑流萤。 | 14 / 4 扇扑罗萤 | Wikisource has two pages (七夕, 秋夕) with variants 銀/紅 and 天/瑤: the title is disputed, so the note says it |
| 4 | 鹊桥仙 (七夕) (The Magpie Bridge Immortals) | Qin Guan; 1049 to c. 1100 | V | 1049-1100 (year unknown); circa death | [鵲橋仙 (秦觀)](https://zh.wikisource.org/wiki/%E9%B5%B2%E6%A9%8B%E4%BB%99_%28%E7%A7%A6%E8%A7%80%29) | 金风玉露一相逢，便胜却人间无数。 | 14 / 2 玉逢 | Qixi festival |
| 5 | 十五夜望月寄杜郎中 (Looking at the Moon on the Fifteenth Night) | Wang Jian; 766? to 831? (en) | V | c. 766-831 (year unknown); circa both | [十五夜望月寄杜郎中](https://zh.wikisource.org/wiki/%E5%8D%81%E4%BA%94%E5%A4%9C%E6%9C%9B%E6%9C%88%E5%AF%84%E6%9D%9C%E9%83%8E%E4%B8%AD) | 中庭地白树栖鸦，冷露无声湿桂花。 | 14 / 2 栖鸦 | Mid-Autumn Festival; Wikisource title 十五夜望月 redirects to this page |
| 6 | 水调歌头 (明月几时有) (Prelude to Water Melody) | Su Shi; 1037 to 1101 | V | 1037-1101 (year unknown) | [水調歌頭 (明月幾時有)](https://zh.wikisource.org/wiki/%E6%B0%B4%E8%AA%BF%E6%AD%8C%E9%A0%AD_%28%E6%98%8E%E6%9C%88%E5%B9%BE%E6%99%82%E6%9C%89%29) | 但愿人长久，千里共婵娟。 | 10 / 2 娟婵 | Mid-Autumn Festival |
| 7 | 九月九日忆山东兄弟 (Thinking of My Brothers on Double Ninth) | Wang Wei; 699 to 761 | V | 699-761 (year unknown) | [九月九日憶山東兄弟](https://zh.wikisource.org/wiki/%E4%B9%9D%E6%9C%88%E4%B9%9D%E6%97%A5%E6%86%B6%E5%B1%B1%E6%9D%B1%E5%85%84%E5%BC%9F) | 独在异乡为异客，每逢佳节倍思亲。 | 14 / 2 佳逢 | Double Ninth festival; Wikisource note: written at 17. Variant 爲/為 marked |
| 8 | 青玉案 (元夕) (Green Jade Table, Lantern Night) | Xin Qiji; 1140 to 1207 | V | 1140-1207 (year unknown) | [青玉案 (辛棄疾)](https://zh.wikisource.org/wiki/%E9%9D%92%E7%8E%89%E6%A1%88_%28%E8%BE%9B%E6%A3%84%E7%96%BE%29) | 众里寻他千百度，蓦然回首，那人却在，灯火阑珊处。 | 20 / 3 珊蓦阑 | Lantern Festival; 20 hanzi, 3 untaught |
| 9 | 春 (Spring) | Zhu Ziqing; 1898 to 1948 | V | 1933 (Wikisource header) | [春 (朱自清)](https://zh.wikisource.org/wiki/%E6%98%A5_%28%E6%9C%B1%E8%87%AA%E6%B8%85%29) | 盼望着，盼望着，东风来了，春天的脚步近了。 | 17 / 1 盼 | The one modern text of the deck; Wikisource header gives 1933. Died 1948, so inside the floor |
| 10 | 千字文 (Thousand Character Classic) | Zhou Xingsi; 470 to 521 (en.wikipedia, Thousand Character Classic) | V | c. 502-521 (the page says the Liang emperor Wu commissioned it; reign 502-549, no exact year) | [千字文](https://zh.wikisource.org/wiki/%E5%8D%83%E5%AD%97%E6%96%87) | 寒来暑往，秋收冬藏。 | 8 / 0 | A line of a primer in four-character lines |
| 11 | 爱莲说 (On the Love of the Lotus) | Zhou Dunyi; 1017 to 1073 | V | 1017-1073 (year unknown) | [愛蓮說](https://zh.wikisource.org/wiki/%E6%84%9B%E8%93%AE%E8%AA%AA) | 予独爱莲之出淤泥而不染，濯清涟而不妖。 | 17 / 6 予妖涟淤濯莲 | 6 untaught hanzi: a candidate for the reserve if the owner wants stricter 'taught only' |
| 12 | 陋室铭 (Inscription for a Humble Room) | Liu Yuxi; 772 to 842 | V | 772-842 (year unknown) | [陋室銘](https://zh.wikisource.org/wiki/%E9%99%8B%E5%AE%A4%E9%8A%98) | 山不在高，有仙则名。水不在深，有龙则灵。 | 16 / 1 仙 | Title not marked as shortened |
| 13 | 岳阳楼记 (Record of Yueyang Tower) | Fan Zhongyan; 989 to 1052 | V | 1046 (the Wikisource text reads: 時六年 [of Qingli] 九月十五日, 1046年) | [岳陽樓記](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | 先天下之忧而忧，后天下之乐而乐。 | 14 / 1 忧 | Date read on the page |
| 14 | 敕勒歌 (Song of the Chile) | anonymous; not read | C | not read: first record not read | [敕勒歌](https://zh.wikisource.org/wiki/%E6%95%95%E5%8B%92%E6%AD%8C) | 天苍苍，野茫茫，风吹草低见牛羊。 | 13 / 1 茫 | Wikisource page names no author; its source date was not read |
| 15 | 江南 (汉乐府) (Jiangnan (Han yuefu)) | anonymous; not read | C | not read: Han yuefu, first collected in the Yuefu Shiji | [江南 (漢樂府)](https://zh.wikisource.org/wiki/%E6%B1%9F%E5%8D%97_%28%E6%BC%A2%E6%A8%82%E5%BA%9C%29) | 江南可采莲，莲叶何田田。 | 10 / 3 何江莲 | Wikisource author 佚名; date not read, and Han is BCE or early CE |
| 16 | 木兰诗 (Ballad of Mulan) | anonymous; not read | C | not read | [木蘭詩](https://zh.wikisource.org/wiki/%E6%9C%A8%E8%98%AD%E8%A9%A9) | 唧唧复唧唧，木兰当户织。 | 10 / 2 兰唧 | Wikisource author 佚名; the page was read for text only |

### What the culture decks need from the owner before a builder starts

`zh-culture-2` and most of `zh-culture-3` are **blocked** by the date question (open question 1): the work's date cannot be written for a Warring States or Han text. `zh-culture-1` and `zh-culture-4` are not blocked.

### Read and dropped, or read and kept in reserve

| Item | What happened |
|---|---|
| 愚公移山 (Yugong Moves the Mountains), Liezi, 湯問 | Text read on zh.wikisource ("北山愚公者，年且九十，面山而居"); the author, Lie Yukou, has no lifespan on the page read and en.wikipedia 'Liezi' gave none: reserve for `zh-culture-3`, status C |
| 望梅止渴 (Longing for plums), Shishuo Xinyu, 假譎 | Text read ("前有大梅林，饒子，甘酸，可以解渴"); the compiler's dates (Liu Yiqing) were not read: reserve, status C |
| 相思 (王維), 望廬山瀑布, 登樂遊原, 長歌行, 送杜少府之任蜀州, 勸學詩 (顏真卿), 端午 (文秀), 鵲橋仙 (as 纖雲弄巧), 青玉案 (as 東風夜放花千樹) | Wikisource page not found under the title tried (404). 鵲橋仙 and 青玉案 were found under other titles and are in the deck |
| 刻舟求劍, 掩耳盜鈴 (Lüshi Chunqiu) | The Wikisource pages found transclude page scans, so the raw page holds no text, and the pages named 呂氏春秋注 (季春紀, 慎大覽, 審分覽) were not found: dropped. Both are cards of `zh-idioms` already |
| 三字經, 大學, 中庸 | Page found, text not readable as raw wikitext (a list of versions, or a scan transclusion): dropped. The Three Character Classic's author is also disputed (the page's own note says so) |
| 故鄉 (Lu Xun, 1921) | Header read (first printed in New Youth, 1 May 1921, Lu Xun died 1936, the page carries a public-domain template), but the text is a page-scan transclusion and was not read: dropped |
| 杯弓蛇影 (Jin shu) | Page title not found: dropped from `zh-culture-3`; the card exists in `zh-idioms` |
| 孫子兵法 謀攻 as its own page | The page read is the whole book: the excerpt is from there |
| The simplified forms of every excerpt | Written by the author of this page as a conversion; **a reviewer must check each** |

## Proverbs and chengyu (ZH-025 to ZH-027, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`. The `source` block has `author: "anonymous"`, `collection` (en.wiktionary, with the entry named; plus en.wikipedia 'Chengyu' and 'Chinese proverbs' for the genre), `date` is not needed for `oral-tradition`, `jurisdiction: "CN"`, `rights_checked: 2026-11-15`. Each card carries a `literal` note (`kind: "note"`) with the literal and the plain meaning, a card `register`, and the builder's own plain English. **None of the 40 chengyu repeats a card of `zh-idioms`** (the 50 cards of that deck were read and excluded); several sayings and idioms with a named classical origin are noted below. A chengyu with a known classical author could be a `public-domain` culture card too; here, the saying itself is the item and the origin goes in the note.

en.wikipedia 'Chengyu' (read): chengyu are "mostly derived from ancient literature" and "not always four characters long"; en.wikipedia 'Chinese proverbs' (read) names Laozi's journey line as an example of a proverb of known origin.

Hanzi column: count of hanzi in the card target / number of those hanzi that no taught word contains. Every chengyu below has **0 untaught hanzi**; the sayings have 0 or 1.

### `zh-proverbs-1`, chengyu: numbers and everyday life (ids zh-6200 to 6249)

| # | Simplified (card target) | Traditional (page title read) | en.wiktionary gloss as read | Hanzi / untaught | Notes |
|---|---|---|---|---|---|
| 1 | 一石二鸟 | 一石二鳥 | to kill two birds with one stone | 4 / 0 |  |
| 2 | 一举两得 | 一舉兩得 | to kill two birds with one stone; to do one task and finish two or more goals | 4 / 0 | Same gloss as the first: one note links the two |
| 3 | 一见钟情 | 一見鍾情 | to fall in love at first sight | 4 / 0 |  |
| 4 | 一言为定 | 一言為定 | that's settled then, it's a deal | 4 / 0 |  |
| 5 | 一箭双雕 | 一箭雙鵰 | to kill two birds with one stone | 4 / 0 |  |
| 6 | 三言两语 | 三言兩語 | just a few words; concise language | 4 / 0 |  |
| 7 | 四面八方 | 四面八方 | in all directions; all around; far and wide | 4 / 0 |  |
| 8 | 五颜六色 | 五顏六色 | multicoloured; colourful | 4 / 0 |  |
| 9 | 七上八下 | 七上八下 | to be nervous, anxious or perturbed | 4 / 0 |  |
| 10 | 九牛一毛 | 九牛一毛 | a drop in the bucket | 4 / 0 |  |
| 11 | 十全十美 | 十全十美 | perfect; flawless | 4 / 0 |  |
| 12 | 万事如意 | 萬事如意 | may all your hopes be fulfilled; all the best | 4 / 0 | A wish formula |
| 13 | 千方百计 | 千方百計 | by every possible means; by hook or by crook | 4 / 0 |  |
| 14 | 千言万语 | 千言萬語 | thousands and thousands of words; to have much to say | 4 / 0 |  |
| 15 | 百发百中 | 百發百中 | every shot hits the target; to shoot with unfailing accuracy | 4 / 0 |  |
| 16 | 百闻不如一见 | 百聞不如一見 | seeing is believing (en.wiktionary labels it a Proverb) | 6 / 0 | Proverb on en.wiktionary, four-plus characters |
| 17 | 一模一样 | 一模一樣 | exactly the same; identical | 4 / 0 |  |
| 18 | 一干二净 | 一乾二淨 | thoroughly; completely | 4 / 0 | Traditional form 乾; simplified 干 is also the 'to do' character, so a note |
| 19 | 九死一生 | 九死一生 | narrow escape from death | 4 / 0 |  |
| 20 | 一路平安 | 一路平安 | have a good trip; bon voyage | 4 / 0 | The entry has no Idiom heading; read as a set phrase |

### `zh-proverbs-2`, chengyu: character, feeling and nature (ids zh-6250 to 6299)

| # | Simplified (card target) | Traditional (page title read) | en.wiktionary gloss as read | Hanzi / untaught | Notes |
|---|---|---|---|---|---|
| 1 | 大公无私 | 大公無私 | selfless and impartial | 4 / 0 |  |
| 2 | 大开眼界 | 大開眼界 | eye-opening; able to broaden one's horizon | 4 / 0 |  |
| 3 | 不知不觉 | 不知不覺 | unconsciously; unwittingly | 4 / 0 |  |
| 4 | 马马虎虎 | 馬馬虎虎 | careless; sloppy; so-so (en.wiktionary: Adjective) | 4 / 0 | Not a four-character idiom by label |
| 5 | 目不转睛 | 目不轉睛 | not to take one's eyes off | 4 / 0 | en.wiktionary gloss (gazing into each other's eyes) is narrower than the usual sense; read the usage line before writing the card |
| 6 | 心想事成 | 心想事成 | may your dreams come true (en.wiktionary: Proverb) | 4 / 0 |  |
| 7 | 心平气和 | 心平氣和 | even-tempered; calm | 4 / 0 |  |
| 8 | 画龙点睛 | 畫龍點睛 | to put on the finishing touches | 4 / 0 |  |
| 9 | 自言自语 | 自言自語 | to talk to oneself (en.wiktionary: Verb) | 4 / 0 | Not an Idiom by label |
| 10 | 自力更生 | 自力更生 | to rely on one's own efforts; self-reliant | 4 / 0 | Reading varies by region (gēng/gèng): the page lists both, the builder takes the mainland gēng and says so |
| 11 | 爱不释手 | 愛不釋手 | to love something too much to part with it | 4 / 0 |  |
| 12 | 开门见山 | 開門見山 | to get right to the point | 4 / 0 |  |
| 13 | 来之不易 | 來之不易 | hard-won; hard-earned | 4 / 0 |  |
| 14 | 说到做到 | 說到做到 | to be as good as one's word (en.wiktionary: Verb) | 4 / 0 | Not an Idiom by label |
| 15 | 人山人海 | 人山人海 | very crowded | 4 / 0 |  |
| 16 | 花好月圆 | 花好月圓 | blooming flowers and full moon; perfect conjugal bliss | 4 / 0 |  |
| 17 | 春暖花开 | 春暖花開 | during the warmth of spring all the flowers bloom | 4 / 0 |  |
| 18 | 生龙活虎 | 生龍活虎 | energetic; spirited; lively | 4 / 0 |  |
| 19 | 举世闻名 | 舉世聞名 | world-famous | 4 / 0 |  |
| 20 | 天长地久 | 天長地久 | enduring as the universe; everlasting | 4 / 0 |  |

### `zh-proverbs-3`, sayings (谚语, 俗语) (ids zh-6300 to 6349)

Entries are the en.wiktionary pages named in the third column; en.wiktionary labels most of them Proverbs.

| # | Simplified (card target) | Traditional (page title read) | en.wiktionary gloss as read | Hanzi / untaught | Notes |
|---|---|---|---|---|---|
| 1 | 千里之行，始于足下 | 千里之行，始於足下 | a journey of a thousand miles begins with a single step | 8 / 0 | Origin: Dao De Jing ch. 64 (read on Wikisource, see zh-culture-2) |
| 2 | 失败是成功之母 | 失敗是成功之母 | failure is the mother of success | 7 / 0 |  |
| 3 | 冰冻三尺，非一日之寒 | 冰凍三尺，非一日之寒 | Rome wasn't built in a day | 9 / 0 |  |
| 4 | 活到老，学到老 | 活到老，學到老 | live and learn; it is never too late to learn | 6 / 0 | en.wiktionary labels it a Phrase |
| 5 | 种瓜得瓜，种豆得豆 | 種瓜得瓜，種豆得豆 | you reap what you sow | 8 / 0 |  |
| 6 | 好事不出门，坏事传千里 | 好事不出門，壞事傳千里 | bad news travels fast | 10 / 0 |  |
| 7 | 读万卷书，行万里路 | 讀萬卷書，行萬里路 | read widely and travel widely to gain wisdom | 8 / 0 |  |
| 8 | 不怕慢，只怕站 | 不怕慢，只怕站 | slow and steady wins the race; any movement is better than none | 6 / 0 |  |
| 9 | 言必信，行必果 | 言必信，行必果 | promises must be kept and action must be resolute | 6 / 0 |  |
| 10 | 书到用时方恨少 | 書到用時方恨少 | you regret not having learned enough only when you need the knowledge | 7 / 0 |  |
| 11 | 一年之计在于春，一日之计在于晨 | 一年之計在於春 | early planning is the key to success | 14 / 0 | en.wiktionary page is titled with the first half only and gives the pair; the card takes the pair |
| 12 | 远亲不如近邻 | 遠親不如近鄰 | nearby neighbours are better than distant relatives | 6 / 0 |  |
| 13 | 礼轻情意重 | 禮輕情意重 | it's the thought that counts | 5 / 0 |  |
| 14 | 三思而后行 | 三思而後行 | look before you leap | 5 / 0 |  |
| 15 | 知人知面不知心 | 知人知面不知心 | you may know a person's face but not their heart | 7 / 0 |  |
| 16 | 家和万事兴 | 家和萬事興 | harmony in the family leads to prosperity | 5 / 0 |  |
| 17 | 日久见人心 | 日久見人心 | time reveals a person's heart | 5 / 0 |  |
| 18 | 十年树木，百年树人 | 十年樹木，百年樹人 | it takes a long time for good education to bear fruit | 8 / 0 |  |
| 19 | 金无足赤，人无完人 | 金無足赤，人無完人 | there is no perfect person | 8 / 1 赤 |  |
| 20 | 有志者事竟成 | 有志者事竟成 | where there's a will, there's a way | 6 / 1 竟 |  |

Reserve (read, entry exists, not in a deck because of an untaught hanzi or an overlap): chengyu 万紫千红, 欢天喜地, 左右为难, 失而复得, 自食其力, 熟能生巧, 取长补短, 四海为家, 无所事事, 全心全意, 说一不二, 无法无天, 教学相长, 爱屋及乌, 入乡随俗, 雪中送炭, 树大招风, 一失足成千古恨; sayings 路遥知马力 (遥), 病从口入，祸从口出 (祸), 前人栽树，后人乘凉 (栽), 他山之石，可以攻玉 (玉), 一分耕耘，一分收获 (耕, 耘), 一朝被蛇咬，十年怕井绳 (咬), 三人成虎 (a chengyu; also a culture card).

**Dropped (no en.wiktionary entry under the title tried, so no gloss was read):** 笑容满面, 良药苦口利于病, 万事开头难, 世上无难事只怕有心人, 天时不如地利，地利不如人和 (it is a culture card from Mencius instead), 胜败乃兵家常事, 人多力量大, 谦虚使人进步，骄傲使人落后, and the chengyu of the first candidate list that already are cards of `zh-idioms` (一心一意, 三心二意, 半途而废, 实事求是, 精益求精 and others, 22 in all).

## Multi-word families (ZH-030 to ZH-032, four families of 20)

Genre `multiword`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part. Chinese has no phrasal verbs, so the English-style families do not apply; the four families below are the plan's choice, and each family's pattern is defined by a page that was read:

- **离合词** (separable verb-object compounds): zh.wiktionary '離合詞' (read): "a word made of a verbal morpheme and a nominal morpheme, which can be used joined or split", with the example 結婚 (joined) and 結過婚 (split). The category `Category:漢語離合詞` was read in full (1,031 members): all 20 items below are members.
- **结果补语** (resultative compounds) and **趋向补语** (directional compounds): defined on en.wikipedia 'Chinese grammar' (read): "A complement of result ... a verbal suffix which indicates the outcome ... of the action" and "A complement of direction ... indicates the direction of an action involving movement", with 去 and 来 as the simplest.
- **Idiomatic verb phrases with 打, 开, 发, 做 and others**: the verb carries little meaning of its own (打 in 打电话 and 打雷, 开 in 开心 and 开学). en.wikipedia 'Chinese grammar' shows 打 in its own examples; no page that was read names this family, so its label is the plan's and the builder may rename it.

A part already taught is written by `ref` (its card id found in the course); a target with no card is added as a new card (all its hanzi are taught), and its pinyin comes from Wiktionary. A **tone-sandhi** note on 不 and 一 follows the queue's convention (not written).

### `zh-multiword-separable`: 离合词, separable verb-object compounds (`pattern_family: separable-verb-object`) (zh-6400 to 6449)

Pattern source: traditional titles all listed in zh.wiktionary's Category:漢語離合詞 (1,031 members read on 2026-11-15, 20 of 20 present).

| # | Target | In the course now | en.wiktionary (read 2026-11-15) |
|---|---|---|---|
| 1 | 吃饭 | card exists, reading chīfàn | entry exists |
| 2 | 睡觉 | card exists, reading shuìjiào | entry exists |
| 3 | 洗澡 | card exists, reading xǐzǎo | entry exists |
| 4 | 唱歌 | card exists, reading chànggē | entry exists |
| 5 | 跳舞 | card exists, reading tiàowǔ | entry exists |
| 6 | 见面 | card exists, reading jiànmiàn | entry exists |
| 7 | 结婚 | card exists, reading jiéhūn | entry exists |
| 8 | 帮忙 | card exists, reading bāngmáng | entry exists |
| 9 | 游泳 | card exists, reading yóuyǒng | entry exists |
| 10 | 聊天 | card exists, reading liáotiān | entry exists |
| 11 | 生气 | card exists, reading shēngqì | entry exists |
| 12 | 开会 | card exists, reading kāihuì | entry exists |
| 13 | 请假 | card exists, reading qǐngjià | entry exists |
| 14 | 散步 | card exists, reading sànbù | entry exists |
| 15 | 毕业 | card exists, reading bìyè | entry exists |
| 16 | 道歉 | card exists, reading dàoqiàn | entry exists |
| 17 | 握手 | card exists, reading wòshǒu | entry exists |
| 18 | 理发 | card exists, reading lǐfà | entry exists |
| 19 | 照相 | card exists, reading zhàoxiàng | entry exists |
| 20 | 挂号 | card exists, reading guàhào | entry exists |

### `zh-multiword-resultative`: 结果补语, resultative compounds (`pattern_family: resultative-compound`) (zh-6450 to 6499)

Pattern source: resultative complement defined on en.wikipedia 'Chinese grammar' (read).

| # | Target | In the course now | en.wiktionary (read 2026-11-15) |
|---|---|---|---|
| 1 | 看见 | card exists, reading kànjiàn | entry exists |
| 2 | 听见 | card exists, reading tīngjiàn | entry exists |
| 3 | 听懂 | card exists, reading tīngdǒng | entry exists |
| 4 | 看懂 | card exists, reading kàndǒng | entry exists |
| 5 | 做完 | card exists, reading zuòwán | entry exists |
| 6 | 写好 | card exists, reading xiěhǎo | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 7 | 找到 | card exists, reading zhǎodào | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 8 | 买到 | card exists, reading mǎidào | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 9 | 打开 | card exists, reading dǎkāi | entry exists |
| 10 | 记住 | card exists, reading jìzhù | entry exists |
| 11 | 吃饱 | card exists, reading chībǎo | entry exists |
| 12 | 写完 | card exists, reading xiěwán | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 13 | 说完 | card exists, reading shuōwán | entry exists |
| 14 | 用完 | card exists, reading yòngwán | entry exists |
| 15 | 做好 | card exists, reading zuòhǎo | entry exists |
| 16 | 想到 | card exists, reading xiǎngdào | entry exists |
| 17 | 遇到 | card exists, reading yùdào | entry exists |
| 18 | 收到 | card exists, reading shōudào | entry exists |
| 19 | 弄坏 | card exists, reading nònghuài | entry exists |
| 20 | 打破 | card exists, reading dǎpò | entry exists |
| 21 | 睡着 | card exists, reading shuìzháo | entry exists |
| 22 | 修好 | card exists, reading xiūhǎo | entry exists |
| 23 | 变成 | card exists, reading biànchéng | entry exists |

### `zh-multiword-directional`: 趋向补语, directional compounds (`pattern_family: directional-compound`) (zh-6500 to 6549)

Pattern source: directional complement defined on en.wikipedia 'Chinese grammar' (read).

| # | Target | In the course now | en.wiktionary (read 2026-11-15) |
|---|---|---|---|
| 1 | 站起来 | card exists, reading zhànqǐlái | entry exists |
| 2 | 坐下 | card exists, reading zuòxià | entry exists |
| 3 | 回去 | card exists, reading huíqu | entry exists |
| 4 | 回来 | card exists, reading huílái | entry exists |
| 5 | 进去 | card exists, reading jìnqu | entry exists |
| 6 | 出来 | card exists, reading chūlái | entry exists |
| 7 | 拿走 | card exists, reading názǒu | entry exists |
| 8 | 扔掉 | card exists, reading rēngdiào | entry exists |
| 9 | 坐下来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | entry exists |
| 10 | 停下来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | entry exists |
| 11 | 走进来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 12 | 跑出去 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 13 | 拿起来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 14 | 带回来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 15 | 爬上去 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 16 | 走过去 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 17 | 想起来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 18 | 拿出来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 19 | 搬进来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 20 | 买回来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 21 | 跳起来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 22 | 笑起来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 23 | 留下来 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |
| 24 | 走进去 | no card yet; every hanzi is taught; the builder adds it with a Wiktionary-read pinyin | no entry (a compositional phrase of the pattern; the pattern page above defines it) |

### `zh-multiword-light-verbs`: idiomatic verb phrases with 打, 开, 发, 做 and friends (`pattern_family: light-verb-idiom`) (zh-6550 to 6599)

Pattern source: each entry read on en.wiktionary (gloss below).

| # | Target | In the course now | en.wiktionary (read 2026-11-15) |
|---|---|---|---|
| 1 | 打电话 | card exists, reading dǎdiànhuà | entry exists |
| 2 | 打扫 | card exists, reading dǎsǎo | entry exists |
| 3 | 打算 | card exists, reading dǎsuàn | entry exists |
| 4 | 打折 | card exists, reading dǎzhé | entry exists |
| 5 | 打针 | card exists, reading dǎzhēn | entry exists |
| 6 | 打雷 | card exists, reading dǎléi | entry exists |
| 7 | 开车 | card exists, reading kāichē | entry exists |
| 8 | 开门 | card exists, reading kāimén | entry exists |
| 9 | 开心 | card exists, reading kāixīn | entry exists |
| 10 | 开学 | card exists, reading kāixué | entry exists |
| 11 | 开花 | card exists, reading kāihuā | entry exists |
| 12 | 发烧 | card exists, reading fāshāo | entry exists |
| 13 | 发现 | card exists, reading fāxiàn | entry exists |
| 14 | 发表 | card exists, reading fābiǎo | entry exists |
| 15 | 做客 | card exists, reading zuòkè | entry exists |
| 16 | 做梦 | card exists, reading zuòmèng | entry exists |
| 17 | 吃药 | card exists, reading chīyào | entry exists |
| 18 | 上网 | card exists, reading shàngwǎng | entry exists |
| 19 | 过敏 | card exists, reading guòmǐn | entry exists |
| 20 | 放心 | card exists, reading fàngxīn | entry exists |

Item counts: separable 20 of 20 (all cards exist); resultative 23 listed (all 23 cards exist; 写好, 找到, 买到 and 写完 have no en.wiktionary entry, so the builder takes 20 of the 23 and may drop those four first); directional 24 listed (8 cards exist and 16 would be new cards: the deck of 20 is the 8 existing plus 12 of the 16, and the builder drops the 4 least frequent); idiomatic 20 of 20 (all cards exist). Overlaps between families were removed (打开 is in the resultative family only; 开会, 做饭, 上班 and 上课 are in the separable list or none).

## Recommendations (ZH-060, about 20)

File `decks/recommendations/zh.yaml`, in the shape of `recommendations/ja.yaml` and `recommendations/fr.yaml`: `kind: "recommendations"`, `id: "recommendations-zh"`, `language: "zh"`, each entry `id: "zh-rec-<name>"`, `medium`, `title { text, reading }` (the `reading` is pinyin), `creator` (ids of `creators/zh.yaml`), `year`, `level`, `briefing { en }` in the builder's own words, 3 questions each that only someone who watched or read can answer, `tags: ["unreviewed"]`, no links (none checked), nothing of the work reproduced (the source-it-yourself mode of Plan-Language-Completeness). `medium` is one of `film`, `series`, `book`, `comic`, `song`, `play`, `podcast`; for books, follow the resolution recorded in Plan-Culture-French (the validator requires a `script` on every book).

Eighteen are source-it-yourself (not public domain by the floor); the last three are public-domain works recommended in full, each also a candidate culture item later (Lu Xun's story is in no culture deck yet). The briefing and the questions are the builder's, never copied from the Wikipedia page.

| # | Title | Medium | Year as read | Creator | Creator dates | What was read | Status | Level (plan's guess) |
|---|---|---|---|---|---|---|---|---|
| 1 | 霸王别姬 (Farewell My Concubine) | film | 1993 | Chen Kaige | b. 1952 | read: en.wikipedia 'Farewell My Concubine (film)', director Chen Kaige, 1993, Mandarin | V | B1 |
| 2 | 活着 (To Live (film)) | film | 1994 | Zhang Yimou | born year not read | read: en.wikipedia 'To Live (1994 film)', director, Cannes 1994, Mandarin | V | B1 |
| 3 | 卧虎藏龙 (Crouching Tiger, Hidden Dragon) | film | 2000 | Ang Lee | b. 1954 | read: en.wikipedia, director Ang Lee, 2000, Mandarin | V | A2 |
| 4 | 饮食男女 (Eat Drink Man Woman) | film | 1994 | Ang Lee | b. 1954 | read: en.wikipedia, 1994, Mandarin, Taiwan | V | A2 |
| 5 | 红高粱 (Red Sorghum) | film | 1988 | Zhang Yimou | born year not read | read: en.wikipedia 'Red Sorghum (film)', 1988 release date | V | B1 |
| 6 | 英雄 (Hero) | film | 2002 | Zhang Yimou | born year not read | read: en.wikipedia 'Hero (2002 film)', 2002 release; the page gives language as English in one field, Mandarin is the spoken language: builder checks | V | A2 |
| 7 | 我不是药神 (Dying to Survive) | film | 2018 | Wen Muye | not read | read: en.wikipedia, director Wen Muye, 2018, Mandarin | V | B1 |
| 8 | 流浪地球 (The Wandering Earth) | film | 2019 | Frant Gwo | not read | read: en.wikipedia, director Frant Gwo, 2019, Mandarin | V | A2 |
| 9 | 哪吒之魔童降世 (Ne Zha) | film | 2019 | Jiaozi (director) | not read | read: en.wikipedia 'Ne Zha (2019 film)', 2019 | V | A2 |
| 10 | 你好，李焕英 (Hi, Mom) | film | 2021 | Jia Ling | b. 1982 | read: en.wikipedia, director Jia Ling, 2021, Mandarin | V | A2 |
| 11 | 活着 (To Live (novel)) | book | 1993 | Yu Hua | b. 1960 | read: en.wikipedia 'To Live (novel)', 1993 | V | B1 |
| 12 | 围城 (Fortress Besieged) | book | 1947 | Qian Zhongshu | 1910 to 1998 | read: en.wikipedia, 1947; not public domain by the floor (died 1998) | V | B1 |
| 13 | 三体 (The Three-Body Problem) | book | 2008 | Liu Cixin | b. 1963 | read: en.wikipedia 'The Three-Body Problem (novel)', 2008 book publication | V | B1 |
| 14 | 骆驼祥子 (Rickshaw Boy) | book | 1937 | Lao She | 1899 to 1966 | read: en.wikipedia, 1937; died 1966, so source-yourself | V | B1 |
| 15 | 西游记 (1986) (Journey to the West (1986 TV series)) | series | 1986 | Yang Jie (director) | not read | en.wikipedia page read, director Yang Jie; the year is taken from the page title only | F | A2 |
| 16 | 红楼梦 (1987) (Dream of the Red Chamber (1987 TV series)) | series | 1987 | Wang Fulin (director) | not read | read: en.wikipedia, first aired 1987, director Wang Fulin | V | B1 |
| 17 | 三毛流浪记 (Sanmao) | comic | year not read | Zhang Leping | 1910 to 1992 | read: en.wikipedia 'Sanmao (comics)', Zhang Leping, manhua; the year of the first strip was not read | F | A2 |
| 18 | 月亮代表我的心 (The Moon Represents My Heart) | song | 1973 or 1977 (the page gives both) | Teresa Teng | 1953 to 1995 | en.wikipedia short description says 1977, its infobox says released May 1973: unresolved | F | A2 |
| 19 | 西游记 (novel) (Journey to the West) | book (public domain) | 1592 (print, circa) | Wu Cheng'en | 1500 or 1505 to 1580 or 1582 | read: en.wikipedia; basis public-domain, recommended in full; see the date question | V | B1 |
| 20 | 红楼梦 (novel) (Dream of the Red Chamber) | book (public domain) | mid-18th century (manuscripts) | Cao Xueqin | 1710 to 1765 (en); other sources differ | read: en.wikipedia; basis public-domain; the date question applies | V | B1 |
| 21 | 狂人日记 (Diary of a Madman) | short story (public domain) | 1918 | Lu Xun | 1881 to 1936 | read: en.wikipedia disambiguation page ('a 1918 short story by Lu Xun'); the story's own page was not read; died 1936, inside the floor | V | B1 |

Not read, so not listed: any podcast or web series (no page was read for one), and any living author's text of a source-yourself work. **The years above are the pages' years**, and an `F` row says what is unresolved.

## Creators and eras (`decks/creators/zh.yaml`)

Eras (the names the pages use; the builder confirms the boundaries): **Zhou** (Spring and Autumn, Warring States; pre-Qin), **Han**, **Three Kingdoms**, **Southern dynasties**, **Tang**, **Northern Song and Southern Song** (one era "Song" if the file allows only one), **Republic of China**. No Yuan, Ming or Qing creator is on the list: the Qing and Ming are covered only by the novels that are recommendations (Wu Cheng'en, Cao Xueqin); a culture batch for them is not planned because their short texts are long passages. An era with one creator (Republic of China, Southern dynasties, Three Kingdoms) is still an era.

`born` and `died` are a plain year (negative for BCE) or `{ year, circa: true }`, never `circa: false`. **Dates of creators with a range ("689 or 691") use the first and `circa: true`.** Creators with no years (Laozi, Zhuang Zhou) need the owner's answer to open question 3.

| Name (`name.en.text`) | 汉字 | Era | Lifespan as read | `born`/`died` form | Source read |
|---|---|---|---|---|---|
| Confucius | 孔子 | Zhou (Spring and Autumn) | c. 551 BCE to c. 479 BCE | circa both | en.wikipedia 'Confucius' |
| Laozi | 老子 | Zhou (traditional) | traditionally 6th century BCE; sometimes 4th | no years | en.wikipedia 'Laozi' |
| Mencius | 孟子 | Zhou (Warring States) | c. 371 BCE to c. 289 BCE | circa both | en.wikipedia 'Mencius' |
| Zhuang Zhou | 庄周 | Zhou (Warring States) | 4th century BCE | no years | en.wikipedia 'Zhuang Zhou' |
| Xunzi | 荀子 | Zhou (Warring States) | c. 310 BCE to after 238 BCE | circa both; death 'after' | en.wikipedia 'Xunzi (philosopher)' |
| Sun Tzu | 孙武 | Zhou (Spring and Autumn) | 544 BCE to 496 BCE (traditional) | traditional | en.wikipedia 'Sun Tzu' |
| Han Fei | 韩非 | Zhou (Warring States) | c. 280 BCE to 233 BCE | circa birth | en.wikipedia 'Han Fei' |
| Liu Xiang | 刘向 | Han | 77 BCE to 6 BCE | plain | en.wikipedia 'Liu Xiang (scholar)' |
| Liu An | 刘安 | Han | c. 179 BCE to 122 BCE | circa birth | en.wikipedia 'Liu An' |
| Sima Qian | 司马迁 | Han | c. 145 BCE to c. 86 BCE | circa both | en.wikipedia 'Sima Qian' |
| Zhuge Liang | 诸葛亮 | Three Kingdoms | 181 to 234 | plain | en.wikipedia 'Zhuge Liang' |
| Zhou Xingsi | 周兴嗣 | Southern dynasties (Liang) | 470 to 521 | plain | en.wikipedia 'Thousand Character Classic' |
| Luo Binwang | 骆宾王 | Tang | c. 619 to 684? | circa both | en.wikipedia 'Luo Binwang' |
| Chen Zi'ang | 陈子昂 | Tang | 661 or 656 to 702 | circa birth | en.wikipedia |
| He Zhizhang | 贺知章 | Tang | c. 659 to 744 | circa birth | en.wikipedia |
| Meng Haoran | 孟浩然 | Tang | 689 or 691 to 740 | circa birth | en.wikipedia |
| Wang Zhihuan | 王之涣 | Tang | c. 688 to 742 | circa birth | en.wikipedia |
| Wang Wei | 王维 | Tang | 699 to 761 | plain | en.wikipedia 'Wang Wei' |
| Li Bai | 李白 | Tang | 701 to 762 | plain | en.wikipedia 'Li Bai' |
| Du Fu | 杜甫 | Tang | 712 to 770 | plain | en.wikipedia 'Du Fu' |
| Zhang Ji | 张继 | Tang | born 712-715, died 779 (fl. 715 to 779) | circa birth | en.wikipedia 'Zhang Ji (poet from Hubei)' |
| Meng Jiao | 孟郊 | Tang | 751 to 814 | plain | en.wikipedia 'Meng Jiao' |
| Wang Jian | 王建 | Tang | 766? to 831? | circa both | en.wikipedia 'Wang Jian (poet)' |
| Liu Yuxi | 刘禹锡 | Tang | 772 to 842 | plain | en.wikipedia 'Liu Yuxi' |
| Liu Zongyuan | 柳宗元 | Tang | 773 to 819 | plain | en.wikipedia 'Liu Zongyuan' |
| Li Shangyin | 李商隐 | Tang | c. 813 to c. 858 | circa both | en.wikipedia 'Li Shangyin' |
| Du Mu | 杜牧 | Tang | 803 to 852 | plain | en.wikipedia 'Du Mu' |
| Li Shen | 李绅 | Tang | died 846 (birth not read) | `born` missing | en.wikipedia 'Li Shen' |
| Fan Zhongyan | 范仲淹 | Northern Song | 989 to 1052 | plain | en.wikipedia 'Fan Zhongyan' |
| Zhou Dunyi | 周敦颐 | Northern Song | 1017 to 1073 | plain | en.wikipedia 'Zhou Dunyi' |
| Wang Anshi | 王安石 | Northern Song | 1021 to 1086 | plain | en.wikipedia 'Wang Anshi' |
| Su Shi | 苏轼 | Northern Song | 1037 to 1101 | plain | en.wikipedia 'Su Shi' |
| Qin Guan | 秦观 | Northern Song | 1049 to c. 1100 | circa death | en.wikipedia 'Qin Guan' |
| Xin Qiji | 辛弃疾 | Southern Song | 1140 to 1207 | plain | en.wikipedia 'Xin Qiji' |
| Zhu Ziqing | 朱自清 | Republic of China | 1898 to 1948 | plain | en.wikipedia 'Zhu Ziqing' |

Creators for the recommendations (not in the table above, lifespans as read): Chen Kaige (b. 1952), Ang Lee (b. 1954), Yu Hua (b. 1960), Liu Cixin (b. 1963), Jia Ling (b. 1982), Qian Zhongshu (1910 to 1998), Lao She (1899 to 1966), Zhang Leping (1910 to 1992), Teresa Teng (1953 to 1995), Wu Cheng'en (1500 or 1505 to 1580 or 1582), Cao Xueqin (1710 to 1765, en.wikipedia; other sources differ), Lu Xun (1881 to 1936); Zhang Yimou, Wen Muye, Frant Gwo, Jiaozi, Yang Jie and Wang Fulin are named on the pages read but their birth years were not.

## Open questions for the owner

1. **BCE dates in `source.date`.** The validator's `parse_years` takes years 1 to 9999 only, and a card of Confucius, Mencius, Han Fei, the Zhan Guo Ce, the Shiji or the Huainanzi has a date before the common era. The creator's `born`/`died` can be negative, so only the work's `date` is blocked. Options, with the main downside: (a) a small code change so `parse_years` accepts a negative year, in its own code pull request with tests; downside: a shared-code change that holds `zh-culture-2` and most of `zh-culture-3` until it lands; (b) put the composition date in the card's note and give `date` the year of the printed edition the Wikisource page cites, which no page read here states and which is not what the field means, so a reviewer must accept it; (c) drop pre-Qin items and ship `zh-culture-2` as Tang, Song and Qing philosophy only, which the list does not have a verified text for. The plan's default is (a), and `zh-culture-1` and `zh-culture-4` go first.
2. **Simplified, traditional, or both.** Wikisource's texts are traditional, the course is simplified, and variant forms (爲/為, 說/悦, 鼃/蛙) differ by edition. Should each card show the simplified rendering only (the plan's choice), or both scripts on the card?
3. **Creators without years.** Laozi (traditional 6th century BCE) and Zhuang Zhou (4th century BCE) have no year on the pages read, and Li Shen has no birth year. Leave out `born`, use `circa` with the century's mid-year, or leave their items out? The plan's default is to leave the item out until a reviewer fills it.
4. **"Basic hanzi only" and classical text.** Every excerpt has 0 to 6 hanzi that no taught word contains. The default is to include an item when it has at most 2 and to give each such hanzi a one-line note (reading and meaning); the six-hanzi items (爱莲说, 自相矛盾's long sentence) are in the lists for completeness and can be cut to a shorter clause. Is that the right reading of the rule?
5. **Wikipedia and Wikisource as the source link.** Source blocks link to zh.wikisource pages, the pages whose raw text was read; a primary library or archive link is not added. Wikisource may hold a modern editor's edition: the page's own footnote says so for some texts, and the reviewer owns the legal opinion on that.
6. **Chengyu with a literary author.** The 40 chengyu and the 20 sayings are `oral-tradition`; those with a known classical origin (千里之行 from the Dao De Jing, 三人成虎 and 亡羊补牢 from the Zhan Guo Ce, 十年树木 from the Guanzi) get the origin in the note. Right, or should those be culture cards with `basis: public-domain`?
7. **The family names.** The fourth multi-word family (打, 开, 发, 做) is the plan's own grouping. Keep, or replace it with a family the owner prefers?

## Verification

Every row above was built from pages read by `curl` on 2026-11-15, as raw wikitext:

- **Texts** (zh.wikisource.org): 論語 (學而, 爲政, 里仁, 述而, 子罕, 衞靈公), 道德經 (王弼本), 荀子勸學篇, 孫子兵法, 莊子 (齊物論, 秋水), 孟子 (梁惠王上, 公孫丑上, 公孫丑下), 禮記學記, 韓非子 (五蠹, 難一, 內儲說上七術, 外儲說左上), 戰國策 (士禮居叢書本; 齊二, 楚一, 楚四, 燕二, 魏二), 列子湯問篇, 淮南子人間訓, 史記 (卷007, 卷041, 卷081), 前出師表, 世說新語假譎, the poems named in the tables, 千字文, 愛蓮說, 陋室銘, 岳陽樓記, 春 (朱自清), 敕勒歌, 江南 (漢樂府), 木蘭詩.
- **Lifespans**: en.wikipedia for each creator in the creators table (short description and infobox; Meng Jiao, Zhang Ji, Wang Wei, Wang Zhihuan and Luo Binwang from the page's lead).
- **Chengyu, sayings, families**: en.wiktionary.org (every entry named, gloss and POS) and zh.wiktionary.org ('離合詞' and its category).
- **Recommendations**: the en.wikipedia page of each title, as the table says.
- **The taught-hanzi check**: every `decks/zh/zh-*.yaml` core on decks-live (`09e2a6d6`) was loaded with PyYAML: 4,351 distinct card targets and 1,834 distinct hanzi. The 50 cards of `zh-idioms` and every card's target were compared with the lists.
- **Not read**: any Qing or Ming short text, any primary library page, Hong Kong or Taiwan law, the legal terms of any jurisdiction, and the Wikisource edition's own copyright notes. Nothing from memory is asserted as checked; the simplified conversions are the one place the author's own hand was used and every one is a reviewer check. The validator and the tests run in CI on the pull request, not here.
