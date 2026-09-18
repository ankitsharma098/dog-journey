import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/age_calculator.dart';
import '../../../../core/utils/photo_url.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/royal/fading_rule.dart';
import '../../../../core/widgets/royal/section_link_header.dart';
import '../../../../core/widgets/royal/status_chip.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../breed_scanner/data/repositories/breed_repository.dart';
import '../../../health_passport/data/models/health_record.dart';
import '../../../health_passport/data/repositories/health_record_repository.dart';
import '../../../nutrition/data/repositories/nutrition_repositories.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../../pets/data/models/pet.dart';
import '../../../pets/presentation/widgets/pet_switcher_sheet.dart';
import '../../../timeline/data/models/timeline_entry.dart';
import '../../../timeline/data/repositories/timeline_repository.dart';
import '../../bloc/home_cubit.dart';

/// Tab 1 — the app's landing screen. Reads across modules
/// (health records, nutrition, timeline) but never writes; every
/// mutation happens on the screen that owns that data. See
/// design-ref/design_handoff_royal_redesign/README.md § "Home dashboard".
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenPassport,
    required this.onOpenNutrition,
    required this.onOpenChat,
    required this.onOpenSettings,
    required this.onOpenCareCalendar,
    required this.onOpenStory,
    required this.onOpenPaywall,
  });

  final VoidCallback onOpenPassport;
  final VoidCallback onOpenNutrition;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenCareCalendar;
  final VoidCallback onOpenStory;
  final VoidCallback onOpenPaywall;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.activePet;
        if (pet == null) return const SizedBox.shrink();
        final userId = context.select<AuthBloc, String>(
          (b) => b.state is AuthAuthenticated
              ? (b.state as AuthAuthenticated).profile.uid
              : '',
        );
        return BlocProvider(
          key: ValueKey(pet.id),
          create: (_) => HomeCubit(
            petId: pet.id,
            breedId: pet.breedId,
            healthRecordRepository: context.read<HealthRecordRepository>(),
            timelineRepository: context.read<TimelineRepository>(),
            feedingPlanRepository: context.read<FeedingPlanRepository>(),
            foodLogRepository: context.read<FoodLogRepository>(),
            breedRepository: context.read<BreedRepository>(),
          ),
          child: _HomeView(
            pet: pet,
            currentUserId: userId,
            onOpenPassport: onOpenPassport,
            onOpenNutrition: onOpenNutrition,
            onOpenChat: onOpenChat,
            onOpenSettings: onOpenSettings,
            onOpenCareCalendar: onOpenCareCalendar,
            onOpenStory: onOpenStory,
            onOpenPaywall: onOpenPaywall,
          ),
        );
      },
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.pet,
    required this.currentUserId,
    required this.onOpenPassport,
    required this.onOpenNutrition,
    required this.onOpenChat,
    required this.onOpenSettings,
    required this.onOpenCareCalendar,
    required this.onOpenStory,
    required this.onOpenPaywall,
  });

  final Pet pet;
  final String currentUserId;
  final VoidCallback onOpenPassport;
  final VoidCallback onOpenNutrition;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenCareCalendar;
  final VoidCallback onOpenStory;
  final VoidCallback onOpenPaywall;

  /// Cosmetic passport code — display-only, derived from the pet id
  /// rather than stored, since it's presentation flavour, not data the
  /// owner enters or edits.
  String _passportCode(Pet pet) {
    final number =
        (pet.id.isEmpty ? pet.name.hashCode : pet.id.hashCode).abs() % 9000 +
        1000;
    final suffix = pet.name.length >= 3
        ? pet.name.substring(0, 3).toUpperCase()
        : pet.name.toUpperCase().padRight(3, 'X');
    return 'PJ-$number-$suffix';
  }

  int _issuedYear(Pet pet) =>
      (pet.adoptedDate ?? pet.birthdate ?? DateTime.now()).year;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = AppColors.textSecondary(brightness);

    return GlassScaffold(
      // Bottom clearance for the floating pill nav lives on the
      // ListView's own `padding` (below), not here — putting it on
      // this outer Padding instead shrinks the Scaffold body itself
      // (Scaffold(extendBody: true) already re-donates that same
      // height back as a MediaQuery bottom inset, so it was being
      // reserved twice), which left the ListView's actual render box
      // too short to reach — let alone scroll to — the Story section.
      // See lib/features/health_passport/.../health_passport_screen.dart
      // for the same split, already correct there.
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              _BrandRow(
                pet: pet,
                onOpenSettings: onOpenSettings,
                onOpenPaywall: onOpenPaywall,
              ),
              const SizedBox(height: 22),
              _PassportHero(
                pet: pet,
                breedName: state.breedName,
                passportCode: _passportCode(pet),
                issuedYear: _issuedYear(pet),
                onTap: onOpenPassport,
              ),
              const SizedBox(height: 12),
              _StatTilesRow(
                weightKg: state.latestWeightKg ?? pet.weightKg,
                nextShot: state.dueSoon.isEmpty ? null : state.dueSoon.first,
                consumedKcal: state.consumedKcal,
                targetKcal: state.targetKcal,
              ),
              const SizedBox(height: 26),
              SectionLinkHeader(
                title: 'Needs you this week',
                linkLabel: 'All care',
                onLinkTap: onOpenCareCalendar,
              ),
              const SizedBox(height: 10),
              if (state.dueSoon.isEmpty)
                _AllCaughtUpNote(textSecondary: textSecondary)
              else
                Column(
                  children: [
                    for (final record in state.dueSoon.take(3)) ...[
                      _CareRow(record: record),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              const SizedBox(height: 12),
              _CompanionCard(petName: pet.name, onTap: onOpenChat),
              const SizedBox(height: 26),
              SectionLinkHeader(
                title: pet.birthdate == null
                    ? 'Our story, so far'
                    : '${((DateTime.now().difference(pet.birthdate!).inDays) / 365.25).floor()} years, so far',
                linkLabel: 'Story',
                onLinkTap: onOpenStory,
              ),
              const SizedBox(height: 10),
              if (state.memories.isEmpty)
                Text(
                  'Add a photo to start ${pet.name}\'s story.',
                  style: AppTextStyles.secondaryLine.copyWith(
                    color: textSecondary,
                  ),
                )
              else
                SizedBox(
                  height: 144,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.memories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _MemoryThumb(
                      entry: state.memories[i],
                      onTap: onOpenStory,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.pet,
    required this.onOpenSettings,
    required this.onOpenPaywall,
  });
  final Pet pet;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPaywall;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return Row(
      children: [
        _PetPill(pet: pet),
        const Spacer(),
        BlocBuilder<BillingCubit, BillingState>(
          builder: (context, billing) => GestureDetector(
            // Already Pro — nothing to sell, so this isn't tappable to
            // the paywall anymore, just a status badge.
            onTap: billing.isPro ? null : onOpenPaywall,
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: champagne.withValues(alpha: 0.5)),
                color: champagne.withValues(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: Text(
                billing.isPro ? 'PRO' : 'GO PRO',
                style: AppTextStyles.chipLabel.copyWith(color: champagne),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _IconCircleButton(
          icon: PhosphorIconsRegular.gearSix,
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

/// Doubles as the multi-dog entry point — design-ref/design_handoff
/// _royal_redesign 2 § "Multi-dog 2a". Tapping it opens the switcher
/// sheet regardless of how many dogs the account has, so the
/// mechanism doesn't need to appear/disappear as a second dog is
/// added.
class _PetPill extends StatelessWidget {
  const _PetPill({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return GestureDetector(
      onTap: () => showPetSwitcherSheet(context),
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 4, right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.hairline(brightness)),
          color: AppColors.card(brightness),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.hairline(brightness),
                border: Border.all(color: champagne.withValues(alpha: 0.45)),
                image: !isRemotePhotoUrl(pet.photoUrl)
                    ? null
                    : DecorationImage(
                        image: NetworkImage(pet.photoUrl!),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: isRemotePhotoUrl(pet.photoUrl)
                  ? null
                  : Icon(
                      PhosphorIconsRegular.dog,
                      size: 14,
                      color: AppColors.textTertiary(brightness),
                    ),
            ),
            const SizedBox(width: 9),
            Text(
              pet.name,
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 13,
                color: AppColors.textPrimary(brightness),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretUpDown,
              size: 13,
              color: AppColors.textSecondary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline(brightness)),
        ),
        child: Icon(icon, size: 15, color: AppColors.textSecondary(brightness)),
      ),
    );
  }
}

class _PassportHero extends StatelessWidget {
  const _PassportHero({
    required this.pet,
    required this.breedName,
    required this.passportCode,
    required this.issuedYear,
    required this.onTap,
  });

  final Pet pet;
  final String? breedName;
  final String passportCode;
  final int issuedYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    final ageLabel = pet.birthdate == null
        ? null
        : AgeCalculator.label(
            pet.birthdate!,
            isEstimate: pet.birthdateIsEstimate,
          );
    final subtitle = [breedName, ageLabel].whereType<String>().join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: champagne.withValues(alpha: 0.22)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.card(brightness),
              AppColors.card(brightness).withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: champagne.withValues(alpha: 0.45),
                    ),
                    color: AppColors.hairline(brightness),
                    image: !isRemotePhotoUrl(pet.photoUrl)
                        ? null
                        : DecorationImage(
                            image: NetworkImage(pet.photoUrl!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: isRemotePhotoUrl(pet.photoUrl)
                      ? null
                      : Icon(
                          PhosphorIconsRegular.dog,
                          color: AppColors.textTertiary(brightness),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: AppTextStyles.screenTitle.copyWith(
                          color: AppColors.textPrimary(brightness),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTextStyles.secondaryLine.copyWith(
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FadingRule(color: champagne.withValues(alpha: 0.55)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PASSPORT · $passportCode',
                  style: AppTextStyles.mono.copyWith(
                    color: champagne.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  'ISSUED $issuedYear',
                  style: AppTextStyles.mono.copyWith(
                    color: champagne.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow({
    required this.weightKg,
    required this.nextShot,
    required this.consumedKcal,
    required this.targetKcal,
  });

  final double? weightKg;
  final HealthRecord? nextShot;
  final int consumedKcal;
  final int targetKcal;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final nextShotDays = nextShot?.dueOn?.difference(DateTime.now()).inDays;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Weight',
            value: weightKg == null ? '—' : weightKg!.toStringAsFixed(1),
            unit: weightKg == null ? '' : 'kg',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Next shot',
            value: nextShotDays == null ? '—' : '$nextShotDays',
            unit: nextShotDays == null ? '' : 'days',
            valueColor: nextShotDays != null && nextShotDays <= 0
                ? AppColors.dangerOn(brightness)
                : AppColors.warningOn(brightness),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Today',
            value: '$consumedKcal',
            unit: targetKcal > 0 ? '/$targetKcal' : 'kcal',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassContainer(
      borderRadius: 14,
      border: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value,
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 16,
                color: valueColor ?? AppColors.textPrimary(brightness),
              ),
              children: [
                TextSpan(
                  text: unit.isEmpty ? '' : ' $unit',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllCaughtUpNote extends StatelessWidget {
  const _AllCaughtUpNote({required this.textSecondary});
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Text(
      'All caught up — nothing due this week.',
      style: AppTextStyles.secondaryLine.copyWith(color: textSecondary),
    );
  }
}

class _CareRow extends StatelessWidget {
  const _CareRow({required this.record});
  final HealthRecord record;

  (String, Color, Color) _chip(Brightness brightness) {
    final days = record.dueOn!.difference(DateTime.now()).inDays;
    if (days < 0) {
      return (
        'OVERDUE',
        AppColors.dangerOn(brightness).withValues(alpha: 0.14),
        AppColors.dangerOn(brightness),
      );
    }
    if (days == 0) {
      return (
        'TODAY',
        AppColors.dangerOn(brightness).withValues(alpha: 0.14),
        AppColors.dangerOn(brightness),
      );
    }
    return (
      '$days DAYS',
      AppColors.warningOn(brightness).withValues(alpha: 0.14),
      AppColors.warningOn(brightness),
    );
  }

  IconData get _icon => switch (record.type) {
    RecordType.vaccine => PhosphorIconsFill.syringe,
    RecordType.medication => PhosphorIconsFill.pill,
    RecordType.weight => PhosphorIconsFill.scales,
    _ => PhosphorIconsFill.calendarBlank,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (label, bg, fg) = _chip(brightness);
    final accent = AppColors.accentOn(brightness);
    return GlassContainer(
      borderRadius: 16,
      border: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(_icon, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: AppTextStyles.listRowTitle.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.clinicName == null
                      ? 'Due ${_formatDate(record.dueOn!)}'
                      : 'Due ${_formatDate(record.dueOn!)} · ${record.clinicName}',
                  style: AppTextStyles.secondaryLine.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          StatusChip(label: label, background: bg, foreground: fg),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({required this.petName, required this.onTap});
  final String petName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.accentOn(brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.20),
              accent.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.25),
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsFill.firstAidKit,
                size: 19,
                color: accent,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Still awake at 3am?',
                    style: AppTextStyles.listRowTitle.copyWith(
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The vet chat is too. Ask anything about $petName.',
                    style: AppTextStyles.secondaryLine.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.arrowRight, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

class _MemoryThumb extends StatelessWidget {
  const _MemoryThumb({required this.entry, required this.onTap});
  final TimelineEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final photoUrl = entry.photos.isEmpty
        ? null
        : entry.photos.first['url'] as String?;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.hairline(brightness)),
                color: AppColors.hairline(brightness),
                image: !isRemotePhotoUrl(photoUrl)
                    ? null
                    : DecorationImage(
                        image: NetworkImage(photoUrl!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: isRemotePhotoUrl(photoUrl)
                  ? null
                  : Icon(
                      PhosphorIconsRegular.image,
                      color: AppColors.textTertiary(brightness),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.title ?? entry.entryType.label,
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 11,
                color: AppColors.textPrimary(brightness),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
