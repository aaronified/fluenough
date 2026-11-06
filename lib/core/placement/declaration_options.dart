import 'assurance_model.dart';

// The first question of "Find my level" (wiki/Plan-Placement-V2.md, section
// 4.5): which answers a language's built path supports.

/// How built a course is, as the levels of its path that are written to the
/// end (the path marks the level and no unit up to it is still to be
/// written): 0 below A1, 1 A1, 2 A2, 3 B1 (complete).
const int builtBelowA1 = 0;
const int builtA1 = 1;
const int builtA2 = 2;
const int builtB1 = 3;

/// The declarations offered for a path [built] to a level, in the order the
/// screen lists them (owner, 2026-11-05: "For decks with just A1, the app
/// will only offer know nothing and amateur. For A2, it will also offer
/// advanced"; "B1 - should be termed expert"; "For below A1, no placement
/// will be offered"). Empty below A1: no question and no run.
List<PlacementDeclaration> declarationOptionsFor(int built) =>
    <PlacementDeclaration>[
      if (built >= builtB1) PlacementDeclaration.expert,
      if (built >= builtA2) PlacementDeclaration.advanced,
      if (built >= builtA1) ...const <PlacementDeclaration>[
        PlacementDeclaration.amateur,
        PlacementDeclaration.beginner,
      ],
    ];
