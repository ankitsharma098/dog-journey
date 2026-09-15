import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../billing/presentation/screens/paywall_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
      ),
      body: BlocBuilder<BillingCubit, BillingState>(
        builder: (context, billing) {
          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, auth) {
              final email = auth is AuthAuthenticated ? auth.profile.email : '';
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Subscription status
                  _SectionHeader(title: 'Subscription'),
                  _SubscriptionCard(billing: billing),
                  const SizedBox(height: 20),
                  // Account
                  _SectionHeader(title: 'Account'),
                  _SettingsTile(
                    icon: Icons.email_outlined,
                    title: email.isEmpty ? 'Not signed in' : email,
                    subtitle: 'Your account email',
                  ),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    iconColor: AppColors.danger,
                    onTap: () => context.read<AuthBloc>().add(
                      const AuthSignedOutRequested(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Danger zone
                  _SectionHeader(title: 'Danger Zone'),
                  _SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete account',
                    subtitle: 'Permanently delete your account and all data',
                    iconColor: AppColors.danger,
                    titleColor: AppColors.danger,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                  const SizedBox(height: 20),
                  // About
                  _SectionHeader(title: 'About'),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: '1.0.0 (build 1)',
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => AppSnackbar.show(
                      context,
                      message: 'Privacy Policy — coming soon.',
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.article_outlined,
                    title: 'Terms of Service',
                    onTap: () => AppSnackbar.show(
                      context,
                      message: 'Terms of Service — coming soon.',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account, all pets, health records, and memories. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await getIt<AuthRepository>().deleteAccount();
              if (!context.mounted) return;
              switch (result) {
                case Ok():
                  context.read<AuthBloc>().add(const AuthSignedOutRequested());
                  AppSnackbar.show(
                    context,
                    message: 'Account deleted.',
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
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.billing});
  final BillingState billing;

  @override
  Widget build(BuildContext context) {
    final isPro = billing.isPro;
    return Container(
      decoration: BoxDecoration(
        gradient: isPro
            ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF9950)],
              )
            : null,
        color: isPro ? null : null,
        borderRadius: BorderRadius.circular(16),
        border: !isPro
            ? Border.all(color: AppColors.dividerLight, width: 0.5)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          isPro ? Icons.workspace_premium_rounded : Icons.lock_outlined,
          color: isPro ? Colors.white : AppColors.primary,
        ),
        title: Text(
          isPro ? 'PawJourney Pro' : 'Free Plan',
          style: TextStyle(
            color: isPro ? Colors.white : null,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          isPro
              ? 'Thank you for supporting PawJourney!'
              : '3 AI chats / day · Basic features',
          style: TextStyle(
            color: isPro ? Colors.white70 : AppColors.textSecondaryLight,
            fontSize: 12,
          ),
        ),
        trailing: !isPro
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BlocProvider.value(
                    value: context.read<BillingCubit>(),
                    child: const PaywallSheet(),
                  ),
                ),
                child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
              )
            : null,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: titleColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: onTap != null
            ? const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryLight,
                size: 18,
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
