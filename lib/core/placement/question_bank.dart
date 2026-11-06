import 'dart:math' as math;

import 'assurance_model.dart';
import 'generated_question.dart';
import 'guessability.dart';
import 'item_picker.dart';
import 'placement_data.dart';
import 'placement_questions.dart';
import 'question_builder.dart';
import 'question_outcome.dart';

// A question bank: every question the real generators produce for a language
// (several seeded variants per card), with stable ids, so that a role-player
// can answer them without running anything and a replay can look the answers
// up. Pure Dart; tool/placement_bank.dart writes it to JSON.
//
// [BankedBuilder] is the engine's question source in "bank mode": it picks a
// bank question by the rules the real builder picks an item by (the nearest
// deck range with five eligible candidates, the five hardest, the request's
// shortlist pick), never one whose word, family or concept was asked.

/// The key two requests share when they ask for the same kind of question.
String signatureOf(PlacementQuestionRequest request) {
  final role = request.role == PlacementQuestionRole.recheck
      ? PlacementQuestionRole.base
      : request.role;
  return '${role.name}|${request.variant.label}|${request.kind.name}|'
      '${request.skills.map((s) => s.name).join('+')}';
}

/// One question of a bank.
class BankEntry {
  BankEntry({
    required this.id,
    required this.question,
    required this.signature,
    this.origin,
  });

  final String id;
  final GeneratedQuestion question;
  final String signature;

  /// The id of the bank question this split or isolating question checks.
  final String? origin;

  /// The ids that stop an answer card being asked again: the card, its word
  /// families and the concept.
  late final Set<String> answerIds = <String>{
    ?question.cardId,
    for (final id in question.itemIds)
      if (id.startsWith('family:') || id.startsWith('concept:')) id,
  };

  /// Whether the credit posterior counts this question (no cue).
  late final bool counted = (creditBaseOf(question) ?? 0) < 1;

  /// What the model takes the guess rate of this question to be.
  double get guessRate {
    final base = creditBaseOf(question);
    return base == null
        ? question.request.kind.creditBase() + creditKappa
        : (base >= 1 ? 1 : base + creditKappa);
  }

  /// `leaky` (a pick whose answer shows by letters), `clean` (a pick),
  /// `produced` (built or said: not guessable by picking).
  String get guessClass => question.mode != PlacementAnswerMode.pick
      ? 'produced'
      : hasCue(question)
      ? 'leaky'
      : 'clean';

  /// What a role-player sees: no answer.
  Map<String, Object?> toPublicJson() {
    final q = question;
    return <String, Object?>{
      'id': id,
      'type': q.request.variant.label,
      'role': q.request.role.name,
      'skills': <String>[for (final s in q.request.skills) s.name],
      'mode': q.mode.name,
      'unit': q.difficulty.deck + 1,
      'level': const <String>['', 'A1', 'A2', 'B1'][q.difficulty.level],
      'promptKind': q.prompt.name,
      'prompt': q.promptText,
      'reading': q.promptReading,
      'heardText': q.audio?.text,
      'meaningHint': q.meaningHint,
      'options': q.options,
      'optionsAreAudio': q.optionsAreAudio,
      'tiles': q.tiles,
      'joiner': q.joiner,
    };
  }

  /// What the replay and the analysis need: the answer and the metadata.
  Map<String, Object?> toKeyJson() {
    final q = question;
    return <String, Object?>{
      'type': q.request.variant.label,
      'role': q.request.role.name,
      'topic': q.request.topic.name,
      'kind': q.request.kind.name,
      'skills': <String>[for (final s in q.request.skills) s.name],
      'signature': signature,
      'mode': q.mode.name,
      'correctIndex': q.correctIndex,
      'accepted': q.accepted,
      'deck': q.difficulty.deck,
      'unit': q.difficulty.deck + 1,
      'level': q.difficulty.level,
      'score': q.difficulty.score,
      'guessRate': guessRate,
      'guessClass': guessClass,
      'cardId': q.cardId,
      'concept': q.concept,
      'itemIds': (q.itemIds.toList()..sort()),
      'origin': origin,
    };
  }
}

/// What is wrong with [q], or null: a pick needs distinct options and one
/// right index in range; a built or said answer needs an accepted answer.
String? questionFault(GeneratedQuestion q) {
  if (q.mode == PlacementAnswerMode.pick) {
    final right = q.correctIndex;
    if (right == null || right < 0 || right >= q.options.length) {
      return 'no correct option';
    }
    if (q.options.toSet().length != q.options.length) {
      return 'duplicate options';
    }
    return null;
  }
  return q.accepted.isEmpty ? 'no accepted answer' : null;
}

