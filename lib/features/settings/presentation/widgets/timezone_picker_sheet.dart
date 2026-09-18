import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Searchable IANA timezone picker. `tz.timeZoneDatabase.locations` is
/// populated at app startup by `NotificationService.init()`'s
/// `tz_data.initializeTimeZones()` call (needed there for scheduling
/// local reminders), so this reads the same database rather than
/// bundling its own list.
Future<String?> showTimezonePickerSheet(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimezonePickerSheet(current: current),
  );
}

class _TimezonePickerSheet extends StatefulWidget {
  const _TimezonePickerSheet({required this.current});
  final String current;

  @override
  State<_TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<_TimezonePickerSheet> {
  late final List<String> _all = tz.timeZoneDatabase.locations.keys.toList()
    ..sort();
  late List<String> _filtered = _all;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.trim().isEmpty
          ? _all
          : _all
                .where((tz) => tz.toLowerCase().contains(query.toLowerCase()))
                .toList();
    });
  }

  String _offsetLabel(String name) {
    final location = tz.timeZoneDatabase.locations[name];
    if (location == null) return '';
    final hours = location.currentTimeZone.offset.inHours;
    final sign = hours >= 0 ? '+' : '';
    return 'UTC$sign$hours';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    final accent = AppColors.accentOn(brightness);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.sheet(brightness),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(
            top: BorderSide(color: champagne.withValues(alpha: 0.3)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary(brightness).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Time zone',
              style: AppTextStyles.sheetTitle.copyWith(
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary(brightness),
              ),
              decoration: InputDecoration(
                hintText: 'Search cities, regions…',
                prefixIcon: Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: _filtered.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: AppColors.hairline(brightness)),
                itemBuilder: (context, i) {
                  final name = _filtered[i];
                  final selected = name == widget.current;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => Navigator.of(context).pop(name),
                    title: Text(
                      name.replaceAll('_', ' '),
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 13.5,
                        color: selected
                            ? accent
                            : AppColors.textPrimary(brightness),
                      ),
                    ),
                    trailing: Text(
                      _offsetLabel(name),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
