import 'package:flutter/material.dart';

import '../../config/theme.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.warmOatmeal,
        appBar: AppBar(
          title: const Text(
            'Inbox',
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
              Icon(Icons.chat_bubble_outline,
                  size: 64,
                  color: AppTheme.earthBrown.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.earthBrown,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Group chats appear here once you join a trip',
                style: TextStyle(color: AppTheme.earthBrown),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
