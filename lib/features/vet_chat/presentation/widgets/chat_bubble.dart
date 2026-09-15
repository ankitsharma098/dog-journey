import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/triage_rule.dart';

/// A single chat bubble for user or assistant messages.
/// Assistant bubbles include disclaimer footer per PRD compliance.
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
    return message.isUser ? _UserBubble(message: message) : _AssistantBubble(
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
      padding: const EdgeInsets.only(bottom: 12, left: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(
            message.content,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
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
    final isEmergency = message.level == TriageLevel.emergency;
    final isUrgent = message.level == TriageLevel.urgent;

    final bubbleBorder = isEmergency
        ? Border.all(color: AppColors.emergency.withValues(alpha: 0.4), width: 1)
        : isUrgent
            ? Border.all(color: AppColors.warning.withValues(alpha: 0.4), width: 1)
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E28),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: bubbleBorder,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isStreaming)
                  _StreamingText(content: message.content)
                else
                  Text(
                    message.content,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF0F0F5),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                // Disclaimer footer on every assistant message (PRD compliance)
                if (!message.isStreaming) ...[
                  const SizedBox(height: 10),
                  const _DisclaimerFooter(),
                ],
              ],
            ),
          ),
          // Feedback row
          if (!message.isStreaming && message.wasHelpful == null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 4),
                _FeedbackButton(
                  icon: Icons.thumb_up_outlined,
                  label: 'Helpful',
                  onTap: onThumbsUp,
                ),
                const SizedBox(width: 8),
                _FeedbackButton(
                  icon: Icons.thumb_down_outlined,
                  label: 'Not helpful',
                  onTap: onThumbsDown,
                ),
              ],
            ),
          ],
          if (message.wasHelpful != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                message.wasHelpful! ? '👍 Marked as helpful' : '👎 Feedback noted',
                style: const TextStyle(
                  color: Color(0xFF888898),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            widget.content.isEmpty ? '' : widget.content,
            style: GoogleFonts.inter(
              color: const Color(0xFFF0F0F5),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
        if (widget.content.isEmpty)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Opacity(
              opacity: 0.3 + 0.7 * _pulse.value,
              child: Container(
                width: 10,
                height: 14,
                margin: const EdgeInsets.only(left: 4, bottom: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DisclaimerFooter extends StatelessWidget {
  const _DisclaimerFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 11, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'General information only — not veterinary advice. Consult a licensed vet for your dog\'s health decisions.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF888898)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF888898), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
