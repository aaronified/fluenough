import 'package:flutter/painting.dart';

import '../core/progress/mastery.dart';

/// One colour per skill, the same on a light and a dark theme and on every
/// seed (owner, 2026-10-26: "The skill colours must not change with theme"),
/// in which a skill's name is always written. They are the hues of the Today
/// tile pills (blue, orange, purple, green, teal, pink) at HCT tone 53 and
/// chroma 56, the tone where the contrast against a light and a dark surface
/// is best and equal: about 3.1 to 3.8:1, the bar for large bold text, icons
/// and bars, so a name in it is set bold at 14 sp or more.
///
/// Script has no pill of its own; pink is the match-pairs set's hue.
Color skillInk(MasterySkill skill) => switch (skill) {
  MasterySkill.read => const Color(0xFF2F80D9),
  MasterySkill.write => const Color(0xFFC06800),
  MasterySkill.hear => const Color(0xFF7E70DB),
  MasterySkill.say => const Color(0xFF518D2C),
  MasterySkill.grammar => const Color(0xFF008F7C),
  MasterySkill.script => const Color(0xFFBC5CA6),
};
