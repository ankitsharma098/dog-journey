import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_source_picker.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/segmented_choice.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_form_status.dart';
import '../../bloc/add_pet_cubit.dart';
import '../../bloc/pets_bloc.dart';

/// Onboarding, not a settings form — PRD §7.2's shortcut principle
/// applies here too: name is the only hard requirement, everything
/// else is skippable and softened rather than demanded. See README
/// § "0d. Add dog".
class AddPetScreen extends StatelessWidget {
  const AddPetScreen({super.key, this.initialBreedId, this.initialBreedMix});

  /// Carried over from a breed scan result (BS-6) when this screen is
  /// reached via "Create a profile for this dog" instead of the
  /// onboarding gate — null for the plain manual-entry path.
  final String? initialBreedId;
  final List<Map<String, dynamic>>? initialBreedMix;

  @override
  Widget build(BuildContext context) {
    final ownerId =
        (context.read<AuthBloc>().state as AuthAuthenticated).profile.uid;
    return BlocProvider(
      create: (_) => getIt<AddPetCubit>(param1: ownerId),
      child: _AddPetView(
        initialBreedId: initialBreedId,
        initialBreedMix: initialBreedMix,
      ),
    );
  }
}

class _AddPetView extends StatefulWidget {
  const _AddPetView({this.initialBreedId, this.initialBreedMix});

  final String? initialBreedId;
  final List<Map<String, dynamic>>? initialBreedMix;

  @override
  State<_AddPetView> createState() => _AddPetViewState();
}

class _AddPetViewState extends State<_AddPetView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _sex = 'unknown';
  DateTime? _birthdate;
  bool _birthdateIsEstimate = false;
  DateTime? _adoptedDate;
  Uint8List? _photoBytes;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickImageWithSourceChoice(context, maxWidth: 800);
    if (bytes == null) return;
    if (mounted) setState(() => _photoBytes = bytes);
  }

  void _submit(AddPetCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    cubit.submit(
      name: _nameController.text,
      sex: _sex,
      birthdate: _birthdate,
      birthdateIsEstimate: _birthdate != null && _birthdateIsEstimate,
      adoptedDate: _adoptedDate,
      breedId: widget.initialBreedId,
      breedMix: widget.initialBreedMix,
      photoBytes: _photoBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AddPetCubit>();
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);

    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      body: MultiBlocListener(
        listeners: [
          BlocListener<AddPetCubit, AddPetState>(
            listener: (context, state) {
              if (state.status == AuthFormStatus.failure &&
                  state.failure != null) {
                AppSnackbar.show(context, message: state.failure!.message);
              }
              // Reached via the onboarding gate (first pet, no
              // breed): success needs no navigation — PetsBloc picks
              // up the new pet and the router redirect takes it from
              // there, same pattern as sign-up. If that doesn't
              // happen, the PetsBloc listener below explains why
              // instead of leaving this screen silently stuck.
              //
              // Reached via a direct push (a second pet, e.g. "Create
              // a profile for this dog" off a breed scan result):
              // there's no router redirect to rely on, so pop back to
              // whatever pushed this screen once the write succeeds.
              if (state.status == AuthFormStatus.success &&
                  Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          BlocListener<PetsBloc, PetsState>(
            listener: (context, state) {
              final addPetSucceeded =
                  context.read<AddPetCubit>().state.status ==
                  AuthFormStatus.success;
              if (addPetSucceeded && state.status == PetsStatus.error) {
                AppSnackbar.show(
                  context,
                  message:
                      "Your dog was saved, but we couldn't load your pets. Check your connection and try again.",
                );
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP 2 OF 2',
                  style: AppTextStyles.chipLabel.copyWith(
                    letterSpacing: 2,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Let's add your dog",
                  style: AppTextStyles.screenTitle.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Just a name to start — the rest can wait for a quieter evening.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 26),
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: champagne.withValues(alpha: 0.5),
                        ),
                        color: AppColors.card(brightness),
                        image: _photoBytes == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(_photoBytes!),
                                fit: BoxFit.cover,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: _photoBytes != null
                          ? null
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.camera,
                                  size: 22,
                                  color: champagne,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add photo',
                                  style: AppTextStyles.caption.copyWith(
                                    color: champagne,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                AppTextField(
                  label: "Dog's name",
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Give your dog a name.'
                      : null,
                ),
                const SizedBox(height: 20),
                Text('Sex', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedChoice<String>(
                  value: _sex,
                  onChanged: (value) => setState(() => _sex = value),
                  options: const [
                    SegmentedChoiceOption(value: 'male', label: 'Male'),
                    SegmentedChoiceOption(value: 'female', label: 'Female'),
                    SegmentedChoiceOption(value: 'unknown', label: 'Not sure'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppDateField(
                        label: 'Birthdate',
                        value: _birthdate,
                        onChanged: (date) => setState(() => _birthdate = date),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppDateField(
                        label: 'Adopted (optional)',
                        value: _adoptedDate,
                        onChanged: (date) =>
                            setState(() => _adoptedDate = date),
                      ),
                    ),
                  ],
                ),
                if (_birthdate != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(
                      () => _birthdateIsEstimate = !_birthdateIsEstimate,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _birthdateIsEstimate
                                  ? AppColors.accent
                                  : AppColors.hairline(brightness),
                            ),
                            color: _birthdateIsEstimate
                                ? AppColors.accent.withValues(alpha: 0.25)
                                : Colors.transparent,
                          ),
                          child: _birthdateIsEstimate
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is a guess, not the real date',
                            style: AppTextStyles.secondaryLine.copyWith(
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                BlocBuilder<AddPetCubit, AddPetState>(
                  builder: (context, state) {
                    // Stays disabled through `success` too, not just
                    // `submitting` — the write is done, but until
                    // PetsBloc's listener confirms it and the router
                    // navigates away, a second tap would create a
                    // second pet.
                    final busy =
                        state.status == AuthFormStatus.submitting ||
                        state.status == AuthFormStatus.success;
                    return SizedBox(
                      height: 54,
                      child: PrimaryButton(
                        label: 'Add my dog',
                        isLoading: busy,
                        onPressed: busy ? null : () => _submit(cubit),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'A passport number is issued the moment you save.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
