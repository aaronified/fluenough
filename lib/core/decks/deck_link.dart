import 'dart:convert';

import 'package:http/http.dart' as http;

/// Why a deck link could not be turned into the deck's text (#22).
enum LinkFailure {
  /// What was typed is not a web address.
  notALink,

  /// The address, or a redirect on the way, is not `https`.
  notHttps,

  /// The site could not be reached, or the connection broke part-way, or it
  /// took too long.
  offline,

  /// The site has nothing at that address.
  notFound,

  /// The site refused the request, or says there have been too many.
  refused,

  /// The reply is larger than a deck may be.
  tooLarge,

  /// The reply is not text.
  notText,

  /// The site answered with another error, or redirected too often.
  badReply,
}

/// The text a link gave, or why there is none.
class LinkFetched {
  const LinkFetched(String this.text) : failure = null, cause = null;

  const LinkFetched.failed(LinkFailure this.failure, {this.cause})
    : text = null;

  final String? text;
  final LinkFailure? failure;

  /// The exception's type behind a [LinkFailure.offline], for the log. The
  /// learner sees only [failure].
  final String? cause;
}

/// The address typed into the link field, or why it is not usable.
typedef DeckLinkParse = ({Uri? uri, LinkFailure? failure});

const DeckLinkParse _notALink = (uri: null, failure: LinkFailure.notALink);
const DeckLinkParse _notHttps = (uri: null, failure: LinkFailure.notHttps);

/// Reads [input] as the address of a deck file.
///
/// Only `https` is accepted. A link to a file's page on github.com
/// (`/blob/`) is turned into the link to the file itself on
/// raw.githubusercontent.com, which is what the learner meant.
DeckLinkParse parseDeckLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return _notALink;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http') return _notHttps;
  if (scheme != 'https' || uri.userInfo.isNotEmpty) return _notALink;
  return (uri: _rawGitHub(uri), failure: null);
}

/// `https://github.com/o/r/blob/ref/path` as the raw file's address; any
/// other address as it is.
Uri _rawGitHub(Uri uri) {
  final parts = uri.pathSegments;
  if (uri.host.toLowerCase() != 'github.com' ||
      parts.length < 5 ||
      parts[2] != 'blob') {
    return uri;
  }
  final path = <String>[parts[0], parts[1], ...parts.skip(3)].join('/');
  return Uri.https('raw.githubusercontent.com', path);
}

/// The name a deck fetched from [uri] is called in messages: the last part
/// of its path, or its host.
String deckLinkName(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty);
  return segments.isEmpty ? uri.host : segments.last;
}

/// Where a linked deck is downloaded from. Narrow enough that tests fake
/// it; only `main.dart` names the one that reaches the network.
abstract interface class DeckLinkFetcher {
  /// Downloads the deck at [uri], an `https` address. Never throws: a
  /// failure is a [LinkFetched.failed]. The text is only text: nothing in it
  /// is run.
  Future<LinkFetched> fetch(Uri uri);
}

/// No network: every link fails as [LinkFailure.offline]. The default, so
/// that no test or gallery state reaches the network.
class NullDeckLinkFetcher implements DeckLinkFetcher {
  const NullDeckLinkFetcher();

  @override
  Future<LinkFetched> fetch(Uri uri) async =>
      const LinkFetched.failed(LinkFailure.offline);
}

/// [DeckLinkFetcher] over `package:http`, which reaches the network in the
/// app and the browser alike.
///
/// A deck is untrusted input: only `https` is fetched, every redirect is
/// followed by hand and must stay on `https`, the reply is cut off at
/// [maxBytes], the whole request ends at [timeout], and the reply is decoded
/// as text and never run.
class HttpDeckLinkFetcher implements DeckLinkFetcher {
  HttpDeckLinkFetcher({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.maxBytes = 2 * 1024 * 1024,
    this.maxRedirects = 5,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// How long the whole download may take, from connecting to the last byte.
  final Duration timeout;

  /// The most a deck file may be. The largest deck is far under it.
  final int maxBytes;

  /// How many redirects are followed before giving up.
  final int maxRedirects;

  @override
  Future<LinkFetched> fetch(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'https') {
      return const LinkFetched.failed(LinkFailure.notHttps);
    }
    try {
      return await _get(uri).timeout(timeout);
    } catch (e) {
      // No network, no DNS, a failed TLS handshake, the connection closing
      // part-way, or the timeout.
      return LinkFetched.failed(
        LinkFailure.offline,
        cause: e.runtimeType.toString(),
      );
    }
  }

  Future<LinkFetched> _get(Uri start) async {
    var uri = start;
    for (var hop = 0; hop <= maxRedirects; hop++) {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client.send(request);
      final status = response.statusCode;
      if (status >= 300 && status < 400) {
        final location = response.headers['location'];
        // Drain, so the connection closes cleanly.
        await response.stream.drain<void>().catchError((_) {});
        final next = location == null ? null : Uri.tryParse(location);
        if (next == null) {
          return const LinkFetched.failed(LinkFailure.badReply);
        }
        uri = uri.resolveUri(next);
        if (uri.scheme.toLowerCase() != 'https') {
          return const LinkFetched.failed(LinkFailure.notHttps);
        }
        continue;
      }
      if (status != 200) {
        await response.stream.drain<void>().catchError((_) {});
        return LinkFetched.failed(failureFor(status));
      }
      final claimed = response.contentLength;
      if (claimed != null && claimed > maxBytes) {
        await response.stream.drain<void>().catchError((_) {});
        return const LinkFetched.failed(LinkFailure.tooLarge);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          return const LinkFetched.failed(LinkFailure.tooLarge);
        }
      }
      return _text(bytes);
    }
    return const LinkFetched.failed(LinkFailure.badReply);
  }

  /// [bytes] as the deck's text, without a leading byte-order mark.
  static LinkFetched _text(List<int> bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return const LinkFetched.failed(LinkFailure.notText);
    }
    return LinkFetched(text.startsWith('﻿') ? text.substring(1) : text);
  }

  /// What an HTTP [status] other than 200 means here.
  static LinkFailure failureFor(int status) => switch (status) {
    404 || 410 => LinkFailure.notFound,
    401 || 403 || 429 => LinkFailure.refused,
    _ => LinkFailure.badReply,
  };
}
