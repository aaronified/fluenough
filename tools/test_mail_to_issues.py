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
    def test_a_report_mail_becomes_a_labelled_issue(self) -> None:
        issue = mail_to_issues.issue_from(mail(
            "[Fluenough] Bug: The card shows twice",
            "After Check\n\n---\nApp: fluenough 0.2.0\nScreen: /drill"))
        self.assertEqual(issue["title"], "Bug: The card shows twice")
        self.assertEqual(issue["labels"], ["bug", "from-app"])
        self.assertIn("After Check", issue["body"])
        self.assertIn("Screen: /drill", issue["body"])
        self.assertNotIn("screenshot", issue["body"].lower())

    def test_each_kind_has_its_label(self) -> None:
        for kind, label in (("Bug", "bug"), ("Feedback", "feedback")):
            with self.subTest(kind=kind):
                issue = mail_to_issues.issue_from(
                    mail(f"[Fluenough] {kind}: x", body(kind)))
                self.assertEqual(issue["title"], f"{kind}: x")
                self.assertEqual(issue["labels"], [label, "from-app"])

    def test_older_kinds_are_filed_as_feedback(self) -> None:
        # Feature requests and suggestions from versions before feedback
        # took them in.
        for kind in ("Feature", "Suggestion"):
            with self.subTest(kind=kind):
                issue = mail_to_issues.issue_from(mail(f"[Fluenough] {kind}: x"))
                self.assertEqual(issue["title"], f"{kind}: x")
                self.assertEqual(issue["labels"], ["feedback", "from-app"])

    def test_support_stays_private(self) -> None:
        self.assertIsNone(mail_to_issues.issue_from(
            mail("[Fluenough] Support: I can't hear anything",
                 body("Support", "My email is me@example.com"))))

    def test_support_stays_private_whichever_of_subject_or_body_says_so(
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

    def test_support_in_the_body_stays_private_with_crlf_line_ends(
            self) -> None:
        # Mail arrives with CRLF, and `$` stops before `\n`, not `\r`.
        for cte in ("7bit", "base64"):
            for subject in ("[Fluenough] Bug: edited", "[Fluenough] Hi"):
                with self.subTest(cte=cte, subject=subject):
                    self.assertIsNone(mail_to_issues.issue_from(
                        delivered(subject, body("Support"), cte)))

    def test_a_delivered_report_has_lf_line_ends(self) -> None:
        issue = mail_to_issues.issue_from(
            delivered("[Fluenough] Bug: x", body("Bug")))
        self.assertNotIn("\r", issue["body"])
        self.assertIn("---\nKind: Bug\nScreen: /deck", issue["body"])
        self.assertEqual(issue["labels"], ["bug", "from-app"])

    def test_support_near_misses_stay_private(self) -> None:
        # Retyped or autocorrected: any case, with or without the colon,
        # by the subject alone or the Kind line alone.
        for subject in ("[Fluenough] support: x", "[Fluenough] SUPPORT: x",
                        "[Fluenough] Support", "[Fluenough] Support - x",
                        "[Fluenough]Support:x"):
            with self.subTest(subject=subject):
                self.assertIsNone(mail_to_issues.issue_from(
                    delivered(subject, body("Bug"))))
        for kind in ("support", "SUPPORT", "Support."):
            with self.subTest(kind=kind):
                self.assertIsNone(mail_to_issues.issue_from(
                    delivered("[Fluenough] Bug: x", body(kind))))

    def test_a_kind_in_any_case_has_its_label(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] bug: x"))
        self.assertEqual(issue["labels"], ["bug", "from-app"])

    def test_support_only_as_the_kind_keeps_a_mail_private(self) -> None:
        # The word in a title or in the details does not.
        issue = mail_to_issues.issue_from(mail(
            "[Fluenough] Bug: Support for Urdu",
            body("Bug", "Kind of support missing")))
        self.assertEqual(issue["labels"], ["bug", "from-app"])

    def test_a_screenshot_stays_in_the_mail_and_the_issue_says_so(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: x",
                                               screenshot=True))
        self.assertIn(mail_to_issues.SCREENSHOT_NOTE, issue["body"])
        self.assertNotIn("PNG", issue["body"])
        self.assertNotIn(mail_to_issues.LOG_NOTE, issue["body"])

    def test_the_app_log_stays_in_the_mail_and_the_issue_says_so(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: x",
                                               body("Bug"), log=True))
        self.assertIn(mail_to_issues.LOG_NOTE, issue["body"])
        self.assertNotIn("Opened /deck", issue["body"])
        self.assertIn("It shows twice", issue["body"])
        self.assertNotIn(mail_to_issues.SCREENSHOT_NOTE, issue["body"])

    def test_the_sender_is_never_in_the_issue(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: x",
                                               sender="secret@example.com"))
        self.assertNotIn("secret@example.com", str(issue))
        self.assertNotIn("A Learner", str(issue))

    def test_mentions_notify_no_one(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: ask @aaronified",
                                               "cc @someone"))
        self.assertNotIn("@aaronified", issue["title"])
        self.assertIn("@​someone", issue["body"])

    def test_mail_not_from_the_app_is_left_alone(self) -> None:
        self.assertIsNone(mail_to_issues.issue_from(mail("Hello")))
        self.assertIsNone(mail_to_issues.issue_from(mail("Re: [Fluenough] Bug: x")))

    def test_an_unknown_kind_is_still_filed(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Something odd"))
        self.assertEqual(issue["title"], "Something odd")
        self.assertEqual(issue["labels"], ["from-app"])


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


class RaterCode(unittest.TestCase):
    def test_the_check_symbol_is_the_apps(self) -> None:
        # The same vectors as test/core/review/rater_code_test.dart.
        for body, check in (("7K3MQ9TD", "6"), ("00000000", "0"),
                            ("ZZZZZZZZ", "3"), ("ABCDEFGH", "2")):
            with self.subTest(body=body):
                self.assertEqual(mail_to_issues.check_symbol(body), check)

    def test_read_loosely_and_checked(self) -> None:
        for text in (CODE, "fl-7k3m-q9td-6", "7K3MQ9TD6", "FL 7K3M Q9TD 6"):
            with self.subTest(text=text):
                self.assertEqual(mail_to_issues.rater_code(text), CODE)
        for text in ("FL-7K3M-Q9TD-7", "FL-K73M-Q9TD-6", "FL-7K3M-Q9TD",
                     "", None, 42):
            with self.subTest(text=text):
                self.assertIsNone(mail_to_issues.rater_code(text))


class ReviewIssueFrom(unittest.TestCase):
    def test_a_review_mail_names_only_the_code_and_languages(self) -> None:
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

    def test_several_decks_in_one_mail_are_one_issue(self) -> None:
        issue = mail_to_issues.review_issue_from(review_mail(
            f"[Fluenough review] {CODE} (te, bn)",
            [review_file(), review_file(language="bn", deck="bn-family"),
             review_file(deck="te-work")]))
        self.assertEqual(issue["title"], f"Review: {CODE} (te, bn)")
        self.assertEqual(issue["labels"],
                         ["review", "from-app", "lang: te", "lang: bn"])
        self.assertIn("Languages: te, bn", issue["body"])

    def test_a_changed_or_missing_subject_goes_by_the_files(self) -> None:
        for subject in (None, "Here you go", "[Fluenough review]",
                        f"[Fluenough review] {OTHER} (te)",
                        f"[Fluenough review] {CODE} (bn)",
                        f"[Fluenough review] {CODE}"):
            with self.subTest(subject=subject):
                issue = mail_to_issues.review_issue_from(
                    review_mail(subject, [review_file()]))
                self.assertEqual(issue["title"], f"Review: {CODE} (te)")
                self.assertIn("subject changed", issue["labels"])
                self.assertNotIn("check the files", issue["labels"])
                self.assertIn("Subject changed", issue["body"])

    def test_files_with_different_codes_or_none_are_checked(self) -> None:
        for files in ([review_file(), review_file(OTHER, deck="te-work")],
                      [review_file(None)],
                      [review_file("FL-7K3M-Q9TD-7")],
                      [review_file(), review_file(None, deck="te-work")]):
            with self.subTest(files=[f.get("rater_code") for f in files]):
                issue = mail_to_issues.review_issue_from(review_mail(
                    f"[Fluenough review] {CODE} (te)", files))
                self.assertIn("check the files", issue["labels"])
                self.assertIn("Check the files", issue["body"])

    def test_different_codes_are_both_named(self) -> None:
        issue = mail_to_issues.review_issue_from(review_mail(
            f"[Fluenough review] {CODE} (te)",
            [review_file(), review_file(OTHER, deck="te-work")]))
        self.assertIn(f"Rater codes: {CODE}, {OTHER}", issue["body"])
        self.assertNotIn("subject changed", issue["labels"])

    def test_a_review_subject_without_files_is_checked(self) -> None:
        issue = mail_to_issues.review_issue_from(review_mail(
            f"[Fluenough review] {CODE} (te)", []))
        self.assertEqual(issue["title"], f"Review: {CODE} (te)")
        self.assertEqual(issue["labels"],
                         ["review", "from-app", "lang: te", "check the files"])

    def test_nothing_from_a_file_but_a_valid_code_and_language(self) -> None:
        bad = review_file("@everyone <script>", language="te) @someone")
        issue = mail_to_issues.review_issue_from(
            review_mail("[Fluenough review]", [bad]))
        self.assertNotIn("@", str(issue))
        self.assertNotIn("script", str(issue))
        self.assertEqual(issue["title"], "Review: no code")

    def test_other_mail_is_not_a_review(self) -> None:
        self.assertIsNone(mail_to_issues.review_issue_from(
            mail("[Fluenough] Bug: x", body("Bug"), log=True)))
        self.assertIsNone(mail_to_issues.review_issue_from(mail("Hello")))
        # JSON that is not a review file.
        message = review_mail("Data", [])
        message.add_attachment(b'{"a": 1}', maintype="application",
                               subtype="json", filename="data.json")
        self.assertIsNone(mail_to_issues.review_issue_from(message))


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
    def test_reports_are_filed_once_and_other_mail_is_untouched(self) -> None:
        imap = FakeImap([mail("[Fluenough] Bug: one"), mail("Newsletter"),
                         mail("[Fluenough] Feature: two")])
        filed: list[dict] = []
        self.assertEqual(mail_to_issues.run(ENV, imap, filed.append), 2)
        self.assertEqual([i["title"] for i in filed], ["Bug: one", "Feature: two"])
        self.assertEqual(imap.labelled, [b"1", b"3"])
        self.assertIn("-label:fluenough-filed", imap.searched[-1])
        self.assertTrue(imap.logged_out)

    def test_crlf_support_mail_with_an_edited_subject_is_left_unfiled(
            self) -> None:
        # As bytes, so that the CRLF reaches the tool as it would.
        imap = FakeImap([delivered_bytes("[Fluenough] Bug: edited",
                                         body("Support"))])
        filed: list[dict] = []
        self.assertEqual(mail_to_issues.run(ENV, imap, filed.append), 0)
        self.assertEqual(filed, [])
        self.assertEqual(imap.labelled, [])

    def test_support_mail_is_left_unfiled_and_unlabelled(self) -> None:
        imap = FakeImap([mail("[Fluenough] Support: help", body("Support")),
                         mail("[Fluenough] Bug: one", body("Bug"))])
        filed: list[dict] = []
        self.assertEqual(mail_to_issues.run(ENV, imap, filed.append), 1)
        self.assertEqual([i["title"] for i in filed], ["Bug: one"])
        self.assertEqual(imap.labelled, [b"2"])

    def test_review_mails_are_filed_with_reports(self) -> None:
        imap = FakeImap([mail("[Fluenough] Bug: one"),
                         review_mail(f"[Fluenough review] {CODE} (te)",
                                     [review_file()]),
                         review_mail(None, [review_file()])])
        filed: list[dict] = []
        self.assertEqual(mail_to_issues.run(ENV, imap, filed.append), 3)
        self.assertEqual([i["title"] for i in filed],
                         ["Bug: one", f"Review: {CODE} (te)",
                          f"Review: {CODE} (te)"])
        self.assertEqual(imap.labelled, [b"1", b"2", b"3"])
        # Found by its files too, when the subject was deleted.
        self.assertIn("filename:fluenough-review", imap.searched[-1])

    def test_without_the_inbox_it_does_nothing(self) -> None:
        def never(_host: str):
            raise AssertionError("connected without an inbox")
        self.assertEqual(mail_to_issues.run({}, never), 0)

    def test_a_mail_is_labelled_only_after_its_issue_is_open(self) -> None:
        imap = FakeImap([mail("[Fluenough] Bug: one")])

        def fail(_issue: dict) -> None:
            raise RuntimeError("GitHub is down")
        with self.assertRaises(RuntimeError):
            mail_to_issues.run(ENV, imap, fail)
        self.assertEqual(imap.labelled, [])
        self.assertTrue(imap.logged_out)


def review_from(sender: str, code: str = CODE) -> email.message.EmailMessage:
    return review_mail(f"[Fluenough review] {code} (te)",
                       [review_file(code)], sender=sender)


class NormalAddress(unittest.TestCase):
    def test_gmail_dots_and_plus_are_ignored(self) -> None:
        for address in ("ra.vi+fluenough@gmail.com", "R.A.V.I@Gmail.com",
                        "ravi+x+y@gmail.com", " ravi@GMAIL.COM "):
            with self.subTest(address=address):
                self.assertEqual(mail_to_issues.normal_address(address),
                                 "ravi@gmail.com")
        self.assertEqual(
            mail_to_issues.normal_address("Ra.Vi+x@googlemail.com"),
            "ravi@googlemail.com")

    def test_other_domains_keep_dots_and_plus_and_lose_case(self) -> None:
        self.assertEqual(mail_to_issues.normal_address("Ra.Vi+x@Example.COM"),
                         "ra.vi+x@example.com")
        self.assertNotEqual(mail_to_issues.normal_address("ravi@example.com"),
                            mail_to_issues.normal_address("ra.vi@example.com"))


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


class AddressIn(unittest.TestCase):
    def test_one_address_bare_or_named_with_a_full_stop_after_it(
            self) -> None:
        for text in ("ravi@gmail.com", " Ravi <ravi@gmail.com> ",
                     "<ravi@gmail.com>", "ravi@gmail.com.",
                     "Ravi Kumar <ravi@gmail.com>.", "ravi@gmail.com,"):
            with self.subTest(text=text):
                self.assertEqual(mail_to_issues.address_in(text),
                                 "ravi@gmail.com")

    def test_none_or_several_is_no_address(self) -> None:
        for text in ("", "<>", "deleted by the owner", "ravi at gmail",
                     "esha@gmail.com, farah@gmail.com",
                     "undisclosed-recipients:;"):
            with self.subTest(text=text):
                self.assertEqual(mail_to_issues.address_in(text), "")


def without_sender(from_: str | None) -> email.message.EmailMessage:
    """A review mail whose From is [from_], or which has none."""
    message = review_from("unused@example.com")
    del message["From"]
    if from_ is not None:
        message["From"] = from_
    return message


class SenderCheck(unittest.TestCase):
    def run_tool(self, imap: FakeImap, raises: type | None = None
                 ) -> tuple[list[dict], str]:
        """Runs the tool on [imap], and checks that no address it holds is
        in any issue or in the log, every time. When [raises] is given,
        the run must raise it, and its traceback is in the log, as it
        would be in the job's."""
        filed: list[dict] = []
        out = io.StringIO()
        with contextlib.redirect_stdout(out), \
                contextlib.redirect_stderr(out):
            if raises is None:
                mail_to_issues.run(ENV, imap, filed.append)
            else:
                with self.assertRaises(raises) as caught:
                    mail_to_issues.run(ENV, imap, filed.append)
                out.write("".join(
                    traceback.format_exception(caught.exception)))
        log = out.getvalue()
        self.assertNoAddress(filed, log, *addresses_in(imap))
        return filed, log

    def assertNoAddress(self, filed: list[dict], log: str,
                        *addresses: str) -> None:
        """Neither [addresses] nor their local parts, as written or as
        compared, are in [filed] or [log]. A local part is only worth
        looking for when it is distinctive, so a short one is refused."""
        for address in addresses:
            forms = {address, mail_to_issues.normal_address(address)}
            for form in set(forms):
                local = form.split("@")[0]
                self.assertGreaterEqual(
                    len(local), 4,
                    f"{address!r}: give the test a distinctive local part")
                forms.add(local)
            for text in (str(filed), log):
                for form in forms:
                    self.assertNotIn(form.lower(), text.lower())

    def test_the_first_mail_ties_the_code_to_its_sender(self) -> None:
        imap = FakeImap([review_from("anvi@example.com")])
        filed, log = self.run_tool(imap)
        self.assertEqual(imap.created, ["fluenough/raters"])
        self.assertEqual(len(imap.appended), 1)
        flags, written = imap.appended[0]
        self.assertIn("Seen", flags)
        tied = email.message_from_bytes(written, policy=email.policy.default)
        self.assertEqual(tied["Subject"], CODE)
        self.assertEqual(tied.get_content().strip(), "anvi@example.com")
        self.assertEqual(filed[0]["labels"], ["review", "from-app", "lang: te"])
        self.assertIn("1 tied", log)

    def test_the_same_sender_passes_and_writes_nothing(self) -> None:
        imap = FakeImap([review_from("bodhi@example.com")],
                        [record(CODE, "bodhi@example.com")])
        filed, log = self.run_tool(imap)
        self.assertEqual(imap.appended, [])
        self.assertEqual(filed[0]["labels"], ["review", "from-app", "lang: te"])
        self.assertIn("1 matched", log)

    def test_a_second_mail_in_the_same_run_meets_the_new_record(self) -> None:
        imap = FakeImap([review_from("chitra@example.com"),
                         review_from("chitra@example.com"),
                         review_from("devika@example.com")])
        filed, log = self.run_tool(imap)
        self.assertEqual(len(imap.appended), 1)
        self.assertEqual([SENDER_DIFFERS in i["labels"] for i in filed],
                         [False, False, True])
        self.assertIn("1 tied, 1 matched, 1 did not match, 0 not checked", log)

    def test_another_sender_is_flagged_and_not_named(self) -> None:
        imap = FakeImap([review_from("intruder@example.com")],
                        [record(CODE, "owner.of.code@example.com")])
        filed, log = self.run_tool(imap)
        self.assertEqual(imap.appended, [])
        issue = filed[0]
        self.assertEqual(issue["title"], f"Review: {CODE} (te)")
        self.assertEqual(issue["labels"],
                         ["review", "from-app", "lang: te", SENDER_DIFFERS])
        self.assertIn("Sender does not match", issue["body"])
        self.assertIn("1 did not match", log)

    def test_each_code_has_its_own_record(self) -> None:
        imap = FakeImap([review_from("esha@example.com", OTHER)],
                        [record(CODE, "farah@example.com")])
        filed, _ = self.run_tool(imap)
        self.assertEqual(len(imap.appended), 1)
        self.assertNotIn(SENDER_DIFFERS, filed[0]["labels"])

    def test_gmail_dot_and_plus_forms_match(self) -> None:
        for sender in ("ra.vi@gmail.com", "ravi+reviews@gmail.com",
                       "R.a.Vi+x@GMAIL.com"):
            with self.subTest(sender=sender):
                imap = FakeImap([review_from(sender)],
                                [record(CODE, "ravi@gmail.com")])
                filed, log = self.run_tool(imap)
                self.assertNotIn(SENDER_DIFFERS, filed[0]["labels"])
                self.assertIn("1 matched", log)

    def test_case_is_ignored(self) -> None:
        imap = FakeImap([review_from("Gauri@Example.COM")],
                        [record(CODE, "gauri@example.com")])
        filed, _ = self.run_tool(imap)
        self.assertEqual(filed[0]["labels"], ["review", "from-app", "lang: te"])

    def test_dots_count_outside_gmail(self) -> None:
        imap = FakeImap([review_from("har.sha@example.com")],
                        [record(CODE, "harsha@example.com")])
        filed, _ = self.run_tool(imap)
        self.assertIn(SENDER_DIFFERS, filed[0]["labels"])

    def test_a_record_the_owner_deleted_is_tied_again(self) -> None:
        # The owner deleted the record: the next mail ties the code anew.
        imap = FakeImap([review_from("jaya@example.com")], [])
        filed, _ = self.run_tool(imap)
        self.assertEqual(len(imap.appended), 1)
        self.assertNotIn(SENDER_DIFFERS, filed[0]["labels"])

    def test_a_record_the_owner_added_is_respected(self) -> None:
        # The owner allowed a second address for the code.
        imap = FakeImap([review_from("lakshmi@example.com")],
                        [record(CODE, "kavya@example.com"),
                         record(CODE, "lakshmi@example.com")])
        filed, _ = self.run_tool(imap)
        self.assertEqual(imap.appended, [])
        self.assertNotIn(SENDER_DIFFERS, filed[0]["labels"])

    def test_a_record_without_an_address_is_passed_over(self) -> None:
        imap = FakeImap([review_from("mohan@example.com")],
                        [record(CODE, "deleted by the owner"),
                         record("not a code", "nandini@example.com")])
        filed, log = self.run_tool(imap)
        self.assertEqual(len(imap.appended), 1)
        self.assertIn("Read 0 rater record(s), 2 passed over.", log)

    def test_an_append_failure_files_the_mail_unchecked(self) -> None:
        for kwargs in ({"append_fails": True}, {"append_raises": True}):
            with self.subTest(**kwargs):
                imap = FakeImap([review_from("omkar@example.com")], **kwargs)
                filed, log = self.run_tool(imap)
                self.assertEqual(len(filed), 1)
                self.assertEqual(filed[0]["labels"],
                                 ["review", "from-app", "lang: te",
                                  SENDER_UNCHECKED])
                self.assertIn("Sender not checked", filed[0]["body"])
                self.assertEqual(imap.labelled, [b"1"])
                self.assertIn("1 not checked", log)

    def test_without_the_label_mails_are_filed_unchecked(self) -> None:
        imap = FakeImap([review_from("priya@example.com"),
                         mail("[Fluenough] Bug: one")], label=False)
        filed, log = self.run_tool(imap)
        self.assertEqual(len(filed), 2)
        self.assertIn(SENDER_UNCHECKED, filed[0]["labels"])
        self.assertEqual(filed[1]["labels"], ["bug", "from-app"])
        self.assertEqual(imap.appended, [])
        self.assertEqual(imap.labelled, [b"1", b"2"])
        self.assertIn("::warning::", log)

    def test_a_mail_without_a_single_sender_is_filed_unchecked(
            self) -> None:
        # No From, an empty one, or several: nothing to tie or compare.
        for from_ in (None, "<>", "", "undisclosed-recipients:;",
                      "esha@gmail.com, farah@gmail.com"):
            with self.subTest(from_=from_):
                imap = FakeImap([without_sender(from_)],
                                [record(CODE, "esha@gmail.com")])
                filed, log = self.run_tool(imap)
                self.assertEqual(imap.appended, [])
                self.assertEqual(filed[0]["labels"],
                                 ["review", "from-app", "lang: te",
                                  SENDER_UNCHECKED])
                self.assertIn("Sender not checked", filed[0]["body"])
                self.assertEqual(imap.labelled, [b"1"])
                self.assertIn("0 tied, 0 matched, 0 did not match, "
                              "1 not checked", log)

    def test_an_owner_record_is_read_as_an_address(self) -> None:
        # Written by hand: with a name, in angle brackets, or as a
        # sentence ends.
        for written in ("Ravi <ravi@gmail.com>", "<ra.vi@gmail.com>",
                        "ravi@gmail.com.", "Ravi Kumar <ravi@gmail.com>.",
                        "Ravi <ravi+reviews@gmail.com>\nAllowed by me"):
            with self.subTest(written=written):
                imap = FakeImap([review_from("ravi@gmail.com")],
                                [record(CODE, written)])
                filed, log = self.run_tool(imap)
                self.assertEqual(imap.appended, [])
                self.assertNotIn(SENDER_DIFFERS, filed[0]["labels"])
                self.assertIn("Read 1 rater record(s), 0 passed over.", log)
                self.assertIn("1 matched", log)

    def test_an_owner_record_with_several_addresses_is_passed_over(
            self) -> None:
        # Not guessed at: counted, so that the log shows it was not read.
        imap = FakeImap([review_from("ravi@gmail.com")],
                        [record(CODE, "ravi@gmail.com, esha@gmail.com"),
                         record(CODE, "farah@gmail.com")])
        filed, log = self.run_tool(imap)
        self.assertIn("Read 1 rater record(s), 1 passed over.", log)
        self.assertIn(SENDER_DIFFERS, filed[0]["labels"])

    def test_a_dropped_connection_while_tying_files_nothing_twice(
            self) -> None:
        # The connection drops while the record is written: the review is
        # neither filed nor labelled, so the next run files it once. Had it
        # been filed unchecked, it could not have been labelled.
        bug, review = mail("[Fluenough] Bug: one"), review_from(
            "qadir@example.com")
        imap = FakeImap([bug, review], drops_on_append=True)
        filed, log = self.run_tool(imap, imaplib.IMAP4.abort)
        self.assertEqual([i["title"] for i in filed], ["Bug: one"])
        self.assertEqual(imap.labelled, [b"1"])
        self.assertEqual(imap.raters, [])
        self.assertTrue(imap.logged_out)
        # The next run: Gmail's search leaves out the labelled report.
        again = FakeImap([review])
        refiled, log = self.run_tool(again)
        self.assertEqual([i["title"] for i in refiled],
                         [f"Review: {CODE} (te)"])
        self.assertNotIn(SENDER_UNCHECKED, refiled[0]["labels"])
        self.assertEqual(again.labelled, [b"1"])
        self.assertIn("1 tied", log)

    def test_a_dropped_connection_reading_the_records_files_nothing(
            self) -> None:
        imap = FakeImap([mail("[Fluenough] Bug: one"),
                         review_from("rekha@example.com")],
                        [record(CODE, "rekha@example.com")],
                        drops_on_label=True)
        filed, _ = self.run_tool(imap, imaplib.IMAP4.abort)
        self.assertEqual(filed, [])
        self.assertEqual(imap.labelled, [])

    def test_reports_and_unsure_files_are_not_checked(self) -> None:
        # A bug report has no code; files with two codes are for the owner.
        imap = FakeImap([mail("[Fluenough] Bug: one"),
                         review_mail(f"[Fluenough review] {CODE} (te)",
                                     [review_file(),
                                      review_file(OTHER, deck="te-work")])])
        filed, log = self.run_tool(imap)
        self.assertEqual(imap.appended, [])
        self.assertNotIn(SENDER_UNCHECKED, filed[1]["labels"])
        self.assertIn("0 tied, 0 matched, 0 did not match, 0 not checked",
                      log)


if __name__ == "__main__":
    unittest.main()
