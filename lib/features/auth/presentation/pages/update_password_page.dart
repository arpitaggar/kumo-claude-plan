import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/constants.dart';
import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_input_field.dart';

class UpdatePasswordPage extends ConsumerStatefulWidget {
  const UpdatePasswordPage({super.key});

  @override
  ConsumerState<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends ConsumerState<UpdatePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .updatePassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is AuthUnauthenticated && prev is AuthLoading) {
        context
          ..showSnackBar('Password updated. Please sign in.')
          ..go('/login');
      } else if (next is AuthError) {
        context.showSnackBar(next.message, isError: true);
      }
    });

    final authState = ref.watch(authNotifierProvider);

    if (authState is AuthLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        body: LoadingWidget(message: 'Updating password…'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        title: const Text('Set New Password'),
        backgroundColor: AppTheme.warmOatmeal,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Create a new password',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkEspresso,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Must be at least ${AppConstants.minPasswordLength} characters.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.earthBrown,
                  ),
                ),
                const SizedBox(height: 32),
                PasswordInputField(
                  controller: _passwordController,
                  labelText: 'New password',
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < AppConstants.minPasswordLength) {
                      return 'At least ${AppConstants.minPasswordLength} characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                PasswordInputField(
                  controller: _confirmController,
                  labelText: 'Confirm new password',
                  onSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Update Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
