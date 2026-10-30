#!/usr/bin/env python3
"""The daily questions' answers (#519): read from the app's files, counted a
data point at a time, settled by two agreeing answers, and what a settled
point does to the decks. Stdlib `unittest` plus PyYAML. Git and GitHub are
the fakes of test_review_bot.py. The words are made up.
"""

from __future__ import annotations

import contextlib
import email.message
import io
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mail_to_issues  # noqa: E402
import question_answers as qa  # noqa: E402
from test_mail_to_issues import ENV  # noqa: E402
from test_proposals import ALICE, BOB, code  # noqa: E402
from test_review_bot import Base, ProposingImap  # noqa: E402

CAROL = code("0Z8Q2XJ7")
SECRET = "SECRET WHY TEXT"

AUDIO = ('    audio: "decks/zz/audio/zz-9202.opus"\n'
         '    audio_credit: { source: "https://commons.wikimedia.org/wiki/File:Zz.ogg", '
         'license: "CC-BY-SA-4.0", credit: "A. Speaker" }\n')


def answer(card: str, point: str, kind: str, given: str, reason: str = "",
           why: str = "") -> dict:
    out = {"card": card, "point": point, "kind": kind, "answer": given}
    if reason:
        out["reason"] = reason
    if why:
        out["why"] = why
    return out


def questions_file(answers: list[dict], rater: str = ALICE, lang: str = "zz") -> dict:
    return {"format": "fluenough-questions", "version": 1, "rater_code": rater,
            "language": lang, "app_version": "0.7.0",
            "made": "2026-10-30T09:41:00.000Z", "answers": answers}


def questions_mail(files: list[dict], sender: str = "anvi@example.com",
                   ident: str = "<q1@example.com>") -> email.message.EmailMessage:
    message = email.message.EmailMessage()
    message["Subject"] = f"[Fluenough questions] {ALICE} (zz)"
    message["From"] = f"Anvi <{sender}>"
    message["Message-ID"] = ident
    message.set_content("2 answers.")
    for data in files:
        message.add_attachment(json.dumps(data).encode("utf-8"),
                               maintype="application", subtype="json",
                               filename=f"fluenough-questions-{data['language']}.json")
    return message


MEANING = answer("zz-9201", "meaning", "meaning", "yes")


class Reading(unittest.TestCase):
    def test_answers_are_read_and_what_cannot_be_right_is_counted(self) -> None:
        files = [
            questions_file([
                MEANING,
                answer("zz-9201", "example:0123abcd", "example", "no", "unnatural", SECRET),
                answer("zz-9202", "sound", "sound", "flag", "noisy"),
                # No such answer for a sound: it is only flagged.
                answer("zz-9202", "sound", "sound", "no"),
                # The point does not belong to the kind.
                answer("zz-9201", "sound", "meaning", "yes"),
                # A card of another language.
                answer("yy-0001", "meaning", "meaning", "yes"),
                # A reason the kind does not know is dropped, the answer kept.
                answer("zz-9201", "confusable:c1", "confusable", "no", "noisy"),
                "not an answer",
            ]),
            questions_file([MEANING], rater=BOB),
            questions_file([MEANING], lang="../x"),
        ]
        batch = qa.read_questions(files, ALICE)
        self.assertEqual(
            [(a.card, a.point, a.answer, a.reason) for a in batch.answers],
            [("zz-9201", "meaning", "yes", ""),
             ("zz-9201", "example:0123abcd", "no", "unnatural"),
             ("zz-9202", "sound", "flag", "noisy"),
             ("zz-9201", "confusable:c1", "no", "")])
        self.assertEqual(batch.dropped, 5)
        # The reviewer's own words are never read.
        self.assertNotIn(SECRET, repr(batch))

    def test_an_image_answer_pins_its_file(self) -> None:
        batch = qa.read_questions([questions_file([
            answer("zz-9201", "image:Blorp.jpg", "image", "yes"),
            answer("zz-9201", "image:../Blorp.jpg", "image", "yes"),
            answer("zz-9201", "image:two words.jpg", "image", "yes"),
        ])], ALICE)
        self.assertEqual([a.point for a in batch.answers], ["image:Blorp.jpg"])


