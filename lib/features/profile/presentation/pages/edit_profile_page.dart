import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';

const _kTravelTags = [
  'adventure', 'backpacking', 'beach', 'budget', 'city',
  'cultural', 'family', 'foodie', 'hiking', 'luxury',
  'nature', 'nightlife', 'road trip', 'solo', 'wellness',
];

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers — initialised once the profile loads.
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _avatarCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _timezoneCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _languageCtrl;

  String _units = 'metric';
  List<String> _selectedTags = [];
  bool _controllersReady = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Initialise with empty controllers; _initFromProfile fills them once loaded.
    _nameCtrl     = TextEditingController();
    _usernameCtrl = TextEditingController();
    _bioCtrl      = TextEditingController();
    _avatarCtrl   = TextEditingController();
    _cityCtrl     = TextEditingController();
    _countryCtrl  = TextEditingController();
    _timezoneCtrl = TextEditingController();
    _currencyCtrl = TextEditingController();
    _languageCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _avatarCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _timezoneCtrl.dispose();
    _currencyCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(dynamic profile) {
    if (_controllersReady) {
      return;
    }
    _controllersReady = true;
    _nameCtrl.text     = profile?.displayName ?? '';
    _usernameCtrl.text = profile?.username    ?? '';
    _bioCtrl.text      = profile?.bio         ?? '';
    _avatarCtrl.text   = profile?.avatarUrl   ?? '';
    _cityCtrl.text     = profile?.city        ?? '';
    _countryCtrl.text  = profile?.country     ?? '';
    _timezoneCtrl.text = profile?.timezone    ?? '';
    _currencyCtrl.text = profile?.preferredCurrency ?? '';
    _languageCtrl.text = profile?.preferredLanguage ?? '';
    setState(() {
      _units        = profile?.unitsPreference       ?? 'metric';
      _selectedTags = List<String>.from(profile?.travelPreferenceTags ?? []);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);

    final name     = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final repo     = ref.read(userProfileRepositoryProvider);

    // Sync display_name + avatar_url to auth metadata so AuthNotifier stays
    // current (drives the Profile page avatar/name header).
    final authResult = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(
          displayName: name.isNotEmpty ? name : null,
          avatarUrl:   _avatarCtrl.text.trim().isNotEmpty
              ? _avatarCtrl.text.trim()
              : null,
        );

    if (!mounted) {
      return;
    }

    var hadAuthError = false;
    authResult.fold((f) {
      hadAuthError = true;
      context.showSnackBar(f.message, isError: true);
    }, (_) {});

    if (hadAuthError) {
      setState(() => _saving = false);
      return;
    }

    // Update all fields in the profiles table via the update_profile RPC.
    final profileResult = await repo.updateProfile(
      displayName:          name.isNotEmpty ? name : null,
      username:             username.isNotEmpty ? username : null,
      bio:                  _bioCtrl.text.trim().isNotEmpty
          ? _bioCtrl.text.trim()
          : null,
      city:                 _cityCtrl.text.trim().isNotEmpty
          ? _cityCtrl.text.trim()
          : null,
      country:              _countryCtrl.text.trim().isNotEmpty
          ? _countryCtrl.text.trim().toUpperCase()
          : null,
      timezone:             _timezoneCtrl.text.trim().isNotEmpty
          ? _timezoneCtrl.text.trim()
          : null,
      preferredCurrency:    _currencyCtrl.text.trim().isNotEmpty
          ? _currencyCtrl.text.trim().toUpperCase()
          : null,
      preferredLanguage:    _languageCtrl.text.trim().isNotEmpty
          ? _languageCtrl.text.trim().toLowerCase()
          : null,
      unitsPreference:      _units,
      travelPreferenceTags: _selectedTags,
      avatarUrl:            _avatarCtrl.text.trim().isNotEmpty
          ? _avatarCtrl.text.trim()
          : null,
    );

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    profileResult.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) {
        ref.invalidate(userProfileProvider);
        context
          ..showSnackBar('Profile updated')
          ..pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: LoadingWidget(message: 'Loading profile…'),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: Center(
          child: Text(
            'Could not load profile.',
            style: TextStyle(color: context.colorScheme.error),
          ),
        ),
      ),
      data: (profile) {
        _initFromProfile(profile);
        return _buildForm(profile);
      },
    );
  }

  Widget _buildForm(dynamic profile) {
    final cooldownActive =
        profile != null && !(profile.canChangeUsername as bool);
    final nextChange = profile?.nextUsernameChangeAt as DateTime?;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Identity ──────────────────────────────────────────────────
            const _SectionHeader('Identity'),
            const SizedBox(height: 12),
            _field(
              label: 'Display Name',
              controller: _nameCtrl,
              icon: Icons.person_outline,
              hint: 'Your name',
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Display name cannot be empty';
                }
                if (v.trim().length > 100) {
                  return 'Must be 100 characters or fewer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _field(
              label: 'Username',
              controller: _usernameCtrl,
              icon: Icons.alternate_email,
              hint: 'e.g. jane_travels',
              enabled: !cooldownActive,
              helperText: cooldownActive && nextChange != null
                  ? 'Next change available '
                    '${DateFormat.yMMMd().format(nextChange)}'
                  : '3–30 chars · letters, numbers, underscores',
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return null; // username is optional
                }
                final trimmed = v.trim();
                if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_]{1,28}[a-zA-Z0-9]$')
                    .hasMatch(trimmed)) {
                  return '3–30 chars, letters/numbers/underscores, '
                      'no leading/trailing underscore';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _field(
              label: 'Bio',
              controller: _bioCtrl,
              icon: Icons.notes_outlined,
              hint: 'A short bio',
              maxLines: 3,
              maxLength: 200,
            ),

            // ── Avatar ────────────────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader('Avatar'),
            const SizedBox(height: 12),
            _field(
              label: 'Avatar URL',
              controller: _avatarCtrl,
              icon: Icons.image_outlined,
              hint: 'https://…',
              keyboardType: TextInputType.url,
              helperText: 'Direct image URL · Supabase Storage upload coming soon',
            ),

            // ── Location ──────────────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader('Location'),
            const SizedBox(height: 12),
            _field(
              label: 'City',
              controller: _cityCtrl,
              icon: Icons.location_city_outlined,
              hint: 'e.g. Tokyo',
            ),
            const SizedBox(height: 16),
            _field(
              label: 'Country',
              controller: _countryCtrl,
              icon: Icons.flag_outlined,
              hint: 'ISO code · e.g. JP, US, GB',
              maxLength: 2,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && v.trim().length != 2) {
                  return 'Use a 2-letter ISO 3166-1 country code';
                }
                return null;
              },
            ),

            // ── Preferences ───────────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader('Preferences'),
            const SizedBox(height: 12),
            _field(
              label: 'Timezone',
              controller: _timezoneCtrl,
              icon: Icons.schedule_outlined,
              hint: 'e.g. America/New_York',
            ),
            const SizedBox(height: 16),
            _field(
              label: 'Currency',
              controller: _currencyCtrl,
              icon: Icons.attach_money_outlined,
              hint: 'ISO 4217 · e.g. USD, EUR, JPY',
              maxLength: 3,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && v.trim().length != 3) {
                  return 'Use a 3-letter ISO 4217 currency code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _field(
              label: 'Language',
              controller: _languageCtrl,
              icon: Icons.translate_outlined,
              hint: 'ISO 639-1 · e.g. en, fr, ja',
              maxLength: 2,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && v.trim().length != 2) {
                  return 'Use a 2-letter ISO 639-1 language code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _UnitsToggle(
              value: _units,
              onChanged: (v) => setState(() => _units = v),
            ),

            // ── Travel interests ──────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader('Travel Interests'),
            const SizedBox(height: 4),
            Text(
              'Select what kinds of travel you enjoy.',
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _TagPicker(
              allTags: _kTravelTags,
              selected: _selectedTags,
              onToggle: (tag) => setState(() {
                if (_selectedTags.contains(tag)) {
                  _selectedTags.remove(tag);
                } else {
                  _selectedTags.add(tag);
                }
              }),
            ),

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colorScheme.surface,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    String? helperText,
    int? maxLines,
    int? maxLength,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines ?? 1,
            maxLength: maxLength,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helperText,
              helperMaxLines: 2,
              prefixIcon: Icon(icon),
            ),
            validator: validator,
          ),
        ],
      );
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
}

// ── Units toggle ─────────────────────────────────────────────────────────────

class _UnitsToggle extends StatelessWidget {
  const _UnitsToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Units',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'metric',   label: Text('Metric')),
              ButtonSegment(value: 'imperial', label: Text('Imperial')),
            ],
            selected: {value},
            onSelectionChanged: (set) => onChanged(set.first),
          ),
        ],
      );
}

// ── Travel interest tag picker ────────────────────────────────────────────────

class _TagPicker extends StatelessWidget {
  const _TagPicker({
    required this.allTags,
    required this.selected,
    required this.onToggle,
  });

  final List<String> allTags;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: allTags
            .map(
              (tag) => FilterChip(
                label: Text(tag),
                selected: selected.contains(tag),
                onSelected: (_) => onToggle(tag),
              ),
            )
            .toList(),
      );
}
