import '../core/data/review_erasure.dart';
import '../core/data/spoken_languages.dart';
import '../core/decks/font_check.dart';
import '../core/decks/language_directory.dart';
import '../core/logs/log_entry.dart';
import '../core/models/deck.dart';
import '../core/private/private_check.dart';
import '../core/private/private_manifest.dart';
import '../core/private/private_package.dart';
import 'app_info.dart';
import 'app_state.dart';
import 'backups.dart';
import 'private_capabilities.dart';
import 'private_import.dart';
import 'private_store.dart';

/// What the learner does with private language packages (#1017), on top of
/// the store and the import: each step reads the catalog again afterwards, so
/// that Languages, Today and the drills see the change, and each guards what
/// can go wrong and logs it (counts and ids only, never a package's text).
extension PrivateLanguagesOnState on AppState {
  /// Where the packages are kept, or null where none can be (the web build,
  /// most tests).
  PrivateStore? get privateStore => deckCatalog.privateStore;

  /// Whether a private package can be added here.
  bool get canAddPrivate => privateStore != null;

  /// Every installed package, active or not, by id. Empty without a store.
  Future<List<PrivatePackage>> privatePackages() async {
    final store = privateStore;
    if (store == null) return const <PrivatePackage>[];
    try {
      return await store.packages();
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: could not list', e, stack));
      return const <PrivatePackage>[];
    }
  }

  /// The manifests of the active packages: what the language directory
  /// merges. A package whose manifest cannot be read is left out, and told.
  Future<List<PrivateManifest>> activePrivateManifests() async {
    final store = privateStore;
    if (store == null) return const <PrivateManifest>[];
    final manifests = <PrivateManifest>[];
    for (final package in await privatePackages()) {
      if (!package.active) continue;
      final manifest = await manifestOf(package.id);
      if (manifest != null) manifests.add(manifest);
    }
    return manifests;
  }

  /// The manifest of the installed package [id], or null when it cannot be
  /// read.
  Future<PrivateManifest?> manifestOf(String id) async {
    final store = privateStore;
    if (store == null) return null;
    try {
      return PrivateManifest.parse(
        await store.read('$privateDeckPrefix$id/$privateManifestName'),
      );
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: manifest of $id', e, stack));
      return null;
    }
  }

  /// The built-in language list with the active packages merged in: what
  /// every screen that names a language reads (task 8).
  Future<List<SpokenLanguage>> languageDirectory(
    List<SpokenLanguage> builtIn,
  ) async => mergeLanguageDirectory(builtIn, await activePrivateManifests());

  /// Opens and checks the bytes of a `.fnzip`, installing nothing. The
  /// built-in decks that a modified language names are the catalog's own.
  Future<PrivateStaging> stagePrivateBytes(
    List<int> bytes, {
    Set<String>? builtInLanguages,
  }) async {
    final store = privateStore;
    if (store == null) {
      return const PrivateStaging(
        findings: <PrivateFinding>[
          PrivateFinding(
            severity: FindingSeverity.error,
            token: 'manifestInvalid',
            params: <String, String>{
              'detail': 'private packages cannot be added here',
            },
          ),
        ],
      );
    }
    return stagePrivateArchive(
      bytes,
      store: store,
      appVersion: AppInfo.version,
      // The decks of the course on the phone, which a modified language's
      // path may name (layers are named by no path, so listing them is
      // harmless).
      builtInCoreIds: <String>{
        for (final entry in allDecks)
          if (entry.bundled) entry.id,
      },
      builtInLanguages: builtInLanguages,
      log: log,
    );
  }

  /// Installs a package [staging] found no error in, then reads the catalog
  /// again. [active] false installs it off (the learner chose which package
  /// to turn off in the fourth-package sheet).
  Future<PrivateImportResult> installPrivate(
    PrivateStaging staging, {
    bool? active,
  }) async {
    final store = privateStore;
    if (store == null) {
      return const PrivateImportResult(outcome: PrivateImportOutcome.refused);
    }
    final result = await installStaged(
      staging,
      store: store,
      active: active,
      log: log,
    );
    if (result.installed) await _reloadPrivate();
    return result;
  }

