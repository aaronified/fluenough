# Fluenough: which skills each question judges, and how far one skill implies another

## Read this first

- The owner's two points are separate problems with separate literatures.
  - **"Same questions can judge multiple skills"** is about measurement. It calls for a Q-matrix: one row per question type, marking which skills that question needs (Tatsuoka 1983 for rule space; Tatsuoka's 1984 report for the fraction Q-matrix).
  - **"One skill may partially imply other skills"** is about how knowledge in one skill carries over to another. The vocabulary-strength and learning-direction literature covers it.
- **The current .68 weight is the wrong kind of number.** Milton & Hopkins (2006) reported it as a correlation between learners' overall vocabulary sizes:
  - the study used yes/no aural (AuralLex) and written (X-Lex) tests;
  - N = 126 learners of English, 38 with L1 Arabic and 88 with L1 Greek;
  - it covers only aural vs written recognition;
  - it is not a per-word transfer rate, it is symmetric, and it says nothing about Say or Write;
  - the figure was checked through secondary sources only (Medium).
- **Other studies put the aural–written correlation anywhere from about .46 to .88:**
  - .46 (Milton, Wade & Hopkins 2010; N ≈ 30; Low confidence);
  - .88 (Ha 2021, Language Testing in Asia 11:20; 234 Vietnamese EFL learners).
- **No study reports what the app actually needs:** the chance of success in skill B given success in skill A on the same word, or a transfer rate expressed in FSRS stability terms. Every numeric weight below is inference unless it says otherwise.

## 1. Which skills each question judges

Key: **P** = primary (the question exercises this skill directly), **S** = secondary (indirect evidence only, through an implication), **–** = none.

Most mappings rest on the Laufer & Goldstein (2004) strength levels. That paper is Language Learning 54(3), 399–436, DOI 10.1111/j.0023-8333.2004.00260.x, with N = 435 learners of English in Israel. The difficulty order, easiest first, is:

1. passive recognition: see the L2 word, pick its meaning;
2. active recognition: see the meaning, pick the L2 word;
3. passive recall: see the L2 word, supply its meaning;
4. active recall: see the meaning, supply the L2 word.

The order is Medium confidence. The claim that it forms an implicational scale holding at every frequency level is Low.

Assigning question types to these levels is my inference (Low). Citations are listed under the table.

| Question type | L&G level | Recognition | Hear | Say | Write | Grammar | Script/form | Notes |
|---|---|---|---|---|---|---|---|---|
| chooseMeaning | passive recognition | P | – | – | – | – | – | 4-option guessing makes success weak evidence [1][2] |
| matchPairs | passive recognition | P | – | – | – | – | – | The last pair is forced by elimination (inference, Low) |
| Recognition self-rated reveal | passive recall | P | – | – | – | – | – | Recall carries information recognition does not, but not the reverse [3]. Self-rating is unvalidated (gap) |
| chooseWord | active recognition | S | – | – | P (choose) | – | – | Choosing does not show spelling can be produced [4] |
| rearrange | none (syntax) | – | – | – | S | P (syntax) | – | No validation evidence found. All Low inference |
| cloze, choose | active recognition in context | S | – | – | P | S | – | The grammar link is Low inference (the cloze sources were dropped) |
| cloze, typed | active recall in context | S | – | – | P (type) | S | S (spelling) | Same caveat as cloze, choose |
| type the word (script or ISO) | active recall | S | – | – | P (type) | – | P | Recall formats beat recognition for productive spelling [4] |
| hearMeaning | aural passive recognition | S | P | – | – | – | – | The answer is the same as chooseMeaning's: the meaning [5][6] |
| hear and type meaning | aural passive recall | S | P | – | – | – | – | Aural recognition and recall form one factor [7] |
| dictation (script practice) | productive phonological | – | P | – | S | – | P | Phonological productive vocab best predicts listening [8]. Conjunctive: needs Hear AND spelling [9] |
| speak | active recall, spoken | S | – (no evidence) | P | – | – | – | Retrieval, not imitation [10]. ASR grading is unvalidated (gap) |
| grammar choose | recognition of form | – | – | – | – | P | – | Recognition comes before recall within each component [11] |
| grammar type | recall of form | – | – | – | S (spelling) | P | S | The typed form implies the choose form [11][12] |
| reading comprehension | – | S | – | – | – | S | – | Meaning recall correlates most with reading [13] |

**Citations for this table**

- [1] Laufer & Goldstein 2004 (above). Order: Medium.
- [2] Inference from guessing (Low). The Stoeckel 2019 figures were dropped.
- [3] Stewart, Gyllstad, Nicklin & McLean 2024, Language Testing 41(1), 89–108, DOI 10.1177/02655322231162853.
  - A two-factor model fit better than one, but discriminant validity is questionable.
  - Recognition added nothing beyond recall.
  - Population not verified. Confidence: High from the abstract.
- [4] Nakata 2016, IRAL 54(3), 257–289, DOI 10.1515/iral-2015-0022.
  - N = 64 English-speaking students learning Swahili.
  - Recall beat recognition for productive spelling; recognition was more useful when spelling was not required. Medium.
- [5] Pan & Rickard 2018, Psychological Bulletin 144(7), 710–756, DOI 10.1037/bul0000151.
  - Response congruency strongly influences transfer: abstract (High).
  - The d values come from a secondary summary (Medium).
- [6] Milton & Hopkins 2006 (above). Medium.
- [7] Uchihara et al. 2025, Language Learning 75(2), 458–492, DOI 10.1111/lang.12668.
  - N = 114 Japanese EFL learners.
  - The one-factor grouping comes from a later paper by the same group (Medium).
- [8] Cheng & Matthews 2018, Language Testing 35(1), 3–25, DOI 10.1177/0265532216676851.
  - N = 250 Chinese EFL learners.
  - Productive phonological knowledge with listening: r = .71. Productive orthographic knowledge with reading: r = .57.
  - High from the abstract. The dictation format itself was not verified.
- [9] Junker & Sijtsma 2001, APM 25(3), 258–272, DOI 10.1177/01466210122032064. DINA: a conjunctive model, i.e. all listed skills are needed.
- [10] Kang, Gollan & Pashler 2013, PB&R 20(6), 1259–1265, DOI 10.3758/s13423-013-0450-z.
  - US undergraduates learning 40 Hebrew nouns.
  - Retrieval practice gave better comprehension and production than imitation, with no loss in pronunciation quality. Medium.
- [11] González-Fernández & Schmitt 2020, Applied Linguistics 41(4), 481–505, DOI 10.1093/applin/amy057.
  - N = 144 L1 Spanish EFL learners.
  - Recognition came before recall within each component. Medium.
- [12] González-Fernández 2025, TESOL Quarterly 59(2), 755–784, DOI 10.1002/tesq.3342.
  - N = 314 L1 Chinese and L1 Spanish learners.
  - The same order held in both L1 groups, but only written tests were used. High from the abstract.
- [13] Zhang & Zhang 2022, Language Teaching Research 26(4), 696–725, DOI 10.1177/1362168820913998.
  - 276 effect sizes from more than 100 studies.
  - Vocabulary correlates r = .57 with reading and r = .56 with listening.
  - Orthographic measures go with reading, aural measures with listening. High.

**Two kinds of question, and how blame should work**

- **Conjunctive (DINA-type):** every listed skill is needed. Examples: dictation, cloze typed, hear and type.
  - A failure means at least one skill is missing, not all of them.
  - Blame should be split across the skills, not given in full to each.
  - Evidence: Koedinger et al. 2011, EDM 91–100. A simple update that lowers all skills after an error caused "problem selection thrashing" in tutor logs. A conjunctive update suggested 441 of 1,370 assigned problems were possibly unnecessary (High).
- **Disjunctive (DINO-type):** any one of several routes is enough. Templin & Henson 2006, Psychological Methods 11(3), 287–305, DOI 10.1037/1082-989X.11.3.287 (Medium).
  - A success says little about any single skill.
  - Whether any app question is truly disjunctive is inference (Low).

## 2. How far each skill implies another (row implies column)

| From (success in) | To | Direction and figure | Population | Confidence |
|---|---|---|---|---|
| Active recall (type the word, Say) | Recognition | Strong; it is the harder level. No transfer figure. | L&G 2004 (Israel EFL, N = 435); G-F & Schmitt 2020 | Medium (order); Low (implication) |
| Productive practice | Receptive knowledge | Productive learning gave larger gains in most aspects; receptive learning gave larger gains in receptive meaning. "If only one method is used, productive learning might be more effective." No effect sizes. | Webb 2009, RELC 40(3), 360–376, DOI 10.1177/0033688209343854; Japanese EFL, N = 84 | High (direction) |
| Productive practice | Receptive knowledge | Counter-evidence: with equal time on task, the receptive reading task was superior (Exp. 1). Writing won only when it got more time (Exp. 2). | Webb 2005, SSLA 27(1), 33–52, DOI 10.1017/S0272263105050023; Japanese EFL | Medium |
| Productive learning | Receptive knowledge | Productive learning yields a considerable amount of receptive knowledge; the reverse effect is less strong. No numbers. | Mondria & Wiersma 2004, DOI 10.1075/lllt.10.08mon; population not verified | Medium (conclusion); Low (population) |
| L1→L2 learning | Both directions | L1→L2 presentation was "the more versatile form" when both production and comprehension are needed. | Griffin & Harley 1996, Applied Psycholinguistics 17(4), 443–460; English pupils aged 11–13 learning French | Medium |
| Either direction | The other direction | Productive learners had a "sizable advantage" on the productive test; receptive learners did better on recognition. Tested immediately and at 3 weeks. Transfer is partial. | Steinel, Hulstijn & Steinel 2007, SSLA 29, 449–484 (hdl 1887/14200); 129 Dutch university students, 20 English idioms | High |
| Either direction | The other direction | Transfer was partial in all 3 experiments and occurred whichever direction came first. No asymmetry reported; no savings figures. | Bernardi, Vaughn, Dunlosky & Rawson 2024, Memory, PMID 39222444; adults, language not verified | Medium |
| Forward test (cue→target) | Backward recall | Better than restudy (the "backward transfer effect"). Shown with L1 pairs and with native–foreign pairs. No size given. | Carpenter, Pashler & Vul 2006, PB&R 13(5), 826–830 | Medium |
| Forward association | Backward association | Forward and backward storage strengths are highly correlated (model fit). | Rizzuto & Kahana 2001, Neural Computation 13, 2075–2092; L1 pairs | Medium |
| Direction effect overall | – | Depends on proficiency: L2→L1 was more effective for lower-proficiency learners, L1→L2 for higher. | Terai, Yamashita & Pasich 2021, SSLA 43(5), 1116–1137, DOI 10.1017/S0272263121000346; Japanese EFL, N = 28 | Medium |
| Recognition (L2→L1) | Write/Say (L1→L2) | Productive-to-receptive vocabulary size ratio: about 65–88% under strict scoring, 91–95% under partial scoring. The gap widens as word frequency falls. | Webb 2008, SSLA 30(1), 79–95, DOI 10.1017/S0272263108080042; Japanese EFL, N = 83 | High (pattern); Medium (ratios, from an unofficial copy) |
| Recognition (passive) | Controlled production (prompted) | Passive and controlled-active sizes "correlated well"; free active correlated with neither. No coefficients. | Laufer 1998, Applied Linguistics 19(2), 255–271; 48 Israeli high-school ESL students | Medium |
| Recognition (choose) | Write (type, spelling) | Weak. Recognition practice does not build productive spelling. No figure. | Nakata 2016 (above) | Medium |
| Recall | Recognition | Recognition adds nothing beyond recall when predicting reading, so recall subsumes it. | Stewart et al. 2024 (above) | High |
| Hear ↔ Recognition (written) | – | Person-level size correlation r = .68, not per word. Aural-only (no captions) learners gained more aural than written recognition; captioned learners showed the reverse. | Milton & Hopkins 2006 (L1 Greek/Arabic EFL, N = 126); Sydorenko 2010, LLT 14(2), 50–73 (US learners of Russian, N = 26) | Medium |
| Hear ↔ Recognition (written) | – | Range of reported values: .46 (N ≈ 30) to .88 (Vietnamese, N = 234). There is no meta-analysis. | Milton, Wade & Hopkins 2010; Ha 2021 | Low (.46); Medium (.88) |
| Hear (aural vocabulary) | Say | AuralLex correlated r = .71 with IELTS speaking; X-Lex correlated .35. Person-level. | Milton, Wade & Hopkins 2010, in *Further* Insights into Non-native Vocabulary Teaching and Learning, 83–98 (from citing papers) | Medium |
| Written-only input | Say | Partial. Hearing the words gave less accented, more comprehensible pronunciation; reading plus listening gave the most spoken-form recall. | Uchihara, Webb, Saito & Trofimovich 2022, MLJ, DOI 10.1111/modl.12775; Japanese EFL, N = 75 | High |
| Hear (aural recognition) | Hear (aural recall) | One declarative factor; they are close to interchangeable. Fast in-context listening is a separate factor. | Uchihara et al. 2025 | Medium |
| Practice on format A | Test on format B (same content) | Overall d = 0.40, 95% CI [0.31, 0.50], versus restudy. 192 effect sizes, 122 experiments, N = 10,382. Weakest for rearranged stimulus–response items (i.e. reversed direction) and for untested material. | Pan & Rickard 2018; mixed, mostly adult L1 | High |
| Same response vs different response | – | Congruent response d ≈ 0.58; no congruency d ≈ 0.28. | Pan & Rickard 2018, via a secondary summary | Medium |
| Tested item | Related untested item | Small. Untested material d = 0.16, p = .20, k = 17 (not significant). Prose facilitation exists but replicates smaller. | Pan & Rickard via Glaser & Richter 2025; Chan, McDermott & Roediger 2006, JEP:G 135(4), 553–571 | Medium |
| Grammar type | Grammar choose | Recognition comes before recall within a component, so the typed form implies the chosen form. No figure. | G-F & Schmitt 2020; G-F 2025 | Medium |
| Say ↔ Write (spoken vs typed form recall) | – | **No figure. No source found.** | – | – |
| Dictation or script practice → word skills; Say (ASR) → Hear or Recognition | – | **No figure. No source found.** | – | – |

**Moderators to remember**

- Implication is stronger for frequent words and small vocabularies, and weaker for rare words and large vocabularies. Source: Schmitt 2014, Language Learning 64(4), 913–951, DOI 10.1111/lang.12077 (High).
- Do not treat .68, or any of these person-level correlations, as a per-answer update size. The researchers who reported them flag the same caveat.

## 3. What the evidence supports

### (a) Elo ability-layer weights

**Option 1 (best): a weighted Q-matrix with a multidimensional Elo update (M-ERS).**

- How it works:
  - each question type gets a loading vector over skills, taken from section 1 (P high, S low);
  - one answer's Elo error is shared out across skills by those loadings;
  - successes and failures get separate weights (PFA style);
  - failure blame is split across skills, not duplicated.
- Evidence:
  - Park, Cornillie, van der Maas & Van Den Noortgate 2019, Frontiers in Psychology 10:620, DOI 10.3389/fpsyg.2019.00620. Unidimensional Elo had "seriously lower prediction accuracy" than M-ERS on multidimensional data (simulation, plus real math-practice data). High.
  - Vermeiren, Hofman & Bolsinova 2025, EDM. M-ERS is robust to a misspecified Q-matrix and weights, and beats M-Elo, which is biased. Simulation only. High. This matters because the first weights will be hand-set.
  - Pavlik, Cen & Koedinger 2009, AIED 531–538, DOI 10.3233/978-1-60750-028-5-531. Separate counts of successes and failures per skill. High.
  - Koedinger et al. 2011 on splitting blame (above). High.
- Main downside: expect only small accuracy gains.
  - Nižnan, Pelánek & Řihák 2015, EDM 109–116: multivariate Elo improved predictions "only slightly" (geography practice data). High.
  - Abdi et al. 2019, arXiv 1910.12581: M-Elo beat Elo but "the difference is rather small." High.
- **Confidence: Medium** for the structure; **Low** for any specific loading values.

**Option 2: a directional skill-to-skill matrix in place of the single .68.**

- How it works: transfer from production to reception (Say/Write → Recognition/Hear) is larger than the reverse; Hear ↔ Recognition is moderate; Say ↔ Write is unknown.
- Evidence for the direction: Webb 2009, Steinel 2007, Griffin & Harley 1996, Laufer & Goldstein order, Stewart 2024.
- Main downside: the research gives the direction but no magnitudes. The asymmetry also reverses under equal time (Webb 2005 Exp. 1) and depends on proficiency (Terai 2021).
- **Confidence: Medium** for the direction; **Low** for the size.

**Option 3: fit the weights from the app's own logs (target state).**

- How it works: fit PFA, AFM or KTM with per-(question type, skill) features.
- Evidence:
  - Vie & Kashima 2019, AAAI 33, 750–757, DOI 10.1609/aaai.v33i01.3301750. KTM handles multiple skills per item and sparse data. High.
  - Gong, Beck & Heffernan 2011, IJAIED 21. PFA predicted much better than knowledge tracing (High). The best PFA variant ignored the tutor's hand-made transfer model (Medium).
  - Zhang et al. 2021, CIKM: AUC AFM .624/.699/.641 vs KTM .792/.794/.730 vs DAS3H .785/.793/.731. KTM and DAS3H are within about .01 of each other. Medium.
- Main downside: needs enough review logs first. Until then, start from Option 1.
- **Confidence: Medium.**

**Option 4: keep a single .68.**

- Main downside: it is a symmetric, person-level correlation of size scores. It covers only Hear vs written recognition, and other studies range from .46 to .88.
- **Confidence that it is adequate: Low.**

### (b) FSRS: should an answer also count as a review of another skill's schedule?

**Option 1 (best): a full review only for skills the question actually exercises (the P cells in section 1), and a partial implicit review for implied skills (S cells) on success only.**

- How it works:
  - A full review goes to every P skill. Dictation, for example, gives a full review to Hear and to the script skill.
  - A success gives S skills a fractional stability increase, but never resets or advances their due date.
  - A failure gives S skills nothing, or only a split share of the blame.
- Evidence:
  - Transfer exists but is partial: Pan & Rickard 2018, d = 0.40 (High); Bernardi 2024, partial in all experiments (Medium); Steinel 2007, matched direction is best (High).
  - Per-skill memory traces updated from multi-skill items, each skill with its own forgetting: DAS3H, Choffin et al. 2019, EDM, arXiv 1905.06873 (High). The authors say no earlier model combined memory decay with multiple skill tagging.
  - Reviewing a well-chosen subset of skills retained better than reviewing the single best skill: Choffin, Popineau & Bourda 2021, JEDM 13(3), article 510 (High, simulation only).
  - Design precedent for discounted implicit credit: FIRe at Math Academy (Skycak, blog). Not peer-reviewed; no weights published.
- Main downside:
  - No study gives the fraction.
  - Any fraction is a guess. Pan & Rickard's .28 vs .58 suggests that reversed-direction credit is roughly half of same-response credit, but that ratio is Low-confidence inference.
  - FSRS has no native partial review, so it needs a custom stability update.
- **Confidence: Medium** for the structure; **Low** for the fraction values.

**Option 2: no cross-skill review. Each skill has its own schedule (the current behaviour, and Anki's sibling handling).**

- Evidence for keeping skills separate:
  - Mondria & Wiersma 2004 and Steinel 2007: performance is best when test direction matches study direction.
  - Sydorenko 2010 and Uchihara 2022: aural and written form knowledge develop partly separately.
  - Anki's siblings are buried for the day, not credited (Anki manual; Low).
- Main downside:
  - It ignores documented transfer (d = 0.40) and the owner's premise.
  - Learners over-review implied skills.
- **Confidence that it is optimal: Low–Medium.**

**Option 3: a full review for every skill tagged to the question (AFM-style: each tagged skill counts a full opportunity).**

- Evidence: AFM, Cen, Koedinger & Junker 2006, ITS, LNCS 4053, 164–175 (Medium).
- Main downside:
  - It over-credits, since transfer is partial and direction-matched practice is best (Steinel, Bernardi).
  - On failures it causes thrashing (Koedinger 2011).
  - Duolingo's HLR is the extreme form. Settles & Meeder 2016, ACL, DOI 10.18653/v1/P16-1174, cut prediction error by 45%+ over baselines (High). Whether HLR pools exercise formats into one trace is the claimant's inference (Medium–Low).
- **Confidence: Low.**

**Calibrating later.** Estimate per-pair weights from logs: how well success in skill A on a word predicts the next answer in skill B on that word. A public start is the Duolingo SLAM data (Settles et al. 2018, BEA, aclanthology W18-0506):

- about 6.4k learners, first 30 days only;
- per-exercise format field (reverse_translate, reverse_tap, listen);
- English-track baseline AUC .774, best .861 (Medium).

## 4. Dropped claims and gaps

**Dropped as unsupported, or unsupported in the form given**

- Laufer & Goldstein's ".65 correlation with achievement" and "mostly L1 Hebrew". The "held at every frequency level" detail is only Low.
- Milton & Hopkins: the claim that written vocabulary grows faster and overtakes aural vocabulary at intermediate and advanced levels.
- Masrai's written–aural r = .58.
- Ha 2021 described as Chinese learners, or as Masrai's paper (it is Vietnamese learners, by Ha).
- Stoeckel et al. 2019: VST and meaning recall r = .88–.91 and .77.
- Laufer & Aviad-Levitzky 2017: r = .91 and .92 with reading.
- Webb, Sasao & Ballance 2017: details of the VLT matching format.
- Kremmel & Schmitt 2016.
- Schmitt, Nation & Kremmel 2020.
- Morris, Bransford & Franks 1977 (transfer-appropriate processing).
- Kang, McDermott & Roediger 2007 (multiple-choice vs short-answer formats).
- The cloze validity studies (Veridian 2015; McKamey 2006).
- Oller 1971 and Oller & Streiff 1975 on dictation.
- The rearrange or elicited-imitation evidence.
- Son 2022 on speaking vs writing.
- Mondria & Wiersma's 53% and 12% gains.
- Webb 2009: MANOVA F(10,51) = 3.73.
- Webb 2005 described as "productive beats receptive at equal time" (the reverse is true).
- Pan & Rickard: "across formats d = 0.58" (0.58 is the congruent-response figure).
- Caplan 2005's "19-word list, mid-range correlation" and the claim about semantically related pairs.
- Pyc & Rawson 2010: "almost 3x restudy".
- DAS3H repository AUCs (0.826 and 0.790) and its time-window lengths.
- Choffin 2021: "500 simulated students per cohort".
- Abdi 2019: "gains grow as sigma rises".
- Steinel 2007: the "80 norming raters".
- The proposed numeric weight table from the retrieval report (0.8–1.0, 0.5–0.6, 0.5, 0.25–0.3, 0.3–0.5, 0–0.15).

**Gaps**

- No per-word conditional transfer, P(B correct | A correct), and no transfer rate in FSRS stability units. Every weight must be inferred, then fitted from logs.
- No evidence on Say ↔ Write (spoken vs typed form recall), ASR-graded speaking, dictation transferring to word skills, ISO transliteration typing, rearrange, self-rated reveal, or grammar practice crediting lexical skills.
- Bernardi et al. 2024: the trials-to-criterion savings, and any asymmetry, are in the full text only. This is the most directly useful missing figure.
- Pan & Rickard: the d for rearranged (reversed) items, and the same-test baseline effect size, were not retrieved.
- Almost all evidence comes from English as the L2. Nothing covers Indic or other new-script target languages, where the aural–written gap may be larger. The faster aural than written learning in the Arabic L1 group is the only hint.
- Asymmetric credit (successes propagate, failures barely do) is supported only indirectly, by PFA and Koedinger 2011.
- Most checks relied on abstracts or secondary text. No full texts were read.

## Appendix: the evidence behind Hear, Say and Write

Moved here from `docs/plans/skill-model.md` (deleted when #207 closed); the design it led to is ADR-0034. It was read from abstracts and summaries, not full texts, and the checks above did not cover it. Full citations are to go in the Research and standards page (`docs/plans/research-and-standards.md`).

The terms are the research's, so that the app's labels match it:

| Axis | Values | Source |
|---|---|---|
| Direction | Understand (the word → its meaning), produce (the meaning → the word) | Nation 2022 |
| Response | Choose (recognition), recall (type, say, write) | Laufer & Goldstein 2004 |
| Channel | Sound, Latin letters, script; a picture is another way to show the meaning | Nation 2022; Milton & Hopkins 2006 |

What decided the design:

- **Recalling is harder than choosing, and producing harder than understanding:** recall the word > recall the meaning > choose the word > choose the meaning, in every frequency band (Laufer & Goldstein 2004). Recognition is learnt before recall in every part of word knowledge (González-Fernández & Schmitt 2020).
- **Channels are related but separable.** Knowing words by ear and in writing correlate at about .68 (Milton & Hopkins 2006); knowing them by sound predicts listening, in writing reading (Cheng & Matthews 2018).
- **What you practise is what improves.** Learning to produce helps production most, learning to understand helps understanding most (Steinel et al. 2007; Webb 2009; DeKeyser 1997), as the match between practice and test predicts (Morris et al. 1977).
- **Hearing a contrast is not keeping two words apart.** Learners can hear or say a contrast and still not store it in their words (Hayes-Harb & Masuda 2008; Llompart 2021). A blurred form retrieves the wrong meaning (Cook et al. 2016), and questions on meaning catch near-homophones that questions on form miss (Ota et al. 2009). Hence Hear asks for the meaning. Writing down a heard word still tests its form (Matthews & Cheng 2015), which is why script practice keeps it.
- **Recall with feedback** gives the best long-term retention (Kang et al. 2007), and retrieval beats repeating after the audio (Kang, Gollan & Pashler 2013).
- **Grammar:** understanding and producing practice build partly separate skills (DeKeyser 1997; Shintani et al. 2013). Timed and untimed tests measure different knowledge (Ellis 2005; Suzuki & DeKeyser 2015).
- **Learner models:** a model with several skills per item and forgetting per skill, DAS3H, did best in its comparison (Choffin et al. 2019); Elo estimates ability and difficulty after each answer with nothing to fit (Pelánek 2016; Pelánek et al. 2017). FSRS's peer-reviewed precursors are Ye et al. 2022 and Su et al. 2023.
- **Pictures** help concrete words (Carpenter & Olson 2012; Lotto & de Groot 1998).
- **Tracked for the learner, not per word:** accent, from hearing several voices (Bradlow & Bent 2008; Baese-Berk et al. 2013); phonemic contrasts, as identification with feedback (Logan et al. 1991; Thomson 2018).
