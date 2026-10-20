#!/usr/bin/env python3
"""Report mails from the app become issues (#160): which mails, what the
issue says, and what it never says. Stdlib `unittest`, like the tool."""

from __future__ import annotations

import base64
import contextlib
import email
import json
import email.message
import email.policy
import imaplib
import io
import re
import traceback
import unittest

import mail_to_issues

SENDER_DIFFERS = "sender does not match"
SENDER_UNCHECKED = "sender not checked"


def mail(subject: str, text: str = "It shows twice", *, sender: str =
         "learner@example.com", screenshot: bool = False,
         log: bool = False) -> email.message.EmailMessage:
    message = email.message.EmailMessage()
    message["Subject"] = subject
    message["From"] = f"A Learner <{sender}>"
    message["To"] = "fluenough@example.com"
    message.set_content(text)
    if screenshot:
        message.add_attachment(b"\x89PNG\r\n\x1a\n", maintype="image",
                               subtype="png", filename="screen.png")
    if log:
        message.add_attachment("2026-10-09T09:00:00.000Z EVENT Opened /deck",
                               filename="fluenough-app-log.txt")
    return message


# A body as the app writes it (lib/core/feedback/report.dart).
def body(kind: str, details: str = "It shows twice") -> str:
    return f"{details}\n\n---\nKind: {kind}\nScreen: /deck"


def delivered_bytes(subject: str, text: str, cte: str = "7bit") -> bytes:
    """A mail as IMAP gives it: every line ending in CRLF, the body's too,
    in 7bit or base64."""
    crlf = text.replace("\n", "\r\n").encode("utf-8")
    payload = base64.encodebytes(crlf) if cte == "base64" else crlf + b"\r\n"
    raw = (f"Subject: {subject}\r\n"
           "From: A Learner <learner@example.com>\r\n"
           "MIME-Version: 1.0\r\n"
           'Content-Type: text/plain; charset="utf-8"\r\n'
           f"Content-Transfer-Encoding: {cte}\r\n\r\n").encode() + payload
    return raw


def delivered(subject: str, text: str,
              cte: str = "7bit") -> email.message.EmailMessage:
    """[delivered_bytes], read as the tool reads it."""
    return email.message_from_bytes(delivered_bytes(subject, text, cte),
                                    policy=email.policy.default)


