"""Fetch Telugu word recordings from Wikimedia Commons as an accuracy test set (#1004).

Usage: python3 -I fetch_wiktionary_audio.py <out folder> [--limit 40] [--category NAME ...]

Writes `w001.wav` + `w001.txt` (the expected word in Telugu script, taken from the file
title) for each recording, 16 kHz mono 16-bit PCM (ffmpeg), and `manifest.json` with the
title, author, licence and source page of every file, for attribution. Recordings are
CC BY-SA or similar: **never commit them**; they go only to the job's output or artifact.

Files whose title carries no Telugu-script word (a transliteration, a number) are skipped
and logged: the reference must be the Telugu word, and nothing is guessed.

Wikimedia API etiquette: a descriptive User-Agent, `maxlag=5`, strictly one request at a
time with a pause of at least 1 s, exponential backoff on 429 and 5xx (honouring
Retry-After), and a hard cap on the number of requests. Every problem is logged; the exit
code is 1 when nothing was fetched, 0 otherwise.

Title patterns understood (categories are configurable, see DEFAULT_CATEGORIES):
  Te-<word>.ogg                         Wiktionary-style
  LL-Q8097 (tel)-<speaker>-<word>.wav   Lingua Libre
  anything else whose stem holds Telugu script: the Telugu-script part of the stem.
"""
import argparse
import html
import json
import logging
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

log = logging.getLogger("asr.fetch_wiktionary_audio")

USER_AGENT = ("fluenough-asr-eval/1.0 (https://github.com/aaronified/fluenough; "
              "tooling for an open-source language app)")
API = "https://commons.wikimedia.org/w/api.php"
# Names recalled from Commons, to be confirmed by the first real run (the log lists what each
# category returned); override with --category.
DEFAULT_CATEGORIES = ["Category:Telugu pronunciation",
                      "Category:Lingua Libre pronunciation-tel"]
AUDIO_EXT = (".ogg", ".oga", ".wav", ".flac", ".mp3", ".opus")
_TELUGU = re.compile(r"[ఀ-౿]")
_TELUGU_RUN = re.compile(r"[ఀ-౿‌‍]+(?: [ఀ-౿‌‍]+)*")


def has_telugu(text):
    return bool(_TELUGU.search(text or ""))


def word_from_title(title):
    """The Telugu-script word in a Commons file title, or None when there is none."""
    name = title.split(":", 1)[1] if title.lower().startswith("file:") else title
    stem = os.path.splitext(name)[0].replace("_", " ").strip()
    m = re.match(r"^LL-Q8097 \(tel\)-[^-]*-(.+)$", stem)
    if m:
        stem = m.group(1)
    elif stem.startswith("Te-"):
        stem = stem[3:]
    runs = _TELUGU_RUN.findall(stem)
    if not runs:
        return None
    return max(runs, key=len).strip() or None


def is_audio(title):
    return title.lower().endswith(AUDIO_EXT)


def strip_html(text):
    return html.unescape(re.sub(r"<[^>]+>", "", text or "")).strip()


def manifest_entry(page, word, wav_name):
    """Attribution record for one imageinfo page."""
    info = (page.get("imageinfo") or [{}])[0]
    meta = info.get("extmetadata") or {}

    def field(key):
        return strip_html((meta.get(key) or {}).get("value", ""))

    return {"file": wav_name, "word": word, "title": page.get("title", ""),
            "author": field("Artist") or info.get("user", ""),
            "license": field("LicenseShortName"), "license_url": field("LicenseUrl"),
            "source": info.get("descriptionurl", ""), "url": info.get("url", "")}


def select(pages, limit, seen=None):
    """From imageinfo pages, the (page, word) pairs to fetch: audio only, a Telugu word,
    one recording per word, at most `limit`. Skips are logged."""
    seen = set() if seen is None else seen
    picked = []
    for page in sorted(pages, key=lambda p: p.get("title", "")):
        if len(picked) >= limit:
            break
        title = page.get("title", "")
        if not is_audio(title):
            log.info("skip %s: not an audio file", title)
            continue
        word = word_from_title(title)
        if not word:
            log.warning("skip %s: no Telugu-script word in the title", title)
            continue
        if word in seen:
            log.info("skip %s: word %s already have", title, word)
            continue
        if not (page.get("imageinfo") or [{}])[0].get("url"):
            log.warning("skip %s: no file url in the API answer", title)
            continue
        seen.add(word)
        picked.append((page, word))
    return picked


