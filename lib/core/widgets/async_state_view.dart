import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../theme/app_colors.dart';

/// Common loading / error / empty scaffolding so every feature screen
/// doesn't reinvent the same three branches around its BlocBuilder.
class AsyncStateView extends StatelessWidget {
  const AsyncStateView.loading({super.key})
    : _mode = _Mode.loading,
      failure = null,
      message = null,
      onRetry = null;

  const AsyncStateView.error({
    super.key,
    required Failure this.failure,
    this.onRetry,
  }) : _mode = _Mode.error,
       message = null;

  const AsyncStateView.empty({
    super.key,
    required String this.message,
    this.onRetry,
  }) : _mode = _Mode.empty,
       failure = null;

  final _Mode _mode;
  final Failure? failure;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      _Mode.loading => const Center(child: CircularProgressIndicator()),
      _Mode.error => _MessageView(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
        message: failure!.message,
        onRetry: onRetry,
      ),
      _Mode.empty => _MessageView(
        icon: Icons.inbox_outlined,
        iconColor: AppColors.textSecondaryLight,
        message: message!,
        onRetry: onRetry,
      ),
    };
  }
}

enum _Mode { loading, error, empty }

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
