import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../domain/entities/travel_itinerary.dart';
import '../providers/itinerary_provider.dart';

// ---------------------------------------------------------------------------
// Local providers
// ---------------------------------------------------------------------------

final _profileDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (_) => const ProfileRemoteDataSourceImpl(),
);

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class InviteMemberPage extends ConsumerStatefulWidget {
  const InviteMemberPage({required this.itineraryId, super.key});

  final String itineraryId;

  @override
  ConsumerState<InviteMemberPage> createState() => _InviteMemberPageState();
}

class _InviteMemberPageState extends ConsumerState<InviteMemberPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> get _existingMemberIds {
    final itinerary =
        ref.read(itineraryStreamProvider(widget.itineraryId)).value;
    return itinerary?.members.map((m) => m.userId).toList() ?? [];
  }

  Future<void> _addMember(
    ProfileResult profile,
    GroupMemberRole role,
  ) async {
    final itinerary =
        ref.read(itineraryStreamProvider(widget.itineraryId)).value;
    if (itinerary == null) {
      return;
    }

    final newMember = GroupMember(
      userId: profile.id,
      userName: profile.displayName.isNotEmpty
          ? profile.displayName
          : profile.email,
      role: role,
      joinedAt: DateTime.now().toUtc(),
    );

    final result = await ref
        .read(updateItineraryUseCaseProvider)
        .call(itinerary.copyWith(members: [...itinerary.members, newMember]));

    if (!mounted) {
      return;
    }
    result.fold(
      (failure) => context.showSnackBar(failure.message, isError: true),
      (_) => context
        ..showSnackBar('${newMember.userName} added to the trip.')
        ..pop(),
    );
  }

  Future<void> _createPendingInvite(
    String email,
    GroupMemberRole role,
  ) async {
    try {
      await ref.read(_profileDataSourceProvider).createPendingInvitation(
            itineraryId: widget.itineraryId,
            invitedEmail: email,
            role: role.name,
          );
      if (!mounted) {
        return;
      }
      context
        ..showSnackBar(
            'Invite saved. $email will join automatically when they sign up.')
        ..pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      context.showSnackBar('Failed to save invite. Please try again.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Invite Traveller'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search people'),
            Tab(icon: Icon(Icons.email_outlined), text: 'Invite by email'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SearchTab(
            existingMemberIds: _existingMemberIds,
            dataSource: ref.read(_profileDataSourceProvider),
            onAdd: _addMember,
          ),
          _EmailTab(
            existingMemberIds: _existingMemberIds,
            dataSource: ref.read(_profileDataSourceProvider),
            onAdd: _addMember,
            onPendingInvite: _createPendingInvite,
          ),
        ],
      ),
    );
}

// ---------------------------------------------------------------------------
// Tab 1 — Search by display name (discoverable users only)
// ---------------------------------------------------------------------------

class _SearchTab extends StatefulWidget {
  const _SearchTab({
    required this.existingMemberIds,
    required this.dataSource,
    required this.onAdd,
  });

  final List<String> existingMemberIds;
  final ProfileRemoteDataSource dataSource;
  final Future<void> Function(ProfileResult, GroupMemberRole) onAdd;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _searchController = TextEditingController();
  List<ProfileResult> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await widget.dataSource.searchByName(
        query,
        excludeIds: widget.existingMemberIds,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _isSearching = false;
        if (results.isEmpty) {
          _error = 'No discoverable users found for "$query".';
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _error = 'Search failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (v) {
              if (v.isEmpty) {
                setState(() {
                  _results = [];
                  _error = null;
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Search by name…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14,
                  color: context.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Only users who have enabled discoverability appear here.',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: context.textTheme.bodySmall
                  ?.copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (_, i) => _ProfileTile(
              profile: _results[i],
              onAdd: (role) => widget.onAdd(_results[i], role),
            ),
          ),
        ),
      ],
    );
}

// ---------------------------------------------------------------------------
// Tab 2 — Invite by email (always works; pending invite if unregistered)
// ---------------------------------------------------------------------------

class _EmailTab extends StatefulWidget {
  const _EmailTab({
    required this.existingMemberIds,
    required this.dataSource,
    required this.onAdd,
    required this.onPendingInvite,
  });

