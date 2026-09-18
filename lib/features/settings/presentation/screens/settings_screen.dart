import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/legal/legal_document_screen.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/app_user.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/data/repositories/user_repository.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../billing/presentation/screens/paywall_sheet.dart';
import '../widgets/timezone_picker_sheet.dart';

/// Care-reminders on/off has no backend field (unlike units/timezone,
/// which already live on `users`) — local_notifications scheduling is
/// entirely client-side already, so this stays a device preference
/// rather than a new Supabase column. See README § "12. Settings".
const _careRemindersPrefKey = 'care_reminders_enabled';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, auth) {
          if (auth is! AuthAuthenticated) return const SizedBox.shrink();
          return ListView(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      PhosphorIconsRegular.arrowLeft,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Settings',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 15,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ProCard(profile: auth.profile),
              const SizedBox(height: 24),
              _SectionKicker('Preferences'),
              const SizedBox(height: 10),
              _PreferencesGroup(profile: auth.profile),
              const SizedBox(height: 24),
              _SectionKicker('Account'),
              const SizedBox(height: 10),
              _AccountGroup(email: auth.profile.email),
            ],
          );
        },
      ),
    );
  }
}

class _SectionKicker extends StatelessWidget {
  const _SectionKicker(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.chipLabel.copyWith(
        letterSpacing: 2.4,
        color: AppColors.textTertiary(brightness),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pro card
// ---------------------------------------------------------------------------
class _ProCard extends StatelessWidget {
  const _ProCard({required this.profile});
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, billing) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: champagne.withValues(alpha: 0.32)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                champagne.withValues(alpha: 0.14),
                AppColors.accent.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(PhosphorIconsFill.crownSimple, size: 20, color: champagne),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      billing.isPro
                          ? 'PawJourney Pro'
                                '${billing.planPeriod == null ? '' : ' — ${billing.planPeriod}'}'
                          : 'Free plan',
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 13.5,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      billing.isPro
                          ? 'Thank you for supporting PawJourney.'
                          : '3 breed scans a day, 3 vet chats free',
                      style: AppTextStyles.secondaryLine.copyWith(
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              if (!billing.isPro)
                GestureDetector(
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
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: champagne),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Manage',
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 11.5,
                        color: champagne,
                      ),
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

// ---------------------------------------------------------------------------
// Preferences group
// ---------------------------------------------------------------------------
class _PreferencesGroup extends StatefulWidget {
  const _PreferencesGroup({required this.profile});
  final AppUser profile;

  @override
  State<_PreferencesGroup> createState() => _PreferencesGroupState();
}

class _PreferencesGroupState extends State<_PreferencesGroup> {
  late String _units = widget.profile.units;
  late String _timezone = widget.profile.timezone;
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(
          () =>
              _remindersEnabled = prefs.getBool(_careRemindersPrefKey) ?? true,
        );
      }
    });
  }

  Future<void> _setUnits(String units) async {
    setState(() => _units = units);
    await getIt<UserRepository>().updateFields(widget.profile.uid, {
      'units': units,
    });
  }

  Future<void> _pickTimezone() async {
    final picked = await showTimezonePickerSheet(context, current: _timezone);
    if (picked == null || !mounted) return;
    setState(() => _timezone = picked);
    await getIt<UserRepository>().updateFields(widget.profile.uid, {
      'timezone': picked,
    });
  }

  Future<void> _toggleReminders() async {
    final next = !_remindersEnabled;
    setState(() => _remindersEnabled = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_careRemindersPrefKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isImperial = _units == 'imperial';

    return GlassContainer(
      borderRadius: 18,
      border: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Row(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Appearance',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, mode) => Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.sheet(brightness),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.hairline(brightness)),
                    ),
                    child: Row(
                      children: [
                        _SegmentPill(
                          label: 'Light',
                          selected: mode == ThemeMode.light,
                          onTap: () => context.read<ThemeCubit>().setThemeMode(
                            ThemeMode.light,
                          ),
                        ),
                        _SegmentPill(
                          label: 'Dark',
                          selected: mode == ThemeMode.dark,
                          onTap: () => context.read<ThemeCubit>().setThemeMode(
                            ThemeMode.dark,
                          ),
                        ),
                        _SegmentPill(
                          label: 'Auto',
                          selected: mode == ThemeMode.system,
                          onTap: () => context.read<ThemeCubit>().setThemeMode(
                            ThemeMode.system,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _divider(brightness),
          _Row(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Units',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.sheet(brightness),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline(brightness)),
                  ),
                  child: Row(
                    children: [
                      _SegmentPill(
                        label: 'lb / °F',
                        selected: isImperial,
                        onTap: () => _setUnits('imperial'),
                      ),
                      _SegmentPill(
                        label: 'kg / °C',
                        selected: !isImperial,
                        onTap: () => _setUnits('metric'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _divider(brightness),
          _Row(
            onTap: _pickTimezone,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Time zone',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                Text(
                  _timezone.replaceAll('_', ' '),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: AppColors.textTertiary(brightness),
                ),
              ],
            ),
          ),
          _divider(brightness),
          _Row(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Care reminders',
                        style: AppTextStyles.listRowTitle.copyWith(
                          fontSize: 13.5,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Two nudges: a week out, then the day of',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleReminders,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: _remindersEnabled
                          ? AppColors.accentDeep
                          : AppColors.hairline(brightness),
                    ),
                    alignment: _remindersEnabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Brightness brightness) =>
      Container(height: 1, color: AppColors.hairline(brightness));
}

/// A single option in a track-style segmented control (Units,
/// Appearance). Colors go through [AppColors.accentOn] rather than the
/// bare dark-tuned `accent`/`accentLightest` constants — those read
/// fine on the dark canvas but wash out to near-invisible on the light
/// theme's white/parchment surfaces.
class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.accentOn(brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.chipLabel.copyWith(
            fontSize: 11.5,
            letterSpacing: 0,
            color: selected ? accent : AppColors.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account group
// ---------------------------------------------------------------------------
class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassContainer(
      borderRadius: 18,
      border: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Row(
            onTap: () => context.read<BillingCubit>().restorePurchases(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Restore purchases',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: AppColors.textTertiary(brightness),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.hairline(brightness)),
          _Row(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LegalDocumentScreen(doc: LegalDoc.terms),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Terms & privacy',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: AppColors.textTertiary(brightness),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.hairline(brightness)),
          _Row(
            onTap: () => _confirmDeleteAccount(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Delete account',
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 13.5,
                      color: AppColors.dangerOn(brightness),
                    ),
                  ),
                ),
                Text(
                  '30-day grace',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.hairline(brightness)),
          _Row(
            onTap: () =>
                context.read<AuthBloc>().add(const AuthSignedOutRequested()),
            child: Text(
              'Sign out',
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 13.5,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheet(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete account?',
          style: AppTextStyles.sheetTitle.copyWith(
            fontSize: 17,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        content: Text(
          'This permanently deletes your account, all pets, health records and memories after a '
          '30-day grace period. This cannot be undone.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary(brightness),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.listRowTitle.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final result = await getIt<AuthRepository>().deleteAccount();
              if (!context.mounted) return;
              switch (result) {
                case Ok():
                  context.read<AuthBloc>().add(const AuthSignedOutRequested());
                  AppSnackbar.show(
                    context,
                    message: 'Account scheduled for deletion.',
                    type: SnackbarType.success,
                  );
                case Err(:final failure):
                  AppSnackbar.show(
                    context,
                    message: 'Could not delete account — ${failure.message}',
                    type: SnackbarType.error,
                  );
              }
            },
            child: Text(
              'Delete',
              style: AppTextStyles.listRowTitle.copyWith(
                color: AppColors.dangerOn(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: child,
      ),
    );
  }
}
