#!/usr/bin/env python3
"""A polite client for Wikimedia's APIs and file servers, shared by the tools
that fetch from Wikimedia Commons, Wiktionary, Wikipedia and Wikidata:
`tools/fetch_sound_audio.py` (ADR-0059, #734) and, next, the culture media
tool (ADR-0060).

Wikimedia rate-limits the shared proxy address the agents run behind: the
action APIs answered 429 with `Retry-After` after about ten requests a
minute, while `upload.wikimedia.org` kept answering 200. So the client:

- sends one request at a time, with a `User-Agent` that names the project and
  a contact URL (env `WIKIMEDIA_CONTACT_URL`; the project's public page by
  default; no personal data, no secrets);
- keeps two budgets, one for API calls and one for file downloads, each with
  its own pause between requests;
- obeys `Retry-After` on a 429 or 503 and backs off exponentially, up to a
  cap, on a 429, a 5xx or a network error; a `Retry-After` longer than
  `retry_after_cap` stops the run (RateLimited) instead of waiting for it,
  unless `wait_rate_limit` is set (the tools' `--wait-rate-limit`), which
  sleeps up to 900 s;
- batches title and id queries, 50 at a time (`BATCH`);
- caches every answer on disk (default `.cache/wikimedia`, git-ignored by
  `/.cache/`), API answers for `ttl` seconds, downloads for good, so a rerun
  after an interruption asks for nothing it already has; `refresh=True`
  ignores what is cached; missing files are cached too (a negative cache);
- stops at a hard cap of requests per run (RequestCapReached);
- takes its transport, sleep and clocks as arguments, so the tests run it
  with a fake and no network.

Needs only Python 3.11+ and the standard library.
"""

from __future__ import annotations

import email.utils
import hashlib
import http.client
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, Iterator

ROOT = Path(__file__).resolve().parent.parent

COMMONS_API = "https://commons.wikimedia.org/w/api.php"
WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"
WIKTIONARY_API = "https://en.wiktionary.org/w/api.php"
WIKIDATA_API = "https://www.wikidata.org/w/api.php"
DOWNLOAD_HOST = "upload.wikimedia.org"
# Commons thumbnails (the `thumburl` of the API) are served from thumb.wikimedia.org.
DOWNLOAD_HOSTS = frozenset({DOWNLOAD_HOST, "thumb.wikimedia.org"})

BATCH = 50                       # titles or ids per API request (Wikimedia's limit)
DEFAULT_CACHE = ROOT / ".cache" / "wikimedia"
DEFAULT_TTL = 30 * 24 * 3600     # an API answer, and a "missing", is good for 30 days
DEFAULT_DOWNLOAD_INTERVAL = 5.0  # seconds between file downloads (0.25 s drew 429s)
MAX_WAIT_RATE_LIMIT = 900.0      # the longest Retry-After a --wait-rate-limit run sleeps for
DEFAULT_CONTACT = "https://github.com/aaronified/fluenough"
CONTACT_ENV = "WIKIMEDIA_CONTACT_URL"
API_HOSTS = frozenset({"commons.wikimedia.org", "en.wikipedia.org", "en.wiktionary.org",
                       "www.wikidata.org"})
MAX_API_BYTES = 8 * 1024 * 1024         # an API answer is read up to this
MAX_DOWNLOAD_BYTES = 5 * 1024 * 1024    # and a file download up to this
REQUEST_TIMEOUT = 30                    # seconds, for every request
CHUNK = 64 * 1024
RETRYABLE = frozenset({429, 500, 502, 503, 504})
MAXLAG = "5"


def user_agent(contact: str | None = None) -> str:
    """A descriptive User-Agent: the project, and where to reach it."""
    contact = contact or os.environ.get(CONTACT_ENV) or DEFAULT_CONTACT
    # Only this. upload.wikimedia.org answered 429 to the same string with
    # ` python-urllib` appended and 200 without it (first real run, #1686).
    return f"fluenough-tools/1.0 ({contact}; polite serial client)"


