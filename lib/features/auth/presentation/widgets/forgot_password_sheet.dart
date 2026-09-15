import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_text_field.dart';

Future<void> showForgotPasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ForgotPasswordSheet(),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  bool _sending = false;
  String? _resultMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _resultMessage = null;
    });
    final result = await getIt<AuthRepository>().sendPasswordResetEmail(
      _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _resultMessage = switch (result) {
        Ok() => 'Check your inbox for a reset link.',
        Err(:final failure) => failure.message,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: GlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset your password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              "We'll email you a link to set a new one.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 12),
              Text(_resultMessage!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Send reset link',
              isLoading: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
