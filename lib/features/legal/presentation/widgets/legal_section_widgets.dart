import 'package:flutter/material.dart';

import '../../../../shared/extensions/context_extensions.dart';

/// Shared building blocks for the legal pages (`PrivacyPolicyPage`,
/// `TermsPage`) — previously byte-for-byte-identical private copies in each
/// page file.

class LegalHeading extends StatelessWidget {
  const LegalHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurface,
      ),
    ),
  );
}

class LegalSection extends StatelessWidget {
  const LegalSection(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurface,
      ),
    ),
  );
}

class LegalBody extends StatelessWidget {
  const LegalBody(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.6,
        color: context.colorScheme.onSurface,
      ),
    ),
  );
}
