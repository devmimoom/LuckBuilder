import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_spacing.dart';
import '../localization/app_language.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';

class IosNotificationGuidePage extends ConsumerWidget {
  const IosNotificationGuidePage({
    super.key,
    this.onComplete,
  });

  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final body = ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Header
        Text(
          uiString(lang, 'ios_guide_title'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          uiString(lang, 'ios_guide_subtitle'),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Setting 1: Deliver Immediately
        _buildSettingCard(
          context,
          lang: lang,
          icon: CupertinoIcons.bell_fill,
          iconColor: const Color(0xFFFF9800),
          titleKey: 'ios_guide_delivery_title',
          descriptionKey: 'ios_guide_delivery_desc',
          stepKeys: [
            'ios_guide_step_open_settings',
            'ios_guide_step_tap_notifications',
            'ios_guide_step_immediately',
          ],
          badgeTextKey: 'ios_guide_badge_important',
          isHighlighted: true,
        ),

        const SizedBox(height: AppSpacing.md),

        // Setting 2: Banner style
        _buildSettingCard(
          context,
          lang: lang,
          icon: CupertinoIcons.rectangle_stack,
          iconColor: const Color(0xFF5B8DEF),
          titleKey: 'ios_guide_banner_title',
          descriptionKey: 'ios_guide_banner_desc',
          stepKeys: [
            'ios_guide_banner_step1',
            'ios_guide_banner_step2',
          ],
          badgeTextKey: 'ios_guide_badge_recommended',
        ),

        const SizedBox(height: AppSpacing.md),

        // Setting 3: Show Previews
        _buildSettingCard(
          context,
          lang: lang,
          icon: CupertinoIcons.eye,
          iconColor: const Color(0xFF66BB6A),
          titleKey: 'ios_guide_previews_title',
          descriptionKey: 'ios_guide_previews_desc',
          stepKeys: [
            'ios_guide_previews_step1',
            'ios_guide_previews_step2',
          ],
          badgeTextKey: 'ios_guide_badge_handy',
        ),

        const SizedBox(height: 32),

        // Why "Immediately" matters
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF9800).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.lightbulb,
                      color: Color(0xFFFF9800),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    uiString(lang, 'ios_guide_why_immediately_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                uiString(lang, 'ios_guide_why_immediately_body1'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                uiString(lang, 'ios_guide_why_immediately_body2'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Open Settings button
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5B8DEF).withValues(alpha: 0.1),
                const Color(0xFF9C27B0).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(
                CupertinoIcons.gear_alt,
                size: 48,
                color: Color(0xFF5B8DEF),
              ),
              const SizedBox(height: 16),
              Text(
                uiString(lang, 'ios_guide_open_settings_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                uiString(lang, 'ios_guide_open_settings_subtitle'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openAppSettings(context),
                icon: const Icon(CupertinoIcons.arrow_right_circle),
                label: Text(uiString(lang, 'ios_guide_open_settings_btn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B8DEF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Footer note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.info_circle,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  uiString(lang, 'ios_guide_footer_note'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (onComplete != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8DEF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              child: Text(uiString(lang, 'ios_guide_get_started')),
            ),
          ),
        ],
      ],
    );

    return PopScope(
      canPop: onComplete == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && onComplete != null) {
          onComplete!();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(uiString(lang, 'notification_settings_title')),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: body,
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required AppLanguage lang,
    required IconData icon,
    required Color iconColor,
    required String titleKey,
    required String descriptionKey,
    required List<String> stepKeys,
    required String badgeTextKey,
    bool isHighlighted = false,
  }) {
    final title = uiString(lang, titleKey);
    final description = uiString(lang, descriptionKey);
    final badgeText = uiString(lang, badgeTextKey);
    final steps = stepKeys.map((k) => uiString(lang, k)).toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? iconColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? iconColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isHighlighted ? 16 : 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                    alpha: isHighlighted ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? iconColor.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHighlighted)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs, top: AppSpacing.xs),
                          child: Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            size: 16,
                            color: iconColor,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings(BuildContext context) async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
