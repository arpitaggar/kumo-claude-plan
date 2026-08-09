import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../extensions/context_extensions.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      return const SizedBox.shrink();
    }
    // inverseSurface/onInverseSurface is the Material-conventional pair for
    // a banner that needs to read clearly regardless of the active theme's
    // brightness (dark-on-light themes, light-on-dark for Synthwave Tokyo).
    final onInverse = context.colorScheme.onInverseSurface;
    return ColoredBox(
      color: context.colorScheme.inverseSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 14, color: onInverse),
              const SizedBox(width: 6),
              Text(
                'You\'re offline — showing cached data',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onInverse, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
