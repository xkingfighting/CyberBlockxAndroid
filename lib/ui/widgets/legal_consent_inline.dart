import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../screens/legal_page.dart';
import '../../services/localization_service.dart';

/// Minimal compliance notice shown on the home screen.
///
/// Renders a single line of small text with two tappable spans:
///   "By continuing, you agree to the [Terms & Conditions] and [Privacy Policy]."
///
/// • TapGestureRecognizer absorbs link taps → they do NOT bubble up to the
///   parent full-screen GestureDetector(onTap: startGame).
/// • Tapping the plain-text portion DOES bubble up → starts the game,
///   which is semantically correct ("continuing = agreeing").
/// • Recognizers are created in State and disposed on widget removal.
class LegalConsentInline extends StatefulWidget {
  const LegalConsentInline({super.key});

  @override
  State<LegalConsentInline> createState() => _LegalConsentInlineState();
}

class _LegalConsentInlineState extends State<LegalConsentInline> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LegalPage(
          title: TermsContent.pageTitle,
          lastUpdated: TermsContent.lastUpdated,
          sections: TermsContent.sections,
        ),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LegalPage(
          title: PrivacyContent.pageTitle,
          lastUpdated: PrivacyContent.lastUpdated,
          sections: PrivacyContent.sections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Padding(
          // Extra horizontal padding to keep text narrower than buttons above
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              // Base style: muted grey, small, monospace – low visual weight
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.35),
                height: 1.6,
                letterSpacing: 0.2,
              ),
              children: [
                TextSpan(text: L.legalConsentPart1.tr),
                // --- Terms link ---
                TextSpan(
                  text: L.legalConsentTermsLabel.tr,
                  recognizer: _termsRecognizer,
                  style: TextStyle(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.75),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    decorationThickness: 0.8,
                    letterSpacing: 0.2,
                  ),
                ),
                TextSpan(text: L.legalConsentPart2.tr),
                // --- Privacy link ---
                TextSpan(
                  text: L.legalConsentPrivacyLabel.tr,
                  recognizer: _privacyRecognizer,
                  style: TextStyle(
                    color: const Color(0xFFCC44FF).withValues(alpha: 0.75),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFCC44FF).withValues(alpha: 0.5),
                    decorationThickness: 0.8,
                    letterSpacing: 0.2,
                  ),
                ),
                TextSpan(text: L.legalConsentPart3.tr),
              ],
            ),
          ),
        );
      },
    );
  }
}