class IssueFrom(unittest.TestCase):
    def _a_report_mail_becomes_a_labelled_issue(self) -> None:
        issue = mail_to_issues.issue_from(mail(
            "[Fluenough] Bug: The card shows twice",
            "After Check\n\n---\nApp: fluenough 0.2.0\nScreen: /drill"))
        self.assertEqual(issue["title"], "Bug: The card shows twice")
        self.assertEqual(issue["labels"], ["bug", "from-app"])
        self.assertIn("After Check", issue["body"])
        self.assertIn("Screen: /drill", issue["body"])
        self.assertNotIn("screenshot", issue["body"].lower())


    def _support_stays_private(self) -> None:
        self.assertIsNone(mail_to_issues.issue_from(
            mail("[Fluenough] Support: I can't hear anything",
                 body("Support", "My email is me@example.com"))))

    def _support_stays_private_whichever_of_subject_or_body_says_so(
            self) -> None:
        # The reporter edits the mail before sending it: either may change.
        for subject, text in (
            ("[Fluenough] Support: x", "No kind line left"),
            ("[Fluenough] Support: x", body("Bug")),
            ("[Fluenough] Bug: x", body("Support")),
            ("[Fluenough] Something else", body("Support")),
        ):
            with self.subTest(subject=subject, text=text):
                self.assertIsNone(
                    mail_to_issues.issue_from(mail(subject, text)))


    def _the_sender_is_never_in_the_issue(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: x",
                                               sender="secret@example.com"))
        self.assertNotIn("secret@example.com", str(issue))
        self.assertNotIn("A Learner", str(issue))


    def test_a_report_becomes_a_labelled_issue_and_support_stays_private(self) -> None:
        cases = (
            self._a_report_mail_becomes_a_labelled_issue,
            self._support_stays_private,
            self._support_stays_private_whichever_of_subject_or_body_says_so,
            self._the_sender_is_never_in_the_issue,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


CODE = "FL-7K3M-Q9TD-6"
OTHER = "FL-0000-0000-0"


def review_file(code: str | None = CODE, language: str = "te",
                deck: str = "te-family") -> dict:
    """A review file as the app writes it (lib/core/review/review_file.dart)."""
    data = {"format": "fluenough-review", "version": 1, "language": language,
            "deck": deck, "app_version": "0.3.4",
            "made": "2026-10-09T09:41:00.000Z", "signed_off": False,
            "cards": [{"card": "te-0384", "at": "2026-10-09T09:40:00.000Z",
                       "suggestion": {"part": "notes", "now": "Formally",
                                      "text": "SECRET SUGGESTION",
                                      "why": "As common"}}]}
    if code is not None:
        data["rater_code"] = code
    return data


def review_mail(subject: str | None, files: list[dict], *,
                sender: str = "reviewer@example.com",
                text: str = "12 reviews of te-family.") -> email.message.EmailMessage:
    message = email.message.EmailMessage()
    if subject is not None:
        message["Subject"] = subject
    message["From"] = f"A Reviewer <{sender}>"
    message["To"] = "fluenough@example.com"
    message.set_content(text)
    for data in files:
        message.add_attachment(json.dumps(data).encode("utf-8"),
                               maintype="application", subtype="json",
                               filename=f"fluenough-review-{data['deck']}.json")
    return message


class ReviewIssueFrom(unittest.TestCase):
    def _a_review_mail_names_only_the_code_and_languages(self) -> None:
        issue = mail_to_issues.review_issue_from(review_mail(
            f"[Fluenough review] {CODE} (te)", [review_file()]))
        self.assertEqual(issue["title"], f"Review: {CODE} (te)")
        self.assertEqual(issue["labels"], ["review", "from-app", "lang: te"])
        self.assertIn(f"Rater code: {CODE}", issue["body"])
        self.assertIn("Language: te", issue["body"])
        for private in ("SECRET SUGGESTION", "As common", "te-family",
                        "te-0384", "reviewer@example.com", "A Reviewer",
                        "12 reviews"):
            self.assertNotIn(private, str(issue))


    def test_a_review_mail_names_only_the_code_and_languages(self) -> None:
        cases = (
            self._a_review_mail_names_only_the_code_and_languages,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


def record(code: str, address: str) -> bytes:
    """A rater record as the owner might leave one in the label."""
    message = email.message.EmailMessage()
    message["Subject"] = code
    message.set_content(address)
    return message.as_bytes()


class FakeImap:
    """Gmail over IMAP, as far as the tool uses it: the inbox, and the
    label of rater records, which APPEND adds to.

    [append_fails] answers APPEND with NO, and [append_raises] with BAD,
    which imaplib raises; the connection stays good after either.
    [drops_on_append] and [drops_on_label] drop the connection there, as a
    reset socket does: every command after it raises, LOGOUT too, as
    imaplib's does."""

    def __init__(self,
                 mails: list[email.message.EmailMessage | bytes],
                 raters: list[bytes] | None = None, *,
                 label: bool = True, append_fails: bool = False,
                 append_raises: bool = False, drops_on_append: bool = False,
                 drops_on_label: bool = False) -> None:
        self.mails = {str(i + 1).encode(): m for i, m in enumerate(mails)}
        self.raters = list(raters or [])
        self.label = label
        self.append_fails = append_fails
        self.append_raises = append_raises
        self.drops_on_append = drops_on_append
        self.drops_on_label = drops_on_label
        self.dropped = False
        self.selected = ""
        self.created: list[str] = []
        self.appended: list[tuple] = []
        self.labelled: list[bytes] = []
        self.searched: tuple = ()
        self.logged_out = False

    def __call__(self, host: str) -> "FakeImap":
        assert host == "imap.gmail.com"
        return self

    def _alive(self) -> None:
        if self.dropped:
            raise imaplib.IMAP4.abort("socket error: EOF")

    def _drop(self) -> None:
        self.dropped = True
        raise imaplib.IMAP4.abort("socket error: [Errno 104] Connection "
                                  "reset by peer")

    def login(self, user: str, password: str) -> None:
        assert (user, password) == ("inbox@example.com", "app-password")

    def create(self, box: str):
        self._alive()
        assert box == "fluenough/raters"
        self.created.append(box)
        if not self.label:
            return "NO", [b"[CANNOT] cannot create"]
        return "NO", [b"[ALREADYEXISTS] Duplicate folder name"]

    def select(self, box: str, readonly: bool = False):
        self._alive()
        if box == "fluenough/raters":
            assert readonly, "the records are only read"
            if self.drops_on_label:
                self._drop()
            if not self.label:
                return "NO", [b"[NONEXISTENT] Unknown Mailbox"]
        else:
            assert box == "INBOX"
        self.selected = box
        return "OK", [b"1"]

    def _box(self) -> dict:
        if self.selected == "fluenough/raters":
            return {str(i + 1).encode(): r for i, r in enumerate(self.raters)}
        assert self.selected == "INBOX"
        return self.mails

    def search(self, charset, *criteria):
        self._alive()
        if self.selected == "INBOX":
            self.searched = criteria
        else:
            assert criteria == ("ALL",)
        return "OK", [b" ".join(self._box())]

    def fetch(self, number: bytes, what: str):
        self._alive()
        assert what == "(BODY.PEEK[])", "reading must not mark mail read"
        found = self._box()[number]
        raw = found if isinstance(found, bytes) else found.as_bytes()
        return "OK", [(b"1 (BODY[] {n}", raw), b")"]

    def append(self, box: str, flags, date_time, message: bytes):
        self._alive()
        assert box == "fluenough/raters"
        if self.drops_on_append:
            self._drop()
        if self.append_raises:
            raise imaplib.IMAP4.error("APPEND command error: BAD [b'no']")
        if self.append_fails:
            return "NO", [b"[OVERQUOTA] no"]
        self.appended.append((flags, message))
        self.raters.append(message)
        return "OK", [b"APPEND completed"]

    def store(self, number: bytes, command: str, label: str) -> None:
        self._alive()
        assert self.selected == "INBOX"
        assert (command, label) == ("+X-GM-LABELS", "fluenough-filed")
        self.labelled.append(number)

    def logout(self) -> None:
        self.logged_out = True
        self._alive()


ENV = {"FEEDBACK_GMAIL_ADDRESS": "inbox@example.com",
       "FEEDBACK_GMAIL_APP_PASSWORD": "app-password"}


class Run(unittest.TestCase):
    def _reports_are_filed_once_and_other_mail_is_untouched(self) -> None:
        imap = FakeImap([mail("[Fluenough] Bug: one"), mail("Newsletter"),
                         mail("[Fluenough] Feature: two")])
        filed: list[dict] = []
        self.assertEqual(mail_to_issues.run(ENV, imap, filed.append), 2)
        self.assertEqual([i["title"] for i in filed], ["Bug: one", "Feature: two"])
        self.assertEqual(imap.labelled, [b"1", b"3"])
        self.assertIn("-label:fluenough-filed", imap.searched[-1])
        self.assertTrue(imap.logged_out)


    def _support_mail_is_left_unfiled_and_unlabelled(self) -> None:
        imap = FakeImap([mail("[Fluenough] Support: help", body("Support")),
                         mail("[Fluenough] Bug: one", body("Bug"))])
        filed: list[dict] = []
        self.assertEqual(mail_to_issues.run(ENV, imap, filed.append), 1)
        self.assertEqual([i["title"] for i in filed], ["Bug: one"])
        self.assertEqual(imap.labelled, [b"2"])


    def test_reports_are_filed_once_and_support_mail_is_left_unfiled(self) -> None:
        cases = (
            self._reports_are_filed_once_and_other_mail_is_untouched,
            self._support_mail_is_left_unfiled_and_unlabelled,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


def review_from(sender: str, code: str = CODE) -> email.message.EmailMessage:
    return review_mail(f"[Fluenough review] {code} (te)",
                       [review_file(code)], sender=sender)


ADDRESS = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)*")


def addresses_in(imap: FakeImap) -> set[str]:
    """Every address [imap] holds: the senders of its mails, and the
    addresses in its records, the ones it was given and the ones written."""
    texts = []
    for found in imap.mails.values():
        raw = found if isinstance(found, bytes) else found.as_bytes()
        message = email.message_from_bytes(raw, policy=email.policy.default)
        texts.append(str(message.get("From", "")))
    for written in imap.raters:
        texts.append(email.message_from_bytes(
            written, policy=email.policy.default).get_content())
    return {found for text in texts for found in ADDRESS.findall(text)}


def without_sender(from_: str | None) -> email.message.EmailMessage:
    """A review mail whose From is [from_], or which has none."""
    message = review_from("unused@example.com")
    del message["From"]
    if from_ is not None:
        message["From"] = from_
    return message


if __name__ == "__main__":
    unittest.main()
