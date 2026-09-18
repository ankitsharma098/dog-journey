import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../bloc/health_passport_cubit.dart';
import '../../data/models/health_record.dart';

/// Bottom sheet for adding a new health record — "Add to the passport"
/// in README § Interactions & Behaviour. Adapts the first field's
/// label/hint to the selected [RecordType]; a dashed champagne "Next
/// due" field pre-fills +1 year for periodic types.
class AddHealthRecordSheet extends StatefulWidget {
  const AddHealthRecordSheet({super.key});

  @override
  State<AddHealthRecordSheet> createState() => _AddHealthRecordSheetState();
}

class _AddHealthRecordSheetState extends State<AddHealthRecordSheet> {
  RecordType _type = RecordType.vaccine;
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  DateTime _occurredOn = DateTime.now();
  DateTime? _dueOn;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _clinicCtrl.dispose();
    _dosageCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheet(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(color: AppColors.champagne.withValues(alpha: 0.3)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 26 + bottomPadding),
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
                  color: AppColors.textPrimary(brightness).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add to the passport',
              style: AppTextStyles.sheetTitle.copyWith(
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Three fields is usually enough. The rest can wait.',
              style: AppTextStyles.secondaryLine.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RecordType.values.map((t) {
                final selected = t == _type;
                return GestureDetector(
                  onTap: () => setState(() {
                    _type = t;
                    _titleCtrl.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.accent
                            : AppColors.hairline(brightness),
                      ),
                    ),
                    child: Text(
                      t.label,
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 12.5,
                        color: selected
                            ? AppColors.textPrimary(brightness)
                            : AppColors.textSecondary(brightness),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _FieldLabel(_titleLabel),
            _RoyalTextField(controller: _titleCtrl, hintText: _titleHint),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Date'),
                      _DateField(
                        value: _occurredOn,
                        onPick: (d) => setState(() => _occurredOn = d),
                      ),
                    ],
                  ),
                ),
                if (_showsNextDue) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Next due'),
                        _DueDateField(
                          value: _dueOn,
                          onPick: (d) => setState(() => _dueOn = d),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_type == RecordType.weight) ...[
              const SizedBox(height: 12),
              const _FieldLabel('Weight (kg)'),
              _RoyalTextField(
                controller: _weightCtrl,
                hintText: 'e.g. 12.5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            if (_type == RecordType.medication) ...[
              const SizedBox(height: 12),
              const _FieldLabel('Dosage'),
              _RoyalTextField(controller: _dosageCtrl, hintText: 'e.g. 16mg once daily'),
            ],
            if (_showsClinic) ...[
              const SizedBox(height: 12),
              const _FieldLabel('Clinic (optional)'),
              _RoyalTextField(controller: _clinicCtrl, hintText: 'Dr. Rao, Paws & Claws'),
            ],
            const SizedBox(height: 12),
            const _FieldLabel('Notes (optional)'),
            _RoyalTextField(controller: _notesCtrl, hintText: 'Any additional details', maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saving ? null : _save,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(
                  _saving ? 'Saving…' : 'Save to passport',
                  style: AppTextStyles.listRowTitle.copyWith(
                    fontSize: 14.5,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A reminder is set automatically when a next-due date exists.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showsNextDue =>
      _type == RecordType.vaccine ||
      _type == RecordType.medication ||
      _type == RecordType.preventive;

  bool get _showsClinic =>
      _type == RecordType.vaccine || _type == RecordType.vetVisit;

  String get _titleLabel => switch (_type) {
        RecordType.vaccine => 'Vaccine name',
        RecordType.vetVisit => 'Reason for visit',
        RecordType.medication => 'Medication name',
        RecordType.weight => 'Weight entry',
        RecordType.allergy => 'Allergen',
        RecordType.preventive => 'Treatment',
      };

  String get _titleHint => switch (_type) {
        RecordType.vaccine => 'e.g. Rabies, DHPP',
        RecordType.vetVisit => 'e.g. Annual checkup',
        RecordType.medication => 'e.g. Apoquel 16mg',
        RecordType.weight => 'e.g. Vet weigh-in',
        RecordType.allergy => 'e.g. Chicken protein',
        RecordType.preventive => 'e.g. Heartworm prevention',
      };

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppSnackbar.show(context, message: 'Please enter a title.');
      return;
    }

    setState(() => _saving = true);

    double? weightKg;
    if (_type == RecordType.weight) {
      weightKg = double.tryParse(_weightCtrl.text.trim());
      if (weightKg == null) {
        setState(() => _saving = false);
        AppSnackbar.show(context, message: 'Please enter a valid weight.');
        return;
      }
    }

    final cubit = context.read<HealthPassportCubit>();
    final record = HealthRecord(
      petId: '',
      type: _type,
      title: title,
      occurredOn: _occurredOn,
      dueOn: _dueOn,
      weightKg: weightKg,
      dosageText: _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
      clinicName: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdById: '',
    );

    final result = await cubit.addRecord(record);
    if (!mounted) return;

    setState(() => _saving = false);
    if (result.isOk) {
      Navigator.of(context).pop();
      AppSnackbar.show(context, message: 'Record saved!');
    } else {
      AppSnackbar.show(
        context,
        message: result.fold((_) => 'Saved', (f) => f.message),
        type: SnackbarType.error,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Field pieces
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.chipLabel.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
          color: AppColors.textTertiary(brightness),
        ),
      ),
    );
  }
}

class _RoyalTextField extends StatelessWidget {
  const _RoyalTextField({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTextStyles.body.copyWith(
        height: 1,
        color: AppColors.textPrimary(brightness),
      ),
      decoration: InputDecoration(hintText: hintText),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onPick});
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2010),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.card(brightness),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline(brightness)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM d, yyyy').format(value),
              style: AppTextStyles.body.copyWith(
                height: 1,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            Icon(PhosphorIconsRegular.calendarBlank, size: 16, color: AppColors.textTertiary(brightness)),
          ],
        ),
      ),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({required this.value, required this.onPick});
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: champagne.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value == null ? '+ 1 year' : DateFormat('MMM d, yyyy').format(value!),
              style: AppTextStyles.body.copyWith(height: 1, color: champagne),
            ),
            Icon(PhosphorIconsFill.bellRinging, size: 15, color: champagne),
          ],
        ),
      ),
    );
  }
}