  /// Turns the package [id] on or off. Turning one on with three already on
  /// changes nothing and says so ([PrivateActivation.needsDeactivation]).
  Future<PrivateActivation> setPrivateActive(
    String id, {
    required bool active,
  }) async {
    final store = privateStore;
    if (store == null) return PrivateActivation.failed;
    try {
      final PrivateActivation done;
      if (active) {
        done = await store.activate(id);
      } else {
        done = await store.deactivate(id)
            ? PrivateActivation.done
            : PrivateActivation.failed;
      }
      if (done == PrivateActivation.done) {
        log.event('Private decks: $id ${active ? 'on' : 'off'}');
        await _reloadPrivate();
      }
      return done;
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: switch failed', e, stack));
      return PrivateActivation.failed;
    }
  }

  /// Turns [off] off and [on] on, in that order, for the fourth-package
  /// sheet. True when both happened.
  Future<bool> swapPrivate({required String off, required String on}) async {
    if (await setPrivateActive(off, active: false) != PrivateActivation.done) {
      return false;
    }
    return await setPrivateActive(on, active: true) == PrivateActivation.done;
  }

  /// Removes the package [id]: its files go, its review history stays
  /// (ADR-0020). With [deleteProgress] the reviews of its cards go too, after
  /// a backup of everything is kept (the second choice of Remove, owner,
  /// 2026-11-13). True when the package was removed.
  Future<bool> removePrivate(String id, {bool deleteProgress = false}) async {
    final store = privateStore;
    if (store == null) return false;
    try {
      // Progress goes only after the package is gone: a failed removal must
      // not cost the learner their reviews. (The backup inside
      // [deletePrivateProgress] is still kept before anything is erased.)
      final removed = await store.remove(id);
      if (removed) {
        log.event('Private decks: removed $id');
        if (deleteProgress) await deletePrivateProgress(id);
        await _reloadPrivate();
      }
      return removed;
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: remove failed', e, stack));
      return false;
    }
  }

  /// Deletes the reviews of the package [id]'s cards (`fnpd-<code>-`), and
  /// nothing of the built-in course of the same code. A backup of everything
  /// is kept first ([BackupKind.delete]): if it cannot be kept this throws and
  /// nothing has changed. Returns how many reviews went.
  Future<int> deletePrivateProgress(String id) async {
    final code = id.startsWith('fnpd-') ? id.substring('fnpd-'.length) : id;
    await progress.ready;
    await backups.keep(BackupKind.delete);
    final removed = await progress.eraseReviews(
      ReviewErasure.privatePackage(code),
    );
    settings.todaySummary = null;
    log.event('Private decks: progress of $id deleted, $removed reviews');
    return removed;
  }

  Future<void> _reloadPrivate() async {
    try {
      await reloadDecks();
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: reload failed', e, stack));
    }
  }

  /// When the learner last answered a card of the package [id], or null if
  /// never: for "least recently studied".
  DateTime? privateLastStudied(String id) {
    final prefix = '$id-';
    final log = progress.log;
    for (var i = log.length - 1; i >= 0; i--) {
      if (log[i].cardId.startsWith(prefix)) return log[i].at;
    }
    return null;
  }

  /// The active packages, the one studied least recently first (never
  /// studied before any): the order of the fourth-package sheet, whose first
  /// row is preselected.
  Future<List<PrivatePackage>> privateLeastRecentlyStudied(
    Iterable<PrivatePackage> active,
  ) async {
    final times = <String, DateTime?>{
      for (final p in active) p.id: privateLastStudied(p.id),
    };
    final ordered = active.toList()
      ..sort((a, b) {
        final x = times[a.id];
        final y = times[b.id];
        if (x == null && y == null) return a.id.compareTo(b.id);
        if (x == null) return -1;
        if (y == null) return 1;
        final byTime = x.compareTo(y);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return ordered;
  }

  /// Whether [code] is the language of an active private package's decks.
  bool isPrivateLanguage(String code) => derived<bool>((
    'privateLanguage',
    code,
  ), () => decks.any((d) => d.private && d.language.code == code));

  /// What the phone can do for the private language [language]: a voice, a
  /// recogniser, and whether its script shows as boxes (task 14).
  PrivateCapabilities privateCapabilities(LanguageInfo language) =>
      PrivateCapabilities(
        voice: voiceStatus(language),
        recogniser: speechStatus(language),
        fontBoxes: <String>[
          for (final script in language.allScripts)
            if (scriptSamples.containsKey(script)) script,
        ].any((s) => settings.fontChoice(s) == FontChoice.boxes),
      );

  /// Whether speaking and sound drills are hidden for [language] because it
  /// is a private language and the phone has no voice for it.
  bool privateNoVoice(LanguageInfo language) =>
      isPrivateLanguage(language.code) &&
      voiceStatus(language) == VoiceStatus.missing;
}
