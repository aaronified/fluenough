#!/usr/bin/env python3
"""Tests for tools/wikimedia_client.py, the shared polite Wikimedia client
(ADR-0059, ADR-0060): a scripted transport, a fake clock and no network.

Stdlib `unittest`, like the tool.
"""

from __future__ import annotations

import email.utils
import http.client
import io
import json
import os
import sys
import tempfile
import threading
import http.server
import unittest
import urllib.parse
import urllib.request
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wikimedia_client as wc  # noqa: E402


class Clock:
    """Time that moves only when the client sleeps."""

    def __init__(self) -> None:
        self.t = 1000.0
        self.sleeps: list[float] = []

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.t += seconds

    def __call__(self) -> float:
        return self.t


class Scripted:
    """A transport that answers from a list, then repeats the last answer;
    an Exception in the list is raised."""

    def __init__(self, *answers: object) -> None:
        self.answers = list(answers)
        self.urls: list[str] = []
        self.headers: list[dict[str, str]] = []

    def __call__(self, url: str, headers: dict[str, str]) -> wc.Response:
        self.urls.append(url)
        self.headers.append(headers)
        answer = self.answers.pop(0) if len(self.answers) > 1 else self.answers[0]
        if isinstance(answer, Exception):
            raise answer
        return answer


def ok(obj: object = None, body: bytes | None = None) -> wc.Response:
    return wc.Response(200, {}, body if body is not None else json.dumps(obj or {}).encode())


def status(code: int, **headers: str) -> wc.Response:
    return wc.Response(code, {k.lower().replace("_", "-"): v for k, v in headers.items()}, b"")


def query(url: str) -> dict[str, str]:
    return {k: v[0] for k, v in urllib.parse.parse_qs(urllib.parse.urlsplit(url).query).items()}


class Case(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.cache = Path(tmp.name) / "cache"
        self.clock = Clock()

    def client(self, transport: object, **kw: object) -> wc.Client:
        args = dict(cache_dir=self.cache, sleep=self.clock.sleep, clock=self.clock,
                    now=self.clock, api_interval=0.0, download_interval=0.0)
        args.update(kw)
        return wc.Client(transport, **args)  # type: ignore[arg-type]


class Identity(Case):
    def test_the_user_agent_names_the_project_and_a_contact_url_from_the_env(self) -> None:
        with mock.patch.dict(os.environ, {wc.CONTACT_ENV: "https://example.org/contact"}):
            agent = wc.user_agent()
        self.assertIn("fluenough", agent)
        self.assertIn("https://example.org/contact", agent)
        self.assertNotIn("@", agent)

    def test_it_defaults_to_the_projects_public_page(self) -> None:
        with mock.patch.dict(os.environ, clear=True):
            self.assertIn(wc.DEFAULT_CONTACT, wc.user_agent())

    def test_every_request_carries_the_user_agent(self) -> None:
        t = Scripted(ok({"a": 1}))
        self.client(t).get_json(wc.COMMONS_API, {"action": "query"})
        self.assertIn("fluenough", t.headers[0]["User-Agent"])


class RealTransport(unittest.TestCase):
    """The real urllib transport against a local server: no external network."""

    def serve(self, handler_cls: type) -> str:
        server = http.server.HTTPServer(("127.0.0.1", 0), handler_cls)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return f"http://127.0.0.1:{server.server_address[1]}/f.ogg"

    def fetch(self, headers: dict[str, str]) -> list[str]:
        seen: list[str] = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self) -> None:          # noqa: N802
                seen.extend(self.headers.get_all("User-Agent") or [])
                self.send_response(200)
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"ok")

            def log_message(self, *a: object) -> None:
                pass

        url = self.serve(Handler)
        env = {"no_proxy": "*", "NO_PROXY": "*"}
        with mock.patch.dict(os.environ, env):
            r = wc.urllib_transport(url, headers)
        self.assertEqual(r.status, 200)
        return seen

    def test_the_exact_descriptive_user_agent_is_sent_and_urllibs_own_is_not(self) -> None:
        with mock.patch.dict(os.environ, {wc.CONTACT_ENV: "https://example.org/c"}):
            agent = wc.user_agent()
        self.assertEqual(agent, "fluenough-tools/1.0 (https://example.org/c; polite serial client)")
        self.assertEqual(self.fetch({"User-Agent": agent}), [agent])

    def test_a_client_sends_nothing_but_its_user_agent(self) -> None:
        c = wc.Client(cache_dir=Path(tempfile.mkdtemp()), api_interval=0, download_interval=0)
        self.assertNotIn("python-urllib", c.headers["User-Agent"].lower())
        self.assertEqual(self.fetch(c.headers), [c.headers["User-Agent"]])

    def test_the_user_agent_has_no_python_urllib_suffix(self) -> None:
        self.assertNotIn("urllib", wc.user_agent().lower())


