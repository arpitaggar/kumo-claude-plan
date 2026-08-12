import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/brand.dart';
import '../../../../config/theme_provider.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/validators/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_input_field.dart';
import '../widgets/password_input_field.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreedToTerms = false;
  DateTime? _dateOfBirth;

  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  /// Client-side mirror of the server-side gate (see
  /// `AuthValidators.validateAge18Plus`'s doc comment) — fast feedback only,
  /// not the security boundary.
  String? get _dateOfBirthError {
    try {
      AuthValidators.validateAge18Plus(_dateOfBirth);
      return null;
    } on ValidationException catch (e) {
      return e.message;
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? eighteenYearsAgo,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/privacy-policy');
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/terms');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _privacyTap.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _dateOfBirthError != null) {
      setState(() {}); // surface the DOB error text if it wasn't shown yet
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          dateOfBirth: _dateOfBirth!,
          displayName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
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
      return const Scaffold(body: LoadingWidget(message: 'Creating account…'));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // Logo
                Center(
                  child: SvgPicture.asset(
                    Brand.logoFor(ref.watch(themeProvider)),
                    height: 56,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Create your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start planning your next adventure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),

                // Name field
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                EmailInputField(controller: _emailController),
                const SizedBox(height: 14),
                PasswordInputField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                PasswordInputField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm password',
                  onSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Date of birth — Kumo accounts require the holder to be
                // 18+ (server-enforced, see AuthValidators.validateAge18Plus
                // doc comment). Anyone younger participates as a Hitchhiker
                // on someone else's trip instead of creating an account.
                InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      errorText: _dateOfBirth == null
                          ? null
                          : _dateOfBirthError,
                    ),
                    child: Text(
                      _dateOfBirth == null
                          ? 'Select your date of birth'
                          : DateFormat.yMMMd().format(_dateOfBirth!),
                      style: TextStyle(
                        color: _dateOfBirth == null
                            ? context.colorScheme.onSurfaceVariant
                            : context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Consent checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (v) =>
                          setState(() => _agreedToTerms = v ?? false),
                      visualDensity: VisualDensity.compact,
                      activeColor: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Privacy Policy',
                                recognizer: _privacyTap,
                                style: TextStyle(
                                  color: context.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Terms of Service',
                                recognizer: _termsTap,
                                style: TextStyle(
                                  color: context.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _agreedToTerms && _dateOfBirthError == null
                      ? _submit
                      : null,
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Sign In'),
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
