import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/home_mesh_reference_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/legal_links.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../providers/entitlement_provider.dart';
import '../providers/feature_trial_provider.dart';
import '../providers/subscription_ui_provider.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  static const List<({IconData icon, String text})> _features = [
    (icon: Icons.auto_fix_high_rounded, text: 'AI 拍照解題不限次數'),
    (icon: Icons.quiz_rounded, text: 'AI 相似題練習不限次數'),
    (icon: Icons.notifications_active_rounded, text: '學習橫幅推播不限次數'),
    (icon: Icons.layers_rounded, text: '其他學習工具可照常使用'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedPlanIndexProvider);
    final selectedPlan = kSubscriptionPlans[selectedIndex];
    final entitlement = ref.watch(entitlementProvider);
    final trialState = ref.watch(featureTrialProvider);
    final authState = ref.watch(authSessionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('訂閱方案'),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildHeader(entitlement, trialState, authState),
            const SizedBox(height: AppSpacing.xxl),
            _buildExperienceCard(trialState, authState),
            const SizedBox(height: AppSpacing.xxl),
            _buildFeatureCard(),
            const SizedBox(height: AppSpacing.xxl),
            _buildPlansSection(ref, selectedIndex),
            const SizedBox(height: AppSpacing.xxl),
            _buildCTAButton(context, ref, selectedPlan, entitlement),
            const SizedBox(height: AppSpacing.lg),
            _buildFooter(context, ref),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    EntitlementState entitlement,
    FeatureTrialState trialState,
    AuthSessionState authState,
  ) {
    return Column(
      children: [
        Image.asset(
          'assets/sub.png',
          height: 160,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '解鎖完整功能',
          textAlign: TextAlign.center,
          style: AppFonts.resolve(const TextStyle(
            fontSize: AppFonts.sizeDisplayMd,
            fontWeight: AppFonts.weightBold,
            color: AppColors.textPrimary,
            height: AppFonts.lineHeightTight,
            letterSpacing: AppFonts.letterSpacingTitle,
          )),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          authState.isLoggedIn
              ? '登入後已啟用免費體驗；訂閱後拍照解題、AI 相似題與學習推播都能不限次使用'
              : '先登入，再開始 AI 拍照解題、AI 相似題與學習推播的免費體驗',
          textAlign: TextAlign.center,
          style: AppFonts.resolve(const TextStyle(
            fontSize: AppFonts.sizeBodyLg,
            fontWeight: AppFonts.weightRegular,
            color: AppColors.textSecondary,
            height: AppFonts.lineHeightBody,
          )),
        ),
        const SizedBox(height: AppSpacing.md),
        _TrialStatusPill(
          entitlement: entitlement,
          trialState: trialState,
          authState: authState,
        ),
      ],
    );
  }

  Widget _buildExperienceCard(
    FeatureTrialState trialState,
    AuthSessionState authState,
  ) {
    Widget row(IconData icon, String label, int remaining) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: HomeMeshReferenceColors.accentPurple),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                authState.isLoggedIn
                    ? '$label：免費體驗剩餘 $remaining 次'
                    : '$label：登入後可免費體驗 3 次',
                style: AppFonts.resolve(const TextStyle(
                  fontSize: AppFonts.sizeBodyLg,
                  fontWeight: AppFonts.weightMedium,
                  color: AppColors.textPrimary,
                )),
              ),
            ),
          ],
        ),
      );
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              '免費體驗額度',
              style: AppFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeTitleSm,
                fontWeight: AppFonts.weightSemibold,
                color: AppColors.textPrimary,
              )),
            ),
          ),
          row(
            Icons.auto_fix_high_rounded,
            'AI 拍照解題',
            trialState.remainingOf(TrialFeature.cameraSolve),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          row(
            Icons.quiz_rounded,
            'AI 相似題練習',
            trialState.remainingOf(TrialFeature.similarPractice),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          row(
            Icons.notifications_active_rounded,
            '學習橫幅推播',
            trialState.remainingOf(TrialFeature.bannerPromotion),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard() {
    return _GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < _features.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
            _FeatureRow(icon: _features[i].icon, text: _features[i].text),
          ],
        ],
      ),
    );
  }

  Widget _buildPlansSection(WidgetRef ref, int selectedIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選擇方案',
          style: AppFonts.resolve(const TextStyle(
            fontSize: AppFonts.sizeCaption,
            fontWeight: AppFonts.weightSemibold,
            color: AppColors.textSecondary,
            letterSpacing: AppFonts.letterSpacingTitle,
          )),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < kSubscriptionPlans.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PlanCard(
                  plan: kSubscriptionPlans[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    AppUX.feedbackClick();
                    ref.read(selectedPlanIndexProvider.notifier).state = i;
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCTAButton(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlan plan,
    EntitlementState entitlement,
  ) {
    final ctaText = switch (entitlement.status) {
      EntitlementStatus.trial => '你已在商店試用中',
      EntitlementStatus.expired => '立即訂閱 ${plan.priceLabel}/${plan.unit}',
      EntitlementStatus.subscribed => '你已解鎖完整功能',
    };

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: entitlement.status == EntitlementStatus.subscribed
            ? null
            : () async {
                await _handleSubscribeTap(context, ref, plan.id);
              },
        child: Text(ctaText),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        TextButton(
          onPressed: () async => _handleRestoreTap(context, ref),
          child: Text(
            '恢復購買',
            style: AppFonts.resolve(const TextStyle(
              fontSize: AppFonts.sizeBodySm,
              fontWeight: AppFonts.weightMedium,
              color: AppColors.textSecondary,
            )),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(
              label: '服務條款',
              uri: LegalLinks.termsOfService,
              context: context,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
              child: Text(
                '·',
                style: AppFonts.resolve(const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: AppFonts.sizeBodySm,
                )),
              ),
            ),
            _LegalLink(
              label: '隱私權政策',
              uri: LegalLinks.privacyPolicy,
              context: context,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '當你第一次使用 AI 拍照解題、AI 相似題練習或學習橫幅推播時，系統會先引導登入；登入後可免費體驗各 3 次。其他學習功能可正常使用。訂閱後三項 AI 功能皆不限次數，並將自動續訂，可隨時取消。',
          textAlign: TextAlign.center,
          style: AppFonts.resolve(const TextStyle(
            fontSize: AppFonts.sizeCaption,
            fontWeight: AppFonts.weightRegular,
            color: AppColors.textTertiary,
            height: AppFonts.lineHeightRelaxed,
          )),
        ),
      ],
    );
  }

  Future<void> _handleSubscribeTap(
    BuildContext context,
    WidgetRef ref,
    String planId,
  ) async {
    try {
      AppUX.feedbackSuccess();
      await ref.read(entitlementProvider.notifier).purchaseByPlanId(planId);
      if (!context.mounted) return;
      AppUX.showSnackBar(context, '訂閱成功，已解鎖完整功能');
    } catch (e) {
      if (!context.mounted) return;
      AppUX.showSnackBar(context, '購買失敗：$e', isError: true);
    }
  }

  Future<void> _handleRestoreTap(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(entitlementProvider.notifier).restorePurchases();
      if (!context.mounted) return;
      final entitlement = ref.read(entitlementProvider);
      final message =
          entitlement.hasAccess ? '已恢復購買，完整功能已解鎖' : '目前沒有可恢復的訂閱';
      AppUX.showSnackBar(context, message);
    } catch (e) {
      if (!context.mounted) return;
      AppUX.showSnackBar(context, '恢復購買失敗：$e', isError: true);
    }
  }
}

