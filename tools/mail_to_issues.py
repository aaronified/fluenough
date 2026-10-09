#!/usr/bin/env python3
"""Turn report mails from the app into GitHub issues (#160, ADR-0021).

Run hourly by `.github/workflows/feedback-mail.yml`. Stdlib only.

It reads the Fluenough Gmail over IMAP with an app password and takes only
mails whose subject starts with `[Fluenough]`, as the app writes it. Any
other mail stays in the inbox, untouched. For each report mail not filed
before, it opens one issue and gives the mail the Gmail label
`fluenough-filed`, so that it is never filed twice. It reads mails without
marking them read.

Bug reports and feedback become issues. Support mails stay private: a mail
is skipped, and left in the inbox untouched, when its subject says
`[Fluenough] Support: …` or its body's `Kind:` line says `Support`, so
that a reporter who edits one of the two still is not made public. Both
are read loosely, failing closed: in any case, with or without the colon,
and with the CRLF line ends that mail arrives with. Mails from older
versions of the app, `Feature: …` and `Suggestion: …`, are filed as
feedback.

The issue is text only: the subject, as `Bug: …`, and the mail's text. A
screenshot or the app log stays in the mail, and the issue says one came.
The sender's address is never written to the issue, which is public.
`@mentions` are broken, so that an issue notifies no one.

Environment:
    FEEDBACK_GMAIL_ADDRESS, FEEDBACK_GMAIL_APP_PASSWORD  the inbox. Without
        them it does nothing and says so: the inbox is not set up yet.
    GITHUB_TOKEN, GITHUB_REPOSITORY  where issues go.
"""

from __future__ import annotations

import email
import email.header
import email.message
import email.policy
import imaplib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from typing import Callable

PREFIX = "[Fluenough]"
FILED = "fluenough-filed"
FROM_APP = "from-app"
# Each kind's label. Feature and Suggestion are older versions' kinds, which
# feedback has taken in.
KINDS = {
    "Bug": "bug",
    "Feedback": "feedback",
    "Feature": "feedback",
    "Suggestion": "feedback",
}
# Never filed: support mails stay private in the inbox. Matched as the start
# of a kind's first word, in any case, so that `support`, `SUPPORT` and
# `Support -` are private too.
PRIVATE = "support"
# Mail comes with CRLF line ends, which [text_of] makes LF; the `\r` here
# is for text that did not come through it.
KIND_LINE = re.compile(r"^Kind:[ \t]*(\S+)[ \t\r]*$", re.M | re.I)
MAX_BODY = 60_000
SCREENSHOT_NOTE = ("_A screenshot came with this report. It is in the "
                   "Fluenough inbox, not here._")
LOG_NOTE = ("_The app log came with this report. It is in the Fluenough "
            "inbox, not here._")
FOOTER = "<sub>Sent from the app by mail (#160).</sub>"


def quiet(text: str) -> str:
    """[text] with every @mention broken, so that it notifies no one."""
    return re.sub(r"@(?=[A-Za-z0-9])", "@​", text)


def subject_of(message: email.message.Message) -> str:
    raw = message.get("Subject", "")
    return str(email.header.make_header(email.header.decode_header(raw))).strip()


def text_of(message: email.message.Message) -> str:
    """The mail's first plain-text part that is not an attachment, with
    LF line ends: mail, over SMTP and IMAP, has CRLF."""
    for part in message.walk():
        if (part.get_content_type() == "text/plain"
                and part.get_content_disposition() != "attachment"):
            payload = part.get_payload(decode=True) or b""
            charset = part.get_content_charset() or "utf-8"
            text = payload.decode(charset, errors="replace")
            return text.replace("\r\n", "\n").replace("\r", "\n").strip()
    return ""


def has_image(message: email.message.Message) -> bool:
    return any(part.get_content_maintype() == "image" for part in message.walk())


