import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/timeline_cubit.dart';
import '../../data/models/timeline_entry.dart';
import '../../../../core/widgets/app_snackbar.dart';

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
  XFile? _pickedPhoto;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Memory',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            // Type
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EntryType.values
                  .where((t) => !t.isSpecialDay && t != EntryType.first)
                  .map(
                    (t) => ChoiceChip(
                      label: Text(t.label),
                      selected: t == _type,
                      onSelected: (v) {
                        if (v) setState(() => _type = t);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Photo picker
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _pickedPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(
                          File(_pickedPhoto!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add photo (optional)',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. First park visit',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Caption (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Date
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2010),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  suffixIcon: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(DateFormat('MMM d, yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Save Memory',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img != null) setState(() => _pickedPhoto = img);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty && _type != EntryType.photo) {
      AppSnackbar.show(context, message: 'Please add a title.');
      return;
    }
    setState(() => _saving = true);

    // For now, photos use local path. Full Supabase Storage upload
    // is handled in the Edge Function / background upload worker.
    final photos = _pickedPhoto != null
        ? [
            {'url': _pickedPhoto!.path, 'storage': 'device'},
          ]
        : <Map<String, dynamic>>[];

    final entry = TimelineEntry(
      petId: '',
      entryType: _type,
      title: title.isEmpty ? _type.label : title,
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      entryDate: _date,
      photos: photos,
      createdById: '',
    );

    final result = await context.read<TimelineCubit>().addEntry(entry);
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
