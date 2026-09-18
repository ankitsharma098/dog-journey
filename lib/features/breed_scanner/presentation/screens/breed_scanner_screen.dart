import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/data/app_config_repository.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/royal/status_chip.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../bloc/breed_scan_cubit.dart';
import '../../data/repositories/scan_quota_repository.dart';
import 'breed_scan_result_screen.dart';

/// Module 1 — see PRD §7.1 flow step 1: camera/gallery picker with a
/// guidance overlay. Restyled to README § "5. Breed Scanner".
class BreedScannerScreen extends StatelessWidget {
  const BreedScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId =
        (context.read<AuthBloc>().state as AuthAuthenticated).profile.uid;
    return BlocProvider(
      create: (_) => getIt<BreedScanCubit>(param1: ownerId),
      child: _ScannerView(ownerId: ownerId),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView({required this.ownerId});
  final String ownerId;

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanLine;
  int? _scansLeft;
  CameraController? _cameraController;
  bool _torchOn = false;

  static const _inFlightPhases = {
    ScanPhase.preparing,
    ScanPhase.checkingCache,
    ScanPhase.checkingQuota,
    ScanPhase.classifying,
    ScanPhase.saving,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadQuota();
    _initCamera();
  }

  Future<void> _loadQuota() async {
    final limitResult = await getIt<AppConfigRepository>().getInt(
      'free_scan_limit',
      fallback: 3,
    );
    final limit = limitResult.fold((v) => v, (_) => 3);
    final remainingResult = await getIt<ScanQuotaRepository>().remaining(
      widget.ownerId,
      limit: limit,
    );
    final remaining = remainingResult.fold((v) => v, (_) => limit);
    if (mounted) setState(() => _scansLeft = remaining);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } catch (_) {
      // No camera, permission denied, or simulator with no hardware —
      // the viewfinder box falls back to its decorative-only look and
      // the shutter button falls back to the OS camera picker below,
      // so scanning still works either way.
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_torchOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {
      // Some devices/lenses don't support torch mode — leave it off
      // rather than get the icon out of sync with reality.
    }
  }

  Future<void> _capture(BuildContext context) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      // Camera never came up (denied/unavailable) — same fallback
      // path the shutter used before this screen had a live preview.
      await _pick(context, ImageSource.camera);
      return;
    }
    final file = await controller.takePicture();
    if (!context.mounted) return;
    context.read<BreedScanCubit>().scan(file);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
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
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);

    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      body: BlocConsumer<BreedScanCubit, BreedScanState>(
        listener: (context, state) async {
          switch (state.phase) {
            case ScanPhase.success:
            case ScanPhase.notADog:
              final cubit = context.read<BreedScanCubit>();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: const BreedScanResultScreen(),
                  ),
                ),
              );
              if (context.mounted) cubit.reset();
              _loadQuota();
            case ScanPhase.quotaExceeded:
              AppSnackbar.show(
                context,
                message:
                    state.failure?.message ?? "You've hit today's free limit.",
              );
              context.read<BreedScanCubit>().reset();
            case ScanPhase.failure:
              AppSnackbar.show(
                context,
                message: state.failure?.message ?? 'Something went wrong.',
              );
              context.read<BreedScanCubit>().reset();
            default:
              break;
          }
        },
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      PhosphorIconsRegular.x,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Breed scanner',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const Spacer(),
                  if (_scansLeft != null)
                    StatusChip(
                      label: '$_scansLeft SCANS LEFT',
                      background: champagne.withValues(alpha: 0.12),
                      foreground: champagne,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _inFlightPhases.contains(state.phase)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _statusLabel(state.phase),
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary(brightness),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: _Viewfinder(
                              pulse: _scanLine,
                              controller: _cameraController,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Stand back a couple of steps and get all four legs in frame — '
                            'daylight beats flash.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _RoundIconButton(
                                icon: PhosphorIconsRegular.images,
                                size: 46,
                                onTap: () =>
                                    _pick(context, ImageSource.gallery),
                              ),
                              const SizedBox(width: 28),
                              GestureDetector(
                                onTap: () => _capture(context),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: champagne.withValues(alpha: 0.6),
                                      width: 2,
                                    ),
                                    color: AppColors.accent.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    PhosphorIconsFill.camera,
                                    size: 28,
                                    color: AppColors.textPrimary(brightness),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),
                              _RoundIconButton(
                                icon: _torchOn
                                    ? PhosphorIconsFill.lightning
                                    : PhosphorIconsRegular.lightning,
                                size: 46,
                                iconColor: _torchOn ? champagne : null,
                                onTap: _cameraController == null
                                    ? null
                                    : _toggleTorch,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.size,
    this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline(brightness)),
        ),
        child: Icon(
          icon,
          size: 19,
          color: iconColor ?? AppColors.textSecondary(brightness),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.pulse, required this.controller});
  final Animation<double> pulse;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ready = controller != null && controller!.value.isInitialized;
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.hairline(brightness)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.card(brightness), AppColors.sheet(brightness)],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The live feed itself — dimmed rather than full
              // brightness so the champagne guide frame and scan line
              // above it stay the visually dominant thing, matching
              // the previous purely-decorative look while still
              // showing the user what they're actually pointing at.
              if (ready)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.55,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller!.value.previewSize?.height ?? 1,
                        height: controller!.value.previewSize?.width ?? 1,
                        child: CameraPreview(controller!),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  'camera viewfinder\nfull body, side on',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mono.copyWith(
                    color: AppColors.textTertiary(brightness),
                    letterSpacing: 0,
                  ),
                ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.champagne.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) => Align(
                  alignment: Alignment(0, -1 + 2 * pulse.value),
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 26),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0),
                          AppColors.accent,
                          AppColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
