import 'package:url_launcher/url_launcher.dart';

/// Addresses the app points people to. Not interface text: a URL is the same
/// in every language.
///
/// A link opens through [LinkOpener]: `openLink` in
/// `lib/ui/widgets/snack.dart` opens it, and copies it with a SnackBar when
/// nothing on the phone can open it.
abstract final class AppLinks {
  /// HeliBoard on F-Droid: a free, open-source keyboard with layouts for
  /// Devanagari, kana, Urdu and many more (#25).
  static const String heliboard =
      'https://f-droid.org/packages/helium314.keyboard/';

  /// Where reports from the app go once mail reports are set up (#160):
  /// the Fluenough Gmail. Empty until it exists; `Feature.feedbackMail`
  /// stays incoming until then.
  static const String feedbackEmail = '';

  /// GitHub's form for a new issue, its body filled in with [body]: where
  /// every report button goes while mail reports are incoming (#160).
  static Uri newIssue(String body) => Uri.https(
    'github.com',
    '/aaronified/fluenough/issues/new',
    <String, String>{'body': body},
  );

  /// The newest release's APK (ADR-0017). GitHub redirects this to the file
  /// of that name on the newest release, which the release workflow builds.
  static const String latestApk =
      'https://github.com/aaronified/fluenough/releases/latest/download/app-release.apk';

  /// The newest release's page, for downloading it in the browser when the
  /// app cannot install it.
  static const String latestRelease =
      'https://github.com/aaronified/fluenough/releases/latest';
}

/// Opens a link outside the app. An interface so that tests need no
/// platform.
abstract interface class LinkOpener {
  /// Opens [url] in the browser, or in the app that handles it. False if
  /// nothing could.
  Future<bool> open(String url);
}

/// [LinkOpener] through url_launcher, always in another app, never a view
/// inside this one: F-Droid opens its own pages, and the browser can
/// download a release (ADR-0017).
class LauncherLinks implements LinkOpener {
  const LauncherLinks();

  @override
  Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      return false;
    }
  }
}

/// A [LinkOpener] that opens whatever it is asked to, unless [opens] is
/// false, and records each link. For tests and the gallery.
class FixedLinks implements LinkOpener {
  FixedLinks({this.opens = true});

  /// Whether a link opens. Can change between links.
  bool opens;

  /// Every link asked for, in order, whether or not it opened.
  final List<String> asked = <String>[];

  @override
  Future<bool> open(String url) async {
    asked.add(url);
    return opens;
  }
}
