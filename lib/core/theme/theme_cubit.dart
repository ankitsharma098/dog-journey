import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app previously had no in-app light/dark override at all —
/// `MaterialApp.router` left `themeMode` unset, which defaults to
/// `ThemeMode.system`, so the device's OS setting was the only lever.
/// This persists an explicit user choice (falling back to `system`
/// until they pick one) the same way `_careRemindersPrefKey` in
/// settings_screen.dart persists its own preference.
const themeModePrefKey = 'app_theme_mode';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(themeModePrefKey);
    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (!isClosed) emit(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModePrefKey, mode.name);
  }
}
