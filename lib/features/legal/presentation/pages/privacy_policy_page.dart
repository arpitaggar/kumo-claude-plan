import 'package:flutter/material.dart';

import '../../../../shared/extensions/context_extensions.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Privacy Policy'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: _PolicyContent(),
        ),
      );
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading('Privacy Policy'),
          _Body('Effective date: 1 July 2026\nLast updated: 1 July 2026'),
          SizedBox(height: 8),
          _Body(
            'Kumo ("we", "us", or "our") is committed to protecting your '
            'personal data. This Privacy Policy explains what information we '
            'collect, how we use it, and your rights under the General Data '
            'Protection Regulation (GDPR) and applicable privacy laws.',
          ),

          _Section('1. Data Controller'),
          _Body(
            'Kumo is the data controller for personal data collected through '
            'the Kumo mobile application. For enquiries about this policy or '
            'your data rights, contact us at privacy@kumoapp.com.',
          ),

          _Section('2. Data We Collect'),
          _SubHeading('Account data'),
          _Body(
            '• Email address — required to create and identify your account.\n'
            '• Display name — optional, used to identify you to collaborators.',
          ),
          _SubHeading('Trip and travel data'),
          _Body(
            '• Itineraries, schedule items, packing lists, trip notes, and '
            'expense records you create or that are shared with you.\n'
            '• Ratings and comments you post on activities or destinations.\n'
            '• Chat messages sent within trip groups.',
          ),
          _SubHeading('Usage data'),
          _Body(
            'We do not run third-party analytics or advertising SDKs. '
            'Standard server logs (IP address, request timestamps) are '
            'retained by our infrastructure provider (Supabase) for up to '
            '30 days for security purposes.',
          ),

          _Section('3. Legal Basis for Processing (GDPR)'),
          _Body(
            '• Contract performance (Art. 6(1)(b)) — providing the app '
            'features you signed up for.\n'
            '• Legitimate interests (Art. 6(1)(f)) — preventing fraud, '
            'securing the service.\n'
            '• Consent (Art. 6(1)(a)) — where we ask for it explicitly '
            '(e.g. marketing emails, if introduced in future).',
          ),

          _Section('4. How We Use Your Data'),
          _Body(
            '• Authenticate your identity and maintain your session.\n'
            '• Enable real-time collaboration on shared trips.\n'
            '• Generate AI itinerary suggestions on your request (data is '
            'sent to Anthropic\'s API; see Section 5).\n'
            '• Display your name and avatar to trip collaborators you invite.\n'
            '• Respond to support requests.',
          ),

          _Section('5. Data Sharing & Sub-processors'),
          _Body(
            'We do not sell your data. We share data only with the following '
            'sub-processors to operate the service:',
          ),
          _Body(
            '• Supabase, Inc. (USA) — database, authentication, real-time '
            'messaging, and file storage. Data is stored on servers in the '
            'EU (Frankfurt) region.\n'
            '• Anthropic, PBC (USA) — AI itinerary generation. Destination '
            'and travel-preference data is transmitted when you use the '
            'Katha AI feature. Anthropic\'s data use is governed by their '
            'API terms.\n'
            '• Apple / Google — app distribution and in-app purchase '
            'infrastructure (if applicable).',
          ),

          _Section('6. International Transfers'),
          _Body(
            'Supabase stores your data in the EU. Anthropic\'s servers are '
            'in the United States. Transfers to the USA rely on Standard '
            'Contractual Clauses (SCCs) adopted by the European Commission.',
          ),

          _Section('7. Data Retention'),
          _Body(
            'Your data is retained for as long as your account is active. '
            'When you delete your account, all personal data — including '
            'itineraries, expenses, packing lists, messages, and ratings — '
            'is permanently deleted within 30 days. Aggregated, anonymised '
            'statistics (e.g. total trip count) may be retained indefinitely.',
          ),

          _Section('8. Your Rights (GDPR)'),
          _Body(
            'If you are in the European Economic Area or UK, you have the '
            'right to:\n\n'
            '• Access — request a copy of your personal data.\n'
            '• Rectification — correct inaccurate data via Profile → Edit Profile.\n'
            '• Erasure ("right to be forgotten") — delete your account and all '
            'associated data via Profile → Privacy → Delete Account.\n'
            '• Restriction — request we limit processing in certain circumstances.\n'
            '• Portability — export your expense data as CSV via the Expenses tab.\n'
            '• Objection — object to processing based on legitimate interests.\n'
            '• Withdraw consent — where processing is based on consent, you may '
            'withdraw at any time without affecting prior lawfulness.\n\n'
            'To exercise any right, contact privacy@kumoapp.com. We will respond '
            'within 30 days. You also have the right to lodge a complaint with '
            'your national data protection authority.',
          ),

          _Section('9. Discoverability & Visibility'),
          _Body(
            'Your display name is visible to other users only within trips you '
            'are a member of. You can disable discoverability in Profile → '
            'Privacy Settings so your name does not appear in invite searches. '
            'Public itineraries you choose to share are visible to all users '
            'in the Discover feed.',
          ),

          _Section('10. Security'),
          _Body(
            'We use HTTPS for all data in transit. Authentication tokens are '
            'stored in the platform secure keychain (iOS Keychain / Android '
            'Keystore). Row-Level Security (RLS) policies on our database '
            'ensure users can only access data they own or have been invited to.',
          ),

          _Section('11. Children'),
          _Body(
            'Kumo is not directed at children under 16. We do not knowingly '
            'collect data from anyone under 16. If you become aware that a '
            'child has provided us with personal data, contact '
            'privacy@kumoapp.com.',
          ),

          _Section('12. Changes to This Policy'),
          _Body(
            'We may update this policy from time to time. We will notify you '
            'of material changes via an in-app notice or email before the '
            'change takes effect. Continued use after the effective date '
            'constitutes acceptance.',
          ),

          _Section('13. Contact'),
          _Body(
            'Kumo Privacy\nprivacy@kumoapp.com',
          ),
        ],
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
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

class _Section extends StatelessWidget {
  const _Section(this.text);
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

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body(this.text);
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
