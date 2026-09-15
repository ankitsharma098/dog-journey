import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../../pets/presentation/screens/add_pet_screen.dart';
import '../../bloc/breed_scan_cubit.dart';
import '../widgets/breed_match_card.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Pushed via a plain [Navigator.push] — [HomeShell] uses an
/// [IndexedStack] for tab switching, not nested go_router routes, so
/// this stays local navigation rather than widening the router.
class BreedScanResultScreen extends StatelessWidget {
  const BreedScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(title: const Text('Scan result')),
      body: BlocConsumer<BreedScanCubit, BreedScanState>(
        listenWhen: (previous, current) =>
            current.phase == ScanPhase.savedToPet || current.phase == ScanPhase.failure,
        listener: (context, state) {
          if (state.phase == ScanPhase.savedToPet) {
            AppSnackbar.show(context, message: 'Saved.');
            Navigator.of(context).pop();
          } else if (state.phase == ScanPhase.failure) {
            AppSnackbar.show(context, message: state.failure?.message ?? 'Could not save that.');
          }
        },
        builder: (context, state) {
          if (state.phase == ScanPhase.notADog) {
            return _NotADogView(onRetry: () => Navigator.of(context).pop());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.fromCache)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Matched an earlier scan of this photo.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                for (final match in state.matches) BreedMatchCard(match: match),
                const SizedBox(height: 8),
                // BS-5: this line is never optional — every result
                // carries it, regardless of confidence.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.chipFillDark
                        : AppColors.chipFillLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This is a visual estimate. Only a DNA test is definitive.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Save this match', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const _SaveOptions(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotADogView extends StatelessWidget {
  const _NotADogView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_outlined, size: 48, color: AppColors.textSecondaryLight),
            const SizedBox(height: 12),
            Text(
              "That doesn't look like a dog to us — try a clear, well-lit photo of just your dog.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Try another photo', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _SaveOptions extends StatelessWidget {
  const _SaveOptions();

  @override
  Widget build(BuildContext context) {
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
            child: PrimaryButton(
              label: 'Save to ${pet.name}',
              onPressed: () => cubit.saveToPet(pet.id),
            ),
          ),
        OutlinedButton(
          onPressed: () {
            final matches = cubit.state.matches;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddPetScreen(
                  initialBreedId: matches.isEmpty ? null : matches.first.breedSlug,
                  initialBreedMix: matches
                      .map((m) => {'breed_id': m.breedSlug, 'name': m.name, 'pct': m.pct})
                      .toList(),
                ),
              ),
            );
          },
          child: const Text('Create a profile for this dog'),
        ),
      ],
    );
  }
}
