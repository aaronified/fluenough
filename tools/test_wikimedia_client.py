#!/usr/bin/env python3
"""Tests for tools/wikimedia_client.py, the shared polite Wikimedia client
(ADR-0059, ADR-0060): a scripted transport, a fake clock and no network.

Stdlib `unittest`, like the tool.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
import urllib.parse
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
