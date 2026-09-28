/// The avatar shapes a profile can pick, drawn by `ProfileAvatar`.
enum AvatarShape { cookie, clover, flower, sunny }

/// Which colour role an avatar is drawn in.
enum AvatarTone { primary, secondary, tertiary }

/// Someone practising on this phone.
///
/// Profiles live in memory for now. The storage decision is one database file
/// per profile, which lands with #3; until then `Feature.profiles` keeps the
/// profile screens disabled and the app opens on [Profile.defaultProfile].
class Profile {
  const Profile({
    required this.id,
    this.name,
    this.languages,
    this.shape = AvatarShape.cookie,
    this.tone = AvatarTone.primary,
    this.pin,
    this.nativeLanguage = 'en',
  });

  /// The profile the app starts with: unnamed, learning every language in
  /// the catalog.
  static const Profile defaultProfile = Profile(id: 'default');

  /// Stable for the life of the profile.
  final String id;

  /// What the learner called themselves, or null for the unnamed default.
  /// Screens greet an unnamed profile without a name, rather than inventing
  /// one.
  final String? name;

  /// BCP-47 primary subtags of the languages this profile learns, like
  /// `{'hi', 'es'}`, or null for every language the catalog has.
  final Set<String>? languages;

  final AvatarShape shape;
  final AvatarTone tone;

  /// The PIN, held in memory only. Null when the profile is not locked.
  ///
  /// Kept as plain text because nothing is stored yet; #3's storage must not
  /// keep it this way.
  final String? pin;

  /// The interface language the learner reads, as a BCP-47 tag. Menus follow
  /// it once a translation exists (#46).
  final String nativeLanguage;

  bool get isLocked => pin != null;

  /// Whether this profile learns the language with BCP-47 [code].
  bool learns(String code) => languages == null || languages!.contains(code);

  Profile copyWith({
    String? name,
    Set<String>? languages,
    AvatarShape? shape,
    AvatarTone? tone,
    String? nativeLanguage,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    languages: languages ?? this.languages,
    shape: shape ?? this.shape,
    tone: tone ?? this.tone,
    pin: pin,
    nativeLanguage: nativeLanguage ?? this.nativeLanguage,
  );

  @override
  String toString() => 'Profile($id, ${name ?? 'unnamed'})';
}
