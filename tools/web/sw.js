'use strict';

// Fluenough's service worker (#1012, wiki: Plan-Web-Pwa). It keeps the app
// shell, the page, the script, the engine's wasm, the icons and the fonts,
// so the app opens with no network after one visit.
//
// Flutter 3.47's own flutter_service_worker.js caches nothing: it unregisters
// itself, so this is written by hand. tools/brand_web.py copies it to web/.
//
// - Same-origin GET requests only. The deck downloads come from another
//   origin (raw.githubusercontent.com) and are kept by the app in IndexedDB
//   (lib/app/stored_downloaded_decks.dart), so they are never touched here.
// - Network first, the cache as fallback: the shell files have no hash in
//   their names, so a cache-first worker would serve an old build for ever.
// - The page tells the worker which files it has loaded so far
//   ('cache-loaded'), which fills the cache on the very first visit too.

// Bump the number to drop every older cache on the next visit.
const CACHE = 'fluenough-shell-v1';
const PREFIX = 'fluenough-shell-';

// Fetched on install, so a reload with no network finds the page itself
// before the page has had a chance to list anything.
const SHELL = ['./', 'index.html', 'flutter_bootstrap.js', 'manifest.json'];

// How long a cached copy waits for a slow network before it is used.
const NETWORK_WAIT_MS = 5000;

const scope = new URL(self.registration.scope);

function inScope(url) {
  return url.origin === scope.origin && url.pathname.startsWith(scope.pathname);
}

// Deck files are never kept here, even if they were served from this origin.
function isDeckFile(url) {
  return url.pathname.startsWith(scope.pathname + 'decks/');
}

function cacheable(request) {
  if (request.method !== 'GET' || request.headers.has('range')) return false;
  const url = new URL(request.url);
  return inScope(url) && !isDeckFile(url);
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      // One missing file must not stop the worker from installing.
      await Promise.allSettled(SHELL.map((path) => cache.add(path)));
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const name of await caches.keys()) {
        if (name.startsWith(PREFIX) && name !== CACHE) await caches.delete(name);
      }
      await self.clients.claim();
    })()
  );
});

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  // A reload of the page, with or without ?query, falls back to the page.
  const cached = async () =>
    (await cache.match(request, { ignoreSearch: true })) ||
    (request.mode === 'navigate' ? await cache.match('index.html') : undefined);
  const fresh = fetch(request).then(async (response) => {
    if (response.ok && response.type === 'basic') {
      await cache.put(request, response.clone());
    }
    return response;
  });
  const old = await cached();
  if (!old) return fresh;
  // A cached copy exists: use it if the network fails or is very slow.
  fresh.catch(() => {});
  return Promise.race([
    fresh.catch(() => old),
    new Promise((resolve) => setTimeout(() => resolve(old), NETWORK_WAIT_MS)),
  ]);
}

self.addEventListener('fetch', (event) => {
  if (!cacheable(event.request)) return;
  event.respondWith(
    networkFirst(event.request).catch(() => Response.error())
  );
});

self.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.type !== 'cache-loaded' || !Array.isArray(data.urls)) return;
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      for (const href of data.urls) {
        let url;
        try {
          url = new URL(href, scope);
        } catch (e) {
          continue;
        }
        if (!inScope(url) || isDeckFile(url)) continue;
        const request = new Request(url.href);
        if (await cache.match(request)) continue;
        try {
          // Usually answered by the browser's own HTTP cache.
          const response = await fetch(request);
          if (response.ok && response.type === 'basic') {
            await cache.put(request, response);
          }
        } catch (e) {
          // Offline now: the next visit will list it again.
        }
      }
    })()
  );
});
