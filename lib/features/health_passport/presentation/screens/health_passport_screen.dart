import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../../pets/data/models/pet.dart';
import '../../bloc/health_passport_cubit.dart';
import '../../data/models/health_record.dart';
import '../widgets/health_record_tile.dart';
import '../widgets/vaccine_card.dart';
import '../widgets/weight_chart.dart';
import 'add_health_record_sheet.dart';

class HealthPassportScreen extends StatelessWidget {
  const HealthPassportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.pets.isNotEmpty ? petsState.pets.first : null;
        if (pet == null) return const _EmptyPassportView();

        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final userId = authState is AuthAuthenticated
                ? authState.profile.uid
                : '';
            return BlocProvider(
              key: ValueKey(pet.id),
              create: (_) => HealthPassportCubit(
                petId: pet.id,
                currentUserId: userId,
                healthRecordRepository: context.read(),
                vaccineTypeRepository: context.read(),
              ),
              child: _PassportView(pet: pet),
            );
          },
        );
      },
    );
  }
}

class _PassportView extends StatefulWidget {
  const _PassportView({required this.pet});
  final Pet pet;

  @override
  State<_PassportView> createState() => _PassportViewState();
}

class _PassportViewState extends State<_PassportView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          '${widget.pet.name}\'s Passport',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignedOutRequested()),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: false,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'Vaccines'),
            Tab(text: 'Meds'),
            Tab(text: 'Weight'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'healthPassportFab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Record'),
        onPressed: () => _openAddSheet(context),
      ),
      body: Column(
        children: [
          _PetHeader(pet: widget.pet),
          Expanded(
            child: BlocBuilder<HealthPassportCubit, HealthPassportState>(
              builder: (context, state) {
                if (state.status == HealthPassportStatus.loading) {
                  return const AsyncStateView.loading();
                }
                if (state.status == HealthPassportStatus.error) {
                  return AsyncStateView.error(
                    failure: ServerFailure(
                      state.errorMessage ?? 'Something went wrong.',
                    ),
                    onRetry: () => context.read<HealthPassportCubit>().retry(),
                  );
                }
                return TabBarView(
                  controller: _tab,
                  children: [
                    _TimelineTab(pet: widget.pet),
                    _VaccinesTab(pet: widget.pet),
                    _MedsTab(),
                    _WeightTab(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<HealthPassportCubit>(),
        child: const AddHealthRecordSheet(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pet Header
// ---------------------------------------------------------------------------
class _PetHeader extends StatelessWidget {
  const _PetHeader({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final age = pet.birthdate != null
        ? _ageString(pet.birthdate!)
        : 'Age unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: pet.photoUrl != null
                  ? NetworkImage(pet.photoUrl!)
                  : null,
              child: pet.photoUrl == null
                  ? const Icon(
                      Icons.pets_rounded,
                      color: AppColors.primary,
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: GoogleFonts.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    age,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            BlocBuilder<HealthPassportCubit, HealthPassportState>(
              builder: (context, state) {
                final weight = state.records
                    .where(
                      (r) => r.type == RecordType.weight && r.weightKg != null,
                    )
                    .toList();
                if (weight.isEmpty) return const SizedBox.shrink();
                final latest = weight.first;
                return _WeightChip(kg: latest.weightKg!);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _ageString(DateTime birthdate) {
    final now = DateTime.now();
    final diff = now.difference(birthdate);
    final months = diff.inDays ~/ 30;
    if (months < 12) return '$months month${months == 1 ? '' : 's'} old';
    final years = months ~/ 12;
    final rem = months % 12;
    if (rem == 0) return '$years yr${years == 1 ? '' : 's'} old';
    return '$years yr${years == 1 ? '' : 's'} $rem mo old';
  }
}

class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.kg});
  final double kg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monitor_weight_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '${kg.toStringAsFixed(1)} kg',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline Tab
// ---------------------------------------------------------------------------
class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthPassportCubit, HealthPassportState>(
      builder: (context, state) {
        if (state.status == HealthPassportStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.records.isEmpty) {
          return _EmptyState(
            icon: Icons.folder_open_rounded,
            title: 'No records yet',
            subtitle: 'Tap + Add Record to log vaccines, vet visits, and more.',
          );
        }

        // Group by year
        final grouped = <int, List<HealthRecord>>{};
        for (final r in state.records) {
          grouped.putIfAbsent(r.occurredOn.year, () => []).add(r);
        }
        final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            for (final year in years) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  year.toString(),
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
              for (final r in grouped[year]!)
                HealthRecordTile(
                  record: r,
                  onDelete: () =>
                      context.read<HealthPassportCubit>().deleteRecord(r.id),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Vaccines Tab
// ---------------------------------------------------------------------------
class _VaccinesTab extends StatelessWidget {
  const _VaccinesTab({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthPassportCubit, HealthPassportState>(
      builder: (context, state) {
        final vaccines = state.vaccines;
        if (vaccines.isEmpty) {
          return _EmptyState(
            icon: Icons.vaccines_rounded,
            title: 'No vaccines recorded',
            subtitle:
                'Add a vaccine record to track your dog\'s immunisation schedule.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: vaccines
              .map(
                (v) => VaccineCard(
                  record: v,
                  vaccineType:
                      state.vaccineTypes.cast<dynamic>().firstWhere(
                            (t) => (t as dynamic).id == v.vaccineTypeId,
                            orElse: () => null,
                          )
                          as dynamic,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Meds Tab
// ---------------------------------------------------------------------------
class _MedsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthPassportCubit, HealthPassportState>(
      builder: (context, state) {
        final meds = state.medications;
        if (meds.isEmpty) {
          return _EmptyState(
            icon: Icons.medication_rounded,
            title: 'No active medications',
            subtitle:
                'Add a medication record to track dose schedules and end dates.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: meds
              .map(
                (r) => HealthRecordTile(
                  record: r,
                  onDelete: () => context
                      .read<HealthPassportCubit>()
                      .deactivateMedication(r.id),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Weight Tab
// ---------------------------------------------------------------------------
class _WeightTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthPassportCubit, HealthPassportState>(
      builder: (context, state) {
        final weights = state.weightRecords;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weight History',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WeightChart(records: weights),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...weights.map(
              (r) => HealthRecordTile(
                record: r,
                onDelete: () =>
                    context.read<HealthPassportCubit>().deleteRecord(r.id),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPassportView extends StatelessWidget {
  const _EmptyPassportView();

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Health Passport',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_shared_rounded,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No Dog Selected',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your dog to track vaccinations, medications, weight, and health records.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