class Client:
    """One request at a time, paced, backing off, with a hard request budget."""

    def __init__(self, max_requests=60, pause=1.5, opener=None, sleep=time.sleep):
        self.max_requests = max_requests
        self.pause = max(pause, 1.0)
        self.requests = 0
        self.opener = opener or urllib.request.urlopen
        self.sleep = sleep

    def fetch(self, url, timeout=60, attempts=5):
        """Bytes of url, or None after the attempts or the budget run out."""
        delay = 2.0
        for attempt in range(1, attempts + 1):
            if self.requests >= self.max_requests:
                log.error("request budget of %d used up: stopping", self.max_requests)
                return None
            self.requests += 1
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            wait = delay
            try:
                with self.opener(req, timeout=timeout) as resp:
                    data = resp.read()
                self.sleep(self.pause)
                return data
            except urllib.error.HTTPError as e:
                retry = e.headers.get("Retry-After") if e.headers else None
                if e.code == 429 or e.code >= 500:
                    if retry and retry.isdigit():
                        wait = max(wait, min(int(retry), 120))
                    log.warning("HTTP %s for %s (attempt %d/%d), waiting %.0f s",
                                e.code, url[:120], attempt, attempts, wait)
                else:
                    log.error("HTTP %s for %s: giving up", e.code, url[:120])
                    return None
            except Exception as e:
                log.warning("%s for %s (attempt %d/%d), waiting %.0f s",
                            e, url[:120], attempt, attempts, wait)
            self.sleep(wait)
            delay *= 2
        log.error("giving up on %s after %d attempts", url[:120], attempts)
        return None

    def api(self, params):
        """Parsed JSON of an API query, or None. Retries when the servers are lagged."""
        params = dict(params, format="json", formatversion="2", maxlag="5")
        url = API + "?" + urllib.parse.urlencode(params)
        for _ in range(3):
            data = self.fetch(url)
            if data is None:
                return None
            try:
                doc = json.loads(data.decode("utf-8"))
            except ValueError:
                log.error("the API did not answer JSON for %s", url[:120])
                return None
            err = doc.get("error")
            if err and err.get("code") == "maxlag":
                log.warning("API lagged (%s): waiting", err.get("info", ""))
                self.sleep(5)
                continue
            if err:
                log.error("API error %s: %s", err.get("code"), err.get("info"))
                return None
            return doc
        return None


def category_files(client, category, want):
    """imageinfo pages of the files in a category, and its subcategory titles."""
    pages, subcats, cont = [], [], {}
    while len(pages) < want * 4:
        params = {"action": "query", "generator": "categorymembers", "gcmtitle": category,
                  "gcmtype": "file", "gcmlimit": "50", "prop": "imageinfo",
                  "iiprop": "url|user|extmetadata|mime"}
        params.update(cont)
        doc = client.api(params)
        if not doc:
            break
        pages.extend((doc.get("query") or {}).get("pages") or [])
        cont = doc.get("continue") or {}
        if not cont:
            break
    doc = client.api({"action": "query", "list": "categorymembers", "cmtitle": category,
                      "cmtype": "subcat", "cmlimit": "20"})
    if doc:
        subcats = [m["title"] for m in (doc.get("query") or {}).get("categorymembers") or []]
    log.info("%s: %d files, %d subcategories", category, len(pages), len(subcats))
    return pages, subcats


def convert(src, dst):
    """ogg and friends to 16 kHz mono 16-bit WAV with ffmpeg. True on success."""
    try:
        r = subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", src,
                            "-ac", "1", "-ar", "16000", "-sample_fmt", "s16", dst],
                           capture_output=True, text=True, timeout=120)
    except Exception:
        log.exception("ffmpeg failed to run for %s", src)
        return False
    if r.returncode != 0:
        log.error("ffmpeg exit %d for %s: %s", r.returncode, src, r.stderr.strip()[:300])
        return False
    return True


def write_manifest(out, entries):
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"note": "Recordings from Wikimedia Commons under the licences listed; "
                           "credit the authors. Not part of the repository.",
                   "count": len(entries), "files": entries}, f, ensure_ascii=False, indent=1)


def run(out, limit, categories, client, convert_fn=convert):
    os.makedirs(out, exist_ok=True)
    pages, queue, seen = [], list(categories), set()
    visited = set()
    while queue and len(pages) < limit * 4:
        cat = queue.pop(0)
        if cat in visited:
            continue
        visited.add(cat)
        got, subs = category_files(client, cat, limit)
        pages.extend(got)
        if len(visited) <= len(categories):  # one level of subcategories only
            queue.extend(subs)
    entries = []
    for page, word in select(pages, limit * 2, seen):
        if len(entries) >= limit:
            break
        info = page["imageinfo"][0]
        data = client.fetch(info["url"])
        if data is None:
            log.error("could not download %s", page.get("title"))
            if client.requests >= client.max_requests:
                break
            continue
        name = f"w{len(entries) + 1:03d}"
        src = os.path.join(out, name + ".src")
        try:
            with open(src, "wb") as f:
                f.write(data)
            ok = convert_fn(src, os.path.join(out, name + ".wav"))
        except Exception:
            log.exception("could not store %s", page.get("title"))
            ok = False
        finally:
            if os.path.exists(src):
                os.remove(src)
        if not ok:
            continue
        with open(os.path.join(out, name + ".txt"), "w", encoding="utf-8") as f:
            f.write(word + "\n")
        entries.append(manifest_entry(page, word, name + ".wav"))
    write_manifest(out, entries)
    log.info("fetched %d recordings with %d requests", len(entries), client.requests)
    return entries


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--category", action="append")
    ap.add_argument("--max-requests", type=int, default=80)
    ap.add_argument("--pause", type=float, default=1.5)
    args = ap.parse_args(argv)
    try:
        client = Client(args.max_requests, args.pause)
        entries = run(args.out, args.limit, args.category or DEFAULT_CATEGORIES, client)
    except Exception:
        log.exception("fetch_wiktionary_audio failed")
        return 1
    if not entries:
        log.error("no recordings fetched (rate limited, or the category names are wrong)")
        return 1
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main())