// ── 功能列 ─────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: HomeMeshReferenceColors.accentPurple.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
            child: Icon(
              icon,
              size: 17,
              color: HomeMeshReferenceColors.accentPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeBodyLg,
                fontWeight: AppFonts.weightMedium,
                color: AppColors.textPrimary,
                height: AppFonts.lineHeightTight,
              )),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: HomeMeshReferenceColors.accentPurple,
          ),
        ],
      ),
    );
  }
}

class _TrialStatusPill extends StatelessWidget {
  const _TrialStatusPill({
    required this.entitlement,
    required this.trialState,
    required this.authState,
  });

  final EntitlementState entitlement;
  final FeatureTrialState trialState;
  final AuthSessionState authState;

  @override
  Widget build(BuildContext context) {
    final totalRemaining =
        trialState.remainingOf(TrialFeature.cameraSolve) +
        trialState.remainingOf(TrialFeature.similarPractice) +
        trialState.remainingOf(TrialFeature.bannerPromotion);
    final (backgroundColor, foregroundColor, label) = switch (entitlement.status) {
      EntitlementStatus.trial => (
          HomeMeshReferenceColors.accentPurple.withValues(alpha: 0.14),
          HomeMeshReferenceColors.accentPurple,
          '目前為商店試用中',
        ),
      EntitlementStatus.expired => (
          AppColors.surface.withValues(alpha: 0.9),
          AppColors.textSecondary,
          !authState.isLoggedIn
              ? '登入後可啟用三項 AI 功能各 3 次免費體驗'
              : totalRemaining > 0
              ? '目前仍有免費體驗額度，訂閱後可不限次使用'
              : '免費體驗額度已用完，訂閱後可不限次使用',
        ),
      EntitlementStatus.subscribed => (
          const Color(0xFFEEF7F1),
          const Color(0xFF2D7A46),
          '已訂閱完整功能',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.tight,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppFonts.resolve(TextStyle(
          fontSize: AppFonts.sizeBodySm,
          fontWeight: AppFonts.weightSemibold,
          color: foregroundColor,
        )),
      ),
    );
  }
}

