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

Review mails (docs/plans/deck-browser.md, "Review in the app, by mail")
carry one JSON file per deck reviewed, each with the rater code, the
language, the deck id, the app version and when it was made. One issue is
opened per mail, saying only who sent something: the rater code and the
languages, read from the files, since the reviewer may have edited the
subject. No deck, no count, no suggestion text: the owner reads the mail.
When the subject is missing or disagrees with the files, the issue goes by
the files and is marked "subject changed"; when the files carry different
codes, or none, or a code whose check symbol fails, it is marked "check
the files".

The sender check (deck-browser.md, "The sender check lives in the Fluenough
Gmail"): a code is public, so the first review mail with a code ties it to
the address it came from. The tool keeps one private record per rater code
in the Gmail label `fluenough/raters`, which it creates: a mail it puts
there itself with IMAP APPEND (nothing is sent), its subject the code, its
body the address. Addresses are compared with case ignored, and for
gmail.com and googlemail.com with the dots of the local part and anything
from `+` ignored. A later review from another address is filed marked
"sender does not match", for the owner to decide; the issue still names
only the code and the languages. The records are read afresh on every run,
so a record the owner deletes in Gmail is tied again by the code's next
mail, and one the owner adds or replaces is what counts from then on: a
sender matching any record of its code passes. A record's address is
read from the first line of its body, bare or as `Name <address>`; a
record whose subject is not a code or whose first line is not one address
is passed over, and the log counts those. When the label cannot be read
or a record cannot be written, or the mail has no single sender, the mail
is filed marked "sender not checked", never dropped. When the connection
drops while a record is written, the run stops before filing that mail,
which stays in the inbox for the next run: filing it unchecked would leave
it unlabelled, and filed again an hour later. No address and no record's
body is ever printed: the job's log is public, so it says counts only.

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
import email.utils
import hashlib
import imaplib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from typing import Callable

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rater_codes import CROCKFORD, check_symbol, rater_code  # noqa: E402,F401

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

# Review mails (deck-browser.md): the subject the app writes, and what a
# review file says it is.
REVIEW_PREFIX = "[Fluenough review]"
REVIEW_FORMAT = "fluenough-review"
REVIEW = "review"
SUBJECT_CHANGED = "subject changed"
CHECK_FILES = "check the files"
REVIEW_SUBJECT = re.compile(
    r"^\[Fluenough review\]\s*([^\s(]+)?\s*(?:\(([^)]*)\))?", re.I)
LANGUAGE = re.compile(r"^[a-z]{2,3}$")
# The sender check: the Gmail label holding one record per rater code, and
# the marks of a review whose sender differs or could not be compared.
RATERS = "fluenough/raters"
SENDER_DIFFERS = "sender does not match"
SENDER_UNCHECKED = "sender not checked"
# Gmail ignores dots in an address's local part and anything from `+`.
GMAIL = ("gmail.com", "googlemail.com")
# The review bot (ADR-0038): the label a review mail gets once its
# proposals are in the decks, or once it is left to the owner, and the mark
# of a review that rejects a proposal.
PROPOSED = "fluenough-proposed"
REJECTED = "proposal rejected"
REVIEW_FOOTER = ("<sub>Opened by the hourly mail workflow. The reviews stay "
                 "in the mail: no suggestion text, no mail address.</sub>")


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


def review_files(message: email.message.Message) -> list[dict]:
    """The review files attached to [message]: JSON that says it is one."""
    files = []
    for part in message.walk():
        if part.get_content_disposition() != "attachment":
            continue
        name = (part.get_filename() or "").lower()
        if not (name.endswith(".json")
                or part.get_content_type() == "application/json"):
            continue
        payload = part.get_payload(decode=True) or b""
        try:
            data = json.loads(payload.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            continue
        if isinstance(data, dict) and data.get("format") == REVIEW_FORMAT:
            files.append(data)
    return files


def _unique(items: list[str]) -> list[str]:
    return list(dict.fromkeys(items))


def review_counts(files: list[dict]) -> tuple[int, int, list[tuple[str, str]]]:
    """How many changes [files] suggest and accept, and the proposals they
    reject, (proposal id, card id) each. No text."""
    suggested = accepted = 0
    rejected: list[tuple[str, str]] = []
    for f in files:
        cards = f.get("cards") if isinstance(f.get("cards"), list) else []
        for c in cards:
            if not isinstance(c, dict):
                continue
            if isinstance(c.get("suggestion"), dict):
                suggested += 1
            answers = c.get("proposals") if isinstance(c.get("proposals"), list) else []
            for a in answers:
                if not isinstance(a, dict):
                    continue
                if a.get("answer") == "accept":
                    accepted += 1
                elif a.get("answer") == "reject" and isinstance(a.get("id"), str) \
                        and re.fullmatch(r"[0-9a-f]{10}", a["id"]) \
                        and isinstance(c.get("card"), str) \
                        and re.fullmatch(r"[a-z]{2,3}-[0-9]{4,}", c["card"]):
                    rejected.append((a["id"], c["card"]))
    return suggested, accepted, rejected


def review_issue_from(
        message: email.message.Message,
        check: Callable[[str], str | None] | None = None) -> dict | None:
    """The issue a review mail becomes, or None for a mail that is not one:
    neither its subject nor any file says so. Only the rater code and the
    languages go into it, from the files.

    When the files carry one good code, [check] is asked about it and
    returns a mark for the sender, or None when the sender passes."""
    subject = subject_of(message)
    files = review_files(message)
    said = REVIEW_SUBJECT.match(subject)
    if not files and not said:
        return None
    subject_code = rater_code(said.group(1)) if said else None
    subject_languages = _unique([
        code.strip().lower()
        for code in ((said.group(2) or "") if said else "").split(",")
        if LANGUAGE.match(code.strip().lower())
    ])
    file_codes = [rater_code(f.get("rater_code")) for f in files]
    codes = _unique([c for c in file_codes if c])
    languages = _unique([
        f["language"] for f in files
        if isinstance(f.get("language"), str) and LANGUAGE.match(f["language"])
    ])
    marks = []
    if not files or None in file_codes or len(codes) != 1:
        marks.append(CHECK_FILES)
    if files and (subject_code not in codes
                  or set(subject_languages) != set(languages)):
        marks.append(SUBJECT_CHANGED)
    if check is not None and CHECK_FILES not in marks:
        mark = check(codes[0])
        if mark:
            marks.append(mark)
    if not files:
        # Nothing to go by but the subject; the owner checks the mail.
        codes = [subject_code] if subject_code else []
        languages = subject_languages
    shown = ", ".join(codes) or "no code"
    title = f"Review: {shown}"
    if languages:
        title += f" ({', '.join(languages)})"
    body = [
        "A review came by mail.",
        f"- Rater code{'s' if len(codes) > 1 else ''}: {shown}\n"
        f"- Language{'s' if len(languages) > 1 else ''}: "
        f"{', '.join(languages) or 'none given'}",
    ]
    suggested, accepted, rejected = review_counts(files)
    if suggested or accepted or rejected:
        body.append(f"- Changes suggested: {suggested}\n"
                    f"- Proposals accepted: {accepted}\n"
                    f"- Proposals rejected: {len(rejected)}")
    if rejected:
        marks.append(REJECTED)
        body.append("**Proposals rejected:** "
                    + ", ".join(f"`{pid}` on `{card}`" for pid, card in rejected)
                    + ". A rejection does not stop a proposal; the owner "
                      "decides.")
    if SUBJECT_CHANGED in marks:
        body.append("**Subject changed:** the mail's subject is missing or "
                    "does not match the files. This issue goes by the "
                    "files.")
    if CHECK_FILES in marks:
        body.append("**Check the files:** the files carry different rater "
                    "codes, or none, or one that fails its check.")
    if SENDER_DIFFERS in marks:
        body.append("**Sender does not match:** this code's first review "
                    "came from another mail address. The owner decides.")
    if SENDER_UNCHECKED in marks:
        body.append("**Sender not checked:** the rater records in the "
                    "Fluenough Gmail could not be read or written, or the "
                    "mail had no single sender, so it was not compared.")
    body.append(REVIEW_FOOTER)
    return {
        "title": title,
        "body": "\n\n".join(body),
        "labels": [REVIEW, FROM_APP,
                   *(f"lang: {code}" for code in languages), *marks],
    }


def normal_address(address: str) -> str:
    """[address] as it is compared: lower case and, for Gmail, without the
    dots of its local part or anything from `+`, which Gmail ignores."""
    address = address.strip().lower()
    local, at, domain = address.rpartition("@")
    if not at:
        return address
    if domain in GMAIL:
        local = local.split("+", 1)[0].replace(".", "")
    return f"{local}@{domain}"


def address_in(text: str) -> str:
    """The one mail address [text] holds, bare or as `Name <address>` and
    with any full stop or comma after it, or "" when it holds none or
    several."""
    _, address = email.utils.parseaddr(text.strip().rstrip(".,;"))
    return address if "@" in address else ""


def sender_of(message: email.message.Message) -> str:
    """The address [message] came from, or "" when it has none, or
    several."""
    return address_in(str(message.get("From", "")))


class Raters:
    """The rater records in the Gmail label [RATERS]: one mail per rater
    code, its subject the code and its body the address the code's first
    review came from. Read once per run, before the inbox is selected.

    Nothing here prints an address or a record's body; only the counts are
    for the log."""

    def __init__(self, imap: imaplib.IMAP4) -> None:
        self.imap = imap
        # Each code's addresses, compared normalised; None when the label
        # could not be read.
        self.known: dict[str, set[str]] | None = None
        self.records = self.passed_over = self.tied = self.matched = 0
        self.differed = self.unchecked = 0

    def load(self) -> None:
        """Reads every record, creating the label first if it is not there.
        A record whose subject is not a code or whose body's first line is
        not one address is passed over, as if deleted, and counted.

        A dropped connection is read as None, like any failure here: the
        inbox cannot be selected after it either, so the run stops before
        filing anything, and no mail is filed twice."""
        try:
            # NO when the label is there already, which is fine.
            self.imap.create(RATERS)
            status, _ = self.imap.select(RATERS, readonly=True)
            if status != "OK":
                return
            status, found = self.imap.search(None, "ALL")
            if status != "OK":
                return
            known: dict[str, set[str]] = {}
            for number in (found[0] or b"").split():
                status, data = self.imap.fetch(number, "(BODY.PEEK[])")
                if status != "OK":
                    return
                raw = next(part[1] for part in data if isinstance(part, tuple))
                record = email.message_from_bytes(
                    raw, policy=email.policy.default)
                code = rater_code(subject_of(record))
                address = address_in(text_of(record).split("\n", 1)[0])
                if code and address:
                    known.setdefault(code, set()).add(normal_address(address))
                    self.records += 1
                else:
                    self.passed_over += 1
            self.known = known
        except (imaplib.IMAP4.error, OSError, StopIteration):
            self.known = None

    def _tie(self, code: str, sender: str) -> bool:
        """Writes the record tying [code] to [sender], by APPEND: no mail is
        sent. Whether it was written.

        A dropped connection is raised, not answered False: the mail could
        be filed but not labelled over it, and would be filed again by the
        next run. Raised, the mail is neither, and the next run files it."""
        record = email.message.EmailMessage()
        record["Subject"] = code
        record.set_content(sender)
        try:
            status, _ = self.imap.append(RATERS, "(\\Seen)", None,
                                         record.as_bytes())
        except (imaplib.IMAP4.abort, OSError):
            raise
        except imaplib.IMAP4.error:
            # A BAD answer: the connection is still good.
            return False
        if status != "OK":
            return False
        assert self.known is not None
        self.known.setdefault(code, set()).add(normal_address(sender))
        return True

    def check(self, code: str, sender: str) -> str | None:
        """The mark for a review with [code] from [sender]: None when the
        sender passes, the code's first mail tying it to [sender]."""
        if self.known is None or not sender:
            self.unchecked += 1
            return SENDER_UNCHECKED
        tied = self.known.get(code)
        if not tied:
            if not self._tie(code, sender):
                self.unchecked += 1
                return SENDER_UNCHECKED
            self.tied += 1
            return None
        if normal_address(sender) in tied:
            self.matched += 1
            return None
        self.differed += 1
        return SENDER_DIFFERS


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


def mail_key(message: email.message.Message) -> str:
    """A name for [message] that stays the same from run to run: from its
    Message-ID, or from the whole mail when it has none."""
    ident = str(message.get("Message-ID", "")).strip()
    raw = ident.encode("utf-8") if ident else message.as_bytes()
    return hashlib.sha256(raw).hexdigest()[:12]


def make_bot(env: dict[str, str]):
    """The review bot, or None when its App is not set up."""
    token = env.get("FLUENOUGH_BOT_TOKEN", "")
    if not token:
        return None
    import tempfile
    from pathlib import Path

    import review_bot
    repo = env.get("GITHUB_REPOSITORY", "")
    root = Path(__file__).resolve().parent.parent
    work = Path(env.get("RUNNER_TEMP") or tempfile.gettempdir()) / "review-bot"
    work.mkdir(parents=True, exist_ok=True)
    return review_bot.Bot(
        review_bot.LocalGit(root, token, work),
        review_bot.RestGitHub(repo, token, env.get("GITHUB_TOKEN", "")),
        review_bot.agreements_needed(env))


def propose_mails(imap: imaplib.IMAP4, raters: Raters, bot) -> dict[str, int]:
    """Makes the proposals of every review mail filed and not yet proposed,
    each through a PR of its own (ADR-0038). A mail is labelled
    [PROPOSED] once its PR is merged, or closed, or there was nothing to
    propose; until then it is tried again each run. A mail whose files
    carry no single good code, or whose sender does not match, is left to
    the owner: labelled, and not proposed. One whose sender could not be
    checked waits for the next run."""
    import review_bot
    counts: dict[str, int] = {}
    _, found = imap.search(
        None, "X-GM-RAW",
        f'"filename:fluenough-review label:{FILED} -label:{PROPOSED}"')
    for number in (found[0] or b"").split():
        _, data = imap.fetch(number, "(BODY.PEEK[])")
        raw = next(part[1] for part in data if isinstance(part, tuple))
        message = email.message_from_bytes(raw, policy=email.policy.default)
        files = review_files(message)
        file_codes = [rater_code(f.get("rater_code")) for f in files]
        codes = _unique([c for c in file_codes if c])
        if not files or None in file_codes or len(codes) != 1:
            outcome = "left to the owner"
        else:
            mark = raters.check(codes[0], sender_of(message))
            if mark == SENDER_UNCHECKED:
                outcome = "waiting for the sender check"
            elif mark == SENDER_DIFFERS:
                outcome = "left to the owner"
            else:
                review = review_bot.read_review(files, codes[0])
                try:
                    outcome = bot.review(mail_key(message), codes[0], review)
                except Exception as error:  # noqa: BLE001 - logged, next run retries
                    print(f"::warning::The proposals of a review by "
                          f"{codes[0]} failed: {type(error).__name__}: {error}")
                    outcome = "failed"
        if outcome in ("merged", "closed", "nothing", "invalid",
                       "left to the owner"):
            imap.store(number, "+X-GM-LABELS", PROPOSED)
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


def run(env: dict[str, str],
        connect: Callable[[str], imaplib.IMAP4] = imaplib.IMAP4_SSL,
        file_issue: Callable[[dict], None] | None = None,
        bot=None) -> int:
    """Files every bug report, feedback and review mail not filed yet, and
    leaves support mails as they are. With the review bot, then makes the
    proposals of review mails, and applies the proposals agreed on `main`.
    Returns how many mails were filed."""
    if bot is None:
        bot = make_bot(env)
    if bot is None:
        print("::notice::The review bot's GitHub App is not set up "
              "(FLUENOUGH_BOT_APP_ID, FLUENOUGH_BOT_PRIVATE_KEY): review "
              "mails wait to become proposals, and nothing is merged.")
    else:
        print(f"Review bot: {bot.threshold} other reviewer(s) must accept a "
              f"proposal.")
    filed = file_mails(env, connect, file_issue, bot)
    if bot is not None:
        try:
            counts = bot.sweep()
            print(f"Agreed proposals: {counts['applied']} merged, "
                  f"{counts['waiting']} waiting; {counts['outdated']} outdated.")
        except Exception as error:  # noqa: BLE001 - logged, next run retries
            print(f"::warning::The agreement sweep failed: "
                  f"{type(error).__name__}: {error}")
    return filed


def file_mails(env: dict[str, str],
               connect: Callable[[str], imaplib.IMAP4],
               file_issue: Callable[[dict], None] | None,
               bot) -> int:
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
        # Before the inbox: selecting the label afterwards would lose the
        # inbox's message numbers.
        raters = Raters(imap)
        raters.load()
        if raters.known is None:
            print(f"::warning::The rater records ({RATERS}) could not be "
                  f"read; review mails are filed as {SENDER_UNCHECKED!r}.")
        else:
            print(f"Read {raters.records} rater record(s), "
                  f"{raters.passed_over} passed over.")
        imap.select("INBOX")
        # Gmail's own search, so that filed mail is left out by its label.
        # A review mail is found by its files too, in case its subject was
        # deleted.
        _, found = imap.search(
            None, "X-GM-RAW",
            f'"{{subject:Fluenough filename:fluenough-review}} '
            f'-label:{FILED}"')
        filed = 0
        for number in (found[0] or b"").split():
            _, data = imap.fetch(number, "(BODY.PEEK[])")
            raw = next(part[1] for part in data if isinstance(part, tuple))
            message = email.message_from_bytes(raw, policy=email.policy.default)
            sender = sender_of(message)
            issue = (review_issue_from(
                message, lambda code: raters.check(code, sender))
                or issue_from(message))
            if issue is None:
                continue
            file_issue(issue)
            imap.store(number, "+X-GM-LABELS", FILED)
            filed += 1
        print(f"Filed {filed} report(s).")
        print(f"Review senders: {raters.tied} tied, {raters.matched} "
              f"matched, {raters.differed} did not match, "
              f"{raters.unchecked} not checked.")
        if bot is not None:
            counts = propose_mails(imap, raters, bot)
            print("Review mails proposed: " + (", ".join(
                f"{n} {outcome}" for outcome, n in sorted(counts.items()))
                or "none waiting") + ".")
        return filed
    finally:
        imap.logout()


if __name__ == "__main__":
    run(dict(os.environ))
    sys.exit(0)
