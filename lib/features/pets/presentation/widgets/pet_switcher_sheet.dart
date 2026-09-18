import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/age_calculator.dart';
import '../../../../core/utils/photo_url.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../billing/presentation/screens/paywall_sheet.dart';
import '../../../breed_scanner/data/models/breed.dart';
import '../../../breed_scanner/data/repositories/breed_repository.dart';
import '../../bloc/pets_bloc.dart';
import '../../data/models/pet.dart';
import '../screens/add_pet_screen.dart';

/// Multi-dog switcher — design-ref/design_handoff_royal_redesign 2
/// § "Multi-dog 2a" ("This is the one I'd ship"). One account, several
/// dogs; switching here is what every other tab's `activePet` reflects
/// next build (see [PetsState.activePet]). First dog is free; a second
/// is a Pro gate, enforced here rather than in [AddPetScreen] so the
/// scanner's "create a profile" shortcut can't bypass it.
Future<void> showPetSwitcherSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PetSwitcherSheet(),
  );
}

class PetSwitcherSheet extends StatefulWidget {
  const PetSwitcherSheet({super.key});

  @override
  State<PetSwitcherSheet> createState() => _PetSwitcherSheetState();
}

class _PetSwitcherSheetState extends State<PetSwitcherSheet> {
  final Map<String, String> _breedNames = {};

  @override
  void initState() {
    super.initState();
    _loadBreedNames();
  }

  Future<void> _loadBreedNames() async {
    final repository = context.read<BreedRepository>();
    final pets = context.read<PetsBloc>().state.pets;
    for (final pet in pets) {
      final breedId = pet.breedId;
      if (breedId == null) continue;
      final Breed? breed = await repository.bySlug(breedId);
      if (breed != null && mounted) {
        setState(() => _breedNames[pet.id] = breed.name);
      }
    }
  }

  String _meta(Pet pet) {
    final breedName = _breedNames[pet.id];
    final ageLabel = pet.birthdate == null
        ? null
        : AgeCalculator.label(
            pet.birthdate!,
            isEstimate: pet.birthdateIsEstimate,
          );
    return [breedName, ageLabel].whereType<String>().join(' · ');
  }

  Future<void> _addAnotherDog(BuildContext context) async {
    final petsBloc = context.read<PetsBloc>();
    final billingCubit = context.read<BillingCubit>();
    final navigator = Navigator.of(context);
    navigator.pop();

    if (petsBloc.state.pets.isNotEmpty && !billingCubit.state.isPro) {
      final unlocked = await showModalBottomSheet<bool>(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: billingCubit,
          child: const PaywallSheet(),
        ),
      );
      if (unlocked != true) return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => const AddPetScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);

    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, state) {
        final activeId = state.activePet?.id;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.sheet(brightness),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(
              top: BorderSide(color: champagne.withValues(alpha: 0.3)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary(
                      brightness,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'YOUR DOGS',
                style: AppTextStyles.engravedLabel.copyWith(color: champagne),
              ),
              const SizedBox(height: 14),
              for (final pet in state.pets) ...[
                _PetRow(
                  pet: pet,
                  meta: _meta(pet),
                  isActive: pet.id == activeId,
                  onTap: () {
                    context.read<PetsBloc>().add(SelectPet(pet.id));
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
              ],
              GestureDetector(
                onTap: () => _addAnotherDog(context),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: champagne.withValues(alpha: 0.45),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: champagne.withValues(alpha: 0.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          PhosphorIconsRegular.plus,
                          size: 18,
                          color: champagne,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add another dog',
                              style: AppTextStyles.listRowTitle.copyWith(
                                color: champagne,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.pets.isEmpty
                                  ? 'Free with your first dog'
                                  : 'Included with Pro',
                              style: AppTextStyles.secondaryLine.copyWith(
                                color: AppColors.textSecondary(brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PetRow extends StatelessWidget {
  const _PetRow({
    required this.pet,
    required this.meta,
    required this.isActive,
    required this.onTap,
  });

  final Pet pet;
  final String meta;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.hairline(brightness),
          ),
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.card(brightness),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.hairline(brightness),
                border: Border.all(
                  color: isActive
                      ? AppColors.accent
                      : AppColors.champagneOn(
                          brightness,
                        ).withValues(alpha: 0.45),
                ),
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
                      size: 18,
                      color: AppColors.textTertiary(brightness),
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary(brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: AppTextStyles.secondaryLine.copyWith(
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isActive)
              Icon(
                PhosphorIconsFill.checkCircle,
                size: 19,
                color: AppColors.accentLight,
              ),
          ],
        ),
      ),
    );
  }
}
