import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/legal/legal_document_screen.dart';
import '../../bloc/billing_cubit.dart';

/// The bottom-sheet paywall — for soft teasers (post-scan, nutrition
/// entry). See README § "10. Paywall — bottom sheet (default)". The
/// full-screen alternate (README § 11) is for hard gates; this app
/// doesn't have a distinct hard-gate flow yet, so this single surface
/// covers both until one is needed.
/// Real savings, not an assumed "50%" — compares the yearly package's
/// normalised monthly-equivalent price against the actual monthly
/// package's price, so this stays correct if pricing ever changes in
/// App Store Connect / Play Console without a code change. Null
/// (renders as just the period) whenever both prices aren't available
/// to compare, rather than guessing.
String? _yearlySavingsLabel(List<Package?> packages) {
  StoreProduct? monthly;
  StoreProduct? yearly;
  for (final pkg in packages) {
    final period = pkg?.storeProduct.subscriptionPeriod;
    if (period == null) continue;
    if (period.contains('Y')) yearly = pkg!.storeProduct;
    if (period.contains('M') && !period.contains('Y')) {
      monthly = pkg!.storeProduct;
    }
  }
  final monthlyPrice = monthly?.price;
  final yearlyPerMonth = yearly?.pricePerMonth;
  if (monthlyPrice == null || monthlyPrice <= 0 || yearlyPerMonth == null) {
    return null;
  }
  final pct = ((1 - (yearlyPerMonth / monthlyPrice)) * 100).round();
  return pct > 0 ? 'save $pct%' : null;
}

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen;

  static const _perks = [
    'Unlimited AI vet chat',
    'Every dog in the house, one account',
    'Photos backed up, forever',
    'Breed health watchlists',
  ];

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillingCubit, BillingState>(
      listener: (context, state) {
        if (state.isPro) Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final offering = state.offerings?.current;
        final packages = offering?.availablePackages ?? const <Package?>[null];
        final savingsLabel = _yearlySavingsLabel(packages);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-0.3, -1),
                end: Alignment(0.3, 1),
                colors: [Color(0xFF2B2741), Color(0xFF1D1F2C)],
                stops: [0, 0.7],
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.champagne.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _sheen,
                    builder: (context, _) => IgnorePointer(
                      child: Align(
                        alignment: Alignment(-3 + _sheen.value * 6, 0),
                        child: Transform.rotate(
                          angle: -0.35,
                          child: Container(
                            width: 140,
                            height: 900,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.champagne.withValues(alpha: 0.09),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    16,
                    22,
                    28 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.champagne.withValues(alpha: 0.6),
                          ),
                          color: AppColors.champagne.withValues(alpha: 0.08),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          PhosphorIconsFill.crownSimple,
                          size: 24,
                          color: AppColors.champagne,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'PAWJOURNEY PRO',
                        style: AppTextStyles.engravedLabel.copyWith(
                          letterSpacing: 0.32 * 9.5,
                          color: AppColors.champagne,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Unlimited vet chat, and nothing left to memory.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.screenTitle.copyWith(
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: _perks
                            .map(
                              (perk) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      PhosphorIconsFill.checkCircle,
                                      size: 16,
                                      color: AppColors.champagne,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        perk,
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      // While the very first RevenueCat/StoreKit round
                      // trip is in flight (a few seconds on a cold
                      // start), show a spinner rather than the
                      // "Unavailable" fallback — that fallback means
                      // the fetch genuinely came back empty, which
                      // isn't true yet during this window and looks
                      // broken to a reviewer who taps in fast.
                      if (state.status == BillingStatus.loading)
                        const SizedBox(
                          height: 92,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            for (final pkg in packages) ...[
                              Expanded(
                                child: _PlanCard(
                                  package: pkg,
                                  savingsLabel:
                                      (pkg?.storeProduct.subscriptionPeriod
                                              ?.contains('Y') ??
                                          false)
                                      ? savingsLabel
                                      : null,
                                ),
                              ),
                              if (pkg != packages.last)
                                const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink(
                            label: 'Restore purchases',
                            onTap: () =>
                                context.read<BillingCubit>().restorePurchases(),
                          ),
                          const SizedBox(width: 18),
                          _FooterLink(
                            label: 'Terms',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LegalDocumentScreen(
                                  doc: LegalDoc.terms,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          _FooterLink(
                            label: 'Privacy',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LegalDocumentScreen(
                                  doc: LegalDoc.privacy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({this.package, this.savingsLabel});
  final Package? package;
  final String? savingsLabel;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    // No fake "$9.99" — if RevenueCat's offerings failed to load, this
    // card must look and behave unavailable rather than pass off a
    // guessed price as real, tappable pricing that can't actually
    // charge anyone (see _purchase's no-op below).
    final unavailable = pkg == null;
    final price = pkg?.storeProduct.priceString;
    final period = pkg?.storeProduct.subscriptionPeriod ?? '';
    final isYearly = period.contains('Y');
    final dimAlpha = unavailable ? 0.4 : 1.0;

    return GestureDetector(
      onTap: unavailable || _loading ? null : _purchase,
      child: Opacity(
        opacity: dimAlpha,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isYearly
                  ? AppColors.champagne
                  : Colors.white.withValues(alpha: 0.16),
            ),
            color: isYearly
                ? AppColors.champagne.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Column(
            children: [
              Text(
                isYearly
                    ? 'YEARLY'
                    : (period.contains('W') ? 'WEEKLY' : 'MONTHLY'),
                style: AppTextStyles.chipLabel.copyWith(
                  fontSize: 10.5,
                  color: isYearly
                      ? AppColors.champagne
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Text(
                  price ?? '—',
                  style: AppTextStyles.listRowTitle.copyWith(
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                unavailable
                    ? 'Unavailable'
                    : (widget.savingsLabel ?? (isYearly ? '' : 'per month')),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
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