class Pacing(Case):
    def test_the_default_download_interval_is_5_seconds(self) -> None:
        self.assertEqual(wc.DEFAULT_DOWNLOAD_INTERVAL, 5.0)
        t = Scripted(ok(body=b"x"))
        c = wc.Client(t, cache_dir=self.cache, sleep=self.clock.sleep, clock=self.clock,
                      now=self.clock)
        c.get_bytes("https://upload.wikimedia.org/a.ogg")
        c.get_bytes("https://upload.wikimedia.org/b.ogg")
        self.assertEqual(self.clock.sleeps, [5.0])

    def test_a_long_retry_after_is_waited_only_with_wait_rate_limit(self) -> None:
        t = Scripted(status(429, Retry_After="600"), ok(body=b"x"))
        with self.assertRaises(wc.RateLimited) as e:
            self.client(t).get_bytes("https://upload.wikimedia.org/a.ogg")
        self.assertIn("--wait-rate-limit", str(e.exception))
        self.assertEqual(self.clock.sleeps, [])
        t = Scripted(status(429, Retry_After="600"), ok(body=b"x"))
        c = self.client(t, wait_rate_limit=True)
        self.assertEqual(c.get_bytes("https://upload.wikimedia.org/a.ogg"), b"x")
        self.assertIn(600.0, self.clock.sleeps)

    def test_wait_rate_limit_still_stops_beyond_900_seconds(self) -> None:
        t = Scripted(status(429, Retry_After="901"), ok(body=b"x"))
        with self.assertRaises(wc.RateLimited):
            self.client(t, wait_rate_limit=True).get_bytes("https://upload.wikimedia.org/a.ogg")
        self.assertEqual(self.clock.sleeps, [])


