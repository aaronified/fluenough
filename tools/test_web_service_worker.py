#!/usr/bin/env python3
"""Tests for the hand-written service worker (#1012): tools/web/sw.js,
register_sw.js, their copy by brand_web.py and check_web_sw.py.

sw.js is run for real under Node, with a small fake of the worker globals
(caches, fetch, events), so what it caches and what it leaves alone is checked
by behaviour. Those tests are skipped where Node is not installed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import brand_web
import check_web_sw

REPO = Path(__file__).resolve().parent.parent
SW = REPO / "tools/web/sw.js"
NODE = shutil.which("node")

HARNESS = r"""
const fs = require('fs');
const listeners = {};
const stores = {};
const key = (r) => (typeof r === 'string' ? new URL(r, 'https://x.test/fluenough/').href : r.url);
const strip = (u, ignoreSearch) => (ignoreSearch ? u.split('?')[0] : u);
function makeCache(name) {
  stores[name] = stores[name] || new Map();
  const m = stores[name];
  return {
    async match(r, o) {
      const k = strip(key(r), o && o.ignoreSearch);
      for (const [u, v] of m) if (strip(u, o && o.ignoreSearch) === k) return v;
    },
    async put(r, v) { m.set(key(r), v); },
    async add(r) {
      const res = await fetch(r);
      if (!res.ok) throw new Error('bad');
      m.set(key(r), res);
    },
  };
}
const fetched = [];
let online = true;
const files = JSON.parse(process.env.FILES);
global.Request = class { constructor(u, o) { this.url = key(u); this.method = (o && o.method) || 'GET'; this.headers = new Map(Object.entries((o && o.headers) || {})); this.mode = (o && o.mode) || 'cors'; } };
global.Response = class { constructor(b, o) { this.body = b; this.ok = !o || o.ok !== false; this.type = (o && o.type) || 'basic'; } clone() { return this; } static error() { const r = new Response(null, { ok: false }); r.type = 'error'; return r; } };
global.fetch = async (r) => {
  const u = key(r);
  fetched.push(u);
  if (!online) throw new TypeError('offline');
  const path = new URL(u).pathname.replace('/fluenough/', '');
  if (!(path in files)) return new Response('', { ok: false });
  return new Response(files[path]);
};
global.caches = {
  open: async (n) => makeCache(n),
  keys: async () => Object.keys(stores),
  delete: async (n) => { delete stores[n]; },
};
global.self = {
  registration: { scope: 'https://x.test/fluenough/' },
  skipWaiting: async () => {},
  clients: { claim: async () => {} },
  addEventListener: (t, f) => { listeners[t] = f; },
};
for (const k of Object.keys(global.self)) if (!(k in global)) global[k] = global.self[k];
eval(fs.readFileSync(process.env.SW, 'utf8'));
const waits = [];
const ev = (extra) => Object.assign({ waitUntil: (p) => waits.push(p) }, extra);
async function dispatchFetch(request) {
  let out; let handled = false;
  listeners.fetch(ev({ request, respondWith: (p) => { handled = true; out = p; } }));
  return handled ? await out : 'bypass';
}
async function drain() { while (waits.length) await waits.shift(); }
(async () => {
  const results = {};
  stores['fluenough-shell-old'] = new Map();
  stores['other-app'] = new Map();
  listeners.install(ev()); await drain();
  listeners.activate(ev()); await drain();
  results.cachesAfterActivate = Object.keys(stores).sort();
  results.shellCached = [...stores['fluenough-shell-v1'].keys()].map((u) => new URL(u).pathname);
  results.crossOrigin = await dispatchFetch(new Request('https://raw.githubusercontent.com/a/decks/index.json'));
  results.post = await dispatchFetch(new Request('https://x.test/fluenough/main.dart.js', { method: 'POST' }));
  results.range = await dispatchFetch(new Request('https://x.test/fluenough/main.dart.js', { headers: { range: 'bytes=0-1' } }));
  results.deckFile = await dispatchFetch(new Request('https://x.test/fluenough/decks/te/x.yaml'));
  results.outOfScope = await dispatchFetch(new Request('https://x.test/other/app.js'));
  const live = await dispatchFetch(new Request('https://x.test/fluenough/main.dart.js'));
  results.liveBody = live.body;
  listeners.message(ev({ data: { type: 'cache-loaded', urls: ['https://x.test/fluenough/canvaskit/c.wasm', 'https://raw.githubusercontent.com/z', 'https://x.test/fluenough/decks/a.yaml'] } })); await drain();
  results.cachedAfterMessage = [...stores['fluenough-shell-v1'].keys()].map((u) => new URL(u).pathname).sort();
  online = false;
  const off = await dispatchFetch(new Request('https://x.test/fluenough/main.dart.js'));
  results.offlineBody = off.body;
  const nav = await dispatchFetch(new Request('https://x.test/fluenough/?utm=1', { mode: 'navigate' }));
  results.offlineNav = nav.body;
  results.missingOffline = (await dispatchFetch(new Request('https://x.test/fluenough/nope.js'))).type;
  console.log(JSON.stringify(results));
})();
"""


def run_sw() -> dict:
    files = {
        "": "PAGE",
        "index.html": "PAGE",
        "flutter_bootstrap.js": "BOOT",
        "manifest.json": "{}",
        "main.dart.js": "APP",
        "canvaskit/c.wasm": "WASM",
    }
    with tempfile.TemporaryDirectory() as tmp:
        harness = Path(tmp) / "harness.js"
        harness.write_text(HARNESS)
        out = subprocess.run(
            [NODE, str(harness)],
            env={"SW": str(SW), "FILES": json.dumps(files), "PATH": ""},
            capture_output=True,
            text=True,
            check=True,
        )
    return json.loads(out.stdout.strip().splitlines()[-1])


@unittest.skipUnless(NODE, "node is not installed")
class ServiceWorkerBehaviour(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = run_sw()

    def test_install_keeps_the_shell_and_activate_drops_old_caches(self):
        self.assertEqual(self.r["cachesAfterActivate"], ["fluenough-shell-v1", "other-app"])
        for path in ("/fluenough/index.html", "/fluenough/flutter_bootstrap.js", "/fluenough/manifest.json"):
            self.assertIn(path, self.r["shellCached"])

    def test_leaves_alone_what_it_must_not_keep(self):
        for what in ("crossOrigin", "post", "range", "deckFile", "outOfScope"):
            self.assertEqual(self.r[what], "bypass", what)

    def test_network_first(self):
        self.assertEqual(self.r["liveBody"], "APP")

    def test_loaded_files_are_kept_but_not_decks_or_other_origins(self):
        cached = self.r["cachedAfterMessage"]
        self.assertIn("/fluenough/canvaskit/c.wasm", cached)
        self.assertIn("/fluenough/main.dart.js", cached)
        self.assertFalse([p for p in cached if "decks" in p or "/z" == p])

    def test_offline_serves_the_cache(self):
        self.assertEqual(self.r["offlineBody"], "APP")
        self.assertEqual(self.r["offlineNav"], "PAGE")

    def test_offline_miss_is_an_error_not_a_hang(self):
        self.assertEqual(self.r["missingOffline"], "error")


class Branding(unittest.TestCase):
    def brand(self, tmp: str) -> Path:
        web = Path(tmp)
        brand_web.brand_service_worker(web)
        return web

    def test_copies_sw_and_registers_it_without_flutters_worker(self):
        with tempfile.TemporaryDirectory() as tmp:
            web = self.brand(tmp)
            self.assertEqual((web / "sw.js").read_text(), SW.read_text())
            boot = (web / "flutter_bootstrap.js").read_text()
            self.assertIn("{{flutter_js}}", boot)
            self.assertIn("{{flutter_build_config}}", boot)
            self.assertIn("serviceWorker.register('sw.js')", boot)
            self.assertNotIn("flutter_service_worker_version", boot)
            self.assertTrue(boot.rstrip().endswith("_flutter.loader.load();"))

    def test_running_twice_gives_the_same_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            web = self.brand(tmp)
            first = (web / "flutter_bootstrap.js").read_text()
            self.assertEqual(self.brand(tmp), web)
            self.assertEqual((web / "flutter_bootstrap.js").read_text(), first)


class BuiltOutputCheck(unittest.TestCase):
    def built(self, tmp: str) -> Path:
        web = Path(tmp)
        brand_web.brand_service_worker(web)
        boot = (web / "flutter_bootstrap.js").read_text()
        # What the build does: fills in the template tags.
        (web / "flutter_bootstrap.js").write_text(
            boot.replace("{{flutter_js}}", "/*js*/").replace("{{flutter_build_config}}", "/*cfg*/")
        )
        (web / "index.html").write_text('<script src="flutter_bootstrap.js" async></script>')
        return web

    def test_a_good_build_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(check_web_sw.check(self.built(tmp)), [])

    def test_each_failure_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            web = self.built(tmp)
            (web / "sw.js").unlink()
            (web / "index.html").write_text("<html></html>")
            (web / "flutter_bootstrap.js").write_text(
                "_flutter.loader.load({serviceWorkerSettings:{}}); {{x}}"
            )
            problems = " | ".join(check_web_sw.check(web))
            for fragment in ("sw.js is missing", "does not load flutter_bootstrap.js",
                             "does not register sw.js", "service worker settings", "unfilled"):
                self.assertIn(fragment, problems)


if __name__ == "__main__":
    unittest.main()
