import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/injector.dart';
import '../logging/app_logger.dart';
import '../services/notification_service.dart';
import 'app_secrets.dart';

/// Runs once before [runApp].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    publishableKey: AppSecrets.supabaseAnonKey,
  );

  await _configurePurchases();

  setupInjector();
  await getIt<NotificationService>().init();
}

/// Every Purchases.* call (BillingCubit._load, .purchase, etc.) throws
/// "no singleton instance" until this runs — RevenueCat needs
/// Purchases.configure() before any other SDK method.
Future<void> _configurePurchases() async {
  final apiKey = Platform.isIOS
      ? AppSecrets.revenueCatAppleApiKey
      : AppSecrets.revenueCatGoogleApiKey;
  if (apiKey.isEmpty) {
    AppLogger.warning(
        'RevenueCat API key missing — skipping Purchases.configure(); '
        'billing will stay in BillingStatus.free until AppSecrets.'
        '${Platform.isIOS ? 'revenueCatAppleApiKey' : 'revenueCatGoogleApiKey'} is set');
    return;
  }
  await Purchases.configure(PurchasesConfiguration(apiKey));
}
