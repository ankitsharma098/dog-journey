import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/segmented_choice.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_form_status.dart';
import '../../bloc/add_pet_cubit.dart';
import '../../bloc/pets_bloc.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Onboarding, not a settings form — PRD §7.2's shortcut principle
/// applies here too: name is the only hard requirement, everything
/// else is skippable and softened rather than demanded.
class AddPetScreen extends StatelessWidget {
  const AddPetScreen({super.key, this.initialBreedId, this.initialBreedMix});

  /// Carried over from a breed scan result (BS-6) when this screen is
  /// reached via "Create a profile for this dog" instead of the
  /// onboarding gate — null for the plain manual-entry path.
  final String? initialBreedId;
  final List<Map<String, dynamic>>? initialBreedMix;

  @override
  Widget build(BuildContext context) {
    final ownerId = (context.read<AuthBloc>().state as AuthAuthenticated).profile.uid;
    return BlocProvider(
      create: (_) => getIt<AddPetCubit>(param1: ownerId),
      child: _AddPetView(initialBreedId: initialBreedId, initialBreedMix: initialBreedMix),
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AddPetCubit>();

    return GlassScaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AddPetCubit, AddPetState>(
            listener: (context, state) {
              if (state.status == AuthFormStatus.failure && state.failure != null) {
                AppSnackbar.show(context, message: state.failure!.message);
              }
              // Reached via the onboarding gate (first pet, no
              // breed): success needs no navigation — PetsBloc picks
              // up the new pet from Firestore and the router redirect
              // takes it from there, same pattern as sign-up. If that
              // doesn't happen, the PetsBloc listener below explains
              // why instead of leaving this screen silently stuck.
              //
              // Reached via a direct push (a second pet, e.g. "Create
              // a profile for this dog" off a breed scan result):
              // there's no router redirect to rely on, so pop back to
              // whatever pushed this screen once the write succeeds.
              if (state.status == AuthFormStatus.success && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          BlocListener<PetsBloc, PetsState>(
            listener: (context, state) {
              final addPetSucceeded =
                  context.read<AddPetCubit>().state.status == AuthFormStatus.success;
              if (addPetSucceeded && state.status == PetsStatus.error) {
                AppSnackbar.show(context, message: "Your dog was saved, but we couldn't load your pets. Check your connection and try again.",);
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: "Let's add your dog",
                  subtitle: 'Just a name to start — you can fill in the rest whenever.',
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: "Dog's name",
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Give your dog a name.' : null,
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
                AppDateField(
                  label: 'Birthdate',
                  value: _birthdate,
                  onChanged: (date) => setState(() => _birthdate = date),
                ),
                if (_birthdate != null) ...[
                  CheckboxListTile(
                    value: _birthdateIsEstimate,
                    onChanged: (value) =>
                        setState(() => _birthdateIsEstimate = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text("This is a guess, not the real date"),
                  ),
                ],
                const SizedBox(height: 12),
                AppDateField(
                  label: 'Adoption date (optional)',
                  value: _adoptedDate,
                  onChanged: (date) => setState(() => _adoptedDate = date),
                ),
                const SizedBox(height: 28),
                BlocBuilder<AddPetCubit, AddPetState>(
                  builder: (context, state) {
                    // Stays disabled through `success` too, not just
                    // `submitting` — the write is done, but until
                    // PetsBloc's listener confirms it and the router
                    // navigates away, a second tap would create a
                    // second pet.
                    final busy = state.status == AuthFormStatus.submitting ||
                        state.status == AuthFormStatus.success;
                    return PrimaryButton(
                      label: 'Add my dog',
                      isLoading: busy,
                      onPressed: busy ? null : () => _submit(cubit),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
