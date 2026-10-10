import 'dart:async';
import 'dart:io';

/// Answers one request in place of the network, so that no test reaches
/// GitHub: [reply] gives the status and the body's bytes, and never
/// answers if it never completes. Records what was asked and sent.
///
/// Use it through [withFakeClient].
class FakeHttpClient implements HttpClient {
  FakeHttpClient(this.reply);

  final Future<(int, List<int>)> Function() reply;

  /// The address asked for.
  Uri? asked;

  /// The headers sent, by name.
  final Map<String, Object> sent = <String, Object>{};

  /// Whether the client was closed, as a fetch must when it is done.
  bool closed = false;

  /// The length the reply claims, when not its body's: a body cut short.
  int? contentLength;

  /// Whether the reply came gzipped and was unzipped on arrival, as
  /// GitHub's are: its [contentLength] is then the compressed size.
  bool compressed = false;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    asked = url;
    return _FakeRequest(this);
  }

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.client);

  final FakeHttpClient client;

  @override
  HttpHeaders get headers => _FakeHeaders(client.sent);

  @override
  Future<HttpClientResponse> close() async {
    final (status, bytes) = await client.reply();
    return _FakeResponse(
      status,
      bytes,
      contentLength: client.contentLength ?? bytes.length,
      compressionState: client.compressed
          ? HttpClientResponseCompressionState.decompressed
          : HttpClientResponseCompressionState.notCompressed,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  _FakeHeaders(this.sent);

  final Map<String, Object> sent;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      sent[name] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(
    this.statusCode,
    this.bytes, {
    required this.contentLength,
    required this.compressionState,
  });

  @override
  final HttpClientResponseCompressionState compressionState;

  @override
  final int statusCode;
  final List<int> bytes;

  @override
  final int contentLength;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs [body] with every [HttpClient] it makes replaced by [client].
Future<T> withFakeClient<T>(FakeHttpClient client, Future<T> Function() body) =>
    HttpOverrides.runZoned(body, createHttpClient: (_) => client);