class Counting(Base):
    def record(self, code_: str, *answers: dict, agreements: int = 1) -> qa.Counted:
        batch = qa.read_questions([questions_file(list(answers), rater=code_)], code_)
        return qa.record(self.git.main, batch, code_, agreements)

    def point(self, key: str = "zz-9201|meaning") -> dict:
        data = json.loads((self.git.main / "review-answers" / "zz.json")
                          .read_text(encoding="utf-8"))
        return data["points"][key]

    def test_one_answer_is_counted_and_two_agreeing_settle_a_point(self) -> None:
        first = self.record(ALICE, MEANING)
        self.assertEqual(first.settled, [])
        self.assertNotIn("settled", self.point())
        second = self.record(BOB, MEANING)
        self.assertEqual(second.settled, [("zz", "zz-9201", "meaning", "yes")])
        self.assertEqual(self.point()["settled"], "yes")
        self.assertEqual(sorted(self.point()["answers"]), sorted([ALICE, BOB]))

    def test_a_code_counts_once_and_may_change_its_mind_until_settled(self) -> None:
        self.record(ALICE, MEANING)
        again = self.record(ALICE, MEANING)
        self.assertEqual(again.ignored, 1)
        self.assertFalse(again.changed)
        self.record(ALICE, answer("zz-9201", "meaning", "meaning", "no", "wrong"))
        self.assertEqual(self.point()["answers"][ALICE],
                         {"answer": "no", "reason": "wrong"})
        # Alice's two answers are one voice: Bob alone does not settle.
        self.record(BOB, MEANING)
        self.assertNotIn("settled", self.point())

    def test_a_disagreement_waits_for_a_third(self) -> None:
        self.record(ALICE, MEANING)
        self.record(BOB, answer("zz-9201", "meaning", "meaning", "no", "wrong"))
        self.assertNotIn("settled", self.point())
        third = self.record(CAROL, answer("zz-9201", "meaning", "meaning", "no"))
        self.assertEqual(third.settled, [("zz", "zz-9201", "meaning", "no")])
        self.assertEqual(self.point()["settled"], "no")

    def test_a_settled_point_never_changes(self) -> None:
        self.record(ALICE, MEANING)
        self.record(BOB, MEANING)
        late = self.record(CAROL, answer("zz-9201", "meaning", "meaning", "no"))
        self.assertEqual(late.ignored, 1)
        self.assertFalse(late.changed)
        self.assertEqual(self.point()["settled"], "yes")
        self.assertNotIn(CAROL, self.point()["answers"])

    def test_more_agreement_can_be_asked_for(self) -> None:
        self.record(ALICE, MEANING, agreements=2)
        self.record(BOB, MEANING, agreements=2)
        self.assertNotIn("settled", self.point())
        self.record(CAROL, MEANING, agreements=2)
        self.assertEqual(self.point()["settled"], "yes")

    def test_two_files_of_one_point_do_not_agree_on_different_pictures(self) -> None:
        a = answer("zz-9201", "image:One.jpg", "image", "yes")
        b = answer("zz-9201", "image:Two.jpg", "image", "yes")
        self.record(ALICE, a)
        self.record(BOB, b)
        self.assertNotIn("settled", self.point("zz-9201|image:One.jpg"))
        self.assertNotIn("settled", self.point("zz-9201|image:Two.jpg"))
        self.record(BOB, a)
        self.assertEqual(self.point("zz-9201|image:One.jpg")["settled"], "yes")

    def test_a_card_the_language_does_not_have_is_counted_not_kept(self) -> None:
        result = self.record(ALICE, answer("zz-0404", "meaning", "meaning", "yes"))
        self.assertEqual(result.missing, 1)
        self.assertFalse(result.changed)
        self.assertFalse((self.git.main / "review-answers").exists())

    def test_the_record_keeps_codes_and_answers_and_never_the_reviewers_words(self) -> None:
        self.record(ALICE, answer("zz-9201", "meaning", "meaning", "no", "wrong", SECRET))
        text = (self.git.main / "review-answers" / "zz.json").read_text(encoding="utf-8")
        self.assertNotIn(SECRET, text)
        self.assertIn(ALICE, text)


