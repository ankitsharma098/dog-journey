import 'dart:async';

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

  bool get isPro => status == BillingStatus.active || status == BillingStatus.trial;
  bool get isFree => status == BillingStatus.free;

  BillingState copyWith({
    BillingStatus? status,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    String? errorMessage,
  }) =>
      BillingState(
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
      AppLogger.warning('BillingCubit skipping load — Purchases not configured');
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
    final isTrial = isActive &&
        info.entitlements.active['pro']?.periodType == PeriodType.trial;
    emit(state.copyWith(
      customerInfo: info,
      status: isActive
          ? (isTrial ? BillingStatus.trial : BillingStatus.active)
          : BillingStatus.free,
    ));
    AppLogger.info(
      'BillingCubit customerInfo updated — isPro=$isActive',
    );
  }

  Future<BillingResult> purchase(Package package) async {
    AppLogger.debug('BillingCubit purchase ${package.storeProduct.identifier}');
    try {
      final info = await Purchases.purchase(PurchaseParams.package(package));
      _handleCustomerInfo(info.customerInfo);
      return BillingResult.success;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return BillingResult.cancelled;
      }
      AppLogger.error('BillingCubit purchase failed — ${e.name}');
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

  @override
  Future<void> close() {
    Purchases.removeCustomerInfoUpdateListener(_handleCustomerInfo);
    return super.close();
  }
}

enum BillingResult { success, cancelled, error }
