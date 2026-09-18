import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/royal/status_chip.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../billing/presentation/screens/paywall_sheet.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../bloc/vet_chat_cubit.dart';
import '../../data/repositories/chat_quota_repository.dart';
import '../widgets/chat_bubble.dart';

/// The Vet Chat tab — a single persistent conversation, not a
/// landing-page-then-push-thread flow. See README § "7. AI Vet Chat":
/// pinned composer, an always-available suggestion-chip row above it,
/// and the emergency block rendered inside the assistant bubble.
class VetChatScreen extends StatelessWidget {
  const VetChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) return const SizedBox.shrink();
        return BlocBuilder<PetsBloc, PetsState>(
          builder: (context, petsState) {
            final pet = petsState.activePet;
            return BlocProvider(
              key: ValueKey(pet?.id ?? ''),
              create: (_) => VetChatCubit(
                petId: pet?.id ?? '',
                currentUserId: authState.profile.uid,
                petSnapshot: pet == null
                    ? {}
                    : {
                        'name': pet.name,
                        'breed': pet.breedId,
                        'weight_kg': pet.weightKg,
                        'allergies': pet.allergies,
                      },
                chatRepository: context.read(),
                chatQuotaRepository: GetIt.I<ChatQuotaRepository>(),
                triageService: context.read(),
                vetAiService: context.read(),
                billingCubit: context.read<BillingCubit>(),
                breedId: pet?.breedId,
              ),
              child: _VetChatBody(petName: pet?.name ?? 'your dog'),
            );
          },
        );
      },
    );
  }
}

class _VetChatBody extends StatefulWidget {
  const _VetChatBody({required this.petName});
  final String petName;

  @override
  State<_VetChatBody> createState() => _VetChatBodyState();
}

class _VetChatBodyState extends State<_VetChatBody> {
  static const _prompts = [
    'My dog ate chocolate',
    'My dog is vomiting and lethargic',
    'My dog is limping on his front leg',
    'My dog has been scratching a lot',
    'Can my dog take ibuprofen?',
    'Can my dog eat broccoli?',
  ];

  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VetChatCubit>().startThread();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    context.read<VetChatCubit>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: BlocBuilder<BillingCubit, BillingState>(
          builder: (context, billing) => BlocConsumer<VetChatCubit, VetChatState>(
            listener: (ctx, state) {
              if (state.messages.isNotEmpty) _scrollToBottom();
            },
            builder: (ctx, state) {
              final isBusy =
                  state.phase == VetChatPhase.triage ||
                  state.phase == VetChatPhase.streaming;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: _ChatHeader(petName: widget.petName),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                      itemCount:
                          state.messages.length +
                          (state.messages.isEmpty ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (state.messages.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Ask anything about ${widget.petName}, or start from one of '
                              'the questions below.',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary(brightness),
                              ),
                            ),
                          );
                        }
                        return ChatBubble(
                          message: state.messages[i],
                          onThumbsUp:
                              state.messages[i].isAssistant &&
                                  state.messages[i].wasHelpful == null
                              ? () => ctx.read<VetChatCubit>().rateFeedback(
                                  state.messages[i].id,
                                  true,
                                )
                              : null,
                          onThumbsDown:
                              state.messages[i].isAssistant &&
                                  state.messages[i].wasHelpful == null
                              ? () => ctx.read<VetChatCubit>().rateFeedback(
                                  state.messages[i].id,
                                  false,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  _Composer(
                    controller: _ctrl,
                    prompts: _prompts,
                    isBusy: isBusy,
                    quotaExceeded:
                        state.quotaExceeded &&
                        !state.isEmergency &&
                        !billing.isPro,
                    onSend: _send,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
          alignment: Alignment.center,
          child: Icon(
            PhosphorIconsFill.firstAidKit,
            size: 16,
            color: AppColors.accentLightest,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vet chat',
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            Text(
              'awake now',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const Spacer(),
        BlocBuilder<BillingCubit, BillingState>(
          builder: (context, billing) {
            return BlocBuilder<VetChatCubit, VetChatState>(
              builder: (context, state) {
                final remaining = (state.quotaLimit - state.quotaUsed).clamp(
                  0,
                  state.quotaLimit,
                );
                final label = billing.isPro
                    ? 'PRO · UNLIMITED'
                    : '$remaining / ${state.quotaLimit} FREE';
                return StatusChip(
                  label: label,
                  background: AppColors.champagne.withValues(alpha: 0.12),
                  foreground: AppColors.champagneOn(brightness),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.prompts,
    required this.isBusy,
    required this.quotaExceeded,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<String> prompts;
  final bool isBusy;
  final bool quotaExceeded;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final canvas = AppColors.canvas(brightness);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [canvas.withValues(alpha: 0), canvas.withValues(alpha: 0.96)],
          stops: const [0, 0.3],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quotaExceeded) ...[
            GestureDetector(
              onTap: () {
                final billingCubit = context.read<BillingCubit>();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BlocProvider.value(
                    value: billingCubit,
                    child: const PaywallSheet(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.champagne.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsFill.lockSimple,
                      size: 15,
                      color: AppColors.champagneOn(brightness),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Today's free chats are used up — tap to go Pro.",
                        style: AppTextStyles.secondaryLine.copyWith(
                          color: AppColors.champagneOn(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => onSend(prompts[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card(brightness).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.hairline(brightness)),
                  ),
                  child: Text(
                    prompts[i],
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(
                        brightness,
                      ).withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  decoration: BoxDecoration(
                    color: AppColors.card(brightness),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline(brightness)),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !isBusy,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.body.copyWith(
                      height: 1,
                      color: AppColors.textPrimary(brightness),
                    ),
                    decoration: InputDecoration(
                      hintText: isBusy ? 'Thinking…' : "Ask anything…",
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: onSend,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isBusy ? null : () => onSend(controller.text),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isBusy
                        ? AppColors.hairline(brightness)
                        : AppColors.accent.withValues(alpha: 0.2),
                    border: Border.all(
                      color: isBusy
                          ? AppColors.hairline(brightness)
                          : AppColors.accent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isBusy
                        ? PhosphorIconsRegular.hourglassMedium
                        : PhosphorIconsFill.paperPlaneTilt,
                    size: 19,
                    color: isBusy
                        ? AppColors.textTertiary(brightness)
                        : AppColors.accentLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