class Retrying(Case):
    def test_it_waits_the_retry_after_on_a_429_then_succeeds(self) -> None:
        t = Scripted(status(429, Retry_After="7"), ok({"x": 1}))
        c = self.client(t)
        self.assertEqual(c.get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(len(t.urls), 2)
        self.assertEqual(self.clock.sleeps, [7.0])
        self.assertEqual(c.stats.retries, 1)

    def test_without_retry_after_it_backs_off_exponentially_up_to_a_cap(self) -> None:
        t = Scripted(status(429))
        c = self.client(t, max_tries=5, backoff_cap=3.0)
        with self.assertRaises(wc.RateLimited):
            c.get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(len(t.urls), 5)
        self.assertEqual(self.clock.sleeps, [1.0, 2.0, 3.0, 3.0])

    def test_a_5xx_and_a_network_error_are_retried(self) -> None:
        t = Scripted(status(503), OSError("reset"), ok({"x": 1}))
        c = self.client(t)
        self.assertEqual(c.get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(len(t.urls), 3)

    def test_a_retry_after_longer_than_the_cap_stops_at_once(self) -> None:
        t = Scripted(status(429, Retry_After="3600"), ok({}))
        c = self.client(t, retry_after_cap=300.0)
        with self.assertRaises(wc.RateLimited) as e:
            c.get_json(wc.COMMONS_API, {"a": "1"})
        self.assertIn("3600", str(e.exception))
        self.assertEqual(len(t.urls), 1)
        self.assertEqual(self.clock.sleeps, [])

    def test_a_404_is_an_error_and_is_not_retried(self) -> None:
        t = Scripted(status(404))
        with self.assertRaises(wc.HttpError) as e:
            self.client(t).get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(e.exception.status, 404)
        self.assertEqual(len(t.urls), 1)

    def test_a_maxlag_answer_is_retried(self) -> None:
        lag = wc.Response(200, {"retry-after": "5"},
                          json.dumps({"error": {"code": "maxlag"}}).encode())
        t = Scripted(lag, ok({"x": 1}))
        self.assertEqual(self.client(t).get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(self.clock.sleeps, [5.0])

    def test_every_api_call_asks_for_maxlag(self) -> None:
        t = Scripted(ok({}))
        self.client(t).get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(query(t.urls[0])["maxlag"], wc.MAXLAG)


class Bounds(Case):
    class Body(io.BytesIO):
        headers: dict[str, str] = {}

    def body(self, data: bytes, **headers: str) -> "Bounds.Body":
        b = self.Body(data)
        b.headers = headers
        return b

    def test_a_body_is_read_in_chunks_and_stops_at_the_limit(self) -> None:
        big = self.body(b"x" * (wc.CHUNK * 4))
        with self.assertRaises(wc.ResponseTooLarge):
            wc.read_limited(big, wc.CHUNK * 2, "https://upload.wikimedia.org/a")
        self.assertLess(big.tell(), wc.CHUNK * 4)           # it did not read it all
        self.assertEqual(wc.read_limited(self.body(b"abc"), 10, "u"), b"abc")

    def test_a_declared_length_over_the_limit_is_refused_before_reading(self) -> None:
        r = self.body(b"x" * 10, **{"Content-Length": "999999"})
        with self.assertRaises(wc.ResponseTooLarge):
            wc.read_limited(r, 100, "u")
        self.assertEqual(r.tell(), 0)

    def test_the_limits_are_a_few_megabytes(self) -> None:
        self.assertLessEqual(wc.MAX_DOWNLOAD_BYTES, 5 * 1024 * 1024)
        self.assertLessEqual(wc.MAX_API_BYTES, 16 * 1024 * 1024)
        self.assertGreater(wc.REQUEST_TIMEOUT, 0)

    def test_a_redirect_to_another_host_is_refused(self) -> None:
        down = "https://upload.wikimedia.org/a/x.ogg"
        api = wc.COMMONS_API + "?a=1"
        for url, target in ((down, "https://evil.example/x.ogg"),
                            (down, "http://upload.wikimedia.org/x.ogg"),
                            (down, "https://commons.wikimedia.org/x"),
                            (api, "https://upload.wikimedia.org/x"),
                            (api, "https://evil.example/w/api.php")):
            handler = wc._SafeRedirects(wc.allowed_hosts(url))
            with self.subTest(url=url, target=target), self.assertRaises(wc.RedirectRefused):
                handler.redirect_request(urllib.request.Request(url), None, 302, "", {}, target)

    def test_a_redirect_within_the_allowed_hosts_is_followed(self) -> None:
        down = "https://upload.wikimedia.org/a/x.ogg"
        handler = wc._SafeRedirects(wc.allowed_hosts(down))
        again = handler.redirect_request(urllib.request.Request(down), None, 302, "", {},
                                         "https://upload.wikimedia.org/b/x.ogg")
        self.assertEqual(again.full_url, "https://upload.wikimedia.org/b/x.ogg")
        api = wc.COMMONS_API
        handler = wc._SafeRedirects(wc.allowed_hosts(api))
        self.assertIsNotNone(handler.redirect_request(
            urllib.request.Request(api), None, 301, "", {}, "https://en.wikipedia.org/w/api.php"))

    def test_an_incomplete_read_is_retried_like_a_network_error(self) -> None:
        t = Scripted(http.client.IncompleteRead(b"par"), ok({"x": 1}))
        self.assertEqual(self.client(t).get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(len(t.urls), 2)

    def test_an_oversize_answer_from_the_transport_is_not_retried(self) -> None:
        t = Scripted(wc.ResponseTooLarge("too big"))
        with self.assertRaises(wc.ResponseTooLarge):
            self.client(t).get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(len(t.urls), 1)


class HttpDate(Case):
    def date(self, ahead: float) -> str:
        return email.utils.formatdate(self.clock() + ahead, usegmt=True)

    def test_a_retry_after_date_is_read_as_seconds_from_now(self) -> None:
        self.assertEqual(wc.retry_after({"retry-after": self.date(7)}, self.clock()), 7.0)
        self.assertEqual(wc.retry_after({"retry-after": self.date(-50)}, self.clock()), 0.0)
        self.assertIsNone(wc.retry_after({"retry-after": "soon"}, self.clock()))

    def test_a_near_date_is_waited_for(self) -> None:
        t = Scripted(wc.Response(429, {"retry-after": self.date(7)}, b""), ok({"x": 1}))
        self.assertEqual(self.client(t).get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(self.clock.sleeps, [7.0])

    def test_a_date_more_than_300_seconds_away_stops_the_run(self) -> None:
        t = Scripted(wc.Response(429, {"retry-after": self.date(900)}, b""), ok({}))
        with self.assertRaises(wc.RateLimited):
            self.client(t).get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(len(t.urls), 1)


class Budgets(Case):
    def test_the_hard_cap_stops_the_run_and_cache_hits_do_not_count(self) -> None:
        t = Scripted(ok({"x": 1}))
        c = self.client(t, max_requests=2)
        c.get_json(wc.COMMONS_API, {"n": "1"})
        c.get_json(wc.COMMONS_API, {"n": "1"})      # cached: free
        c.get_json(wc.COMMONS_API, {"n": "2"})
        with self.assertRaises(wc.RequestCapReached):
            c.get_json(wc.COMMONS_API, {"n": "3"})
        self.assertEqual(len(t.urls), 2)

    def test_the_cap_counts_the_retries_too(self) -> None:
        t = Scripted(status(429))
        c = self.client(t, max_requests=3, max_tries=5)
        with self.assertRaises(wc.RequestCapReached):
            c.get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(len(t.urls), 3)

    def test_api_calls_and_downloads_have_separate_pauses(self) -> None:
        t = Scripted(ok({"x": 1}, body=b"{}"))
        c = self.client(t, api_interval=10.0, download_interval=0.0)
        c.get_json(wc.COMMONS_API, {"n": "1"})
        c.get_bytes("https://upload.wikimedia.org/a.ogg")
        c.get_bytes("https://upload.wikimedia.org/b.ogg")
        self.assertEqual(self.clock.sleeps, [])           # downloads did not wait for the API
        c.get_json(wc.COMMONS_API, {"n": "2"})
        self.assertEqual(self.clock.sleeps, [10.0])       # the API budget did
        self.assertEqual((c.stats.api_requests, c.stats.download_requests), (2, 2))

    def test_downloads_only_from_upload_wikimedia_over_https(self) -> None:
        c = self.client(Scripted(ok()))
        for url in ("http://upload.wikimedia.org/a.ogg", "https://example.org/a.ogg"):
            with self.assertRaises(wc.WikimediaError):
                c.get_bytes(url)


class Caching(Case):
    def test_an_api_answer_is_cached_on_disk_for_the_ttl(self) -> None:
        t = Scripted(ok({"x": 1}))
        self.client(t, ttl=100).get_json(wc.COMMONS_API, {"a": "1"})
        again = self.client(t, ttl=100)                   # a new run, same folder
        self.assertEqual(again.get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(len(t.urls), 1)
        self.assertEqual(again.stats.cache_hits, 1)
        self.clock.t += 101                               # stale
        again.get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(len(t.urls), 2)

    def test_the_key_is_the_url_and_params_whatever_their_order(self) -> None:
        t = Scripted(ok({"x": 1}))
        c = self.client(t)
        c.get_json(wc.COMMONS_API, {"a": "1", "b": "2"})
        c.get_json(wc.COMMONS_API, {"b": "2", "a": "1"})
        c.get_json(wc.COMMONS_API, {"a": "1", "b": "3"})
        self.assertEqual(len(t.urls), 2)

    def test_refresh_ignores_the_cache(self) -> None:
        t = Scripted(ok({"x": 1}))
        self.client(t).get_json(wc.COMMONS_API, {"a": "1"})
        self.client(t, refresh=True).get_json(wc.COMMONS_API, {"a": "1"})
        self.assertEqual(len(t.urls), 2)

    def test_a_download_is_cached_for_good(self) -> None:
        t = Scripted(ok(body=b"OggS-bytes"))
        c = self.client(t, ttl=1)
        url = "https://upload.wikimedia.org/a/ab/x.ogg"
        self.assertEqual(c.get_bytes(url), b"OggS-bytes")
        self.clock.t += 10 ** 9
        self.assertEqual(self.client(t, ttl=1).get_bytes(url), b"OggS-bytes")
        self.assertEqual(len(t.urls), 1)

    def test_a_damaged_cache_file_is_asked_again(self) -> None:
        t = Scripted(ok({"x": 1}))
        c = self.client(t)
        c.get_json(wc.COMMONS_API, {"a": "1"})
        for f in (self.cache / "api").glob("*.json"):
            f.write_text("{not json", encoding="utf-8")
        self.assertEqual(self.client(t).get_json(wc.COMMONS_API, {"a": "1"}), {"x": 1})
        self.assertEqual(len(t.urls), 2)


def pages_answer(have: set[str], moved: dict[str, str] | None = None) -> object:
    """A transport answering `imageinfo` for the titles asked: found for
    those in [have], missing for the rest."""
    moved = moved or {}

    def answer(url: str, headers: dict[str, str]) -> wc.Response:
        titles = query(url)["titles"].split("|")
        pages = []
        redirects = []
        for title in titles:
            final = moved.get(title, title)
            if final != title:
                redirects.append({"from": title, "to": final})
            if final in have:
                pages.append({"title": final, "imageinfo": [{"url": f"https://upload.wikimedia.org/{final}"}]})
            else:
                pages.append({"title": final, "missing": True})
        return ok({"query": {"redirects": redirects, "pages": pages}})
    return answer


class Titles(Case):
    def test_titles_go_50_to_a_request(self) -> None:
        asked: list[list[str]] = []
        base = pages_answer(set())

        def transport(url: str, headers: dict[str, str]) -> wc.Response:
            asked.append(query(url)["titles"].split("|"))
            return base(url, headers)
        titles = [f"File:T{i}.ogg" for i in range(120)]
        self.client(transport).imageinfo(titles)
        self.assertEqual([len(a) for a in asked], [50, 50, 20])
        self.assertEqual(sum(asked, []), titles)

    def test_batched_helper(self) -> None:
        self.assertEqual([len(b) for b in wc.batched(map(str, range(101)))], [50, 50, 1])
        self.assertEqual(list(wc.batched([])), [])

    def test_found_and_missing_titles_and_redirects(self) -> None:
        t = pages_answer({"File:A.ogg", "File:New.ogg"}, moved={"File:Old.ogg": "File:New.ogg"})
        got = self.client(t).imageinfo(["File:A.ogg", "File:Nope.ogg", "File:Old.ogg"])
        self.assertEqual(got["File:A.ogg"]["title"], "File:A.ogg")
        self.assertIsNone(got["File:Nope.ogg"])
        self.assertEqual(got["File:Old.ogg"]["title"], "File:New.ogg")

    def test_missing_titles_are_cached_and_only_new_ones_are_asked(self) -> None:
        asked: list[list[str]] = []
        base = pages_answer({"File:A.ogg"})

        def transport(url: str, headers: dict[str, str]) -> wc.Response:
            asked.append(query(url)["titles"].split("|"))
            return base(url, headers)
        c = self.client(transport)
        c.imageinfo(["File:A.ogg", "File:Nope.ogg"])
        got = self.client(transport).imageinfo(["File:Nope.ogg", "File:A.ogg", "File:B.ogg"])
        self.assertEqual(asked, [["File:A.ogg", "File:Nope.ogg"], ["File:B.ogg"]])
        self.assertIsNone(got["File:Nope.ogg"])
        self.assertIsNotNone(got["File:A.ogg"])

    def test_imageinfo_follows_continue_to_the_whole_batch(self) -> None:
        def page(t: str) -> dict:
            return {"title": t, "imageinfo": [{"url": f"https://upload.wikimedia.org/{t}"}]}
        first = {"query": {"pages": [page("File:A.ogg"), {"title": "File:B.ogg"}]},
                 "continue": {"iicontinue": "tok", "continue": "||"}}
        second = {"query": {"pages": [page("File:B.ogg")]}}
        t = Scripted(ok(first), ok(second))
        got = self.client(t).imageinfo(["File:A.ogg", "File:B.ogg"])
        self.assertIsNotNone(got["File:A.ogg"])
        self.assertIsNotNone(got["File:B.ogg"])
        self.assertEqual(query(t.urls[1])["iicontinue"], "tok")

    def test_a_title_the_api_never_listed_is_not_cached_as_missing(self) -> None:
        answers = [ok({"query": {"pages": [{"title": "File:A.ogg", "missing": True}]}})]
        t = Scripted(*answers)
        c = self.client(t)
        self.assertIsNone(c.imageinfo(["File:A.ogg", "File:B.ogg"])["File:B.ogg"])
        self.client(t).imageinfo(["File:A.ogg", "File:B.ogg"])
        self.assertEqual(query(t.urls[-1])["titles"], "File:B.ogg")   # B asked again, A cached

    def test_a_category_is_followed_to_its_end(self) -> None:
        pages = [{"query": {"categorymembers": [{"title": "File:B.ogg"}]},
                  "continue": {"cmcontinue": "next"}},
                 {"query": {"categorymembers": [{"title": "File:A.ogg"}]}}]
        t = Scripted(ok(pages[0]), ok(pages[1]))
        self.assertEqual(self.client(t).category_files("Category:X"),
                         ["File:A.ogg", "File:B.ogg"])
        self.assertEqual(query(t.urls[1])["cmcontinue"], "next")

    def test_wikidata_ids_go_50_to_a_request(self) -> None:
        sizes: list[int] = []

        def transport(url: str, headers: dict[str, str]) -> wc.Response:
            ids = query(url)["ids"].split("|")
            sizes.append(len(ids))
            return ok({"entities": {i: {"id": i} for i in ids}})
        got = self.client(transport).wikidata_entities([f"Q{i}" for i in range(60)])
        self.assertEqual(sizes, [50, 10])
        self.assertEqual(len(got), 60)


if __name__ == "__main__":
    unittest.main()
