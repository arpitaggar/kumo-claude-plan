import 'package:flutter/material.dart';

import '../../config/theme.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        appBar: AppBar(
          title: const Text(
            'Discover',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: AppTheme.darkEspresso,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_outlined,
                  size: 64,
                  color: AppTheme.earthBrown.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text(
                'Coming soon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.earthBrown,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore destinations and travel inspiration',
                style: TextStyle(color: AppTheme.earthBrown),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
