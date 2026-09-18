import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/triage_rule.dart';

/// A single chat bubble. The emergency block lives *inside* the
/// assistant bubble (not a separate banner) — see README § "7. AI Vet
/// Chat". The disclaimer line must stay at 0.72 alpha or above; it is
/// deliberately not dimmed further than the design spec.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onThumbsUp,
    this.onThumbsDown,
  });

  final ChatMessage message;
  final VoidCallback? onThumbsUp;
  final VoidCallback? onThumbsDown;

  @override
  Widget build(BuildContext context) {
    return message.isUser
        ? _UserBubble(message: message)
        : _AssistantBubble(
            message: message,
            onThumbsUp: onThumbsUp,
            onThumbsDown: onThumbsDown,
          );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.accentDeep,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.content,
            style: AppTextStyles.body.copyWith(
              fontSize: 13.5,
              height: 1.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.message,
    this.onThumbsUp,
    this.onThumbsDown,
  });

  final ChatMessage message;
  final VoidCallback? onThumbsUp;
  final VoidCallback? onThumbsDown;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isEmergency = message.level == TriageLevel.emergency;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card(brightness),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.hairline(brightness)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isStreaming)
                    _StreamingText(content: message.content)
                  else
                    Text(
                      message.content,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  if (isEmergency && !message.isStreaming) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerOn(brightness).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dangerOn(brightness).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Call an emergency vet now — this one does not wait until morning.',
                        style: AppTextStyles.listRowTitle.copyWith(
                          fontSize: 11.5,
                          color: AppColors.emergencyTextDark,
                        ),
                      ),
                    ),
                  ],
                  if (!message.isStreaming) ...[
                    const SizedBox(height: 10),
                    Text(
                      'General information, not a diagnosis.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary(brightness).withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!message.isStreaming && message.wasHelpful == null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  _FeedbackButton(
                    icon: PhosphorIconsRegular.thumbsUp,
                    label: 'Helpful',
                    onTap: onThumbsUp,
                  ),
                  const SizedBox(width: 8),
                  _FeedbackButton(
                    icon: PhosphorIconsRegular.thumbsDown,
                    label: 'Not helpful',
                    onTap: onThumbsDown,
                  ),
                ],
              ),
            ],
            if (message.wasHelpful != null) ...[
              const SizedBox(height: 4),
              Text(
                message.wasHelpful! ? 'Marked as helpful' : 'Feedback noted',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreamingText extends StatefulWidget {
  const _StreamingText({required this.content});
  final String content;

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (widget.content.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = (_pulse.value - i * 0.2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Opacity(
                    opacity: 0.3 + 0.7 * t,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      );
    }
    return Text(
      widget.content,
      style: AppTextStyles.body.copyWith(
        fontSize: 13.5,
        height: 1.6,
        color: AppColors.textPrimary(brightness),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline(brightness)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textTertiary(brightness)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary(brightness)),
            ),
          ],
        ),
      ),
    );
  }
}
