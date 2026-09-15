import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/auth_form_status.dart';
import '../../bloc/sign_in_cubit.dart';
import '../../../../core/widgets/section_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/forgot_password_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SignInCubit>(),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView();

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(SignInCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    cubit.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignInCubit>();

    return GlassScaffold(
      body: BlocListener<SignInCubit, SignInState>(
        listener: (context, state) {
          if (state.status == AuthFormStatus.failure && state.failure != null) {
            AppSnackbar.show(context, message: state.failure!.message);
          }
          // AuthFormStatus.success needs no navigation here — AuthBloc
          // picks up the Supabase Auth change and the router redirect
          // takes it from there.
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Welcome back',
                  subtitle: "Your dog's whole story, in one place.",
                ),
                const SizedBox(height: 32),
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
                  textInputAction: TextInputAction.done,
                  validator: Validators.password,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(cubit),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => showForgotPasswordSheet(context),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                BlocBuilder<SignInCubit, SignInState>(
                  builder: (context, state) {
                    return PrimaryButton(
                      label: 'Sign in',
                      isLoading: state.status == AuthFormStatus.submitting,
                      onPressed: () => _submit(cubit),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.signUp),
                    child: const Text("Don't have an account? Create one"),
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
