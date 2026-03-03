import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class LegalSection {
  final String heading;
  final String body;

  const LegalSection({required this.heading, required this.body});
}

// ---------------------------------------------------------------------------
// Reusable page widget (Terms & Conditions / Privacy Policy)
// ---------------------------------------------------------------------------

class LegalPage extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalPage({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: CyberColors.cyan, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: CyberColors.cyan,
            letterSpacing: 1,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: CyberColors.cyan.withValues(alpha: 0.25),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last updated badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CyberColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: CyberColors.cyan.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.update,
                    size: 13,
                    color: CyberColors.cyan.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      lastUpdated,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: CyberColors.cyan.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Sections
            ...sections.asMap().entries.map(
              (e) => _LegalSectionWidget(index: e.key + 1, section: e.value),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _LegalSectionWidget extends StatelessWidget {
  final int index;
  final LegalSection section;

  const _LegalSectionWidget({required this.index, required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: CyberColors.cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$index. ${section.heading}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Section body (selectable for accessibility)
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: SelectableText(
              section.body,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Color(0xFFBBBBCC),
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Divider(color: CyberColors.cyan.withValues(alpha: 0.1), height: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms & Conditions content
// ---------------------------------------------------------------------------

class TermsContent {
  TermsContent._();

  static const String pageTitle = 'Terms & Conditions';

  static const String lastUpdated =
      'Effective: Feb 28, 2026  ·  Last Updated: Feb 28, 2026';

  static const List<LegalSection> sections = [
    LegalSection(
      heading: 'ACCEPTANCE OF TERMS',
      body: 'By downloading, installing, accessing, or using Cyber Blockx '
          '("the App", "the Game", "we", "us", "our"), you acknowledge that '
          'you have read, understood, and agree to be bound by these Terms and '
          'Conditions ("Terms").\n\n'
          'If you do not agree to these Terms in their entirety, you must '
          'immediately discontinue use of the App. Your continued use of the '
          'App after any modification to these Terms constitutes acceptance of '
          'the revised Terms.',
    ),
    LegalSection(
      heading: 'ELIGIBILITY',
      body: 'You must be at least 13 years of age to use this App. Users '
          'between 13 and 18 years of age may only use the App with the '
          'consent and supervision of a parent or legal guardian who agrees '
          'to these Terms on their behalf.\n\n'
          'By using the App, you represent and warrant that:\n'
          '• You are at least 13 years of age;\n'
          '• You have the legal capacity to enter into these Terms;\n'
          '• You are not located in a jurisdiction where blockchain-based '
          'applications, Solana network interactions, or digital asset '
          'activities are prohibited by applicable law;\n'
          '• Your use of the App does not violate any applicable law or '
          'regulation in your jurisdiction.',
    ),
    LegalSection(
      heading: 'WALLETS & THIRD-PARTY SERVICES',
      body: 'The App offers optional integration with third-party Solana '
          'wallet applications, including but not limited to Phantom and '
          'Solflare ("Wallet Services"). The following terms apply to all '
          'wallet integrations:\n\n'
          '• NO CUSTODY OF PRIVATE KEYS: We do not, at any time, custody, '
          'store, control, or have access to your private keys, seed phrases, '
          'recovery phrases, or wallet credentials. You retain full and sole '
          'control of your wallet.\n\n'
          '• THIRD-PARTY CONTROL: We do not control any third-party wallet '
          'application. Each wallet app is operated by its respective '
          'provider under that provider\'s own terms of service, privacy '
          'policy, and security practices. We are not responsible for the '
          'functionality, security, or availability of any third-party '
          'wallet.\n\n'
          '• YOUR RESPONSIBILITY: You are solely responsible for the '
          'security of your wallet, including safeguarding your private keys '
          'and seed phrases. Loss of your private key means permanent loss '
          'of access to your wallet assets.\n\n'
          '• NO LIABILITY FOR WALLET LOSSES: We are not liable for any loss '
          'of digital assets, unauthorized transactions, or damages arising '
          'from your use of, or inability to use, any third-party wallet '
          'service.\n\n'
          '• OPTIONAL: Connecting a wallet is entirely optional. Core game '
          'functionality is available without wallet integration.',
    ),
    LegalSection(
      heading: 'DIGITAL ASSETS & TRANSACTIONS',
      body: 'Where the App involves interaction with the Solana blockchain '
          'or references digital assets, the following applies:\n\n'
          '• IRREVERSIBILITY: All on-chain transactions are final and '
          'irreversible once confirmed by the network. We cannot cancel, '
          'reverse, or modify any blockchain transaction.\n\n'
          '• VOLATILITY: Digital asset values are highly volatile. We make '
          'no representation, warranty, or guarantee regarding the present '
          'or future value of any digital asset.\n\n'
          '• NETWORK FEES: You are responsible for all applicable network '
          'fees, gas fees, and transaction costs associated with any '
          'blockchain interaction.\n\n'
          '• REGULATORY COMPLIANCE: You are solely responsible for '
          'determining and complying with all applicable laws, regulations, '
          'and tax obligations in your jurisdiction relating to digital '
          'assets, including but not limited to anti-money laundering (AML) '
          'and know-your-customer (KYC) requirements.\n\n'
          '• NOT FINANCIAL ADVICE: Nothing in this App constitutes financial, '
          'investment, tax, or legal advice. We are not a financial '
          'institution, broker-dealer, investment adviser, or money services '
          'business.',
    ),
    LegalSection(
      heading: 'PROMOTIONS & LEADERBOARDS',
      body: 'The App features local and global leaderboards and may '
          'periodically offer promotions, competitions, events, or rewards '
          '("Promotions"). The following terms govern all Promotions:\n\n'
          '• MODIFICATION & CANCELLATION: We reserve the right to modify, '
          'suspend, or terminate any Promotion at any time, for any reason, '
          'without prior notice or liability.\n\n'
          '• FAIR PLAY: Leaderboard rankings are determined solely by scores '
          'legitimately recorded within the App. We reserve the right to '
          'review, adjust, or remove any scores we reasonably determine to '
          'be fraudulent, manipulated, or obtained by prohibited means.\n\n'
          '• DISQUALIFICATION: Any player found to be cheating, exploiting '
          'bugs, using unauthorized automation, bots, hacks, modified '
          'clients, or any other prohibited means will be permanently '
          'disqualified from all Promotions and may be permanently banned '
          'from the App. Disqualified players forfeit any accrued rewards.\n\n'
          '• REWARD DISTRIBUTION: Where Promotions involve digital asset '
          'rewards, eligibility and distribution are subject to applicable '
          'laws and our sole discretion. We reserve the right to withhold '
          'rewards where distribution would violate applicable law, or where '
          'we reasonably suspect fraudulent activity.\n\n'
          '• NO GUARANTEE: Participation in leaderboards or Promotions does '
          'not guarantee any reward, prize, or benefit.',
    ),
    LegalSection(
      heading: 'PROHIBITED CONDUCT',
      body: 'You agree that you will NOT, under any circumstances:\n\n'
          '• Reverse engineer, decompile, disassemble, or attempt to derive '
          'source code from the App or any portion thereof;\n'
          '• Use cheats, exploits, automation software, bots, hacks, mods, '
          'or any unauthorized third-party software that interacts with the '
          'App;\n'
          '• Attempt to gain unauthorized access to any server, system, or '
          'account associated with the App;\n'
          '• Use the App for any unlawful purpose or in violation of any '
          'applicable law or regulation;\n'
          '• Impersonate any person or entity, or misrepresent your '
          'affiliation with any person or entity;\n'
          '• Submit false, misleading, or fraudulent scores or data to the '
          'leaderboard;\n'
          '• Interfere with, disrupt, or damage the integrity, performance, '
          'or availability of the App or its underlying infrastructure;\n'
          '• Collect, harvest, or aggregate information about other users '
          'without their express consent;\n'
          '• Engage in any conduct that restricts or inhibits any other user '
          'from using or enjoying the App.',
    ),
    LegalSection(
      heading: 'INTELLECTUAL PROPERTY',
      body: 'All content within the App—including but not limited to game '
          'mechanics, graphics, artwork, animations, music, sound effects, '
          'text, code, trademarks, and trade dress—is the exclusive property '
          'of Cyber Blockx or its licensors, and is protected by applicable '
          'intellectual property laws.\n\n'
          'You are granted a limited, non-exclusive, non-transferable, '
          'revocable license to access and use the App solely for your '
          'personal, non-commercial entertainment. This license does not '
          'include any right to sublicense, sell, resell, copy, modify, '
          'create derivative works from, or publicly display any App content.',
    ),
    LegalSection(
      heading: 'DISCLAIMER OF WARRANTIES',
      body: 'THE APP IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS, '
          'WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, OR '
          'STATUTORY. TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, '
          'WE EXPRESSLY DISCLAIM ALL WARRANTIES, INCLUDING BUT NOT LIMITED '
          'TO:\n\n'
          '• IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR '
          'PURPOSE, AND NON-INFRINGEMENT;\n'
          '• WARRANTIES THAT THE APP WILL BE UNINTERRUPTED, TIMELY, SECURE, '
          'OR FREE FROM ERRORS OR VIRUSES;\n'
          '• WARRANTIES REGARDING THE ACCURACY, RELIABILITY, OR COMPLETENESS '
          'OF ANY INFORMATION PROVIDED THROUGH THE APP;\n'
          '• WARRANTIES WITH RESPECT TO ANY THIRD-PARTY WALLET, BLOCKCHAIN '
          'NETWORK, OR DIGITAL ASSET.',
    ),
    LegalSection(
      heading: 'LIMITATION OF LIABILITY',
      body: 'TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CYBER BLOCKX '
          'AND ITS AFFILIATES, OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, AND '
          'LICENSORS SHALL NOT BE LIABLE FOR:\n\n'
          '• ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR '
          'PUNITIVE DAMAGES OF ANY KIND;\n'
          '• LOSS OF PROFITS, REVENUE, DATA, DIGITAL ASSETS, GOODWILL, OR '
          'BUSINESS OPPORTUNITY;\n'
          '• DAMAGES ARISING FROM UNAUTHORIZED ACCESS TO OR ALTERATION OF '
          'YOUR ACCOUNT OR TRANSMISSIONS;\n'
          '• DAMAGES ARISING FROM YOUR USE OF, OR INABILITY TO USE, THE APP '
          'OR ANY CONNECTED THIRD-PARTY WALLET OR SERVICE;\n'
          '• DAMAGES ARISING FROM ANY BUG, VIRUS, OR OTHER HARMFUL COMPONENT '
          'TRANSMITTED THROUGH THE APP;\n\n'
          'WHETHER BASED ON WARRANTY, CONTRACT, TORT (INCLUDING NEGLIGENCE), '
          'STRICT LIABILITY, OR ANY OTHER THEORY, EVEN IF WE HAVE BEEN '
          'ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.\n\n'
          'OUR TOTAL CUMULATIVE LIABILITY TO YOU FOR ANY CLAIMS ARISING FROM '
          'OR RELATING TO THESE TERMS OR THE APP SHALL NOT EXCEED '
          'US\$10.00.',
    ),
    LegalSection(
      heading: 'INDEMNIFICATION',
      body: 'You agree to defend, indemnify, and hold harmless Cyber Blockx '
          'and its affiliates, officers, directors, employees, and agents '
          'from and against any and all claims, damages, losses, liabilities, '
          'costs, and expenses (including reasonable attorneys\' fees) '
          'arising out of or relating to:\n\n'
          '• Your use of or access to the App;\n'
          '• Your violation of these Terms;\n'
          '• Your violation of any applicable law or the rights of any '
          'third party;\n'
          '• Any content you submit, post, or transmit through the App.',
    ),
    LegalSection(
      heading: 'PRIVACY',
      body: 'Your use of the App is also governed by our Privacy Policy, '
          'which is incorporated into these Terms by reference. By using '
          'the App, you consent to the data collection and processing '
          'practices described in the Privacy Policy.\n\n'
          'You may review our Privacy Policy at any time from the Settings '
          'screen.',
    ),
    LegalSection(
      heading: 'CHANGES TO TERMS',
      body: 'We reserve the right to update or modify these Terms at any '
          'time at our sole discretion. When we make material changes, we '
          'will update the "Last Updated" date displayed on this page.\n\n'
          'Your continued use of the App following the posting of any '
          'changes constitutes your acceptance of the revised Terms. If you '
          'do not agree to the revised Terms, you must stop using the App.\n\n'
          'We encourage you to review these Terms periodically to stay '
          'informed of any updates.',
    ),
    LegalSection(
      heading: 'GOVERNING LAW & DISPUTES',
      body: 'These Terms shall be governed by and construed in accordance '
          'with applicable law, without regard to conflict-of-law principles. '
          'Any dispute arising from or relating to these Terms or the App '
          'that cannot be resolved informally shall be submitted to binding '
          'arbitration or resolved in a court of competent jurisdiction, '
          'as required by applicable law in your jurisdiction.',
    ),
    LegalSection(
      heading: 'CONTACT INFORMATION',
      body: 'If you have any questions, concerns, or requests regarding '
          'these Terms and Conditions, please contact us:\n\n'
          'Email:    support@cyberblockx.com\n'
          'Website:  cyberblockx.com\n\n'
          'We will endeavour to respond to all inquiries within a '
          'reasonable timeframe.',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Privacy Policy content (basic – reuses LegalPage)
// ---------------------------------------------------------------------------

class PrivacyContent {
  PrivacyContent._();

  static const String pageTitle = 'Privacy Policy';

  static const String lastUpdated =
      'Effective: Feb 28, 2026  ·  Last Updated: Feb 28, 2026';

  static const List<LegalSection> sections = [
    LegalSection(
      heading: 'INFORMATION WE COLLECT',
      body: 'We collect limited information necessary to operate the App:\n\n'
          '• GAME DATA: Scores, level progress, settings preferences, and '
          'in-app activity stored locally on your device.\n'
          '• WALLET ADDRESS: If you choose to connect a Solana wallet, we '
          'store your public wallet address to enable global leaderboard '
          'features. We never access or store private keys or seed phrases.\n'
          '• DEVICE INFORMATION: Basic device and OS information for '
          'compatibility and analytics purposes.\n'
          '• USAGE DATA: Aggregated, anonymised data about how the App is '
          'used, to improve game performance and features.',
    ),
    LegalSection(
      heading: 'HOW WE USE YOUR INFORMATION',
      body: 'We use the information we collect to:\n\n'
          '• Operate and improve the App;\n'
          '• Maintain global leaderboard rankings;\n'
          '• Authenticate wallet connections;\n'
          '• Detect and prevent fraud or cheating;\n'
          '• Respond to support inquiries;\n'
          '• Comply with applicable legal obligations.',
    ),
    LegalSection(
      heading: 'THIRD-PARTY WALLETS & SERVICES',
      body: 'The App integrates with third-party wallet providers (Phantom, '
          'Solflare). These providers operate under their own privacy '
          'policies. We do not control the data practices of third-party '
          'wallet applications and encourage you to review their respective '
          'privacy policies.\n\n'
          'We do not share your personal data with third parties for '
          'marketing purposes.',
    ),
    LegalSection(
      heading: 'DATA RETENTION',
      body: 'We retain information for as long as necessary to provide our '
          'services, or as required by applicable law. Local game data is '
          'stored on your device and can be cleared by uninstalling the App. '
          'Global leaderboard data associated with your wallet address may '
          'be retained after you disconnect your wallet.',
    ),
    LegalSection(
      heading: 'SECURITY',
      body: 'We implement reasonable technical and organisational measures '
          'to protect your data against unauthorised access, disclosure, '
          'alteration, or destruction. However, no method of transmission '
          'over the internet or electronic storage is completely secure, '
          'and we cannot guarantee absolute security.',
    ),
    LegalSection(
      heading: 'CHILDREN\'S PRIVACY',
      body: 'The App is not directed to children under 13 years of age. '
          'We do not knowingly collect personal information from children '
          'under 13. If you believe we have inadvertently collected '
          'information from a child under 13, please contact us immediately '
          'at support@cyberblockx.com and we will take steps to delete '
          'such information.',
    ),
    LegalSection(
      heading: 'YOUR RIGHTS',
      body: 'Depending on your jurisdiction, you may have the right to:\n\n'
          '• Access the personal data we hold about you;\n'
          '• Request correction of inaccurate data;\n'
          '• Request deletion of your data;\n'
          '• Object to or restrict processing of your data;\n'
          '• Data portability.\n\n'
          'To exercise any of these rights, contact us at '
          'support@cyberblockx.com.',
    ),
    LegalSection(
      heading: 'CHANGES TO THIS POLICY',
      body: 'We may update this Privacy Policy from time to time. Material '
          'changes will be reflected by updating the "Last Updated" date at '
          'the top of this page. Your continued use of the App after any '
          'changes constitutes acceptance of the revised policy.',
    ),
    LegalSection(
      heading: 'CONTACT',
      body: 'For privacy-related questions or requests, please contact:\n\n'
          'Email:    support@cyberblockx.com\n'
          'Website:  cyberblockx.com',
    ),
  ];
}
