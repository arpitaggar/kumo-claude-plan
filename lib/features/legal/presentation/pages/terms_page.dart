import 'package:flutter/material.dart';

import '../widgets/legal_section_widgets.dart';

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
      LegalHeading('Terms of Service'),
      LegalBody('Effective date: 1 July 2026\nLast updated: 1 July 2026'),
      SizedBox(height: 8),
      LegalBody(
        'Please read these Terms of Service ("Terms") carefully before '
        'using the Kumo mobile application ("the App"). By creating an '
        'account or using the App you agree to be bound by these Terms.',
      ),

      LegalSection('1. About Kumo'),
      LegalBody(
        'Kumo is a collaborative travel-planning application that allows '
        'users to create, manage, and share travel itineraries; split '
        'expenses; maintain packing lists; and chat with co-travellers '
        'in real time.',
      ),

      LegalSection('2. Eligibility'),
      LegalBody(
        'You must be at least 16 years old to use the App. By creating '
        'an account you confirm that you meet this age requirement. '
        'If you are using the App on behalf of an organisation, you '
        'confirm you have authority to bind that organisation to these Terms.',
      ),

      LegalSection('3. Your Account'),
      LegalBody(
        '• You are responsible for maintaining the confidentiality of '
        'your password and for all activity that occurs under your account.\n'
        '• You must provide accurate information when creating your account.\n'
        '• Notify us immediately at support@kumoapp.com if you suspect '
        'unauthorised access to your account.\n'
        '• We reserve the right to suspend or terminate accounts that '
        'violate these Terms.',
      ),

      LegalSection('4. Acceptable Use'),
      LegalBody('You agree not to:'),
      LegalBody(
        '• Upload or share content that is unlawful, harmful, defamatory, '
        'or infringes third-party rights.\n'
        '• Attempt to gain unauthorised access to other users\' data.\n'
        '• Use the App to send spam, unsolicited messages, or commercial '
        'promotions to other users.\n'
        '• Reverse-engineer, decompile, or extract source code from the App.\n'
        '• Use automated tools to scrape, crawl, or overload the service.\n'
        '• Impersonate any person or entity.',
      ),

      LegalSection('5. User Content'),
      LegalBody(
        'You retain ownership of content you create in the App '
        '(itineraries, notes, messages, etc.). By using the App you '
        'grant us a limited, worldwide, royalty-free licence to store, '
        'process, and display your content solely to provide the service '
        'to you and your collaborators. We do not use your travel data '
        'for advertising or sell it to third parties.',
      ),

      LegalSection('6. Sharing & Collaboration'),
      LegalBody(
        'When you invite another user to a trip or make an itinerary '
        'public, you agree that:\n'
        '• Invited members can view and (depending on their role) edit '
        'your trip data.\n'
        '• Public itineraries are visible to all Kumo users in the '
        'Discover feed and may be cloned.\n'
        '• You are responsible for the content you share.',
      ),

      LegalSection('7. Katha AI'),
      LegalBody(
        'The Katha AI feature generates itinerary suggestions using '
        'Anthropic\'s Claude API. AI-generated content is provided for '
        'inspiration only — we make no guarantees about its accuracy, '
        'safety, or suitability. Always verify travel information '
        'independently before booking.',
      ),

      LegalSection('8. Availability & Changes'),
      LegalBody(
        'We aim to keep the App available but do not guarantee uninterrupted '
        'access. We may modify, suspend, or discontinue features at any '
        'time. Where practical we will give reasonable notice of material '
        'changes.',
      ),

      LegalSection('9. Intellectual Property'),
      LegalBody(
        'The Kumo name, logo, and all original App content are our '
        'intellectual property. Nothing in these Terms transfers ownership '
        'of our IP to you. You may not use our branding without prior '
        'written consent.',
      ),

      LegalSection('10. Disclaimer of Warranties'),
      LegalBody(
        'The App is provided "as is" and "as available" without warranties '
        'of any kind, express or implied, including fitness for a '
        'particular purpose or non-infringement. We do not warrant that '
        'the App will be error-free or that data will not be lost.',
      ),

      LegalSection('11. Limitation of Liability'),
      LegalBody(
        'To the maximum extent permitted by law, we shall not be liable '
        'for any indirect, incidental, special, or consequential damages '
        'arising from your use of the App, including loss of data, '
        'travel disruption, or financial loss. Our total aggregate '
        'liability shall not exceed the amount you paid us (if any) in '
        'the 12 months preceding the claim.',
      ),

      LegalSection('12. Indemnity'),
      LegalBody(
        'You agree to indemnify and hold harmless Kumo and its team from '
        'any claims, losses, or expenses (including legal fees) arising '
        'from your violation of these Terms or misuse of the App.',
      ),

      LegalSection('13. Termination'),
      LegalBody(
        'You may stop using the App and delete your account at any time '
        'via Profile → Privacy → Delete Account. We may suspend or '
        'terminate your access immediately if you breach these Terms. '
        'On termination, your right to use the App ceases; Sections 5, '
        '9–12, and 14 survive termination.',
      ),

      LegalSection('14. Governing Law'),
      LegalBody(
        'These Terms are governed by the laws of England and Wales. '
        'Any disputes shall be subject to the exclusive jurisdiction '
        'of the courts of England and Wales, without prejudice to your '
        'rights as a consumer under local mandatory law.',
      ),

      LegalSection('15. Changes to These Terms'),
      LegalBody(
        'We may update these Terms from time to time. We will provide '
        'at least 14 days\' notice of material changes via in-app notice '
        'or email. Continued use after the effective date constitutes '
        'acceptance of the revised Terms.',
      ),

      LegalSection('16. Contact'),
      LegalBody('Kumo Support\nsupport@kumoapp.com'),
    ],
  );
}
