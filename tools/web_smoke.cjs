#!/usr/bin/env node
/*
 * Smoke test of the built web app, in headless Chromium (wiki: Plan-Web-Pwa).
 *
 *   node tools/web_smoke.cjs build/web [--base /fluenough/] [--shots dir]
 *
 * Serves the build under the base path it was built for, opens it as a new
 * visitor and walks: the first frame and title, the first-launch pages
 * (the sound check names the browser, not "your phone"), a language to
 * learn, then the four tabs (Today, Decks, Progress, Settings, which draws
 * no Reminders or Updates row in a browser), and a reload, which opens the
 * app on Today because progress and settings are kept in the browser. The
 * page must raise no uncaught error and log no console error, and the
 * manifest and the service worker must not get in the way.
 *
 * Needs Playwright (`npm install playwright`, `npx playwright install
 * chromium`) and network access, because the first decks are downloaded
 * from GitHub. Exits 0 when everything held, 1 with the problems listed.
 *
 * Flutter draws to a canvas, so the page is read through its accessibility
 * tree, which Flutter builds once its hidden placeholder button is pressed.
 */
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require('playwright');

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};
const root = path.resolve(args.find((a) => !a.startsWith('--') && args.indexOf(a) === 0) || 'build/web');
const base = flag('--base', '/fluenough/');
const shots = flag('--shots', '');

const TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.css': 'text/css',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
};