class WikimediaError(Exception):
    """Any failure of a request."""


class HttpError(WikimediaError):
    """An answer that is neither a success nor worth retrying (404, 403...)."""

    def __init__(self, status: int, url: str) -> None:
        super().__init__(f"HTTP {status} for {url}")
        self.status = status
        self.url = url


class ResponseTooLarge(WikimediaError):
    """An answer bigger than the limit for its kind; the read stops there."""


class RedirectRefused(WikimediaError):
    """A redirect to a host the request may not go to."""


class RateLimited(WikimediaError):
    """The server kept refusing: the tries ran out, or it asked for a wait
    longer than the client will make. The run stops cleanly; a rerun resumes
    from the cache."""


class RequestCapReached(WikimediaError):
    """The run's hard cap of requests is spent."""


@dataclass
class Response:
    status: int
    headers: dict[str, str]
    body: bytes


# A transport takes a URL and headers and returns a Response; it raises
# OSError for a network failure. The tests pass their own.
Transport = Callable[[str, dict[str, str]], Response]


def allowed_hosts(url: str) -> frozenset[str]:
    """The hosts a request for [url] may be redirected to: downloads stay on
    upload.wikimedia.org, API calls on the API hosts."""
    host = urllib.parse.urlsplit(url).hostname
    return DOWNLOAD_HOSTS if host in DOWNLOAD_HOSTS else API_HOSTS


class _SafeRedirects(urllib.request.HTTPRedirectHandler):
    def __init__(self, hosts: frozenset[str]) -> None:
        self.hosts = hosts

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
        parts = urllib.parse.urlsplit(newurl)
        if parts.scheme != "https" or parts.hostname not in self.hosts:
            raise RedirectRefused(f"{req.full_url} redirects to {newurl}: only https "
                                  f"on {', '.join(sorted(self.hosts))} is followed")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def read_limited(response: object, limit: int, url: str) -> bytes:
    """[response]'s body, read in chunks; raises ResponseTooLarge as soon as
    it passes [limit] bytes (or says it will in Content-Length)."""
    declared = response.headers.get("Content-Length")  # type: ignore[attr-defined]
    if declared and declared.isdigit() and int(declared) > limit:
        raise ResponseTooLarge(f"{url} is {declared} bytes; the limit is {limit}")
    body = bytearray()
    while chunk := response.read(CHUNK):  # type: ignore[attr-defined]
        body += chunk
        if len(body) > limit:
            raise ResponseTooLarge(f"{url} is over {limit} bytes; read stopped")
    return bytes(body)


def urllib_transport(url: str, headers: dict[str, str]) -> Response:
    """The real network: urllib, with HTTP errors returned as responses, a
    timeout, redirects only to the allowed hosts and a byte limit on the
    body."""
    limit = MAX_DOWNLOAD_BYTES if urllib.parse.urlsplit(url).hostname in DOWNLOAD_HOSTS \
        else MAX_API_BYTES
    opener = urllib.request.build_opener(_SafeRedirects(allowed_hosts(url)))
    # urllib's opener adds `Python-urllib/x.y` unless a User-Agent is already
    # set: replace its default, and set the header on the request as well.
    opener.addheaders = [(k, v) for k, v in headers.items()]
    request = urllib.request.Request(url, headers=headers)
    try:
        with opener.open(request, timeout=REQUEST_TIMEOUT) as r:
            return Response(r.status, {k.lower(): v for k, v in r.headers.items()},
                            read_limited(r, limit, url))
    except urllib.error.HTTPError as e:
        return Response(e.code, {k.lower(): v for k, v in (e.headers or {}).items()},
                        read_limited(e, 65536, url) if e.fp else b"")


