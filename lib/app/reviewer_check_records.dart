import 'dart:convert';

import '../core/placement/reviewer_check_status.dart';
import 'settings.dart';

/// The reviewer check's record of each course, kept in the settings as one
/// JSON object by language code (ADR-0058, decision 1; W6). Only the facets
/// passed, the time of the last attempt, whether the check was offered and
/// which cards it asked about: never a score.
extension ReviewerCheckRecords on SettingsNotifier {
  Map<String, Object?> get _checks {
    final text = reviewerChecks;
    if (text == null || text.isEmpty) return <String, Object?>{};
    try {
      final json = jsonDecode(text);
      if (json is Map) {
        return <String, Object?>{
          for (final MapEntry(:key, :value) in json.entries)
            if (key is String) key: value,
        };
      }
    } on FormatException {
      // An unreadable record is as good as none.
    }
    return <String, Object?>{};
  }

  /// [language]'s record, empty when the check was never taken or offered.
  ReviewerCheckRecord reviewerCheckOf(String language) =>
      ReviewerCheckRecord.fromJson(_checks[language]);

  /// Keeps [record] as [language]'s.
  void setReviewerCheck(String language, ReviewerCheckRecord record) {
    final next = _checks..[language] = record.toJson();
    reviewerChecks = jsonEncode(next);
  }

  /// The passed-facets flag of [language] went in a review mail.
  void markReviewerCheckMailed(String language) =>
      setReviewerCheck(language, reviewerCheckOf(language).withMailed());
}
