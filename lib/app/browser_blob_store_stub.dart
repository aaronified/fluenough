import 'blob_store.dart';

/// No browser storage off the web: null, so the decks stay in memory.
Future<BlobStore?> openBrowserBlobStore({String name = ''}) async => null;