/// A set of questions with their ids.
class QuestionBank {
  QuestionBank(Iterable<BankEntry> entries)
    : entries = List<BankEntry>.unmodifiable(entries) {
    for (final entry in this.entries) {
      byId[entry.id] = entry;
      (bySignature[entry.signature] ??= <BankEntry>[]).add(entry);
    }
  }

  final List<BankEntry> entries;
  final Map<String, BankEntry> byId = <String, BankEntry>{};
  final Map<String, List<BankEntry>> bySignature = <String, List<BankEntry>>{};
}

String _hex(int n) => n.toRadixString(16).padLeft(8, '0');

String _idOf(GeneratedQuestion q, String? origin) {
  final text = <String>[
    q.request.variant.label,
    q.request.role.name,
    q.cardId ?? '',
    q.promptText ?? '',
    ([...q.options]..sort()).join('|'),
    q.tiles.join('|'),
    origin ?? '',
  ].join('\u0001');
  return '${q.request.variant.label.toLowerCase()}-${_hex(stableHash(text))}';
}

PlacementQuestionRequest _request(
  PlacementTopic topic,
  PlacementQuestionRole role,
  PlacementVariant variant,
  PlacementQuestionKind kind,
  List<PlacementSkill> skills,
  int deck,
  int deckCount,
  int pick, {
  PlacementVariant? origin,
}) => PlacementQuestionRequest(
  number: 1,
  role: role,
  topic: topic,
  variant: variant,
  kind: kind,
  skills: skills,
  deck: deck,
  percentile: deckCount <= 1 ? 100 : deck * 100 / (deckCount - 1),
  shortlistPick: pick,
  originVariant: origin,
);

/// The faults found while building the last bank (questions left out).
final List<String> faults = <String>[];

