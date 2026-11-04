/// The browser's persistent [BlobStore], where there is one (#1012).
///
/// [openBrowserBlobStore] is the web implementation where `dart:js_interop`
/// exists, which is only in a browser build; anywhere else, such as the
/// Dart VM that runs the tests, it is a stub that answers null, so nothing
/// that is browser-only is ever compiled there.
library;

export 'browser_blob_store_stub.dart'
    if (dart.library.js_interop) 'browser_blob_store_web.dart';
