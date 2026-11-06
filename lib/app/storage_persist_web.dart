import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `navigator.storage.persist()`, guarded: a browser with no `storage`
/// (an old one, or a page in a context that has none) or one whose promise
/// rejects gives false.
Future<bool> requestPersistentStorage() async {
  try {
    final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
    final storage = navigator?.getProperty<JSObject?>('storage'.toJS);
    if (storage == null || !storage.has('persist')) return false;
    final granted = await storage
        .callMethod<JSPromise<JSBoolean>>('persist'.toJS)
        .toDart;
    return granted.toDart;
  } on Object {
    return false;
  }
}
