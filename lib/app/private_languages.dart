import '../core/data/review_erasure.dart';
import '../core/data/spoken_languages.dart';
import '../core/decks/font_check.dart';
import '../core/decks/language_directory.dart';
import '../core/logs/log_entry.dart';
import '../core/models/deck.dart';
import '../core/private/private_check.dart';
import '../core/private/private_export.dart';
import '../core/private/private_ids.dart';
import '../core/private/private_manifest.dart';
import '../core/private/private_package.dart';
import '../core/private/private_starter.dart';
import 'app_info.dart';
import 'app_state.dart';
import 'backups.dart';
import 'private_capabilities.dart';
import 'private_import.dart';
import 'private_store.dart';

/// What came of offering a file to save: the learner saved it, cancelled the
/// dialog, or something went wrong (told in the app log).
enum PrivateSave { saved, cancelled, failed }

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
    bool allowLowerRevision = false,
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
      allowLowerRevision: allowLowerRevision,
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
      if (deleteProgress) {
        await deletePrivateProgress(id);
      }
      final removed = await store.remove(id);
      if (removed) {
        log.event('Private decks: removed $id');
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

  /// Offers the installed package [id] to the learner to save as a `.fnzip`
  /// (Plan-Private-Languages task 19): the same file imports on another
  /// phone.
  Future<PrivateSave> exportPrivate(String id) async {
    final store = privateStore;
    if (store == null) return PrivateSave.failed;
    try {
      final package = (await store.packages())
          .where((p) => p.id == id)
          .firstOrNull;
      final files = await store.readPackage(id);
      if (package == null || files == null) return PrivateSave.failed;
      final saved = await backups.saveFile(
        PrivateExport.fileName(id, package.revision),
        PrivateExport.archive(files),
      );
      if (saved) log.event('Private decks: exported $id');
      return saved ? PrivateSave.saved : PrivateSave.cancelled;
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: export failed', e, stack));
      return PrivateSave.failed;
    }
  }

  /// The courses of the app a learner can download to change: each language
  /// that has decks of the app's own on the phone, with how many.
  List<({LanguageInfo language, int decks})> downloadableCourses() {
    final counts = <String, ({LanguageInfo language, int decks})>{};
    for (final entry in allDecks) {
      if (!entry.bundled) continue;
      final earlier = counts[entry.language.code];
      counts[entry.language.code] = (
        language: earlier?.language ?? entry.language,
        decks: (earlier?.decks ?? 0) + 1,
      );
    }
    return counts.values.toList()
      ..sort((a, b) => a.language.name.compareTo(b.language.name));
  }

  /// Makes the package that lets a learner change the course of [language]
  /// ([PrivateExport.fromBuiltIn]) from the course's files on the phone.
  /// Null, after logging, when they cannot be read or none could be copied.
  Future<PrivateExportResult?> buildCoursePackage(LanguageInfo language) async {
    try {
      final source = deckCatalog.source;
      final prefix = 'decks/${language.code}/';
      final files = <String, String>{};
      for (final path in await source.list()) {
        if (path.startsWith(prefix)) files[path] = await source.read(path);
      }
      final result = PrivateExport.fromBuiltIn(
        language: language,
        files: files,
        basedOn: '${language.code}-${AppInfo.version}',
      );
      if (result.decks == 0) {
        log.warning('Private decks: no deck of ${language.code} to copy');
        return null;
      }
      return result;
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: course copy failed', e, stack));
      return null;
    }
  }

  /// Offers the course of [language] to the learner as a `.fnzip` to change
  /// and import again (Download a course to change, task 19). Returns what
  /// was made and whether the learner saved it (`saved` false too when it
  /// was `tooBig` for a package), or null when nothing could be made.
  Future<({PrivateExportResult package, bool saved, bool tooBig})?>
  downloadCourse(LanguageInfo language) async {
    final package = await buildCoursePackage(language);
    if (package == null) return null;
    try {
      final bytes = PrivateExport.archive(package.files);
      if (bytes.length > privateArchiveMaxBytes) {
        log.warning(
          'Private decks: the course ${language.code} is ${bytes.length} '
          'bytes, over the $privateArchiveMaxBytes limit',
        );
        return (package: package, saved: false, tooBig: true);
      }
      final saved = await backups.saveFile(
        PrivateExport.fileName(packageIdFor(language.code), 1),
        bytes,
      );
      if (saved) log.event('Private decks: downloaded ${language.code}');
      return (package: package, saved: saved, tooBig: false);
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: course save failed', e, stack));
      return null;
    }
  }

  /// Offers the starter package (task 21) to save.
  Future<PrivateSave> saveStarterPackage() async {
    try {
      final saved = await backups.saveFile(
        privateStarterFileName,
        privateStarterArchive(),
      );
      return saved ? PrivateSave.saved : PrivateSave.cancelled;
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: starter failed', e, stack));
      return PrivateSave.failed;
    }
  }

  /// The packages on the phone and the retired ids of removed ones, as a
  /// backup carries them (task 20). A package that cannot be read is
  /// logged and left out.
  Future<PrivateSnapshot> privateBackupSnapshot() async {
    final store = privateStore;
    if (store == null) {
      return (
        packages: const <BackupPrivatePackage>[],
        tombstones: const <String, List<String>>{},
      );
    }
    final packages = <BackupPrivatePackage>[];
    for (final package in await privatePackages()) {
      try {
        final files = await store.readPackage(package.id);
        if (files == null) {
          log.warning('Private decks: ${package.id} could not be backed up');
          continue;
        }
        var name = package.id;
        try {
          final text = files[privateManifestFile];
          if (text != null) name = PrivateManifest.parse(text).language.name;
        } on FormatException {
          // The name only labels the restore screen.
        }
        packages.add(
          BackupPrivatePackage(
            id: package.id,
            name: name,
            revision: package.revision,
            kind: package.kind,
            active: package.active,
            archive: PrivateExport.archive(files),
            retired: package.retired,
          ),
        );
      } on Object catch (e, stack) {
        log.error(
          describeError('Private decks: backup of a package', e, stack),
        );
      }
    }
    Map<String, List<String>> tombstones;
    try {
      tombstones = await store.tombstones();
    } on Object catch (e, stack) {
      log.error(describeError('Private decks: backup tombstones', e, stack));
      tombstones = const <String, List<String>>{};
    }
    return (packages: packages, tombstones: tombstones);
  }

  /// Installs the packages of a backup that is being restored (task 20), each
  /// through the same checks as an import: a package that no longer passes
  /// them, or that names another package than the backup says, is left out
  /// and told. A package is installed active as it was, or off when that
  /// would be a fourth. The retired ids the backup carries, and the
  /// tombstones, are kept, so a restore never frees an id to be reused. The
  /// catalog is read again once. Returns how many were installed.
  Future<int> restorePrivatePackages(
    List<BackupPrivatePackage> packages,
    Map<String, List<String>> tombstones,
  ) async {
    final store = privateStore;
    if (store == null) {
      log.warning(
        'Private decks: a backup has packages; none can be kept here',
      );
      return 0;
    }
    var installed = 0;
    for (final entry in tombstones.entries) {
      try {
        await store.addTombstone(entry.key, entry.value);
      } on Object catch (e, stack) {
        log.error(describeError('Private decks: restore tombstone', e, stack));
      }
    }
    for (final package in packages) {
      try {
        final staging = await stagePrivateBytes(
          package.archive,
          allowLowerRevision: true,
        );
        final manifest = staging.manifest;
        if (manifest == null ||
            !staging.canInstall ||
            manifest.package != package.id) {
          log.warning(
            'Private decks: ${package.id} from a backup was left out, '
            '${staging.errors.length} errors',
          );
          continue;
        }
        final retired = <String>{
          ...staging.retired,
          ...package.retired,
          ...?tombstones[package.id],
        }.toList()..sort();
        final merged = PrivateStaging(
          findings: staging.findings,
          manifest: manifest,
          files: staging.files,
          counts: staging.counts,
          retired: retired,
          dropped: staging.dropped,
        );
        var result = await installStaged(
          merged,
          store: store,
          active: package.active,
          log: log,
        );
        if (result.outcome == PrivateImportOutcome.needsDeactivation) {
          result = await installStaged(
            merged,
            store: store,
            active: false,
            log: log,
          );
        }
        if (result.installed) installed++;
      } on Object catch (e, stack) {
        log.error(
          describeError('Private decks: restore of a package', e, stack),
        );
      }
    }
    if (installed > 0) await _reloadPrivate();
    log.event('Private decks: restored $installed of ${packages.length}');
    return installed;
  }
}
