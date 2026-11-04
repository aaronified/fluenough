/// Asks the browser to keep this site's storage, on the web build only.
///
/// Safari on iOS deletes a site's data (the progress database, settings)
/// after 7 days without a visit, unless the page is installed to the home
/// screen, which exempts it. `navigator.storage.persist()` asks for it to
/// be kept; Safari decides for itself, with no prompt, and may say no, so it
/// is only a best effort. Elsewhere this does nothing (#1012).
library;

import 'storage_persist_stub.dart'
    if (dart.library.js_interop) 'storage_persist_web.dart'
    as impl;

/// Asks once, at start. Never throws: a browser without the call, or one
/// that refuses it, is the same as one that says no. Returns whether the
/// browser said yes.
Future<bool> requestPersistentStorage() => impl.requestPersistentStorage();
