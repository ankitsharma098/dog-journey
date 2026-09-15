import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/health_passport_cubit.dart';
import '../../data/models/health_record.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Bottom sheet for adding a new health record.
/// Adapts form fields based on the selected RecordType.
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
              'Add Health Record',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // Record type selector
            Text(
              'Type',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RecordType.values
                  .map((t) => ChoiceChip(
                        label: Text(t.label),
                        selected: t == _type,
                        onSelected: (v) {
                          if (v) setState(() { _type = t; _titleCtrl.clear(); });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: t == _type
                              ? AppColors.primary
                              : AppColors.textSecondaryLight,
                          fontWeight: t == _type
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Title
            AppTextField(
              controller: _titleCtrl,
              label: _titleLabel,
              hintText: _titleHint,
            ),
            const SizedBox(height: 12),

            // Date occurred
            _DateField(
              label: 'Date',
              value: _occurredOn,
              onPick: (d) => setState(() => _occurredOn = d),
            ),
            const SizedBox(height: 12),

            // Type-specific fields
            ..._typeFields(),

            // Notes
            AppTextField(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              hintText: 'Any additional details...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: _saving ? 'Saving…' : 'Save Record',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  String get _titleLabel => switch (_type) {
        RecordType.vaccine => 'Vaccine Name',
        RecordType.vetVisit => 'Reason for Visit',
        RecordType.medication => 'Medication Name',
        RecordType.weight => 'Weight Entry',
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

  List<Widget> _typeFields() {
    final fields = <Widget>[];
    switch (_type) {
      case RecordType.weight:
        fields.addAll([
          AppTextField(
            controller: _weightCtrl,
            label: 'Weight (kg)',
            hintText: 'e.g. 12.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
        ]);
      case RecordType.vaccine:
        fields.addAll([
          _DateField(
            label: 'Next Due (optional)',
            value: _dueOn,
            onPick: (d) => setState(() => _dueOn = d),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _clinicCtrl,
            label: 'Clinic / Vet (optional)',
            hintText: 'e.g. Happy Paws Vet Clinic',
          ),
          const SizedBox(height: 12),
        ]);
      case RecordType.vetVisit:
        fields.addAll([
          AppTextField(
            controller: _clinicCtrl,
            label: 'Clinic / Vet',
            hintText: 'e.g. City Animal Hospital',
          ),
          const SizedBox(height: 12),
        ]);
      case RecordType.medication:
        fields.addAll([
          AppTextField(
            controller: _dosageCtrl,
            label: 'Dosage',
            hintText: 'e.g. 16mg once daily',
          ),
          const SizedBox(height: 12),
          _DateField(
            label: 'Ends On (optional)',
            value: _dueOn,
            onPick: (d) => setState(() => _dueOn = d),
          ),
          const SizedBox(height: 12),
        ]);
      case RecordType.preventive:
        fields.addAll([
          _DateField(
            label: 'Next Due',
            value: _dueOn,
            onPick: (d) => setState(() => _dueOn = d),
          ),
          const SizedBox(height: 12),
        ]);
      default:
        break;
    }
    return fields;
  }

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
      dosageText:
          _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
      clinicName:
          _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
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
      AppSnackbar.show(context, 
        message: result.fold((_) => 'Saved', (f) => f.message),
        type: SnackbarType.error,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2010),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Text(
          value == null
              ? 'Select date'
              : DateFormat('MMM d, yyyy').format(value!),
          style: TextStyle(
            color: value == null
                ? AppColors.textSecondaryLight
                : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }
}
