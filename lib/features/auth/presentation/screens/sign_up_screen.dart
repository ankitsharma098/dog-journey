import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/auth_form_status.dart';
import '../../bloc/sign_up_cubit.dart';
import '../widgets/auth_text_field.dart';

/// Matches `sign_up_screen.dart` per README § "0c. Sign up".
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SignUpCubit>(),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit(SignUpCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    cubit.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignUpCubit>();
    final brightness = Theme.of(context).brightness;

    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      body: BlocListener<SignUpCubit, SignUpState>(
        listener: (context, state) {
          if (state.status == AuthFormStatus.failure && state.failure != null) {
            AppSnackbar.show(context, message: state.failure!.message);
          }
        },
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Icon(
                    PhosphorIconsRegular.arrowLeft,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create your account',
                  style: AppTextStyles.screenTitle.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Breed, vaccines, weight, memories — all in one place, from day one.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isPassword: true,
                  validator: Validators.password,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Confirm password',
                  controller: _confirmController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      Validators.confirmPassword(value, _passwordController.text),
                  onSubmitted: (_) => _submit(cubit),
                ),
                const SizedBox(height: 24),
                BlocBuilder<SignUpCubit, SignUpState>(
                  builder: (context, state) {
                    return SizedBox(
                      height: 54,
                      child: PrimaryButton(
                        label: 'Create account',
                        isLoading: state.status == AuthFormStatus.submitting,
                        onPressed: () => _submit(cubit),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'By continuing you agree this app offers triage and record-keeping, not a '
                  'substitute for veterinary care.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
