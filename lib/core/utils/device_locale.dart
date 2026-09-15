import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Device defaults used once, at sign-up, to seed `users.locale` /
/// `timezone` / `units` (db-design/00_core.sql). After that the user
/// owns these from settings, so nothing else should call this.
abstract final class DeviceLocale {
  static String locale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return '${locale.languageCode}-${locale.countryCode ?? locale.languageCode.toUpperCase()}';
  }

  static Future<String> timezone() async {
    final tz = await FlutterTimezone.getLocalTimezone();
    return tz.identifier;
  }

  /// The US and a couple of holdouts read pounds; everyone else reads
  /// kg. A reasonable seed default — the user can override it later.
  static String units() {
    final country = WidgetsBinding.instance.platformDispatcher.locale
        .countryCode;
    return {'US', 'LR', 'MM'}.contains(country) ? 'imperial' : 'metric';
  }
}
