import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/organization_provider.dart';

class CreateOrganizationPage extends ConsumerStatefulWidget {
  const CreateOrganizationPage({super.key});

  @override
  ConsumerState<CreateOrganizationPage> createState() =>
      _CreateOrganizationPageState();
}

class _CreateOrganizationPageState
    extends ConsumerState<CreateOrganizationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Lowercase, hyphenated, alnum-only — good enough for an internal
  /// identifier nobody but this org's own members will ever see. A
  /// collision (same name picked twice) just fails the unique-constraint
  /// insert with a clear error; not worth a live-availability check for v1.
  String _slugify(String name) {
    final base = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return base.isEmpty ? suffix : '$base-$suffix';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final result = await ref
        .read(createOrganizationUseCaseProvider)
        .call(name: name, slug: _slugify(name));

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold((f) => context.showSnackBar(f.message, isError: true), (org) {
      ref.invalidate(myOrganizationsProvider);
      context
        ..showSnackBar('$name created')
        ..pop();
      context.push('/organizations/${org.id}/members');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return const Scaffold(
        body: LoadingWidget(message: 'Creating organization…'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New Organization')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tag trips as work trips, and route submitted expenses to '
                  'admins for approval.',
                  style: TextStyle(color: context.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Organization name',
                    hintText: 'e.g. Acme Corp',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 32),
                FilledButton(onPressed: _submit, child: const Text('Create')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
