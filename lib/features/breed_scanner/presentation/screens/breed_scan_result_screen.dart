import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/royal/fading_rule.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../billing/presentation/screens/paywall_sheet.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../../pets/presentation/screens/add_pet_screen.dart';
import '../../bloc/breed_scan_cubit.dart';
import '../../data/models/breed.dart';
import '../../data/repositories/breed_repository.dart';

/// Pushed via a plain [Navigator.push] — [HomeShell] uses an
/// [IndexedStack] for tab switching, not nested go_router routes, so
/// this stays local navigation rather than widening the router. See
/// README § "6. Scan result".
class BreedScanResultScreen extends StatelessWidget {
  const BreedScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      body: BlocConsumer<BreedScanCubit, BreedScanState>(
        listenWhen: (previous, current) =>
            current.phase == ScanPhase.savedToPet ||
            current.phase == ScanPhase.failure,
        listener: (context, state) {
          if (state.phase == ScanPhase.savedToPet) {
            AppSnackbar.show(context, message: 'Saved.');
            Navigator.of(context).pop();
          } else if (state.phase == ScanPhase.failure) {
            AppSnackbar.show(
              context,
              message: state.failure?.message ?? 'Could not save that.',
            );
          }
        },
        builder: (context, state) {
          if (state.phase == ScanPhase.notADog) {
            return _NotADogView(onRetry: () => Navigator.of(context).pop());
          }
          if (state.matches.isEmpty) return const SizedBox.shrink();

          final top = state.matches.first;
          final runnersUp = state.matches.skip(1).toList();

          return ListView(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 14),
                label: const Text('Rescan'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.25),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      height: 190,
                      color: AppColors.sheet(brightness),
                      alignment: Alignment.center,
                      child: Text(
                        'scanned photo',
                        style: AppTextStyles.mono.copyWith(
                          color: AppColors.textTertiary(brightness),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: AppColors.card(brightness),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.fromCache) ...[
                            Text(
                              'Matched an earlier scan of this photo.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary(brightness),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            'MOST LIKELY',
                            style: AppTextStyles.engravedLabel.copyWith(
                              color: AppColors.champagneOn(brightness),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            top.name,
                            style: AppTextStyles.screenTitleCompact.copyWith(
                              fontSize: 23,
                              color: AppColors.textPrimary(brightness),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (top.pct / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: AppColors.hairline(
                                      brightness,
                                    ),
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${top.pct.round()}%',
                                style: AppTextStyles.listRowTitle.copyWith(
                                  color: AppColors.accentLight,
                                ),
                              ),
                            ],
                          ),
                          if (top.confidence < 0.6) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Best guess — lower confidence match',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.warningOn(brightness),
                              ),
                            ),
                          ],
                          if (runnersUp.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            FadingRule(
                              color: AppColors.champagne.withValues(alpha: 0.4),
                              fadeEnd: true,
                            ),
                            const SizedBox(height: 12),
                            for (final m in runnersUp)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      m.name,
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary(
                                          brightness,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${m.pct.round()}%',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary(
                                          brightness,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _HealthWatchlist(breedSlug: top.breedSlug, breedName: top.name),
              const SizedBox(height: 10),
              const _SaveOptions(),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Breed health watchlist — Pro teaser
// ---------------------------------------------------------------------------
class _HealthWatchlist extends StatelessWidget {
  const _HealthWatchlist({required this.breedSlug, required this.breedName});
  final String breedSlug;
  final String breedName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Breed?>(
      future: getIt<BreedRepository>().bySlug(breedSlug),
      builder: (context, snapshot) {
        final risks = snapshot.data?.healthRisks ?? const [];
        if (risks.isEmpty) return const SizedBox.shrink();
        return BlocBuilder<BillingCubit, BillingState>(
          builder: (context, billing) {
            return billing.isPro
                ? _UnlockedWatchlist(breedName: breedName, risks: risks)
                : _LockedWatchlist(breedName: breedName);
          },
        );
      },
    );
  }
}

class _LockedWatchlist extends StatelessWidget {
  const _LockedWatchlist({required this.breedName});
  final String breedName;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return GestureDetector(
      onTap: () {
        final billingCubit = context.read<BillingCubit>();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BlocProvider.value(
            value: billingCubit,
            child: const PaywallSheet(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: champagne.withValues(alpha: 0.35)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              champagne.withValues(alpha: 0.14),
              AppColors.accent.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsFill.lockSimple, size: 16, color: champagne),
                const SizedBox(width: 10),
                Text(
                  'Breed health watchlist',
                  style: AppTextStyles.listRowTitle.copyWith(
                    fontSize: 13.5,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$breedName${breedName.endsWith('s') ? '' : 's'} are prone to conditions worth '
              'screening early. Unlock the full report, weight targets and a tailored '
              'vaccine schedule.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  _fakeBar(brightness, 0.82),
                  const SizedBox(height: 6),
                  _fakeBar(brightness, 0.64),
                  const SizedBox(height: 6),
                  _fakeBar(brightness, 0.73),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: champagne),
                color: champagne.withValues(alpha: 0.12),
              ),
              child: Text(
                'Unlock with Pro',
                style: AppTextStyles.listRowTitle.copyWith(
                  fontSize: 13,
                  color: champagne,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fakeBar(Brightness brightness, double width) => FractionallySizedBox(
    widthFactor: width,
    alignment: Alignment.centerLeft,
    child: Container(
      height: 9,
      decoration: BoxDecoration(
        color: AppColors.textPrimary(brightness).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}

class _UnlockedWatchlist extends StatelessWidget {
  const _UnlockedWatchlist({required this.breedName, required this.risks});
  final String breedName;
  final List<Map<String, dynamic>> risks;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassContainer(
      borderRadius: 20,
      border: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsFill.heartbeat,
                size: 16,
                color: AppColors.accentLight,
              ),
              const SizedBox(width: 10),
              Text(
                'Breed health watchlist',
                style: AppTextStyles.listRowTitle.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in risks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${r['condition'] ?? ''}${r['severity'] != null ? ' · ${r['severity']}' : ''}',
                style: AppTextStyles.secondaryLine.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Not a dog
// ---------------------------------------------------------------------------
class _NotADogView extends StatelessWidget {
  const _NotADogView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.dog,
              size: 48,
              color: AppColors.textTertiary(brightness),
            ),
            const SizedBox(height: 12),
            Text(
              "That doesn't look like a dog to us — try a clear, well-lit photo of just your dog.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                side: const BorderSide(color: AppColors.accent),
              ),
              child: Text(
                'Try another photo',
                style: AppTextStyles.listRowTitle.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save options
// ---------------------------------------------------------------------------
class _SaveOptions extends StatelessWidget {
  const _SaveOptions();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cubit = context.read<BreedScanCubit>();
    final petsWithoutBreed = context
        .watch<PetsBloc>()
        .state
        .pets
        .where((pet) => pet.breedId == null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final pet in petsWithoutBreed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => cubit.saveToPet(pet.id),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: AppColors.accent),
                ),
                child: Text(
                  'Save breed to ${pet.name}\'s passport',
                  style: AppTextStyles.listRowTitle.copyWith(
                    fontSize: 13.5,
                    color: AppColors.accentLight,
                  ),
                ),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              final matches = cubit.state.matches;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddPetScreen(
                    initialBreedId: matches.isEmpty
                        ? null
                        : matches.first.breedSlug,
                    initialBreedMix: matches
                        .map(
                          (m) => {
                            'breed_id': m.breedSlug,
                            'name': m.name,
                            'pct': m.pct,
                          },
                        )
                        .toList(),
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              side: BorderSide(color: AppColors.hairline(brightness)),
            ),
            child: Text(
              'Create a profile for this dog',
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 13.5,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
