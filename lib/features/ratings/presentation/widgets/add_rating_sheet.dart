import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../providers/rating_provider.dart';

Future<void> showAddRatingSheet(
  BuildContext context, {
  required String itineraryId,
  required List<ItineraryItem> items,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRatingSheet(
        itineraryId: itineraryId,
        items: items,
      ),
    );

class _AddRatingSheet extends ConsumerStatefulWidget {
  const _AddRatingSheet({
    required this.itineraryId,
    required this.items,
  });

  final String itineraryId;
  final List<ItineraryItem> items;

  @override
  ConsumerState<_AddRatingSheet> createState() => _AddRatingSheetState();
}

class _AddRatingSheetState extends ConsumerState<_AddRatingSheet> {
  final _customNameController = TextEditingController();
  final _commentController = TextEditingController();

  // null = custom name mode, non-null = linked to item
  ItineraryItem? _selectedItem;
  bool _useCustomName = false;
  int _stars = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.items.isEmpty) {
      _useCustomName = true;
    }
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String? get _targetName {
    if (_useCustomName) {
      final v = _customNameController.text.trim();
      return v.isEmpty ? null : v;
    }
    return _selectedItem?.title;
  }

  Future<void> _submit() async {
    final name = _targetName;
    if (name == null) {
      context.showSnackBar('Enter a place or activity name', isError: true);
      return;
    }
    if (_stars == 0) {
      context.showSnackBar('Pick a star rating', isError: true);
      return;
    }

    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ref.read(addRatingUseCaseProvider).call(
          itineraryId: widget.itineraryId,
          targetName: name,
          stars: _stars,
          userId: auth.user.id,
          userName: auth.user.displayName ?? auth.user.email,
          itemId: _selectedItem?.id,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      (f) => context.showSnackBar(f.message, isError: true),
      (_) => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.warmOatmeal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.sakuraStone,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Rate your experience',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkEspresso,
                  ),
                ),
                const SizedBox(height: 20),

                // What to rate
                if (widget.items.isNotEmpty) ...[
                  Text('What are you rating?',
                      style: context.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _SourceToggle(
                    useCustom: _useCustomName,
                    onChanged: (v) => setState(() {
                      _useCustomName = v;
                      _selectedItem = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],

                if (!_useCustomName && widget.items.isNotEmpty) ...[
                  DropdownButtonFormField<ItineraryItem>(
                    initialValue: _selectedItem,
                    hint: const Text('Pick an activity'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    items: widget.items
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedItem = v),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextFormField(
                    controller: _customNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Place or activity name',
                      prefixIcon: Icon(Icons.edit_location_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Stars
                Text('Your rating', style: context.textTheme.labelLarge),
                const SizedBox(height: 10),
                _StarPicker(
                  value: _stars,
                  onChanged: (v) => setState(() => _stars = v),
                ),
                const SizedBox(height: 16),

                // Comment
                TextFormField(
                  controller: _commentController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.comment_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.softCoral,
                    foregroundColor: AppTheme.cloudWhite,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.cloudWhite,
                          ),
                        )
                      : const Text('Submit Review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.useCustom, required this.onChanged});

  final bool useCustom;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Chip(
            label: 'Trip activity',
            selected: !useCustom,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Other place',
            selected: useCustom,
            onTap: () => onChanged(true),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? AppTheme.softCoral : AppTheme.cloudWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.softCoral
                  : AppTheme.sakuraStone,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected
                  ? AppTheme.cloudWhite
                  : AppTheme.darkEspresso,
            ),
          ),
        ),
      );
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final star = i + 1;
          return GestureDetector(
            onTap: () => onChanged(star),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: star <= value
                    ? const Color(0xFFFFC107)
                    : AppTheme.sakuraStone,
              ),
            ),
          );
        }),
      );
}
