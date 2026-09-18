import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/logging/app_logger.dart';

enum BillingStatus { loading, free, trial, active, cancelled, error }

class BillingState {
  const BillingState({
    this.status = BillingStatus.loading,
    this.customerInfo,
    this.offerings,
    this.errorMessage,
  });

  final BillingStatus status;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final String? errorMessage;

  bool get isPro =>
      status == BillingStatus.active || status == BillingStatus.trial;
  bool get isFree => status == BillingStatus.free;

  /// "yearly" / "monthly" / "weekly", derived from the active `pro`
  /// entitlement's actual billing-period length rather than assumed —
  /// RevenueCat doesn't expose a friendly period string directly, and
  /// guessing from the product identifier would break the moment a
  /// differently-named SKU is added in App Store Connect / Play
  /// Console. Null while loading or on the free tier.
  String? get planPeriod {
    final pro = customerInfo?.entitlements.active['pro'];
    if (pro == null) return null;
    final expires = pro.expirationDate == null
        ? null
        : DateTime.tryParse(pro.expirationDate!);
    final purchased = DateTime.tryParse(pro.latestPurchaseDate);
    if (expires == null || purchased == null) return null;
    final days = expires.difference(purchased).inDays;
    if (days >= 300) return 'yearly';
    if (days >= 25) return 'monthly';
    if (days >= 6) return 'weekly';
    return null;
  }

  BillingState copyWith({
    BillingStatus? status,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    String? errorMessage,
  }) => BillingState(
    status: status ?? this.status,
    customerInfo: customerInfo ?? this.customerInfo,
    offerings: offerings ?? this.offerings,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class BillingCubit extends Cubit<BillingState> {
  BillingCubit() : super(const BillingState()) {
    _load();
  }

  Future<void> _load() async {
    AppLogger.debug('BillingCubit loading');
    // Purchases.configure() is skipped in bootstrap() while
    // AppSecrets.revenueCat*ApiKey is blank — calling any other
    // Purchases.* method first would just throw "no singleton
    // instance" every time, so check for that instead of relying on
    // the catch block to quietly swallow it every load.
    if (!await Purchases.isConfigured) {
      AppLogger.warning(
        'BillingCubit skipping load — Purchases not configured',
      );
      if (!isClosed) emit(state.copyWith(status: BillingStatus.free));
      return;
    }
    try {
      // Subscribe to customer info updates
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfo);
      // Initial fetch
      final info = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      _handleCustomerInfo(info);
      if (!isClosed) {
        emit(state.copyWith(offerings: offerings));
      }
    } catch (e, st) {
      AppLogger.error('BillingCubit _load failed', e, st);
      // Non-fatal — app works without billing
      if (!isClosed) emit(state.copyWith(status: BillingStatus.free));
    }
  }

  void _handleCustomerInfo(CustomerInfo info) {
    if (isClosed) return;
    final isActive = info.entitlements.active.containsKey('pro');
    final isTrial =
        isActive &&
        info.entitlements.active['pro']?.periodType == PeriodType.trial;
    emit(
      state.copyWith(
        customerInfo: info,
        status: isActive
            ? (isTrial ? BillingStatus.trial : BillingStatus.active)
            : BillingStatus.free,
      ),
    );
    AppLogger.info('BillingCubit customerInfo updated — isPro=$isActive');
  }

  Future<BillingResult> purchase(Package package) async {
    AppLogger.debug('BillingCubit purchase ${package.storeProduct.identifier}');
    try {
      final info = await Purchases.purchase(PurchaseParams.package(package));
      _handleCustomerInfo(info.customerInfo);
      return BillingResult.success;
    } on PlatformException catch (e) {
      // The SDK throws a plain PlatformException with a numeric string
      // `code` (e.g. "1"), not a PurchasesErrorCode directly — that
      // has to be decoded via PurchasesErrorHelper first. A bare
      // `on PurchasesErrorCode catch` never matches anything thrown,
      // so every cancellation (completely normal — backing out of the
      // sandbox sheet) fell through to "unexpected error" below and
      // showed a false "Purchase failed" message.
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        AppLogger.debug('BillingCubit purchase cancelled by user');
        return BillingResult.cancelled;
      }
      AppLogger.error('BillingCubit purchase failed — ${code.name}');
      return BillingResult.error;
    } catch (e, st) {
      AppLogger.error('BillingCubit purchase unexpected error', e, st);
      return BillingResult.error;
    }
  }

  Future<BillingResult> restorePurchases() async {
    AppLogger.debug('BillingCubit restorePurchases');
    try {
      final info = await Purchases.restorePurchases();
      _handleCustomerInfo(info);
      return BillingResult.success;
    } catch (e, st) {
      AppLogger.error('BillingCubit restorePurchases failed', e, st);
      return BillingResult.error;
    }
  }

  /// Ties RevenueCat's entitlement lookup to our own Supabase user id
  /// instead of the SDK's device-local anonymous id — without this,
  /// a purchase made under one anonymous id (e.g. before this call
  /// ever ran, or after a reinstall) is invisible to the same person
  /// signed into the same account on a different device/install,
  /// even though the entitlement is real. Called once AuthBloc emits
  /// AuthAuthenticated (see app.dart).
  Future<void> identify(String userId) async {
    if (!await Purchases.isConfigured) return;
    try {
      final result = await Purchases.logIn(userId);
      _handleCustomerInfo(result.customerInfo);
      AppLogger.info('BillingCubit identified as $userId');
    } catch (e, st) {
      AppLogger.error('BillingCubit identify failed', e, st);
    }
  }

  /// Detaches RevenueCat from the signed-out user's id so the next
  /// person to sign in on this device (or a return to guest state)
  /// never inherits the previous account's entitlement.
  Future<void> reset() async {
    if (!await Purchases.isConfigured) return;
    try {
      final info = await Purchases.logOut();
      _handleCustomerInfo(info);
      AppLogger.info('BillingCubit reset to anonymous');
    } catch (e, st) {
      AppLogger.error('BillingCubit reset failed', e, st);
    }
  }

  @override
  Future<void> close() {
    Purchases.removeCustomerInfoUpdateListener(_handleCustomerInfo);
    return super.close();
  }
}

enum BillingResult { success, cancelled, error }
