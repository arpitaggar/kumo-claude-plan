import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_input_field.dart';
import '../widgets/password_input_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthError) {
        context.showSnackBar(next.message, isError: true);
        ref.read(authNotifierProvider.notifier).clearError();
      } else if (next is AuthAuthenticated) {
        context.go('/home');
      }
    });

    if (authState is AuthLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        body: LoadingWidget(message: 'Signing in…'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 64),

                // Logo
                Center(
                  child: SvgPicture.asset(
                    'assets/icons/kumo_logo_stacked_charcoal.svg',
                    height: 72,
                  ),
                ),
                const SizedBox(height: 32),

                // Tagline
                const Text(
                  // 'Travel planning,\nreimagined.',
                  'Plan. Explore. Go.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkEspresso,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue your journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.earthBrown),
                ),
                const SizedBox(height: 48),

                // Fields
                EmailInputField(controller: _emailController),
                const SizedBox(height: 14),
                PasswordInputField(
                  controller: _passwordController,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Sign In'),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.earthBrown,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/signup'),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
