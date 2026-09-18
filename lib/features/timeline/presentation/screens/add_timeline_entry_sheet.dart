import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_source_picker.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/timeline_cubit.dart';
import '../../data/models/timeline_entry.dart';

IconData _entryTypeIcon(EntryType type) => switch (type) {
  EntryType.photo => PhosphorIconsFill.imagesSquare,
  EntryType.milestone => PhosphorIconsFill.trophy,
  EntryType.note => PhosphorIconsFill.notepad,
  EntryType.gotchaDay => PhosphorIconsFill.house,
  EntryType.birthday => PhosphorIconsFill.cake,
  EntryType.first => PhosphorIconsFill.sparkle,
};

/// "Add a memory" — reached from the shell's centre FAB. The photo
/// picker leads (this app's whole story feature is photo-first — see
/// Home's "so far" strip) rather than being one field among many, and
/// the sheet stays champagne-accented like the passport/crest instead
/// of borrowing the generic hairline chrome other "add X" sheets use,
/// since a memory is meant to feel more occasion than form.
class AddTimelineEntrySheet extends StatefulWidget {
  const AddTimelineEntrySheet({super.key});

  @override
  State<AddTimelineEntrySheet> createState() => _AddTimelineEntrySheetState();
}

class _AddTimelineEntrySheetState extends State<AddTimelineEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  EntryType _type = EntryType.photo;
  DateTime _date = DateTime.now();
  Uint8List? _photoBytes;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    final accent = AppColors.accentOn(brightness);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheet(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(color: champagne.withValues(alpha: 0.3)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 26 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary(
                    brightness,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A new memory',
                        style: AppTextStyles.sheetTitle.copyWith(
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A photo says it best — everything else is optional.',
                        style: AppTextStyles.secondaryLine.copyWith(
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsFill.sparkle,
                  size: 20,
                  color: champagne.withValues(alpha: 0.7),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 176,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: _photoBytes == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            champagne.withValues(alpha: 0.14),
                            accent.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  border: Border.all(color: champagne.withValues(alpha: 0.5)),
                ),
                child: _photoBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: Image.memory(
                              _photoBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsRegular.arrowsClockwise,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: champagne.withValues(alpha: 0.6),
                              ),
                              color: champagne.withValues(alpha: 0.1),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              PhosphorIconsFill.camera,
                              color: champagne,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Capture this moment',
                            style: AppTextStyles.listRowTitle.copyWith(
                              fontSize: 13,
                              color: AppColors.textPrimary(brightness),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to choose a photo',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Title',
              controller: _titleCtrl,
              hintText: 'e.g. First park visit',
            ),
            const SizedBox(height: 16),
            Text(
              'Kind of memory',
              style: AppTextStyles.secondaryLine.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EntryType.values
                  .where((t) => !t.isSpecialDay && t != EntryType.first)
                  .map((t) {
                    final selected = t == _type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected
                              ? accent.withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? accent
                                : AppColors.hairline(brightness),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _entryTypeIcon(t),
                              size: 14,
                              color: selected
                                  ? accent
                                  : AppColors.textSecondary(brightness),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.label,
                              style: AppTextStyles.listRowTitle.copyWith(
                                fontSize: 12.5,
                                color: selected
                                    ? AppColors.textPrimary(brightness)
                                    : AppColors.textSecondary(brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Caption (optional)',
              controller: _bodyCtrl,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            AppDateField(
              label: 'Date',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Save memory',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickImageWithSourceChoice(context);
    if (bytes == null) return;
    if (mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty && _photoBytes == null) {
      AppSnackbar.show(
        context,
        message: 'Add a title or a photo to save this memory.',
      );
      return;
    }
    setState(() => _saving = true);

    final entry = TimelineEntry(
      petId: '',
      entryType: _type,
      title: title.isEmpty ? _type.label : title,
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      entryDate: _date,
      createdById: '',
    );

    final result = await context.read<TimelineCubit>().addEntry(
      entry,
      photoBytes: _photoBytes,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isOk) {
      Navigator.of(context).pop();
    } else {
      AppSnackbar.show(
        context,
        message: result.fold((_) => 'Saved', (f) => f.message),
        type: SnackbarType.error,
      );
    }
  }
}
