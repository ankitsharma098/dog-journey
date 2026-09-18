import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass/glass_scaffold.dart';

/// Terms of Service and Privacy Policy — see [_termsSections] and
/// [_privacySections] below.
///
/// IMPORTANT: this is a functional starter draft, written to actually
/// describe what PawJourney does (Supabase accounts, Gemini-powered
/// vet chat and breed scanning, RevenueCat subscriptions, local
/// notifications, the 30-day account-deletion grace period) rather
/// than generic boilerplate — Apple's App Store Review Guidelines
/// §3.1.2 require a working Terms/Privacy link for any app selling
/// auto-renewing subscriptions, so "coming soon" here blocks
/// submission, not just looks unfinished. It is NOT a substitute for
/// review by a lawyer before shipping — update the placeholders
/// (company name, support email, effective date, governing law) and
/// have it reviewed before this goes live with real users' health
/// data and payment info attached to it.
enum LegalDoc { terms, privacy }

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.doc});
  final LegalDoc doc;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late LegalDoc _doc = widget.doc;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sections = _doc == LegalDoc.terms ? _termsSections : _privacySections;

    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      body: ListView(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  PhosphorIconsRegular.arrowLeft,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Terms & privacy',
                style: AppTextStyles.listRowTitle.copyWith(
                  fontSize: 15,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.sheet(brightness),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline(brightness)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DocTab(
                    label: 'Terms of Service',
                    selected: _doc == LegalDoc.terms,
                    onTap: () => setState(() => _doc = LegalDoc.terms),
                  ),
                ),
                Expanded(
                  child: _DocTab(
                    label: 'Privacy Policy',
                    selected: _doc == LegalDoc.privacy,
                    onTap: () => setState(() => _doc = LegalDoc.privacy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Last updated September 2026',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary(brightness),
            ),
          ),
          const SizedBox(height: 18),
          for (final section in sections) ...[
            Text(
              section.heading,
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              section.body,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _DocTab extends StatelessWidget {
  const _DocTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.accentOn(brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.chipLabel.copyWith(
            fontSize: 10.5,
            letterSpacing: 0,
            color: selected ? accent : AppColors.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}

typedef _Section = ({String heading, String body});

const _termsSections = <_Section>[
  (
    heading: '1. Acceptance of terms',
    body:
        'By creating an account or using PawJourney, you agree to these '
        'Terms of Service and the Privacy Policy. If you do not agree, '
        'do not use the app.',
  ),
  (
    heading: '2. What PawJourney is',
    body:
        'PawJourney helps you keep records for your dog: vaccines, '
        'medications, weight, nutrition, breed identification, and '
        'photo memories. It is a record-keeping and information tool, '
        'not a veterinary service.',
  ),
  (
    heading: '3. Not veterinary advice',
    body:
        'The AI Vet Chat and any other AI-generated content in this app '
        '(including breed identification) provide general information '
        'only. They are not a diagnosis, and not a substitute for '
        'examination and advice from a licensed veterinarian. Always '
        'consult a vet for any health concern, and treat any '
        'emergency-flagged guidance as a prompt to seek care '
        'immediately — not as the care itself.',
  ),
  (
    heading: '4. Your account',
    body:
        'You are responsible for the accuracy of the information you '
        'enter and for keeping your login credentials secure. You must '
        'be at least 18, or the age of majority in your jurisdiction, '
        'to create an account.',
  ),
  (
    heading: '5. Subscriptions (PawJourney Pro)',
    body:
        'PawJourney Pro is offered as an auto-renewing subscription '
        '(monthly or yearly) billed through the Apple App Store or '
        'Google Play. Payment is charged to your store account at '
        'confirmation of purchase. Subscriptions renew automatically '
        'unless auto-renew is turned off at least 24 hours before the '
        'end of the current period. Manage or cancel your subscription '
        'in your device\'s App Store/Play Store account settings — '
        'refunds are handled by Apple/Google under their own policies, '
        'not directly by us.',
  ),
  (
    heading: '6. Acceptable use',
    body:
        'Do not use PawJourney to upload content you don\'t have the '
        'right to share, to attempt to disrupt or reverse-engineer the '
        'service, or to rely on it as a substitute for emergency '
        'veterinary or human medical care.',
  ),
  (
    heading: '7. Termination',
    body:
        'You may delete your account at any time in Settings. We may '
        'suspend or terminate accounts that violate these terms. See '
        'the Privacy Policy for what happens to your data after '
        'deletion.',
  ),
  (
    heading: '8. Changes to these terms',
    body:
        'We may update these terms as the app changes. Continued use '
        'after an update means you accept the revised terms.',
  ),
  (
    heading: '9. Contact',
    body: 'Questions about these terms: support@pawjourney.app',
  ),
];

const _privacySections = <_Section>[
  (
    heading: '1. What we collect',
    body:
        'Account information (email address); your dog\'s profile '
        '(name, breed, birthdate, weight, photos); health records you '
        'enter (vaccines, medications, weight history); nutrition logs; '
        'photos and captions you add to your dog\'s story; and the '
        'messages you send in AI Vet Chat.',
  ),
  (
    heading: '2. How we use it',
    body:
        'To provide the service you signed up for: storing your dog\'s '
        'records, generating AI vet-chat responses and breed '
        'identification, calculating nutrition targets, sending local '
        'care reminders, and processing your Pro subscription.',
  ),
  (
    heading: '3. Third parties we rely on',
    body:
        'Supabase hosts your account and pet data. Google\'s Gemini API '
        'processes the text/photos you send to AI Vet Chat and the '
        'breed scanner in order to generate a response — that content '
        'is sent to Google for processing. RevenueCat and the Apple '
        'App Store/Google Play process subscription payments; we '
        'never see your card details. None of these partners are '
        'permitted to sell your data.',
  ),
  (
    heading: '4. Data retention & deletion',
    body:
        'Deleting your account in Settings starts a 30-day grace '
        'period, during which you can sign back in to cancel the '
        'deletion. After 30 days, your account and associated pet '
        'records, photos, and chat history are permanently deleted '
        'from our systems.',
  ),
  (
    heading: '5. Photos and storage',
    body:
        'Photos you upload (pet profile pictures, story memories) are '
        'stored via Supabase Storage and are only accessible through '
        'your account.',
  ),
  (
    heading: '6. Children\'s privacy',
    body:
        'PawJourney is not directed at children under 13, and we do '
        'not knowingly collect data from them.',
  ),
  (
    heading: '7. Your rights',
    body:
        'You can access, correct, or export your pet\'s records at any '
        'time in the app, and request full account deletion in '
        'Settings. Depending on where you live, you may have '
        'additional rights under laws like the GDPR or CCPA — contact '
        'us to exercise them.',
  ),
  (
    heading: '8. Changes to this policy',
    body:
        'We\'ll update the "last updated" date above if this policy '
        'changes materially.',
  ),
  (
    heading: '9. Contact',
    body: 'Questions about this policy: support@pawjourney.app',
  ),
];
