import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../billing/bloc/billing_cubit.dart';
import '../../../billing/presentation/screens/paywall_sheet.dart';
import '../../bloc/vet_chat_cubit.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_doodle_background.dart';
import '../widgets/emergency_banner.dart';

/// The actual chat conversation screen — dark glass aesthetic per PRD.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, this.initialMessage});
  final String? initialMessage;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = context.read<VetChatCubit>();
      await cubit.startThread();
      if (widget.initialMessage != null && mounted) {
        _send(widget.initialMessage!);
      }
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
    setState(() => _bannerDismissed = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F14),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Vet Chat',
          style: GoogleFonts.sora(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          BlocBuilder<VetChatCubit, VetChatState>(
            builder: (ctx, state) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _QuotaChip(used: state.quotaUsed, limit: state.quotaLimit),
            ),
          ),
        ],
      ),
      body: ChatDoodleBackground(
        child: BlocConsumer<VetChatCubit, VetChatState>(
          listener: (ctx, state) {
            if (state.messages.isNotEmpty) _scrollToBottom();
          },
          builder: (ctx, state) {
            return Column(
              children: [
                // Emergency banner — always above fold, slides in
                if (state.isEmergency &&
                    !_bannerDismissed &&
                    state.triageResult != null)
                  EmergencyBanner(
                    headline: state.triageResult!.headline,
                    actionText: state.triageResult!.actionText,
                    onDismiss: () => setState(() => _bannerDismissed = true),
                  ),

                // Urgent (non-emergency) banner
                if (!state.isEmergency &&
                    state.triageResult?.isUrgent == true &&
                    !_bannerDismissed &&
                    state.triageResult != null)
                  _UrgentBanner(
                    headline: state.triageResult!.headline,
                    onDismiss: () => setState(() => _bannerDismissed = true),
                  ),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: state.messages.length,
                    itemBuilder: (_, i) {
                      final msg = state.messages[i];
                      return ChatBubble(
                        message: msg,
                        onThumbsUp: msg.isAssistant && msg.wasHelpful == null
                            ? () => ctx.read<VetChatCubit>().rateFeedback(
                                msg.id,
                                true,
                              )
                            : null,
                        onThumbsDown: msg.isAssistant && msg.wasHelpful == null
                            ? () => ctx.read<VetChatCubit>().rateFeedback(
                                msg.id,
                                false,
                              )
                            : null,
                      );
                    },
                  ),
                ),

                // Quota exhausted — show prompt to upgrade
                if (state.quotaExceeded && !state.isEmergency)
                  _QuotaExhaustedBar(),

                // Input bar
                _InputBar(
                  controller: _ctrl,
                  onSend: _send,
                  disabled:
                      state.phase == VetChatPhase.triage ||
                      state.phase == VetChatPhase.streaming,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.headline, this.onDismiss});
  final String headline;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headline,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                color: AppColors.warning.withValues(alpha: 0.6),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuotaExhaustedBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1A1A22),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "You've used today's 3 free chats. Upgrade for unlimited.",
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BlocProvider.value(
                value: context.read<BillingCubit>(),
                child: const PaywallSheet(),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.disabled = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF141419),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPad),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !disabled,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: disabled
                    ? 'Thinking…'
                    : 'Ask about your dog\'s health…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (v) => onSend(v),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(disabled: disabled, onTap: () => onSend(controller.text)),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.disabled, required this.onTap});
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFFF9950)],
                ),
          color: disabled ? Colors.white12 : null,
          shape: BoxShape.circle,
        ),
        child: Icon(
          disabled ? Icons.hourglass_top_rounded : Icons.send_rounded,
          color: disabled ? Colors.white30 : Colors.white,
          size: 20,
        ),
      ),
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
