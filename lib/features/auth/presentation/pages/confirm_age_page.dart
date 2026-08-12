import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/age_gate_provider.dart';
import '../providers/auth_provider.dart';

/// Forced on an invite-created (Crew) account whose `age_verified_at` is
/// still null — see `docs/supabase_migrations/stage44_age_gate.sql` and
/// `age_gate_provider.dart`. Direct signup can never reach this screen: it
/// collects and validates DOB before an account is ever created. This is
/// the one-time completion step for the path where that isn't possible.
class ConfirmAgePage extends ConsumerStatefulWidget {
  const ConfirmAgePage({super.key});

  @override
  ConsumerState<ConfirmAgePage> createState() => _ConfirmAgePageState();
}

class _ConfirmAgePageState extends ConsumerState<ConfirmAgePage> {
  DateTime? _dateOfBirth;
  bool _isSubmitting = false;

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

  Future<void> _submit() async {
    final dob = _dateOfBirth;
    if (dob == null) {
      return;
    }
    setState(() => _isSubmitting = true);

    final result = await ref.read(confirmAgeUseCaseProvider).call(dob);
    if (!mounted) {
      return;
    }

    await result.fold(
      (failure) async {
        setState(() => _isSubmitting = false);
        context.showSnackBar(failure.message, isError: true);
      },
      (verified) async {
        if (verified) {
          ref.read(ageGateProvider.notifier).markVerified();
          return;
        }
        // Rejected — the account was just deleted server-side (see
        // confirm_age_and_finish_signup()'s 'rejected_underage' branch).
        // Explain before signing out: once the session goes to
        // AuthUnauthenticated, the router redirects away from this page on
        // its own (see _RouterNotifier.redirect), which could otherwise cut
        // the dialog off mid-flow.
        setState(() => _isSubmitting = false);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('18+ required'),
            content: const Text(
              'Kumo accounts require you to be 18 or older, so this one '
              "couldn't be completed. Ask the trip owner to add you as a "
              'Hitchhiker instead — no account needed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          await ref.read(authNotifierProvider.notifier).logout();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return const Scaffold(body: LoadingWidget(message: 'Confirming…'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('One more thing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Confirm your date of birth',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kumo accounts require you to be 18 or older. This only '
                'takes a second.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              InkWell(
                onTap: _pickDateOfBirth,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _dateOfBirth != null ? _submit : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