def batched(items: Iterable[str], size: int = BATCH) -> Iterator[list[str]]:
    """[items] in lists of at most [size], in order."""
    batch: list[str] = []
    for item in items:
        batch.append(item)
        if len(batch) == size:
            yield batch
            batch = []
    if batch:
        yield batch


class Pacer:
    """Keeps a pause of [interval] seconds between the requests of one
    budget."""

    def __init__(self, interval: float, sleep: Callable[[float], None],
                 clock: Callable[[], float]) -> None:
        self.interval = interval
        self._sleep = sleep
        self._clock = clock
        self._last: float | None = None

    def wait(self) -> None:
        if self._last is not None:
            gap = self.interval - (self._clock() - self._last)
            if gap > 0:
                self._sleep(gap)
        self._last = self._clock()


@dataclass
class Stats:
    api_requests: int = 0
    download_requests: int = 0
    cache_hits: int = 0
    retries: int = 0
    waited: float = 0.0

    @property
    def requests(self) -> int:
        return self.api_requests + self.download_requests


def _key(*parts: str) -> str:
    return hashlib.sha256("\n".join(parts).encode("utf-8")).hexdigest()


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".part")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def retry_after(headers: dict[str, str], now: float | None = None) -> float | None:
    """The seconds a `Retry-After` header asks for: a number of seconds, or
    an HTTP date (seconds from [now], the wall clock); None if it is neither."""
    value = headers.get("retry-after")
    if value is None:
        return None
    try:
        return max(0.0, float(value.strip()))
    except ValueError:
        pass
    try:
        when = email.utils.parsedate_to_datetime(value.strip())
        return max(0.0, when.timestamp() - (time.time() if now is None else now))
    except (TypeError, ValueError, IndexError):
        return None


