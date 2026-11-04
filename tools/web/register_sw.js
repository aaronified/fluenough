// Registers sw.js and tells it which files the page has loaded, so the first
// visit fills the cache too (tools/web/sw.js). Appended to flutter_bootstrap.js
// by tools/brand_web.py. Nothing here may stop the app from starting.
(function () {
  if (!('serviceWorker' in navigator)) return;
  var sent = {};
  function listLoaded() {
    try {
      return performance.getEntriesByType('resource')
        .map(function (e) { return e.name; })
        .filter(function (u) { return u.indexOf(location.origin) === 0 && !sent[u]; });
    } catch (e) {
      return [];
    }
  }
  function send() {
    navigator.serviceWorker.ready.then(function (reg) {
      var worker = reg.active;
      var urls = listLoaded();
      if (!worker || !urls.length) return;
      urls.forEach(function (u) { sent[u] = true; });
      worker.postMessage({ type: 'cache-loaded', urls: urls });
    }).catch(function () {});
  }
  navigator.serviceWorker.register('sw.js').then(function () {
    send();
    document.addEventListener('flutter-first-frame', send);
    if (document.readyState === 'complete') {
      setTimeout(send, 3000);
    } else {
      window.addEventListener('load', function () { setTimeout(send, 3000); });
    }
  }).catch(function (e) {
    console.warn('Service worker not registered:', e);
  });
})();