function serve() {
  const server = http.createServer((req, res) => {
    let p = decodeURIComponent(req.url.split('?')[0]);
    if (!p.startsWith(base)) {
      res.writeHead(404);
      return res.end();
    }
    p = p.slice(base.length) || 'index.html';
    const file = path.join(root, p);
    if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404);
      return res.end();
    }
    res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

const problems = [];
const problem = (text) => {
  problems.push(text);
  console.log(`  PROBLEM ${text}`);
};

async function main() {
  if (!fs.existsSync(path.join(root, 'index.html'))) {
    console.error(`No index.html in ${root}: build the web app first.`);
    process.exit(2);
  }
  const server = await serve();
  const origin = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({
    args: [
      // CanvasKit needs WebGL; a headless runner has software GL only.
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      // A microphone that plays a beep, allowed without a prompt.
      '--use-fake-device-for-media-stream',
      '--use-fake-ui-for-media-stream',
    ],
  });
  const context = await browser.newContext({
    viewport: { width: 430, height: 900 },
    locale: 'en-US',
    permissions: ['microphone'],
  });
  const page = await context.newPage();

  page.on('pageerror', (e) => problem(`uncaught error: ${String(e).split('\n')[0]}`));
  page.on('console', (m) => {
    if (m.type() !== 'error') return;
    problem(`console error: ${m.text().slice(0, 300)}`);
  });
  page.on('response', (r) => {
    if (r.url().startsWith(origin) && r.status() >= 400) {
      problem(`${r.status()} for ${r.url().slice(origin.length)}`);
    }
  });

  let n = 0;
  const shot = async (name) => {
    if (!shots) return;
    fs.mkdirSync(shots, { recursive: true });
    await page.screenshot({ path: path.join(shots, `${String(++n).padStart(2, '0')}-${name}.png`) });
  };

  // Every labelled node of the accessibility tree: [role, label].
  const nodes = () =>
    page.$$eval('flt-semantics', (els) =>
      els
        .map((e) => [e.getAttribute('role') || '', e.getAttribute('aria-label') || e.textContent || ''])
        .filter(([, label]) => label),
    );
  const has = async (text) => (await nodes()).some(([, label]) => label.includes(text));
  const waitFor = async (text, what, timeout = 30000) => {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      if (await has(text)) return;
      await page.waitForTimeout(250);
    }
    const seen = (await nodes()).map(([role, label]) => `${role}:${label.slice(0, 40)}`);
    throw new Error(`${what}: no "${text}" within ${timeout / 1000}s; saw ${JSON.stringify(seen).slice(0, 600)}`);
  };
  // Presses the first node whose label has [text], at its centre.
  const press = async (text, roles = ['button', 'tab', 'checkbox', 'radio']) => {
    await waitFor(text, `press ${text}`, 15000);
    const box = await page.evaluateHandle(
      ([t, rs]) => {
        for (const e of document.querySelectorAll('flt-semantics')) {
          const label = e.getAttribute('aria-label') || e.textContent || '';
          if (rs.includes(e.getAttribute('role') || '') && label.includes(t)) return e;
        }
        return null;
      },
      [text, roles],
    );
    const el = box.asElement();
    if (!el) throw new Error(`press ${text}: no such control`);
    const rect = await el.boundingBox();
    await page.mouse.click(rect.x + rect.width / 2, rect.y + rect.height / 2);
    await page.waitForTimeout(700);
  };
  const step = async (name, body) => {
    process.stdout.write(`- ${name}\n`);
    try {
      await body();
    } catch (e) {
      problem(`${name}: ${e.message}`);
      await shot(`failed-${name.replace(/\W+/g, '-')}`);
      throw e;
    }
  };
  const openApp = async () => {
    await page.goto(`${origin}${base}`);
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
    // Flutter builds the accessibility tree once this button is pressed.
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  };
  const scrollDown = async () => {
    await page.mouse.move(215, 450);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(500);
  };

  try {
    await step('the first frame and the title', async () => {
      await openApp();
      const title = await page.title();
      if (title !== 'Fluenough') throw new Error(`title is "${title}"`);
      await waitFor('Get started', 'the welcome page', 60000);
      await shot('welcome');
    });

    await step('the first-launch pages, with the sound check naming the browser', async () => {
      await press('Get started');
      for (let i = 0; i < 4; i++) await press('Next');
      await waitFor('Check your microphone and sound', 'the sound check');
      if (await has('Your phone will ask')) throw new Error('the sound check says "phone" in a browser');
      if (!(await has('Your browser will ask'))) throw new Error('the sound check does not say the browser will ask');
      await shot('sound-check');
      // Records two seconds from the fake microphone, plays them back, and
      // says what became of speaking: on, or no recogniser in this browser.
      await press('Record two seconds');
      await waitFor('Did you hear', 'the playback question', 30000);
      await press('Yes, I heard it');
      await waitFor('Speaking', 'the sound check result', 10000);
      const text = (await nodes()).map(([, label]) => label).join('\n');
      if (!/Speaking is on|speech recogniser/.test(text)) {
        throw new Error('the sound check says nothing about speaking');
      }
      if (/this phone|Your phone/.test(text)) throw new Error('the sound check says "phone" in a browser');
      console.log(`  speaking: ${/Speaking is on/.test(text) ? 'on' : 'no recogniser in this browser'}`);
      await shot('sound-check-result');
      await press('Next');
      await press('Choose my languages');
    });

    await step('choosing a language to learn', async () => {
      await waitFor('Add a language', 'the languages page');
      await press('Add a language');
      await press('Bengali');
      await press('I can only speak Bengali');
      // A skill cycles know, neither, learn.
      await press('Spoken');
      await press('Spoken');
      // Learning a language first checks that its voice plays, and says
      // how it went; either way the dialog is dismissed.
      if (!(await has('Add Bengali'))) {
        await press('Check', ['button']);
        await waitFor('Done', 'the voice check', 30000);
        await press('Done');
      }
      await press('Add Bengali');
      await press('Continue');
    });

    await step('Today, Decks, Progress and Settings are reachable', async () => {
      // The first decks are downloaded from GitHub first.
      await waitFor('Today', 'the tab bar', 150000);
      await page.waitForTimeout(1000);
      const tabs = [
        ['Today', 'Start'],
        ['Decks', 'hours left'],
        ['Progress', 'No reviews yet'],
        ['Settings', 'Support'],
      ];
      for (const [tab, marker] of tabs) {
        await press(tab, ['tab']);
        if (tab === 'Settings') {
          for (let i = 0; i < 8 && !(await has('Support')); i++) await scrollDown();
        }
        await waitFor(marker, `the ${tab} tab`, 20000);
        await shot(`tab-${tab.toLowerCase()}`);
      }
    });

    await step('Settings draws no Reminders or Updates row', async () => {
      // The list builds its rows as they scroll into view: back to the top,
      // then down, noting every label on the way.
      await page.mouse.move(215, 450);
      await page.mouse.wheel(0, -3000);
      await page.waitForTimeout(500);
      const seen = new Set();
      for (let i = 0; i < 8; i++) {
        for (const [, label] of await nodes()) seen.add(label);
        await scrollDown();
      }
      const all = [...seen].join('\n');
      if (!/Your languages/.test(all) || !/Your data/.test(all)) throw new Error('the Your languages or Your data row is missing, so the list was not read');
      if (/Reminders|Daily reminder/.test(all)) throw new Error('Settings draws Reminders in a browser');
      if (/\bUpdates\b/.test(all)) throw new Error('Settings draws Updates in a browser');
    });

    await step('a reload opens the app on Today: progress and settings are kept', async () => {
      await openApp();
      await waitFor('Today', 'the tab bar after a reload', 60000);
      if (await has('Get started')) throw new Error('first launch again after a reload');
    });

    await step('the manifest and the service worker do not get in the way', async () => {
      const manifest = await page.evaluate(async (b) => {
        const link = document.querySelector('link[rel="manifest"]');
        if (!link) return { error: 'no <link rel="manifest">' };
        const r = await fetch(link.href);
        if (!r.ok) return { error: `manifest ${r.status}` };
        return r.json();
      }, base);
      if (manifest.error) throw new Error(manifest.error);
      for (const key of ['name', 'start_url', 'display', 'icons']) {
        if (!manifest[key] || (Array.isArray(manifest[key]) && !manifest[key].length)) {
          throw new Error(`manifest has no ${key}`);
        }
      }
      for (const icon of manifest.icons) {
        const r = await page.request.get(new URL(icon.src, `${origin}${base}`).toString());
        if (!r.ok()) throw new Error(`icon ${icon.src} is ${r.status()}`);
      }
      // A page under a service worker must still be there offline; one
      // without (the worker is not registered yet) is left alone.
      const controlled = await page.evaluate(async () => {
        if (!('serviceWorker' in navigator)) return false;
        const registrations = await navigator.serviceWorker.getRegistrations();
        return registrations.some((r) => r.active) && !!navigator.serviceWorker.controller;
      });
      console.log(`  service worker controls the page: ${controlled}`);
      if (controlled) {
        await context.setOffline(true);
        await openApp();
        await waitFor('Today', 'the app offline, under its service worker', 60000);
        await context.setOffline(false);
      }
    });
  } catch (e) {
    console.log(`stopped: ${e.message}`);
  }

  await browser.close();
  server.close();
  if (problems.length) {
    console.log(`\n${problems.length} problem(s):`);
    for (const p of problems) console.log(`  - ${p}`);
    process.exit(1);
  }
  console.log('\nThe web app passed its smoke test.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
