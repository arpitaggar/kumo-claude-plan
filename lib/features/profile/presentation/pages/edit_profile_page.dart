import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    final current = auth is AuthAuthenticated ? auth.user.displayName ?? '' : '';
    _nameCtrl = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
    });

    final result = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(displayName: _nameCtrl.text.trim());

    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
    });

    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => context
        ..showSnackBar('Profile updated')
        ..pop(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        appBar: AppBar(
          backgroundColor: AppTheme.warmOatmeal,
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppTheme.darkEspresso,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Display Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.earthBrown,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Display name cannot be empty';
                  }
                  if (v.trim().length > 100) {
                    return 'Name must be 100 characters or fewer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.cloudWhite,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      );
}
