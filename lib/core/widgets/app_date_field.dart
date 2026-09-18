import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A tappable field that opens the platform date picker — every date
/// input in the app (pet birthdate, vaccine date, weigh-in date…) uses
/// this instead of wiring showDatePicker by hand each time.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 30),
          lastDate: lastDate ?? now,
          // The default Material picker reads as a generic system
          // dialog dropped onto an otherwise fully custom, dark
          // "Royal" screen — this re-skins it in the same palette
          // (champagne header/selection, accent "Today" outline)
          // rather than building a bespoke calendar from scratch.
          builder: (context, child) =>
              Theme(data: _datePickerTheme(brightness), child: child!),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null
                  ? DateFormat.yMMMd().format(value!)
                  : 'Select a date',
              style: TextStyle(
                color: value != null
                    ? null
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  ThemeData _datePickerTheme(Brightness brightness) {
    final champagne = AppColors.champagneOn(brightness);
    final accent = AppColors.accentOn(brightness);
    final surface = AppColors.sheet(brightness);
    final onSurface = AppColors.textPrimary(brightness);

    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: champagne,
        onPrimary: AppColors.canvasDark,
        surface: surface,
        onSurface: onSurface,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerBackgroundColor: champagne.withValues(alpha: 0.14),
        headerForegroundColor: onSurface,
        headerHeadlineStyle: AppTextStyles.screenTitleCompact.copyWith(
          color: onSurface,
        ),
        weekdayStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary(brightness),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.canvasDark
              : onSurface,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? champagne
              : Colors.transparent,
        ),
        // Flutter resolves today's cell colors from todayForeground/
        // BackgroundColor even when it's also the *selected* day — it
        // does NOT fall back to dayForegroundColor/dayBackgroundColor
        // in that case. Leaving todayBackgroundColor unset meant a
        // selected-and-today cell rendered transparent with champagne
        // text on top of the champagne-tinted header/selection area,
        // i.e. invisible. Both must branch on selected state exactly
        // like the day colors above.
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.canvasDark
              : champagne,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? champagne
              : Colors.transparent,
        ),
        todayBorder: const BorderSide(),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.canvasDark
              : onSurface,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? champagne
              : Colors.transparent,
        ),
        rangePickerBackgroundColor: surface,
        dividerColor: AppColors.hairline(brightness),
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
    );
  }
}
