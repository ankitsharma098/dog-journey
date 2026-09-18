import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/supabase_storage_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/royal/engraved_label.dart';
import '../../../../core/widgets/royal/fading_rule.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../../pets/data/models/pet.dart';
import '../../bloc/timeline_cubit.dart';
import '../../data/models/timeline_entry.dart';

/// The "Story" screen — README § "9. Memory Timeline". Reached from
/// Home's "Nine years, so far" strip; adding a memory now happens
/// behind the shell's centre FAB rather than a local one here.
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.activePet;
        if (pet == null) return const SizedBox.shrink();
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final userId = authState is AuthAuthenticated
                ? authState.profile.uid
                : '';
            return BlocProvider(
              key: ValueKey(pet.id),
              create: (_) => TimelineCubit(
                petId: pet.id,
                currentUserId: userId,
                timelineRepository: context.read(),
                storageService: GetIt.I<SupabaseStorageService>(),
              ),
              child: _TimelineView(pet: pet),
            );
          },
        );
      },
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      body: BlocBuilder<TimelineCubit, TimelineState>(
        builder: (context, state) {
          if (state.status == TimelineStatus.loading) {
            return const AsyncStateView.loading();
          }
          if (state.status == TimelineStatus.error) {
            return AsyncStateView.error(
              failure: ServerFailure(
                state.errorMessage ?? 'Something went wrong.',
              ),
              onRetry: () => context.read<TimelineCubit>().retry(),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Masthead(pet: pet)),
              if (state.entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyTimeline(petName: pet.name),
                )
              else ...[
                for (final key in state.monthKeys)
                  SliverToBoxAdapter(
                    child: _MonthSection(
                      monthKey: key,
                      entries: state.grouped[key]!,
                    ),
                  ),
                const SliverToBoxAdapter(child: _PrintYearbookCard()),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    final years = pet.birthdate == null
        ? null
        : ((DateTime.now().difference(pet.birthdate!).inDays) / 365.25).floor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          EngravedLabel(
            years == null ? 'The story so far' : '$years years and counting',
          ),
          const SizedBox(height: 6),
          Text(
            '${pet.name}\'s story',
            textAlign: TextAlign.center,
            style: AppTextStyles.screenTitle.copyWith(
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: 80, child: FadingRule(color: champagne)),
        ],
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({required this.monthKey, required this.entries});
  final String monthKey;
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _monthLabel(monthKey).toUpperCase(),
              style: AppTextStyles.chipLabel.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
          for (final e in entries) ...[
            _EntryCard(entry: e),
            const SizedBox(height: 26),
          ],
        ],
      ),
    );
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMMM yyyy').format(dt);
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          PhosphorIconsRegular.trash,
          color: AppColors.dangerOn(brightness),
        ),
      ),
      onDismissed: (_) => context.read<TimelineCubit>().deleteEntry(entry.id),
      child: GlassContainer(
        borderRadius: 20,
        border: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photos.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  aspectRatio: 390 / 230,
                  child: _EntryPhoto(photo: entry.photos.first),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title ?? entry.entryType.label,
                          style: AppTextStyles.listRowTitle.copyWith(
                            fontSize: 15,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _share(context, entry),
                        child: Icon(
                          PhosphorIconsRegular.export,
                          size: 16,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMMM d, yyyy').format(entry.entryDate),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                  if (entry.body != null && entry.body!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      entry.body!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _share(BuildContext context, TimelineEntry entry) async {
    final cubit = context.read<TimelineCubit>();
    final text = StringBuffer();
    if (entry.title != null) text.writeln(entry.title);
    if (entry.body != null) text.writeln(entry.body);
    text.writeln(DateFormat('MMMM d, yyyy').format(entry.entryDate));
    text.writeln('\nShared from PawJourney 🐾');

    await Share.share(
      text.toString(),
      subject: entry.title ?? "My dog's memory",
    );
    cubit.shareEntry(entry.id);
  }
}

class _EntryPhoto extends StatelessWidget {
  const _EntryPhoto({required this.photo});
  final Map<String, dynamic> photo;

  static Widget _errorPlaceholder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    final brightness = Theme.of(context).brightness;
    return Container(
      color: AppColors.hairline(brightness),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.image,
        color: AppColors.textTertiary(brightness),
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = (photo['url'] as String?) ?? '';
    if (url.isEmpty) return _errorPlaceholder(context, 'empty url', null);
    // Photos not yet uploaded to Supabase Storage live on-device — those
    // paths aren't URLs, so they need Image.file, not Image.network.
    final isDevicePhoto = photo['storage'] == 'device';
    return isDevicePhoto
        ? Image.file(
            File(url),
            fit: BoxFit.cover,
            errorBuilder: _errorPlaceholder,
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: _errorPlaceholder,
          );
  }
}

class _PrintYearbookCard extends StatelessWidget {
  const _PrintYearbookCard();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: champagne.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Print the year as a book',
            style: AppTextStyles.listRowTitle.copyWith(
              fontSize: 13,
              color: champagne,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Twelve months, bound in linen. A Pro perk.',
            textAlign: TextAlign.center,
            style: AppTextStyles.secondaryLine.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.bookOpen,
              size: 48,
              color: AppColors.textTertiary(brightness),
            ),
            const SizedBox(height: 18),
            Text(
              "$petName's story starts here",
              style: AppTextStyles.sectionHeading.copyWith(
                fontSize: 17,
                color: AppColors.textPrimary(brightness),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add photos, milestones, and memories. Birthdays and gotcha days are added automatically.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