class Flagged(Base):
    def setUp(self) -> None:
        super().setUp()
        deck = self.git.main / "decks" / "zz" / "zz-en-extra.yaml"
        text = deck.read_text(encoding="utf-8")
        deck.write_text(text.replace('    native: "water"\n',
                                     '    native: "water"\n' + AUDIO, 1),
                        encoding="utf-8")
        audio = self.git.main / "decks" / "zz" / "audio"
        audio.mkdir()
        (audio / "zz-9202.opus").write_bytes(b"OggS")

    def flag(self, who: str) -> qa.Batch:
        return qa.read_questions([questions_file(
            [answer("zz-9202", "sound", "sound", "flag", "noisy", SECRET)],
            rater=who)], who)

    def test_a_recording_two_reviewers_flag_is_taken_off_the_card(self) -> None:
        self.assertEqual(self.bot.questions("m1", ALICE, self.flag(ALICE)), "merged")
        self.assertIn("audio:", self.main_text())
        before = self.git.made
        self.assertEqual(self.bot.questions("m2", BOB, self.flag(BOB)), "merged")
        # The file went with the line that named it: the validator refuses a
        # recording no card plays.
        self.assertTrue((self.git.main / "decks/zz/audio/zz-9202.opus").exists())
        self.assertFalse((self.tmp / f"work{before + 1}" / "decks/zz/audio/zz-9202.opus").exists())
        text = self.main_text()
        self.assertNotIn("audio", text)
        self.assertIn('native: "water"', text)
        self.assertIn('target: "నీళ్ళు"', text)
        pr_ = self.github.prs[-1]
        self.assertIn("Recording taken off", pr_["body"])
        self.assertIn("daily questions", [l["name"] for l in pr_["labels"]])
        for text in (pr_["body"], pr_["title"], "\n".join(self.logged)):
            self.assertNotIn(SECRET, text)

    def test_one_flag_changes_no_deck(self) -> None:
        self.bot.questions("m1", ALICE, self.flag(ALICE))
        self.assertIn("audio:", self.main_text())
        self.assertIn(ALICE, (self.git.main / "review-answers/zz.json")
                      .read_text(encoding="utf-8"))

    def test_a_confirmed_recording_stays(self) -> None:
        yes = lambda who: qa.read_questions([questions_file(  # noqa: E731
            [answer("zz-9202", "sound", "sound", "yes")], rater=who)], who)
        self.bot.questions("m1", ALICE, yes(ALICE))
        self.bot.questions("m2", BOB, yes(BOB))
        self.assertIn("audio:", self.main_text())
        self.assertEqual(json.loads((self.git.main / "review-answers/zz.json")
                                    .read_text(encoding="utf-8"))
                         ["points"]["zz-9202|sound"]["settled"], "yes")

    def test_a_recording_written_over_several_lines_is_left_for_the_owner(self) -> None:
        deck = self.git.main / "decks" / "zz" / "zz-en-extra.yaml"
        deck.write_text(deck.read_text(encoding="utf-8").replace(
            AUDIO, "").replace(
            '    native: "water"\n',
            '    native: "water"\n    audio: "decks/zz/audio/zz-9202.opus"\n'
            '    audio_credit:\n      source: "https://commons.wikimedia.org/wiki/File:Zz.ogg"\n'
            '      license: "CC-BY-SA-4.0"\n      credit: "A. Speaker"\n', 1),
            encoding="utf-8")
        self.bot.questions("m1", ALICE, self.flag(ALICE))
        self.bot.questions("m2", BOB, self.flag(BOB))
        self.assertIn("audio:", self.main_text())
        self.assertIn("could not be taken off", self.github.prs[-1]["body"])


