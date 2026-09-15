import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../bloc/breed_scan_cubit.dart';
import 'breed_scan_result_screen.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Module 1 — see PRD §7.1 flow step 1: camera/gallery picker with a
/// guidance overlay (full body, side-on, good light).
class BreedScannerScreen extends StatelessWidget {
  const BreedScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId = (context.read<AuthBloc>().state as AuthAuthenticated).profile.uid;
    return BlocProvider(
      create: (_) => getIt<BreedScanCubit>(param1: ownerId),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView();

  static const _inFlightPhases = {
    ScanPhase.preparing,
    ScanPhase.checkingCache,
    ScanPhase.checkingQuota,
    ScanPhase.classifying,
    ScanPhase.saving,
  };

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (file == null || !context.mounted) return;
    context.read<BreedScanCubit>().scan(file);
  }

  String _statusLabel(ScanPhase phase) => switch (phase) {
    ScanPhase.preparing => 'Preparing photo…',
    ScanPhase.checkingCache => 'Checking for a match…',
    ScanPhase.checkingQuota => 'Checking your daily scans…',
    ScanPhase.classifying => 'Looking closely at your dog…',
    ScanPhase.saving => 'Saving result…',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(title: const Text('Breed Scanner')),
      body: BlocConsumer<BreedScanCubit, BreedScanState>(
        listener: (context, state) async {
          switch (state.phase) {
            case ScanPhase.success:
            case ScanPhase.notADog:
              final cubit = context.read<BreedScanCubit>();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BlocProvider.value(value: cubit, child: const BreedScanResultScreen()),
                ),
              );
              if (context.mounted) cubit.reset();
            case ScanPhase.quotaExceeded:
              AppSnackbar.show(context, message: state.failure?.message ?? "You've hit today's free limit.");
              context.read<BreedScanCubit>().reset();
            case ScanPhase.failure:
              AppSnackbar.show(context, message: state.failure?.message ?? 'Something went wrong.');
              context.read<BreedScanCubit>().reset();
            default:
              break;
          }
        },
        builder: (context, state) {
          if (_inFlightPhases.contains(state.phase)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusLabel(state.phase)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  icon: Icons.camera_alt_rounded,
                  title: 'What breed is your dog?',
                  subtitle: 'A full-body, side-on photo in good light works best.',
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Take a photo',
                  icon: Icons.camera_alt_rounded,
                  onPressed: () => _pick(context, ImageSource.camera),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Choose from gallery',
                  icon: Icons.photo_library_rounded,
                  onPressed: () => _pick(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
