/// Mirrors supabase/migrations/0001_init.sql `users`. Supabase Auth
/// stays the source of truth for identity (email, password) — this is
/// the profile (tier, locale, timezone) everything else reads. [uid]
/// is the same value as the row's `id` column, which is itself the
/// Supabase auth user id (see the `users.id references auth.users(id)`
/// FK) — there's no separate mirrored-uid column to keep in sync.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.locale = 'en-US',
    this.timezone = 'America/New_York',
    this.units = 'imperial',
    this.tier = 'free',
    this.onboardingDone = false,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String locale;
  final String timezone;
  final String units;
  final String tier;
  final bool onboardingDone;

  bool get isPremium => tier == 'premium';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    uid: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String?,
    photoUrl: json['photo_url'] as String?,
    locale: json['locale'] as String? ?? 'en-US',
    timezone: json['timezone'] as String? ?? 'America/New_York',
    units: json['units'] as String? ?? 'imperial',
    tier: json['tier'] as String? ?? 'free',
    onboardingDone: json['onboarding_done'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'display_name': displayName,
    'photo_url': photoUrl,
    'locale': locale,
    'timezone': timezone,
    'units': units,
    'tier': tier,
    'onboarding_done': onboardingDone,
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? locale,
    String? timezone,
    String? units,
    bool? onboardingDone,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      units: units ?? this.units,
      tier: tier,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          locale == other.locale &&
          timezone == other.timezone &&
          units == other.units &&
          tier == other.tier &&
          onboardingDone == other.onboardingDone);

  @override
  int get hashCode => Object.hash(
    uid,
    email,
    displayName,
    photoUrl,
    locale,
    timezone,
    units,
    tier,
    onboardingDone,
  );
}
