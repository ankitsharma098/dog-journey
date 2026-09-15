import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../bloc/timeline_cubit.dart';
import '../../data/models/timeline_entry.dart';
import 'add_timeline_entry_sheet.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.pets.isNotEmpty ? petsState.pets.first : null;
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
              ),
              child: _TimelineView(petName: pet.name),
            );
          },
        );
      },
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          '$petName\'s Story',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'timelineFab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_photo_alternate_rounded),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BlocProvider.value(
            value: context.read<TimelineCubit>(),
            child: const AddTimelineEntrySheet(),
          ),
        ),
      ),
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
          if (state.entries.isEmpty) {
            return _EmptyTimeline(petName: petName);
          }
          return _TimelineList(state: state);
        },
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.state});
  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    final monthKeys = state.monthKeys;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: monthKeys.length,
      itemBuilder: (_, i) {
        final key = monthKeys[i];
        final entries = state.grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _monthLabel(key),
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
            ...entries.map((e) => _EntryCard(entry: e)),
          ],
        );
      },
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
    final isSpecial = entry.isSpecialDay;

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) => context.read<TimelineCubit>().deleteEntry(entry.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSpecial ? AppColors.primary.withValues(alpha: 0.08) : null,
          border: isSpecial
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo grid
            if (entry.photos.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _EntryPhoto(photo: entry.photos.first),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title ?? entry.entryType.label,
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // Share button
                      GestureDetector(
                        onTap: () => _share(context, entry),
                        child: Icon(
                          Icons.ios_share_rounded,
                          size: 18,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM d, yyyy').format(entry.entryDate),
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                  if (entry.body != null && entry.body!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.body!,
                      style: const TextStyle(fontSize: 13, height: 1.5),
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
  ) => Container(
    color: AppColors.primary.withValues(alpha: 0.1),
    child: const Icon(Icons.image_rounded, color: AppColors.primary, size: 40),
  );

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

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 20),
            Text(
              '$petName\'s story starts here',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add photos, milestones, and memories. Birthdays and gotcha days are added automatically.',
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
    );
  }
}