class Pull(Base):
    def test_an_answers_mail_is_one_pr_merged_once_its_checks_pass(self) -> None:
        batch = qa.read_questions([questions_file([MEANING])], ALICE)
        self.assertEqual(self.bot.questions("k1", ALICE, batch), "merged")
        pr_ = self.github.prs[0]
        self.assertEqual(pr_["head"]["ref"], "review-bot/questions/k1")
        self.assertEqual(self.bot.questions("k1", ALICE, batch), "merged")
        self.assertEqual(len(self.github.prs), 1)

    def test_a_pr_whose_checks_are_pending_is_left_open(self) -> None:
        self.github.check = "pending"
        batch = qa.read_questions([questions_file([MEANING])], ALICE)
        self.assertEqual(self.bot.questions("k1", ALICE, batch), "pending")
        self.assertFalse((self.git.main / "review-answers").exists())

    def test_nothing_new_opens_no_pr(self) -> None:
        batch = qa.read_questions([questions_file(
            [answer("zz-0404", "meaning", "meaning", "yes")])], ALICE)
        self.assertEqual(self.bot.questions("k1", ALICE, batch), "nothing")
        self.assertEqual(self.github.prs, [])


class Mails(Base):
    def run_tool(self, imap: ProposingImap) -> tuple[list[dict], str]:
        filed: list[dict] = []
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            mail_to_issues.run(ENV, imap, filed.append, bot=self.bot)
        return filed, out.getvalue()

    def test_a_questions_mail_is_filed_without_text_and_counted(self) -> None:
        files = [questions_file([
            MEANING, answer("zz-9202", "meaning", "meaning", "no", "wrong", SECRET)])]
        imap = ProposingImap([questions_mail(files)])
        filed, log = self.run_tool(imap)
        issue = filed[0]
        self.assertEqual(issue["title"], f"Questions: {ALICE} (zz)")
        self.assertIn("questions", issue["labels"])
        self.assertIn("lang: zz", issue["labels"])
        self.assertIn("- Answers: 2", issue["body"])
        self.assertIn("- No or flagged: 1", issue["body"])
        self.assertEqual(imap.answered, [b"1"])
        self.assertIn("Question mails counted: 1 merged.", log)
        for text in (str(issue), log, str(self.github.prs)):
            self.assertNotIn(SECRET, text)
            self.assertNotIn("anvi@example.com", text)
        # The issue says who and how many, never which card.
        self.assertNotIn("zz-92", str(issue))
        self.assertEqual(self.github.prs[0]["head"]["ref"],
                         "review-bot/questions/"
                         + mail_to_issues.mail_key(questions_mail([])))
        self.assertIn("fluenough-filed -label:fluenough-answered",
                      imap.searches[-1][1])

    def test_it_is_not_taken_for_a_review_nor_the_other_way(self) -> None:
        imap = ProposingImap([questions_mail([questions_file([MEANING])])])
        filed, _ = self.run_tool(imap)
        # Not proposed as a review: only the answers' label is put on.
        self.assertEqual(imap.proposed, [])
        self.assertEqual(imap.answered, [b"1"])
        self.assertEqual(len(filed), 1)

    def test_another_sender_is_left_to_the_owner(self) -> None:
        record = email.message.EmailMessage()
        record["Subject"] = ALICE
        record.set_content("first@example.com")
        imap = ProposingImap(
            [questions_mail([questions_file([MEANING])], sender="other@example.com")],
            raters=[record.as_bytes()])
        filed, log = self.run_tool(imap)
        self.assertIn(mail_to_issues.SENDER_DIFFERS, filed[0]["labels"])
        self.assertEqual(self.github.prs, [])
        self.assertIn("1 left to the owner", log)

    def test_changed_subject_is_marked_and_the_files_decide(self) -> None:
        message = questions_mail([questions_file([MEANING])])
        del message["Subject"]
        message["Subject"] = "hello"
        issue = mail_to_issues.questions_issue_from(message)
        self.assertIn(mail_to_issues.SUBJECT_CHANGED, issue["labels"])
        self.assertEqual(issue["title"], f"Questions: {ALICE} (zz)")

    def test_files_with_two_codes_are_for_the_owner(self) -> None:
        message = questions_mail([questions_file([MEANING]),
                                  questions_file([MEANING], rater=BOB)])
        issue = mail_to_issues.questions_issue_from(message)
        self.assertIn(mail_to_issues.CHECK_FILES, issue["labels"])


if __name__ == "__main__":
    unittest.main()
