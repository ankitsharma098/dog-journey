import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../bloc/billing_cubit.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Paywall sheet presented when user hits a pro feature gate.
class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillingCubit, BillingState>(
      listener: (context, state) {
        if (state.isPro) Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final offering = state.offerings?.current;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF14142B), Color(0xFF1E1E40)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFFFF9950)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'PawJourney Pro',
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock unlimited AI vet chats, PDF export, and premium features for your dog.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Feature list
                _FeatureList(),
                const SizedBox(height: 24),
                // Pricing packages
                if (offering != null) ...[
                  ...offering.availablePackages.map(
                    (pkg) => _PackageCard(package: pkg),
                  ),
                ] else ...[
                  _PackageCard(package: null),
                ],
                const SizedBox(height: 16),
                // Restore
                TextButton(
                  onPressed: () =>
                      context.read<BillingCubit>().restorePurchases(),
                  child: Text(
                    'Restore purchases',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
                // Legal
                Text(
                  'Subscription auto-renews. Cancel anytime in App Store/Play Store settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.chat_rounded, 'Unlimited AI vet chats'),
      (Icons.vaccines_rounded, 'Full health passport export'),
      (Icons.picture_as_pdf_rounded, 'PDF export & vet sharing'),
      (Icons.notifications_active_rounded, 'Smart reminders'),
      (Icons.auto_stories_rounded, 'Unlimited memory timeline'),
      (Icons.cloud_sync_rounded, 'Multi-device sync'),
    ];

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(f.$1, color: AppColors.primary, size: 18),
                const SizedBox(width: 12),
                Text(
                  f.$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PackageCard extends StatefulWidget {
  const _PackageCard({this.package});
  final Package? package;

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final price = pkg?.storeProduct.priceString ?? '\$6.99';
    final period = pkg?.storeProduct.subscriptionPeriod ?? 'P1M';
    final label = period.contains('Y') ? 'year' : 'month';
    final isYearly = period.contains('Y');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: isYearly
            ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF9950)],
              )
            : null,
        color: isYearly ? null : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: !isYearly
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loading ? null : _purchase,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isYearly ? 'Annual' : 'Monthly',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          if (isYearly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '$price / $label',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _purchase() async {
    final pkg = widget.package;
    if (pkg == null) return;
    setState(() => _loading = true);
    final result = await context.read<BillingCubit>().purchase(pkg);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == BillingResult.error) {
      AppSnackbar.show(context, message: 'Purchase failed. Please try again.');
    }
  }
}