// ── 方案卡 ─────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? HomeMeshReferenceColors.accentPurple
        : HomeMeshReferenceColors.glassBorderWhite;
    final bgColor = selected
        ? HomeMeshReferenceColors.accentPurple.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.52);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: borderColor,
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        plan.label,
                        textAlign: TextAlign.center,
                        style: AppFonts.resolve(TextStyle(
                          fontSize: AppFonts.sizeTitleSm,
                          fontWeight: AppFonts.weightSemibold,
                          color: selected
                              ? HomeMeshReferenceColors.accentPurple
                              : AppColors.textSecondary,
                          height: AppFonts.lineHeightTight,
                        )),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'NT\$${plan.price}',
                        textAlign: TextAlign.center,
                        style: AppFonts.resolve(TextStyle(
                          fontSize: AppFonts.sizeTitleLg,
                          fontWeight: AppFonts.weightBold,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textPrimary,
                          height: AppFonts.lineHeightTight,
                        )),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '/${plan.unit}',
                        textAlign: TextAlign.center,
                        style: AppFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeCaption,
                          fontWeight: AppFonts.weightRegular,
                          color: AppColors.textTertiary,
                        )),
                      ),
                      if (plan.savingsNote != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          plan.savingsNote!,
                          textAlign: TextAlign.center,
                          style: AppFonts.resolve(TextStyle(
                            fontSize: AppFonts.sizeXs,
                            fontWeight: AppFonts.weightMedium,
                            color: HomeMeshReferenceColors.accentPurple
                                .withValues(alpha: 0.9),
                            height: AppFonts.lineHeightBody,
                          )),
                        ),
                      ],
                    ],
                  ),
                ),
                if (plan.badgeText != null)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.compact,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: HomeMeshReferenceColors.accentPurple,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(AppSpacing.radiusMd),
                          bottomLeft: Radius.circular(AppSpacing.radiusXs),
                        ),
                      ),
                      child: Text(
                        plan.badgeText!,
                        style: AppFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBadge,
                          fontWeight: AppFonts.weightSemibold,
                          color: Colors.white,
                          letterSpacing: AppFonts.letterSpacingButton,
                        )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 玻璃卡殼 ───────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: HomeMeshReferenceColors.glassBorderWhite,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── 法律連結 ───────────────────────────────────────────────────

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.uri,
    required this.context,
  });

  final String label;
  final Uri uri;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () async {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          AppUX.showSnackBar(context, '無法開啟連結', isError: true);
        }
      },
      child: Text(
        label,
        style: AppFonts.resolve(const TextStyle(
          fontSize: AppFonts.sizeBodySm,
          fontWeight: AppFonts.weightRegular,
          color: AppColors.textTertiary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textTertiary,
        )),
      ),
    );
  }
}