/// Every question the real generators make for [data]: each base question,
/// its two splits (each checking every base question built), the
/// positioning probes, the top-ups, the grammar probes and the isolating
/// questions, at every deck, with [seeds] seeded variants of the options,
/// five shortlist picks each. At most about [maxQuestions] are kept, evenly
/// over decks and kinds, a split always with the question it checks.
QuestionBank buildQuestionBank(
  PlacementLanguageData data, {
  Set<PlacementSkill> tested = const <PlacementSkill>{
    PlacementSkill.read,
    PlacementSkill.hear,
    PlacementSkill.write,
  },
  int seeds = 2,
  int maxQuestions = 4000,
  int deckStride = 1,
  int picks = 5,
  bool onlyProbes = false,
}) {
  final n = data.deckCount;
  final entries = <BankEntry>[];
  final ids = <String>{};
  faults.clear();
  final bases = buildBaseQuestions(tested, microphone: false);
  final bandAsked = <String, Set<String>>{};
  for (var seed = 0; seed < seeds * (onlyProbes ? 6 : 1); seed++) {
    final builder = QuestionBuilder(
      data,
      tested: tested,
      microphone: false,
      seed: seed,
    );
    BankEntry? tagged(
      PlacementQuestionRequest request,
      GeneratedQuestion? failed,
      String? origin,
    ) {
      // A probe or top-up asked again in the same band skips the items
      // already in the bank, so that a band holds many different items.
      final bandKey =
          request.role == PlacementQuestionRole.probe ||
              request.role == PlacementQuestionRole.topUp
          ? '${request.skills.first.name}:${PlacementLevels(n).bandOf(request.deck).to}'
          : null;
      final skip = bandKey == null || !onlyProbes
          ? const <String>{}
          : (bandAsked[bandKey] ??= <String>{});
      final outcome = builder.build(request, asked: skip, failed: failed);
      if (outcome is! QuestionBuilt) return null;
      final q = outcome.question;
      final fault = questionFault(q);
      if (fault != null) {
        faults.add('${q.request.variant.label} ${q.cardId}: $fault');
        return null;
      }
      final entry = BankEntry(
        id: _idOf(q, origin),
        question: GeneratedQuestion(
          request: q.request,
          prompt: q.prompt,
          mode: q.mode,
          difficulty: q.difficulty,
          itemIds: q.itemIds,
          promptText: q.promptText,
          promptReading: q.promptReading,
          audio: q.audio,
          options: q.options,
          correctIndex: q.correctIndex,
          accepted: q.accepted,
          tiles: q.tiles,
          joiner: q.joiner,
          splits: q.splits,
          cardId: q.cardId,
          concept: q.concept,
          optionsAreAudio: q.optionsAreAudio,
          tilesFallback: q.tilesFallback,
          dialectRisk: q.dialectRisk,
          meaningHint: q.meaningHint,
          bankId: _idOf(q, origin),
        ),
        signature: signatureOf(request),
        origin: origin,
      );
      if (bandKey != null && onlyProbes) {
        bandAsked[bandKey]!.addAll(entry.answerIds);
      }
      if (!ids.add(entry.id)) return null;
      entries.add(entry);
      return entry;
    }

    for (var deck = 0; deck < n; deck += deckStride) {
      for (var pick = 0; pick < picks; pick++) {
        for (final base
            in onlyProbes ? const <PlacementBaseQuestion>[] : bases) {
          final request = _request(
            base.topic,
            PlacementQuestionRole.base,
            base.id,
            base.kind,
            base.skills,
            deck,
            n,
            pick,
          );
          final entry = tagged(request, null, null);
          if (entry == null) continue;
          for (final split in base.splits) {
            tagged(
              _request(
                base.topic,
                PlacementQuestionRole.split,
                split.id,
                split.kind,
                split.skills,
                deck,
                n,
                pick,
                origin: base.id,
              ),
              entry.question,
              entry.id,
            );
          }
          if (base.topic == PlacementTopic.minimalPairs &&
              tested.contains(PlacementSkill.write)) {
            tagged(
              _request(
                base.topic,
                PlacementQuestionRole.isolating,
                PlacementVariant.isolating,
                PlacementQuestionKind.tilesWord,
                const <PlacementSkill>[PlacementSkill.write],
                deck,
                n,
                pick,
                origin: base.id,
              ),
              entry.question,
              entry.id,
            );
          }
        }
        for (final skill in tested) {
          if (skill == PlacementSkill.say) continue;
          final kind = skill == PlacementSkill.write
              ? PlacementQuestionKind.tilesWord
              : PlacementQuestionKind.pickOne;
          for (final (role, variant, topic)
              in <(PlacementQuestionRole, PlacementVariant, PlacementTopic)>[
                (
                  PlacementQuestionRole.probe,
                  PlacementVariant.probe,
                  PlacementTopic.positioning,
                ),
                (
                  PlacementQuestionRole.topUp,
                  PlacementVariant.topUp,
                  PlacementTopic.topUp,
                ),
              ]) {
            tagged(
              _request(
                topic,
                role,
                variant,
                kind,
                <PlacementSkill>[skill],
                deck,
                n,
                pick,
              ),
              null,
              null,
            );
          }
        }
        if (!onlyProbes) {
          tagged(
            _request(
              PlacementTopic.grammarLevel,
              PlacementQuestionRole.grammar,
              PlacementVariant.grammar,
              PlacementQuestionKind.pickOne,
              const <PlacementSkill>[PlacementSkill.read],
              deck,
              n,
              pick,
            ),
            null,
            null,
          );
        }
      }
    }
  }
  // Keep about [maxQuestions]: thin the questions that check nothing evenly,
  // then add back the splits and isolating questions of those kept.
  final heads = <BankEntry>[
    for (final e in entries)
      if (e.origin == null) e,
  ];
  final followers = <String, List<BankEntry>>{};
  for (final e in entries) {
    if (e.origin != null) (followers[e.origin!] ??= <BankEntry>[]).add(e);
  }
  List<BankEntry> thinned(int step) {
    final bySig = <String, List<BankEntry>>{};
    for (final e in heads) {
      (bySig[e.signature] ??= <BankEntry>[]).add(e);
    }
    final kept = <BankEntry>[];
    for (final group in bySig.values) {
      group.sort((a, b) {
        final c = a.question.difficulty.deck.compareTo(
          b.question.difficulty.deck,
        );
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      for (var i = 0; i < group.length; i += step) {
        kept.add(group[i]);
      }
    }
    return kept;
  }

  var step = 1;
  var kept = thinned(step);
  int size(List<BankEntry> k) =>
      k.length + k.fold<int>(0, (s, e) => s + (followers[e.id]?.length ?? 0));
  while (size(kept) > maxQuestions && step < 1000) {
    step++;
    kept = thinned(step);
  }
  return QuestionBank(<BankEntry>[
    for (final e in kept) ...<BankEntry>[e, ...?followers[e.id]],
  ]);
}

/// The engine's question source in bank mode: the same rules as the builder's
/// `_item` (the nearest deck range with five eligible candidates, the five
/// hardest, the request's shortlist pick) over the bank's questions.
class BankedBuilder implements QuestionSource {
  BankedBuilder(this.bank, this.deckCount);

  final QuestionBank bank;
  final int deckCount;

  List<List<int>> _ranges(int deck, {required bool around}) {
    final last = deckCount - 1;
    final at = deck.clamp(0, last);
    List<int> span(int from, int to) => <int>[
      for (var i = math.max(0, from); i <= math.min(last, to); i++) i,
    ];
    return around
        ? <List<int>>[
            span(at, at),
            span(at - 1, at + 1),
            span(at - 3, at + 3),
            span(0, last),
          ]
        : <List<int>>[
            span(at, at),
            span(at - 1, at),
            span(at - deckCount ~/ 4, at),
            span(0, at),
          ];
  }

  @override
  QuestionOutcome build(
    PlacementQuestionRequest request, {
    Set<String> asked = const <String>{},
    GeneratedQuestion? failed,
  }) {
    final probingRole =
        request.role == PlacementQuestionRole.probe ||
        request.role == PlacementQuestionRole.topUp;
    // Probes and top-ups of one skill and kind share a pool.
    final all = probingRole
        ? <BankEntry>[
            for (final role in <PlacementQuestionRole>[
              PlacementQuestionRole.probe,
              PlacementQuestionRole.topUp,
            ])
              ...?bank.bySignature['${role.name}|'
                  '${role == PlacementQuestionRole.probe ? PlacementVariant.probe.label : PlacementVariant.topUp.label}|'
                  '${request.kind.name}|'
                  '${request.skills.map((s) => s.name).join('+')}'],
          ]
        : bank.bySignature[signatureOf(request)] ?? const <BankEntry>[];
    final needsOrigin =
        request.role == PlacementQuestionRole.split ||
        request.role == PlacementQuestionRole.isolating;
    if (needsOrigin && failed?.bankId == null) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noOrigin,
        'a split needs the bank question it checks',
      );
    }
    final pool = <BankEntry>[
      for (final e in all)
        if ((!needsOrigin || e.origin == failed!.bankId) &&
            !e.answerIds.any(asked.contains))
          e,
    ];
    if (pool.isEmpty) {
      return QuestionUnavailable(
        asked.isNotEmpty
            ? PlacementUnavailableReason.allAsked
            : PlacementUnavailableReason.noWords,
        'no bank question for ${signatureOf(request)}',
      );
    }
    List<BankEntry> best = const <BankEntry>[];
    final seen = <String>{};
    final probing =
        request.role == PlacementQuestionRole.probe ||
        request.role == PlacementQuestionRole.topUp;
    final band = PlacementLevels(deckCount).bandOf(request.deck);
    final ranges = probing
        ? <List<int>>[
            <int>[request.deck.clamp(band.from, band.to)],
            <int>[
              for (
                var i = band.from;
                i <= request.deck.clamp(band.from, band.to);
                i++
              )
                i,
            ],
          ]
        : _ranges(request.deck, around: false);
    for (final range in ranges) {
      if (range.isEmpty || !seen.add('${range.first}-${range.last}')) continue;
      final from = range.first;
      final to = range.last;
      final candidates = <BankEntry>[
        for (final e in pool)
          if (e.question.difficulty.deck >= from &&
              e.question.difficulty.deck <= to)
            e,
      ];
      if (candidates.length > best.length) best = candidates;
      if (candidates.length >= 5) break;
    }
    if (best.isEmpty && !probing) best = pool;
    if (best.isEmpty) {
      return QuestionUnavailable(
        PlacementUnavailableReason.noWords,
        'no bank question in the band of deck ${request.deck}',
      );
    }
    // Counted questions before leaky ones, then the hardest first, one entry
    // per card.
    best.sort((a, b) {
      final x = a.counted ? 0 : 1;
      final y = b.counted ? 0 : 1;
      if (x != y) return x.compareTo(y);
      final c = b.question.difficulty.score.compareTo(
        a.question.difficulty.score,
      );
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    final shortlist = <BankEntry>[];
    final cards = <String>{};
    for (final e in best) {
      if (needsOrigin || cards.add(e.question.cardId ?? e.id)) {
        shortlist.add(e);
      }
      if (shortlist.length == 5) break;
    }
    final chosen = shortlist[request.shortlistPick % shortlist.length];
    // Hand the engine the question with this request (its role and number).
    return QuestionBuilt(_forRequest(chosen.question, request));
  }

  GeneratedQuestion _forRequest(
    GeneratedQuestion q,
    PlacementQuestionRequest request,
  ) => GeneratedQuestion(
    request: request,
    prompt: q.prompt,
    mode: q.mode,
    difficulty: q.difficulty,
    itemIds: q.itemIds,
    promptText: q.promptText,
    promptReading: q.promptReading,
    audio: q.audio,
    options: q.options,
    correctIndex: q.correctIndex,
    accepted: q.accepted,
    tiles: q.tiles,
    joiner: q.joiner,
    splits: q.splits,
    cardId: q.cardId,
    concept: q.concept,
    optionsAreAudio: q.optionsAreAudio,
    tilesFallback: q.tilesFallback,
    dialectRisk: q.dialectRisk,
    meaningHint: q.meaningHint,
    bankId: q.bankId,
  );
}

/// A question's answer in an answer table judged right or wrong: a pick
/// index, an option's text (for a pick) or a typed or built text, or a
/// boolean (right or wrong as the persona's answer was scored).
bool judgeAnswer(GeneratedQuestion q, Object? answer) {
  if (answer == null) return false;
  if (answer is bool) return answer;
  if (answer is int) return q.isRightPick(answer);
  if (answer is String) {
    final norm = answer.trim().toLowerCase();
    if (q.mode == PlacementAnswerMode.pick) {
      final right = q.correctIndex;
      return right != null &&
          right >= 0 &&
          right < q.options.length &&
          q.options[right].trim().toLowerCase() == norm;
    }
    return q.accepted.any((a) => a.trim().toLowerCase() == norm);
  }
  return false;
}

T _named<T extends Enum>(List<T> values, Object? name) =>
    values.firstWhere((v) => v.name == name);

/// The bank written by `tool/placement_bank.dart`, read back from its two
/// JSON files ([questions] of the public file, [keys] of the key file), as
/// questions a run can be asked.
QuestionBank bankFromJson(
  List<Object?> questions,
  Map<String, Object?> keys, {
  required String language,
}) {
  final entries = <BankEntry>[];
  for (final raw in questions) {
    final pub = raw! as Map<String, Object?>;
    final id = pub['id']! as String;
    final key = keys[id] as Map<String, Object?>?;
    if (key == null) continue;
    final variant = PlacementVariant.values.firstWhere(
      (v) => v.label == key['type'],
    );
    final skills = <PlacementSkill>[
      for (final name in key['skills']! as List<Object?>)
        _named(PlacementSkill.values, name),
    ];
    final request = PlacementQuestionRequest(
      number: 1,
      role: _named(PlacementQuestionRole.values, key['role']),
      topic: _named(PlacementTopic.values, key['topic']),
      variant: variant,
      kind: _named(PlacementQuestionKind.values, key['kind']),
      skills: skills,
      deck: key['deck']! as int,
      percentile: 0,
      shortlistPick: 0,
    );
    final heard = pub['heardText'] as String?;
    final question = GeneratedQuestion(
      request: request,
      prompt: _named(PlacementPromptKind.values, pub['promptKind']),
      mode: _named(PlacementAnswerMode.values, key['mode']),
      difficulty: ItemDifficulty(
        deck: key['deck']! as int,
        depth: 0,
        form: 0,
        closeness: 0,
        score: (key['score']! as num).toDouble(),
        level: key['level']! as int,
      ),
      itemIds: <String>{
        for (final i in key['itemIds']! as List<Object?>) i! as String,
      },
      promptText: pub['prompt'] as String?,
      promptReading: pub['reading'] as String?,
      audio: heard == null
          ? null
          : PlacementAudio(text: heard, language: language),
      options: <String>[for (final o in pub['options']! as List<Object?>) '$o'],
      correctIndex: key['correctIndex'] as int?,
      accepted: <String>[
        for (final a in key['accepted']! as List<Object?>) '$a',
      ],
      tiles: <String>[for (final t in pub['tiles']! as List<Object?>) '$t'],
      joiner: pub['joiner'] as String? ?? ' ',
      cardId: key['cardId'] as String?,
      concept: key['concept'] as String?,
      optionsAreAudio: pub['optionsAreAudio'] as bool? ?? false,
      meaningHint: pub['meaningHint'] as String?,
      bankId: id,
    );
    entries.add(
      BankEntry(
        id: id,
        question: question,
        signature: key['signature']! as String,
        origin: key['origin'] as String?,
      ),
    );
  }
  return QuestionBank(entries);
}
