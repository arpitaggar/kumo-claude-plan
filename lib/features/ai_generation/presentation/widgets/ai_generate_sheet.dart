import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../domain/entities/ai_generation_request.dart';
import '../providers/ai_generation_provider.dart';

/// Shows the AI generation bottom sheet and returns the generated
/// [List<ItineraryItem>] when the user taps "Use this itinerary", or null
/// if the user dismisses without generating.
Future<List<ItineraryItem>?> showAiGenerateSheet(
  BuildContext context, {
  required DateTime startDate,
  required DateTime endDate,
}) =>
    showModalBottomSheet<List<ItineraryItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cloudWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        child: _AiGenerateSheet(startDate: startDate, endDate: endDate),
      ),
    );

class _AiGenerateSheet extends ConsumerStatefulWidget {
  const _AiGenerateSheet({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  @override
  ConsumerState<_AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends ConsumerState<_AiGenerateSheet> {
  final _destinationController = TextEditingController();
  final _interestsController = TextEditingController();
  TravelStyle _style = TravelStyle.adventure;

  @override
  void dispose() {
    _destinationController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final dest = _destinationController.text.trim();
    if (dest.isEmpty) {
      context.showSnackBar('Please enter a destination', isError: true);
      return;
    }
    await ref.read(aiGenerationProvider.notifier).generate(
          AiGenerationRequest(
            destination: dest,
            startDate: widget.startDate,
            endDate: widget.endDate,
            travelStyle: _style,
            interests: _interestsController.text.trim().isEmpty
                ? null
                : _interestsController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiGenerationProvider);

    ref.listen<AiGenerationState>(aiGenerationProvider, (_, next) {
      if (next is AiGenerationError) {
        context.showSnackBar(next.message, isError: true);
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: switch (state) {
        AiGenerationLoading() => const _LoadingView(),
        AiGenerationSuccess(:final items) => _SuccessView(
            items: items,
            onUse: () => Navigator.of(context).pop(items),
            onRegenerate: () =>
                ref.read(aiGenerationProvider.notifier).reset(),
          ),
        _ => _FormView(
            destinationController: _destinationController,
            interestsController: _interestsController,
            selectedStyle: _style,
            onStyleChanged: (s) => setState(() => _style = s),
            onGenerate: _generate,
          ),
      },
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 260,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: AppTheme.featuredGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.cloudWhite,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Crafting your itinerary…',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkEspresso,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This usually takes 5–10 seconds',
              style: TextStyle(fontSize: 13, color: AppTheme.earthBrown),
            ),
          ],
        ),
      );
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.items,
    required this.onUse,
    required this.onRegenerate,
  });

  final List<ItineraryItem> items;
  final VoidCallback onUse;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.featuredGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppTheme.cloudWhite, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Itinerary ready!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkEspresso,
                      ),
                    ),
                    Text(
                      '${items.length} activities generated',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.earthBrown),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: AppTheme.warmOatmeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (_, i) {
                final item = items[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemTypeIcon(itemType: item.itemType),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkEspresso,
                            ),
                          ),
                          if (item.location != null)
                            Text(
                              item.location!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.earthBrown),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onUse,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.softCoral,
              foregroundColor: AppTheme.cloudWhite,
            ),
            child: const Text('Use this itinerary'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRegenerate,
            child: const Text(
              'Try again',
              style: TextStyle(color: AppTheme.earthBrown),
            ),
          ),
        ],
      );
}

// ── Form ──────────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    required this.destinationController,
    required this.interestsController,
    required this.selectedStyle,
    required this.onStyleChanged,
    required this.onGenerate,
  });

  final TextEditingController destinationController;
  final TextEditingController interestsController;
  final TravelStyle selectedStyle;
  final void Function(TravelStyle) onStyleChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.featuredGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppTheme.cloudWhite, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Generate with AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkEspresso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: destinationController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Destination',
              hintText: 'e.g. Tokyo, Japan',
              prefixIcon: const Icon(Icons.location_on_outlined),
              filled: true,
              fillColor: AppTheme.warmOatmeal,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Travel style',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkEspresso,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TravelStyle.values.map((s) {
              final selected = s == selectedStyle;
              return GestureDetector(
                onTap: () => onStyleChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.softCoral
                        : AppTheme.warmOatmeal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.label,
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
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: interestsController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onGenerate(),
            decoration: InputDecoration(
              labelText: 'Interests (optional)',
              hintText: 'e.g. street food, temples, hiking',
              prefixIcon: const Icon(Icons.favorite_border_outlined),
              filled: true,
              fillColor: AppTheme.warmOatmeal,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate itinerary'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.softCoral,
              foregroundColor: AppTheme.cloudWhite,
            ),
          ),
        ],
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ItemTypeIcon extends StatelessWidget {
  const _ItemTypeIcon({required this.itemType});

  final String itemType;

  @override
  Widget build(BuildContext context) {
    final icon = switch (itemType) {
      'flight' => Icons.flight,
      'hotel' => Icons.hotel_outlined,
      'restaurant' => Icons.restaurant_outlined,
      'transport' => Icons.directions_car_outlined,
      _ => Icons.star_outline,
    };
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppTheme.cherryBlossom,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: AppTheme.softCoral),
    );
  }
}