  final List<String> existingMemberIds;
  final ProfileRemoteDataSource dataSource;
  final Future<void> Function(ProfileResult, GroupMemberRole) onAdd;
  final Future<void> Function(String email, GroupMemberRole role)
      onPendingInvite;

  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  GroupMemberRole _role = GroupMemberRole.viewer;
  ProfileResult? _foundProfile;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _lookupError;
  // true = email found in system, false = will create pending invite
  bool? _userExists;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSearching = true;
      _lookupError = null;
      _foundProfile = null;
      _userExists = null;
    });

    final email = _emailController.text.trim().toLowerCase();

    try {
      final profile = await widget.dataSource.findByEmail(email);
      if (!mounted) {
        return;
      }

      if (profile != null) {
        if (widget.existingMemberIds.contains(profile.id)) {
          setState(() {
            _lookupError = '$email is already a member of this trip.';
            _isSearching = false;
          });
          return;
        }
        setState(() {
          _foundProfile = profile;
          _userExists = true;
          _isSearching = false;
        });
      } else {
        setState(() {
          _userExists = false;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lookupError = 'Lookup failed. Please try again.';
        _isSearching = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    if (_userExists == true && _foundProfile != null) {
      await widget.onAdd(_foundProfile!, _role);
    } else {
      await widget.onPendingInvite(
          _emailController.text.trim().toLowerCase(), _role);
    }
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return const LoadingWidget(message: 'Sending invite…');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter any email address. If they already have a Kumo account '
              'they\'ll be added instantly. Otherwise we\'ll keep the invite '
              'ready and they\'ll auto-join when they sign up.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _lookup(),
                    onChanged: (_) => setState(() {
                      _foundProfile = null;
                      _userExists = null;
                      _lookupError = null;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _isSearching
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : FilledButton.tonal(
                          onPressed: _lookup,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.search),
                        ),
                ),
              ],
            ),

            if (_lookupError != null) ...[
              const SizedBox(height: 8),
              Text(
                _lookupError!,
                style: context.textTheme.bodySmall
                    ?.copyWith(color: context.colorScheme.error),
              ),
            ],

            if (_userExists != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              if (_userExists == true && _foundProfile != null)
                _ProfileCard(profile: _foundProfile!)
              else
                _PendingBanner(email: _emailController.text.trim()),

              const SizedBox(height: 16),
              DropdownButtonFormField<GroupMemberRole>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: GroupMemberRole.viewer,
                    child: Text('Viewer — can view only'),
                  ),
                  DropdownMenuItem(
                    value: GroupMemberRole.editor,
                    child: Text('Editor — can edit itinerary'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _role = v);
                  }
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(_userExists == true
                    ? 'Add to Trip'
                    : 'Send Invite'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _ProfileTile extends StatefulWidget {
  const _ProfileTile({required this.profile, required this.onAdd});

  final ProfileResult profile;
  final void Function(GroupMemberRole role) onAdd;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  GroupMemberRole _role = GroupMemberRole.viewer;

  @override
  Widget build(BuildContext context) => ListTile(
      leading: CircleAvatar(
        backgroundColor: context.colorScheme.secondaryContainer,
        child: Text(
          widget.profile.displayName.isNotEmpty
              ? widget.profile.displayName[0].toUpperCase()
              : widget.profile.email[0].toUpperCase(),
          style:
              TextStyle(color: context.colorScheme.onSecondaryContainer),
        ),
      ),
      title: Text(widget.profile.displayName.isNotEmpty
          ? widget.profile.displayName
          : widget.profile.email),
      subtitle: widget.profile.displayName.isNotEmpty
          ? Text(
              widget.profile.email,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<GroupMemberRole>(
            value: _role,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: const [
              DropdownMenuItem(
                value: GroupMemberRole.viewer,
                child: Text('Viewer'),
              ),
              DropdownMenuItem(
                value: GroupMemberRole.editor,
                child: Text('Editor'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _role = v);
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.person_add_outlined, size: 18),
            onPressed: () => widget.onAdd(_role),
            tooltip: 'Add to trip',
          ),
        ],
      ),
    );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final ProfileResult profile;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.colorScheme.secondaryContainer,
            child: Text(
              profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : profile.email[0].toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                color: context.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.displayName.isNotEmpty)
                  Text(
                    profile.displayName,
                    style: context.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                Text(
                  profile.email,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle,
              color: context.colorScheme.primary, size: 20),
        ],
      );
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_outlined,
                size: 20, color: context.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No account found for $email',
                    style: context.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'They\'ll be added to this trip automatically when they create a Kumo account.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
