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

  /// Where reports from the app go (#160): the Fluenough Gmail, which
  /// `tools/mail_to_issues.py` reads.
  static const String feedbackEmail = 'fluenough@gmail.com';

  /// GitHub's form for a new issue, its body filled in with [body]: where
  /// every report button goes while mail reports are incoming (#160).
  static Uri newIssue(String body) => Uri.https(
    'github.com',
    '/aaronified/fluenough/issues/new',
    <String, String>{'body': body},
  );

  /// Where tips go, as a UPI ID, and the name it is registered to. UPI is
  /// India's payment system; the ID is the same in every UPI app.
  static const String supportUpiId = 'das.arani@pingpay';
  static const String supportName = 'Arani Das';

  /// A UPI payment to [supportUpiId], with no amount: the learner chooses it
  /// in their UPI app. Built by hand because [Uri] would write the `@` as
  /// `%40` and the space as `+`, which some UPI apps do not read.
  static final String supportUpi =
      'upi://pay?pa=$supportUpiId&pn=${Uri.encodeComponent(supportName)}';

  /// The newest release's APK (ADR-0017). GitHub redirects this to the file
  /// of that name on the newest release, which the release workflow builds.
  static const String latestApk =
      'https://github.com/aaronified/fluenough/releases/latest/download/app-release.apk';

  /// The newest release's page, for downloading it in the browser when the
  /// app cannot install it.
  static const String latestRelease =
      'https://github.com/aaronified/fluenough/releases/latest';

  /// How to contribute a change to a deck on GitHub (the wiki's
  /// Contributing page): where a new theme or unit goes, by pull request
  /// (#477).
  static const String contribute =
      'https://github.com/aaronified/fluenough/wiki/Contributing';

  /// English Wiktionary, credited for the narrow IPA in a card's `phonetic`.
  static const String wiktionary = 'https://en.wiktionary.org';

  /// The CC BY-SA 4.0 licence, which the decks and Wiktionary's data are
  /// under.
  static const String ccBySa =
      'https://creativecommons.org/licenses/by-sa/4.0/';

  /// Every release's page, where "What's new" sends the learner for the
  /// releases it does not list.
  static const String releases =
      'https://github.com/aaronified/fluenough/releases';
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
