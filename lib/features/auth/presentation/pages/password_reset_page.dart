import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_input_field.dart';

class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isLoading = true);
    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(_emailController.text.trim());
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    result.fold(
      (failure) => context.showSnackBar(
        failure is NetworkFailure ? 'No internet connection' : failure.message,
        isError: true,
      ),
      (_) => setState(() => _emailSent = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        body: LoadingWidget(message: 'Sending email…'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppTheme.warmOatmeal,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _emailSent
              ? _SentConfirmation(
                  email: _emailController.text,
                  onBack: () => context.pop(),
                )
              : _ResetForm(
                  formKey: _formKey,
                  emailController: _emailController,
                  onSubmit: _submit,
                ),
        ),
      ),
    );
  }
}

class _ResetForm extends StatelessWidget {
  const _ResetForm({
    required this.formKey,
    required this.emailController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Forgot your password?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkEspresso,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your email and we'll send a reset link.",
              style: TextStyle(fontSize: 14, color: AppTheme.earthBrown),
            ),
            const SizedBox(height: 32),
            EmailInputField(
              controller: emailController,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onSubmit,
              child: const Text('Send Reset Link'),
            ),
          ],
        ),
      );
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.email, required this.onBack});

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.cherryBlossom,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 40,
              color: AppTheme.softCoral,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Check your inbox',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkEspresso,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a password reset link to\n$email',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.earthBrown,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: onBack,
            child: const Text('Back to Sign In'),
          ),
        ],
      );
}