def has_log(message: email.message.Message) -> bool:
    """Whether a text file came attached, as the app log does."""
    return any(
        part.get_content_maintype() == "text"
        and part.get_content_disposition() == "attachment"
        for part in message.walk()
    )


def is_support(word: str) -> bool:
    """Whether [word], a kind, says support, loosely: a near miss is
    private, not public."""
    return word.strip().casefold().startswith(PRIVATE)


def is_private(rest: str, text: str) -> bool:
    """Whether a mail is for support, by the first word of its subject
    after the prefix, [rest], or its [text]'s `Kind:` line, either of which
    the reporter may have edited."""
    first = rest.split(maxsplit=1)[0] if rest.split() else ""
    return is_support(first) or any(
        is_support(found) for found in KIND_LINE.findall(text))


def issue_from(message: email.message.Message) -> dict | None:
    """The issue a report mail becomes, or None for a mail not from the app
    or a support mail, which stays private. Nothing of the sender's goes
    into it."""
    subject = subject_of(message)
    if not subject.startswith(PREFIX):
        return None
    rest = subject[len(PREFIX):].strip()
    kind, colon, title = rest.partition(":")
    text = text_of(message)
    if is_private(rest, text):
        return None
    label = KINDS.get(kind.strip().capitalize()) if colon else None
    labels = [label, FROM_APP] if label and title.strip() else [FROM_APP]
    body = [quiet(text)[:MAX_BODY] or "_No details given._"]
    if has_image(message):
        body.append(SCREENSHOT_NOTE)
    if has_log(message):
        body.append(LOG_NOTE)
    body.append(FOOTER)
    return {
        "title": quiet(rest)[:250] or "Report from the app",
        "body": "\n\n".join(body),
        "labels": labels,
    }


def post_issue(repo: str, token: str, issue: dict) -> None:
    """Opens [issue] on [repo]; again without labels if GitHub refuses them."""
    def post(payload: dict) -> None:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/issues",
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "Content-Type": "application/json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        with urllib.request.urlopen(request, timeout=30):
            pass

    try:
        post(issue)
    except urllib.error.HTTPError as error:
        if error.code != 422:
            raise
        post({k: v for k, v in issue.items() if k != "labels"})


def run(env: dict[str, str],
        connect: Callable[[str], imaplib.IMAP4] = imaplib.IMAP4_SSL,
        file_issue: Callable[[dict], None] | None = None) -> int:
    """Files every bug report and feedback mail not filed yet, and leaves
    support mails as they are. Returns how many were filed."""
    address = env.get("FEEDBACK_GMAIL_ADDRESS", "")
    password = env.get("FEEDBACK_GMAIL_APP_PASSWORD", "")
    if not address or not password:
        print("::notice::The feedback inbox is not set up yet (#160); "
              "nothing to do.")
        return 0
    if file_issue is None:
        repo, token = env["GITHUB_REPOSITORY"], env["GITHUB_TOKEN"]
        file_issue = lambda issue: post_issue(repo, token, issue)  # noqa: E731
    imap = connect("imap.gmail.com")
    imap.login(address, password)
    try:
        imap.select("INBOX")
        # Gmail's own search, so that filed mail is left out by its label.
        _, found = imap.search(None, "X-GM-RAW",
                               f'"subject:Fluenough -label:{FILED}"')
        filed = 0
        for number in (found[0] or b"").split():
            _, data = imap.fetch(number, "(BODY.PEEK[])")
            raw = next(part[1] for part in data if isinstance(part, tuple))
            message = email.message_from_bytes(raw, policy=email.policy.default)
            issue = issue_from(message)
            if issue is None:
                continue
            file_issue(issue)
            imap.store(number, "+X-GM-LABELS", FILED)
            filed += 1
        print(f"Filed {filed} report(s).")
        return filed
    finally:
        imap.logout()


if __name__ == "__main__":
    run(dict(os.environ))
    sys.exit(0)
