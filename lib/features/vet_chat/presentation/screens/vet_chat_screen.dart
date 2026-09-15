import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../bloc/vet_chat_cubit.dart';
import 'chat_thread_screen.dart';

/// Vet chat tab — shows thread list + FAB to start new chat.
class VetChatScreen extends StatelessWidget {
  const VetChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) return const SizedBox.shrink();
        return BlocBuilder<PetsBloc, PetsState>(
          builder: (context, petsState) {
            final pet = petsState.pets.isNotEmpty ? petsState.pets.first : null;
            return _VetChatShell(
              userId: authState.profile.uid,
              petId: pet?.id ?? '',
              petSnapshot: pet == null
                  ? {}
                  : {
                      'name': pet.name,
                      'breed': pet.breedId,
                      'weight_kg': pet.weightKg,
                      'allergies': pet.allergies,
                    },
              breedId: pet?.breedId,
            );
          },
        );
      },
    );
  }
}

class _VetChatShell extends StatelessWidget {
  const _VetChatShell({
    required this.userId,
    required this.petId,
    required this.petSnapshot,
    this.breedId,
  });

  final String userId;
  final String petId;
  final Map<String, dynamic> petSnapshot;
  final String? breedId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VetChatCubit(
        petId: petId,
        currentUserId: userId,
        petSnapshot: petSnapshot,
        chatRepository: context.read(),
        triageService: context.read(),
        vetAiService: context.read(),
        breedId: breedId,
      ),
      child: _VetChatScreenBody(
        userId: userId,
        petId: petId,
        petSnapshot: petSnapshot,
        breedId: breedId,
      ),
    );
  }
}

class _VetChatScreenBody extends StatelessWidget {
  const _VetChatScreenBody({
    required this.userId,
    required this.petId,
    required this.petSnapshot,
    this.breedId,
  });

  final String userId;
  final String petId;
  final Map<String, dynamic> petSnapshot;
  final String? breedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Vet Chat',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          // Quota chip
          BlocBuilder<VetChatCubit, VetChatState>(
            builder: (context, state) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _QuotaChip(used: state.quotaUsed, limit: state.quotaLimit),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Start new chat card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask about your dog\'s health',
                    style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get instant triage guidance and general health information. '
                    'Not a replacement for your vet.',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ExamplePrompts(
                    onTap: (prompt) => _openChat(context, prompt),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vetChatFab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_rounded),
        label: const Text(
          'Start Chat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => _openChat(context, null),
        elevation: 4,
      ),
    );
  }

  void _openChat(BuildContext context, String? initialMessage) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<VetChatCubit>()),
            BlocProvider.value(value: context.read<BillingCubit>()),
          ],
          child: ChatThreadScreen(initialMessage: initialMessage),
        ),
      ),
    );
  }
}

class _ExamplePrompts extends StatelessWidget {
  const _ExamplePrompts({required this.onTap});
  final ValueChanged<String> onTap;

  static const _prompts = [
    ('🍫', 'My dog ate chocolate'),
    ('🤒', 'My dog is vomiting and lethargic'),
    ('🦴', 'My dog is limping on his front leg'),
    ('🐾', 'My dog has been scratching a lot'),
    ('💊', 'Can my dog take ibuprofen?'),
    ('🥦', 'Can my dog eat broccoli?'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _prompts.map((p) {
        return GestureDetector(
          onTap: () => onTap(p.$2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppColors.cardBorderDark
                    : AppColors.cardBorderLight,
                width: 1,
              ),
            ),
            child: Text(
              '${p.$1} ${p.$2}',
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  const _QuotaChip({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - used).clamp(0, limit);
    final color = remaining == 0
        ? AppColors.danger
        : remaining == 1
        ? AppColors.warning
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        '$remaining / $limit free',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