class Client:
    def __init__(self, transport: Transport | None = None, *,
                 cache_dir: Path | str = DEFAULT_CACHE, ttl: float = DEFAULT_TTL,
                 refresh: bool = False, contact: str | None = None,
                 api_interval: float = 1.0,
                 download_interval: float = DEFAULT_DOWNLOAD_INTERVAL,
                 max_requests: int = 500, max_tries: int = 5,
                 backoff_base: float = 2.0, backoff_cap: float = 120.0,
                 retry_after_cap: float = 300.0, wait_rate_limit: bool = False,
                 sleep: Callable[[float], None] = time.sleep,
                 clock: Callable[[], float] = time.monotonic,
                 now: Callable[[], float] = time.time) -> None:
        self.transport = transport or urllib_transport
        self.cache_dir = Path(cache_dir)
        self.ttl = ttl
        self.refresh = refresh
        self.headers = {"User-Agent": user_agent(contact), "Accept-Encoding": "identity"}
        self.max_requests = max_requests
        self.max_tries = max_tries
        self.backoff_base = backoff_base
        self.backoff_cap = backoff_cap
        # By default a Retry-After over `retry_after_cap` stops the run; with
        # `wait_rate_limit` the client sleeps it out, up to MAX_WAIT_RATE_LIMIT.
        self.wait_rate_limit = wait_rate_limit
        self.retry_after_cap = max(retry_after_cap, MAX_WAIT_RATE_LIMIT) \
            if wait_rate_limit else retry_after_cap
        self._sleep = sleep
        self._now = now
        self._pacers = {"api": Pacer(api_interval, sleep, clock),
                        "download": Pacer(download_interval, sleep, clock)}
        self.stats = Stats()

    # --- The request loop ---------------------------------------------------

    def _wait(self, seconds: float) -> None:
        self.stats.waited += seconds
        self._sleep(seconds)

    def _request(self, url: str, kind: str) -> bytes:
        """[url]'s body, on the [kind] budget ("api" or "download"), retrying
        what is worth retrying."""
        last = "no answer"
        for attempt in range(1, self.max_tries + 1):
            if self.stats.requests >= self.max_requests:
                raise RequestCapReached(
                    f"the cap of {self.max_requests} requests for this run is spent")
            self._pacers[kind].wait()
            if kind == "api":
                self.stats.api_requests += 1
            else:
                self.stats.download_requests += 1
            ask: float | None = None
            try:
                response = self.transport(url, self.headers)
            except (OSError, http.client.HTTPException) as e:
                last = f"network error: {e}"
            else:
                if 200 <= response.status < 300:
                    body_error = self._maxlag(response) if kind == "api" else None
                    if body_error is None:
                        return response.body
                    last, ask = body_error, retry_after(response.headers, self._now())
                elif response.status in RETRYABLE:
                    last = f"HTTP {response.status}"
                    ask = retry_after(response.headers, self._now())
                else:
                    raise HttpError(response.status, url)
            if ask is not None and ask > self.retry_after_cap:
                raise RateLimited(f"{last} for {url}: the server asks for {ask:.0f} s, "
                                  f"more than the {self.retry_after_cap:.0f} s the client "
                                  f"waits (a run started with --wait-rate-limit waits up to "
                                  f"{MAX_WAIT_RATE_LIMIT:.0f} s); rerun later, the cache "
                                  f"keeps what was fetched")
            if attempt == self.max_tries:
                break
            backoff = min(self.backoff_cap, self.backoff_base ** (attempt - 1))
            self.stats.retries += 1
            self._wait(max(backoff, ask or 0.0))
        raise RateLimited(f"{last} for {url} after {self.max_tries} tries; rerun later, "
                          f"the cache keeps what was fetched")

    @staticmethod
    def _maxlag(response: Response) -> str | None:
        """A 200 whose JSON says the servers lag (`maxlag`) is a refusal."""
        if b'"maxlag"' not in response.body[:400]:
            return None
        try:
            data = json.loads(response.body)
        except ValueError:
            return None
        if isinstance(data, dict) and (data.get("error") or {}).get("code") == "maxlag":
            return "maxlag"
        return None

    # --- The cache ------------------------------------------------------------

    def _cache_read(self, group: str, key: str) -> object | None:
        path = self.cache_dir / group / f"{key}.json"
        if self.refresh or not path.is_file():
            return None
        try:
            entry = json.loads(path.read_text(encoding="utf-8"))
            if self._now() - float(entry["fetched"]) > self.ttl:
                return None
            self.stats.cache_hits += 1
            return entry["value"]
        except (OSError, ValueError, KeyError, TypeError):
            return None

    def _cache_write(self, group: str, key: str, value: object) -> None:
        entry = {"fetched": self._now(), "value": value}
        _atomic_write(self.cache_dir / group / f"{key}.json",
                      json.dumps(entry, ensure_ascii=False, sort_keys=True).encode("utf-8"))

    # --- Calls ----------------------------------------------------------------

    def get_json(self, endpoint: str, params: dict[str, str]) -> dict:
        """An API call's JSON, from the cache when it is fresh. `maxlag` and
        `format=json` are added."""
        params = {"format": "json", "maxlag": MAXLAG, **params}
        url = endpoint + "?" + urllib.parse.urlencode(sorted(params.items()))
        key = _key(url)
        cached = self._cache_read("api", key)
        if isinstance(cached, dict):
            return cached
        try:
            data = json.loads(self._request(url, "api"))
        except ValueError as e:
            raise WikimediaError(f"{url} did not answer JSON: {e}") from e
        if not isinstance(data, dict):
            raise WikimediaError(f"{url} did not answer a JSON object")
        self._cache_write("api", key, data)
        return data

    def get_bytes(self, url: str) -> bytes:
        """A file's bytes, from the cache if it was downloaded before. Only
        https URLs on upload.wikimedia.org and thumb.wikimedia.org are fetched."""
        parts = urllib.parse.urlsplit(url)
        if parts.scheme != "https" or parts.hostname not in DOWNLOAD_HOSTS:
            raise WikimediaError(f"{url}: only https://{DOWNLOAD_HOST}/ and "
                                 f"https://thumb.wikimedia.org/ files are downloaded")
        path = self.cache_dir / "files" / _key(url)
        if not self.refresh and path.is_file():
            self.stats.cache_hits += 1
            return path.read_bytes()
        data = self._request(url, "download")
        _atomic_write(path, data)
        return data

    def imageinfo(self, titles: Iterable[str],
                  props: str = "url|size|mime|extmetadata") -> dict[str, dict | None]:
        """Commons `imageinfo` for [titles] (`File:Name.ogg`), 50 to a
        request, asking only for the titles not cached (each title is cached
        by itself, a missing one too). Returns title to the file's info (its
        `imageinfo` entry, plus `title`), or None where there is no such
        file. Redirects are followed."""
        wanted = list(dict.fromkeys(titles))
        out: dict[str, dict | None] = {}
        todo: list[str] = []
        for title in wanted:
            cached = self._cache_read("imageinfo", _key(title, props))
            if cached is not None and isinstance(cached, dict) and "found" in cached:
                out[title] = cached["info"] if cached["found"] else None
            else:
                todo.append(title)
        for batch in batched(todo):
            base = {"action": "query", "prop": "imageinfo", "iiprop": props,
                    "formatversion": "2", "redirects": "1", "titles": "|".join(batch)}
            moved: dict[str, str] = {}
            by_title: dict[str, dict] = {}
            extra: dict[str, str] = {}
            for _ in range(20):           # follow `continue` until the batch is whole
                data = self.get_json(COMMONS_API, {**base, **extra})
                query = data.get("query") or {}
                for entry in (query.get("normalized") or []) + (query.get("redirects") or []):
                    moved[entry["from"]] = entry["to"]
                for page in query.get("pages") or []:
                    have = by_title.setdefault(page.get("title"), {})
                    if page.get("imageinfo"):
                        have["imageinfo"] = page["imageinfo"]
                    if page.get("missing"):
                        have["missing"] = True
                more = data.get("continue")
                if not isinstance(more, dict) or not more:
                    break
                extra = {k: str(v) for k, v in more.items()}
            else:
                raise WikimediaError("imageinfo kept asking to continue; batch dropped")
            for title in batch:
                final = title
                for _ in range(5):          # a short chain, never a loop
                    if final not in moved:
                        break
                    final = moved[final]
                page = by_title.get(final)
                infos = (page or {}).get("imageinfo") or []
                info = {**infos[0], "title": final} if infos else None
                out[title] = info
                if page is not None:       # a title the API never listed is not cached
                    self._cache_write("imageinfo", _key(title, props),
                                      {"found": info is not None, "info": info})
        return {title: out[title] for title in wanted}

    def category_files(self, category: str) -> list[str]:
        """The titles of the files in a Commons [category] (`Category:...`),
        sorted; follows the API's continuation."""
        titles: list[str] = []
        extra: dict[str, str] = {}
        for _ in range(100):
            data = self.get_json(COMMONS_API, {
                "action": "query", "list": "categorymembers", "cmtitle": category,
                "cmtype": "file", "cmlimit": "500", **extra})
            for member in (data.get("query") or {}).get("categorymembers") or []:
                if isinstance(member.get("title"), str):
                    titles.append(member["title"])
            more = (data.get("continue") or {}).get("cmcontinue")
            if not more:
                break
            extra = {"cmcontinue": more}
        return sorted(set(titles))

    def wikidata_entities(self, ids: Iterable[str], props: str = "labels|claims|sitelinks"
                          ) -> dict[str, dict]:
        """Wikidata items by id (`Q42`), 50 to a request."""
        out: dict[str, dict] = {}
        for batch in batched(dict.fromkeys(ids)):
            data = self.get_json(WIKIDATA_API, {
                "action": "wbgetentities", "ids": "|".join(batch), "props": props})
            for qid, entity in (data.get("entities") or {}).items():
                out[qid] = entity
        return out
