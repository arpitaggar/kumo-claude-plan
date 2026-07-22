import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import 'profile_field_data.dart';

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

  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _cityCtrl;
  late FocusNode _cityFocusNode;

  // Picker-field state (ISO code or null if unset).
  String? _avatarUrl;
  String? _country;
  String? _timezone;
  String? _currency;
  String? _language;

  String _units = 'metric';
  List<String> _selectedTags = [];
  bool _controllersReady = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl      = TextEditingController();
    _usernameCtrl  = TextEditingController();
    _bioCtrl       = TextEditingController();
    _cityCtrl      = TextEditingController();
    _cityFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _cityFocusNode.dispose();
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
    _cityCtrl.text     = profile?.city        ?? '';
    setState(() {
      _avatarUrl = (profile?.avatarUrl as String?)?.isNotEmpty == true
          ? profile!.avatarUrl as String
          : null;
      _country  = (profile?.country           as String?)?.isNotEmpty == true ? profile!.country           as String : null;
      _timezone = (profile?.timezone          as String?)?.isNotEmpty == true ? profile!.timezone          as String : null;
      _currency = (profile?.preferredCurrency as String?)?.isNotEmpty == true ? profile!.preferredCurrency as String : null;
      _language = (profile?.preferredLanguage as String?)?.isNotEmpty == true ? profile!.preferredLanguage as String : null;
      _units        = profile?.unitsPreference       ?? 'metric';
      _selectedTags = List<String>.from(profile?.travelPreferenceTags ?? []);
    });
  }

  // ── Avatar editing ────────────────────────────────────────────────────────

  Future<void> _onEditAvatar() async {
    final choice = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Library'),
              onTap: () => Navigator.of(context).pop(_AvatarAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(context).pop(_AvatarAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter Image URL'),
              onTap: () => Navigator.of(context).pop(_AvatarAction.url),
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: context.colorScheme.error),
                title: Text('Remove Photo',
                    style: TextStyle(color: context.colorScheme.error)),
                onTap: () => Navigator.of(context).pop(_AvatarAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case _AvatarAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
      case _AvatarAction.camera:
        await _pickAndUpload(ImageSource.camera);
      case _AvatarAction.url:
        await _enterAvatarUrl();
      case _AvatarAction.remove:
        setState(() => _avatarUrl = null);
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) {
      return;
    }

    setState(() => _uploadingAvatar = true);

    try {
      final supabase = Supabase.instance.client;
      final userId   = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final bytes = await file.readAsBytes();
      final ext   = file.path.split('.').last.toLowerCase();
      final path  = '$userId/avatar.$ext';

      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      final url =
          '${supabase.storage.from('avatars').getPublicUrl(path)}'
          '?t=${DateTime.now().millisecondsSinceEpoch}';

      if (mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _enterAvatarUrl() async {
    final ctrl = TextEditingController(text: _avatarUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image URL'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _avatarUrl = result);
    }
  }

  // ── City autocomplete helpers ─────────────────────────────────────────────

  Iterable<CityEntry> _cityOptions(TextEditingValue value) {
    if (value.text.length < 2) {
      return const [];
    }
    final q = value.text.toLowerCase();
    return kCityData.where((c) => c.name.toLowerCase().contains(q)).take(8);
  }

  void _onCitySelected(CityEntry city) {
    setState(() {
      _country  = city.country;
      _timezone = city.timezone;
      _currency = city.currency;
    });
  }

  Widget _cityFieldView(BuildContext context, TextEditingController controller,
          FocusNode focusNode, VoidCallback onFieldSubmitted) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TextFormField(
          controller: controller,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Tokyo',
            prefixIcon: const Icon(Icons.location_city_outlined),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: controller.clear,
                  )
                : null,
          ),
        ),
      );

  Widget _cityOptionsView(
    BuildContext context,
    AutocompleteOnSelected<CityEntry> onSelected,
    Iterable<CityEntry> options,
  ) =>
      Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 256),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final city = options.elementAt(i);
                final countryName = kCountries
                        .where((c) => c.code == city.country)
                        .firstOrNull
                        ?.name ??
                    city.country;
                return ListTile(
                  dense: true,
                  title: Text(city.name),
                  subtitle: Text('$countryName  ·  ${city.currency}'),
                  onTap: () => onSelected(city),
                );
              },
            ),
          ),
        ),
      );

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);

    final name     = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final repo     = ref.read(userProfileRepositoryProvider);

    final authResult = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(
          displayName: name.isNotEmpty ? name : null,
          avatarUrl:   _avatarUrl,
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

    final profileResult = await repo.updateProfile(
      displayName:          name.isNotEmpty ? name : null,
      username:             username.isNotEmpty ? username : null,
      bio:                  _bioCtrl.text.trim().isNotEmpty
          ? _bioCtrl.text.trim()
          : null,
      city:                 _cityCtrl.text.trim().isNotEmpty
          ? _cityCtrl.text.trim()
          : null,
      country:              _country,
      timezone:             _timezone,
      preferredCurrency:    _currency,
      preferredLanguage:    _language,
      unitsPreference:      _units,
      travelPreferenceTags: _selectedTags,
      avatarUrl:            _avatarUrl,
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            _AvatarHeader(
              avatarUrl:   _avatarUrl,
              displayName: _nameCtrl.text,
              uploading:   _uploadingAvatar,
              onTap:       _onEditAvatar,
            ),
            const SizedBox(height: 32),

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
                  return null;
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

            // ── Location ──────────────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader('Location'),
            const SizedBox(height: 12),

            // City with autocomplete; selecting a suggestion auto-fills
            // Country, Timezone, and Currency below.
            _fieldLabel('City'),
            const SizedBox(height: 6),
            RawAutocomplete<CityEntry>(
              textEditingController: _cityCtrl,
              focusNode: _cityFocusNode,
              displayStringForOption: (c) => c.name,
              optionsBuilder: _cityOptions,
              onSelected: _onCitySelected,
              fieldViewBuilder: _cityFieldView,
              optionsViewBuilder: _cityOptionsView,
            ),
            const SizedBox(height: 4),
            Text(
              'Selecting a known city auto-fills country, timezone, and currency.',
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),
            _PickerField(
              label: 'Country',
              icon: Icons.flag_outlined,
              data: kCountries,
              value: _country,
              hint: 'Select country',
              onChanged: (v) => setState(() => _country = v),
            ),

            // ── Preferences ───────────────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader('Preferences'),
            const SizedBox(height: 12),
            _PickerField(
              label: 'Timezone',
              icon: Icons.schedule_outlined,
              data: kTimezones,
              value: _timezone,
              hint: 'Select timezone',
              onChanged: (v) => setState(() => _timezone = v),
            ),
            const SizedBox(height: 16),
            _PickerField(
              label: 'Currency',
              icon: Icons.attach_money_outlined,
              data: kCurrencies,
              value: _currency,
              hint: 'Select currency',
              onChanged: (v) => setState(() => _currency = v),
            ),
            const SizedBox(height: 16),
            _PickerField(
              label: 'Language',
              icon: Icons.translate_outlined,
              data: kLanguages,
              value: _language,
              hint: 'Select language',
              onChanged: (v) => setState(() => _language = v),
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

  Widget _fieldLabel(String label) => Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurfaceVariant,
        ),
      );

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
          _fieldLabel(label),
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

enum _AvatarAction { gallery, camera, url, remove }

// ── Avatar header ─────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({
    required this.avatarUrl,
    required this.displayName,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String displayName;
  final bool uploading;
  final VoidCallback onTap;

  String _initials() {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage:
                avatarUrl != null && !uploading ? NetworkImage(avatarUrl!) : null,
            child: uploading
                ? CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.onPrimaryContainer,
                  )
                : avatarUrl == null
                    ? Text(
                        _initials(),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: uploading ? null : onTap,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  size: 15,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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

// ── Units toggle ──────────────────────────────────────────────────────────────

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

// ── Searchable picker field ───────────────────────────────────────────────────

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.data,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final IconData icon;
  final List<LookupEntry> data;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hint;

  String? _displayText() {
    if (value == null || value!.isEmpty) {
      return null;
    }
    final entry = data.where((e) => e.code == value).firstOrNull;
    return entry != null ? '${entry.name}  ·  ${entry.code}' : value;
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LookupSheet(title: label, data: data, selected: value),
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayText();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _open(context),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
              suffixIcon: display != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear',
                      onPressed: () => onChanged(null),
                    )
                  : const Icon(Icons.expand_more),
            ),
            isEmpty: display == null,
            child: display != null
                ? Text(display, style: const TextStyle(fontSize: 16))
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// ── Search bottom sheet ───────────────────────────────────────────────────────

class _LookupSheet extends StatefulWidget {
  const _LookupSheet({
    required this.title,
    required this.data,
    this.selected,
  });

  final String title;
  final List<LookupEntry> data;
  final String? selected;

  @override
  State<_LookupSheet> createState() => _LookupSheetState();
}

class _LookupSheetState extends State<_LookupSheet> {
  late List<LookupEntry> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.data;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.data
          : widget.data
              .where(
                (e) =>
                    e.name.toLowerCase().contains(q) ||
                    e.code.toLowerCase().contains(q),
              )
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final entry = _filtered[i];
                final isSelected = entry.code == widget.selected;
                return ListTile(
                  title: Text(entry.name),
                  subtitle: Text(entry.code),
                  trailing: isSelected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null,
                  selected: isSelected,
                  onTap: () => Navigator.of(context).pop(entry.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
