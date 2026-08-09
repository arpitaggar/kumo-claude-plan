import 'package:flutter/material.dart';

import '../../../../shared/extensions/context_extensions.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Terms of Service'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    ),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: _TermsContent(),
    ),
  );
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Heading('Terms of Service'),
      _Body('Effective date: 1 July 2026\nLast updated: 1 July 2026'),
      SizedBox(height: 8),
      _Body(
        'Please read these Terms of Service ("Terms") carefully before '
        'using the Kumo mobile application ("the App"). By creating an '
        'account or using the App you agree to be bound by these Terms.',
      ),

      _Section('1. About Kumo'),
      _Body(
        'Kumo is a collaborative travel-planning application that allows '
        'users to create, manage, and share travel itineraries; split '
        'expenses; maintain packing lists; and chat with co-travellers '
        'in real time.',
      ),

      _Section('2. Eligibility'),
      _Body(
        'You must be at least 16 years old to use the App. By creating '
        'an account you confirm that you meet this age requirement. '
        'If you are using the App on behalf of an organisation, you '
        'confirm you have authority to bind that organisation to these Terms.',
      ),

      _Section('3. Your Account'),
      _Body(
        '• You are responsible for maintaining the confidentiality of '
        'your password and for all activity that occurs under your account.\n'
        '• You must provide accurate information when creating your account.\n'
        '• Notify us immediately at support@kumoapp.com if you suspect '
        'unauthorised access to your account.\n'
        '• We reserve the right to suspend or terminate accounts that '
        'violate these Terms.',
      ),

      _Section('4. Acceptable Use'),
      _Body('You agree not to:'),
      _Body(
        '• Upload or share content that is unlawful, harmful, defamatory, '
        'or infringes third-party rights.\n'
        '• Attempt to gain unauthorised access to other users\' data.\n'
        '• Use the App to send spam, unsolicited messages, or commercial '
        'promotions to other users.\n'
        '• Reverse-engineer, decompile, or extract source code from the App.\n'
        '• Use automated tools to scrape, crawl, or overload the service.\n'
        '• Impersonate any person or entity.',
      ),

      _Section('5. User Content'),
      _Body(
        'You retain ownership of content you create in the App '
        '(itineraries, notes, messages, etc.). By using the App you '
        'grant us a limited, worldwide, royalty-free licence to store, '
        'process, and display your content solely to provide the service '
        'to you and your collaborators. We do not use your travel data '
        'for advertising or sell it to third parties.',
      ),

      _Section('6. Sharing & Collaboration'),
      _Body(
        'When you invite another user to a trip or make an itinerary '
        'public, you agree that:\n'
        '• Invited members can view and (depending on their role) edit '
        'your trip data.\n'
        '• Public itineraries are visible to all Kumo users in the '
        'Discover feed and may be cloned.\n'
        '• You are responsible for the content you share.',
      ),

      _Section('7. Katha AI'),
      _Body(
        'The Katha AI feature generates itinerary suggestions using '
        'Anthropic\'s Claude API. AI-generated content is provided for '
        'inspiration only — we make no guarantees about its accuracy, '
        'safety, or suitability. Always verify travel information '
        'independently before booking.',
      ),

      _Section('8. Availability & Changes'),
      _Body(
        'We aim to keep the App available but do not guarantee uninterrupted '
        'access. We may modify, suspend, or discontinue features at any '
        'time. Where practical we will give reasonable notice of material '
        'changes.',
      ),

      _Section('9. Intellectual Property'),
      _Body(
        'The Kumo name, logo, and all original App content are our '
        'intellectual property. Nothing in these Terms transfers ownership '
        'of our IP to you. You may not use our branding without prior '
        'written consent.',
      ),

      _Section('10. Disclaimer of Warranties'),
      _Body(
        'The App is provided "as is" and "as available" without warranties '
        'of any kind, express or implied, including fitness for a '
        'particular purpose or non-infringement. We do not warrant that '
        'the App will be error-free or that data will not be lost.',
      ),

      _Section('11. Limitation of Liability'),
      _Body(
        'To the maximum extent permitted by law, we shall not be liable '
        'for any indirect, incidental, special, or consequential damages '
        'arising from your use of the App, including loss of data, '
        'travel disruption, or financial loss. Our total aggregate '
        'liability shall not exceed the amount you paid us (if any) in '
        'the 12 months preceding the claim.',
      ),

      _Section('12. Indemnity'),
      _Body(
        'You agree to indemnify and hold harmless Kumo and its team from '
        'any claims, losses, or expenses (including legal fees) arising '
        'from your violation of these Terms or misuse of the App.',
      ),

      _Section('13. Termination'),
      _Body(
        'You may stop using the App and delete your account at any time '
        'via Profile → Privacy → Delete Account. We may suspend or '
        'terminate your access immediately if you breach these Terms. '
        'On termination, your right to use the App ceases; Sections 5, '
        '9–12, and 14 survive termination.',
      ),

      _Section('14. Governing Law'),
      _Body(
        'These Terms are governed by the laws of England and Wales. '
        'Any disputes shall be subject to the exclusive jurisdiction '
        'of the courts of England and Wales, without prejudice to your '
        'rights as a consumer under local mandatory law.',
      ),

      _Section('15. Changes to These Terms'),
      _Body(
        'We may update these Terms from time to time. We will provide '
        'at least 14 days\' notice of material changes via in-app notice '
        'or email. Continued use after the effective date constitutes '
        'acceptance of the revised Terms.',
      ),

      _Section('16. Contact'),
      _Body('Kumo Support\nsupport@kumoapp.com'),
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
