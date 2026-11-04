# Plans retired

Source of truth: this wiki page.

A plan is retired when it is fully built and merged, or when the owner dropped or replaced it. Its page stays, cut to a two-line pointer to this list, so links keep working; the full text is in git history (`git show <commit>:wiki/<page>.md`). Live plans are in [Plans Index](Plans-Index).

Retired on 2026-11-04 (owner, 2026-11-04: "update all issues, wiki, docs, and retire obsolete or completed plans."). Each status below was checked against the code, the CHANGELOG and the merged pull requests.

| Plan | Status | Built by | Last full text |
|---|---|---|---|
| [Ipa Course](Plan-Ipa-Course): the IPA, taught like a language | Done | #541 (closes #534, merged 2026-10-17): 179 cards, the language picker entries, "the sounds of this word", ADR-0041; #658 (tagged Complete); #983 (shown on the Languages page). The speaker's check of the uncertain tags is still open as #338; the revamp is its own plan, [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology). | `98be300` |
| [Placement V2](Plan-Placement-V2): placement, script first, then a three-skill check | Done | #481 (CHANGELOG 0.5.4: a script check per script, a shorter check); reworked by #993 (merged 2026-11-02: sentence tiles instead of writing, no ask screens, all in the review's screen, started after Learn in onboarding) and #1005 (placement in the shared shell). The exam variant of the shell is not part of placement; it waits on the exam screen of #509 ([Plan-Question-Engine-2-And-Exams](Plan-Question-Engine-2-And-Exams)). | `98be300` |
| [Progress Revamp](Plan-Progress-Revamp): mastery across all skills | Done | #678 (CHANGELOG 0.6.7, "Progress is redrawn"); hours spent and left, #227. | `98be300` |

Nothing is retired as obsolete yet. A plan the owner drops, or one that a later plan replaces, goes in this table with the owner's words and the date.

See also: [Plans Index](Plans-Index) · [Roadmap](Roadmap) · [Owner decisions history](Owner-Decisions-History)
