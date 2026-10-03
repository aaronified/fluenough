#!/usr/bin/env python3
"""Report mails from the app become issues (#160): which mails, what the
issue says, and what it never says. Stdlib `unittest`, like the tool."""

from __future__ import annotations

import email.message
import unittest

import mail_to_issues


def mail(subject: str, text: str = "It shows twice", *, sender: str =
         "learner@example.com", screenshot: bool = False) -> email.message.EmailMessage:
    message = email.message.EmailMessage()
    message["Subject"] = subject
    message["From"] = f"A Learner <{sender}>"
    message["To"] = "fluenough@example.com"
    message.set_content(text)
    if screenshot:
        message.add_attachment(b"\x89PNG\r\n\x1a\n", maintype="image",
                               subtype="png", filename="screen.png")
    return message


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
        for kind, label in (("Feature", "enhancement"),
                            ("Suggestion", "suggestion")):
            with self.subTest(kind=kind):
                issue = mail_to_issues.issue_from(mail(f"[Fluenough] {kind}: x"))
                self.assertEqual(issue["labels"], [label, "from-app"])

    def test_a_screenshot_stays_in_the_mail_and_the_issue_says_so(self) -> None:
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: x",
                                               screenshot=True))
        self.assertIn(mail_to_issues.SCREENSHOT_NOTE, issue["body"])
        self.assertNotIn("PNG", issue["body"])

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


class FakeImap:
    """Gmail over IMAP, as far as the tool uses it."""

    def __init__(self, mails: list[email.message.EmailMessage]) -> None:
        self.mails = {str(i + 1).encode(): m for i, m in enumerate(mails)}
        self.labelled: list[bytes] = []
        self.searched: tuple = ()
        self.logged_out = False

    def __call__(self, host: str) -> "FakeImap":
        assert host == "imap.gmail.com"
        return self

    def login(self, user: str, password: str) -> None:
        assert (user, password) == ("inbox@example.com", "app-password")

    def select(self, box: str) -> None:
        assert box == "INBOX"

    def search(self, charset, *criteria):
        self.searched = criteria
        return "OK", [b" ".join(self.mails)]

    def fetch(self, number: bytes, what: str):
        assert what == "(BODY.PEEK[])", "reading must not mark mail read"
        return "OK", [(b"1 (BODY[] {n}", self.mails[number].as_bytes()), b")"]

    def store(self, number: bytes, command: str, label: str) -> None:
        assert (command, label) == ("+X-GM-LABELS", "fluenough-filed")
        self.labelled.append(number)

    def logout(self) -> None:
        self.logged_out = True


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


if __name__ == "__main__":
    unittest.main()
