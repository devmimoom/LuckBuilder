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
import '../../auth/presentation/login_gate_page.dart';
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
    final selectedPlanId = ref.watch(selectedPlanIdProvider);
    final offersAsync = ref.watch(subscriptionPlanOffersProvider);
    final entitlement = ref.watch(entitlementProvider);
    final trialState = ref.watch(featureTrialProvider);
    final authState = ref.watch(authSessionProvider);
    final selectedPlan = _selectedOfferFor(
      selectedPlanId: selectedPlanId,
      offers: offersAsync.valueOrNull,
    );

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
            _buildPlansSection(ref, selectedPlanId, offersAsync),
            const SizedBox(height: AppSpacing.xxl),
            _buildCTAButton(
              context,
              ref,
              selectedPlan,
              entitlement,
              offersAsync,
              authState,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildEffectiveDateHint(entitlement),
            const SizedBox(height: AppSpacing.lg),
            _buildFooter(context, ref, entitlement),
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

  Widget _buildPlansSection(
    WidgetRef ref,
    String selectedPlanId,
    AsyncValue<List<SubscriptionPlanOffer>> offersAsync,
  ) {
    return offersAsync.when(
      data: (offers) => Column(
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
              for (var i = 0; i < offers.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PlanCard(
                    offer: offers[i],
                    currentPlanId: ref.read(entitlementProvider).currentPlanId,
                    latestPendingPlanId:
                        ref.read(entitlementProvider).pendingChanges.isEmpty
                            ? null
                            : ref
                                .read(entitlementProvider)
                                .pendingChanges
                                .last
                                .planId,
                    selected: offers[i].plan.id == selectedPlanId,
                    onTap: () {
                      AppUX.feedbackClick();
                      ref.read(selectedPlanIdProvider.notifier).state =
                          offers[i].plan.id;
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _GlassCard(
        child: Padding(
          padding: AppSpacing.cardPaddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '方案資料載入失敗',
                style: AppFonts.resolve(const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFonts.sizeBodyLg,
                  fontWeight: AppFonts.weightSemibold,
                )),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$error',
                style: AppFonts.resolve(const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFonts.sizeBodySm,
                )),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () {
                  AppUX.feedbackClick();
                  ref.invalidate(subscriptionPlanOffersProvider);
                },
                child: const Text('重新載入方案'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCTAButton(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlanOffer? selectedPlan,
    EntitlementState entitlement,
    AsyncValue<List<SubscriptionPlanOffer>> offersAsync,
    AuthSessionState authState,
  ) {
    final currentPlanId = entitlement.currentPlanId;
    final latestPendingPlanId = entitlement.pendingChanges.isEmpty
        ? null
        : entitlement.pendingChanges.last.planId;
    final isCurrentPlan =
        currentPlanId != null && selectedPlan?.plan.id == currentPlanId;
    final isLatestPendingPlan = latestPendingPlanId != null &&
        selectedPlan?.plan.id == latestPendingPlanId;
    final ctaText = selectedPlan == null
        ? '載入方案中'
        : isCurrentPlan
            ? '目前方案'
            : isLatestPendingPlan
                ? '已排程於下次續訂生效'
                : entitlement.hasAccess
                    ? '切換為${selectedPlan.plan.label}'
                    : authState.isLoggedIn
                        ? '立即訂閱 ${selectedPlan.priceLabel}/${selectedPlan.plan.unit}'
                        : '登入並訂閱 ${selectedPlan.priceLabel}/${selectedPlan.plan.unit}';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: selectedPlan == null ||
                offersAsync.isLoading ||
                entitlement.isLoading ||
                isCurrentPlan ||
                isLatestPendingPlan
            ? null
            : () async {
                await _handleSubscribeTap(context, ref, selectedPlan.plan.id);
              },
        child: Text(ctaText),
      ),
    );
  }

  Widget _buildEffectiveDateHint(EntitlementState entitlement) {
    return Text(
      entitlement.hasAccess
          ? '若日後 App 提供多種訂閱週期，變更方案時通常會在下次續訂日生效（以 App Store 為準）。'
          : '訂閱成功後會立即解鎖完整功能。',
      textAlign: TextAlign.center,
      style: AppFonts.resolve(const TextStyle(
        fontSize: AppFonts.sizeCaption,
        fontWeight: AppFonts.weightRegular,
        color: AppColors.textTertiary,
        height: AppFonts.lineHeightRelaxed,
      )),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    EntitlementState entitlement,
  ) {
    return Column(
      children: [
        if (entitlement.managementUrl != null)
          TextButton(
            onPressed: () async =>
                _handleManageSubscriptionTap(context, entitlement),
            child: Text(
              '管理訂閱',
              style: AppFonts.resolve(const TextStyle(
                fontSize: AppFonts.sizeBodySm,
                fontWeight: AppFonts.weightMedium,
                color: AppColors.textSecondary,
              )),
            ),
          ),
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
          '當你第一次使用 AI 拍照解題、AI 相似題練習或學習橫幅推播時，系統會先引導登入；登入後可免費體驗各 3 次。訂閱後三項 AI 功能皆不限次數，並可透過商店管理頁面隨時取消或變更方案。',
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
    final authNotifier = ref.read(authSessionProvider.notifier);
    await authNotifier.ensureLoaded();
    if (!context.mounted) return;
    if (!ref.read(authSessionProvider).isLoggedIn) {
      final loginResult = await Navigator.of(context).push<bool>(
        AppUX.fadeRoute(const LoginGatePage()),
      );
      if (!context.mounted || loginResult != true) {
        return;
      }
    }

    await authNotifier.syncRevenueCatForCurrentSession();
    if (!context.mounted) return;

    final wasSubscribed = ref.read(entitlementProvider).hasAccess;
    try {
      await ref.read(entitlementProvider.notifier).purchaseByPlanId(planId);
      if (!context.mounted) return;
      AppUX.feedbackSuccess();
      AppUX.showSnackBar(
        context,
        wasSubscribed ? '方案切換已送出，實際生效時間以 App Store 為準' : '訂閱成功，已解鎖完整功能',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppUX.showSnackBar(context, '購買失敗：$e', isError: true);
    }
  }

  Future<void> _handleRestoreTap(BuildContext context, WidgetRef ref) async {
    try {
      final authNotifier = ref.read(authSessionProvider.notifier);
      await authNotifier.syncRevenueCatForCurrentSession();
      await ref.read(entitlementProvider.notifier).restorePurchases();
      if (!context.mounted) return;
      final entitlement = ref.read(entitlementProvider);
      final message = entitlement.hasAccess ? '已恢復購買，完整功能已解鎖' : '目前沒有可恢復的訂閱';
      AppUX.showSnackBar(context, message);
    } catch (e) {
      if (!context.mounted) return;
      AppUX.showSnackBar(context, '恢復購買失敗：$e', isError: true);
    }
  }

  Future<void> _handleManageSubscriptionTap(
    BuildContext context,
    EntitlementState entitlement,
  ) async {
    final rawUrl = entitlement.managementUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      AppUX.showSnackBar(context, '目前沒有可用的管理訂閱連結', isError: true);
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      AppUX.showSnackBar(context, '管理訂閱連結格式錯誤', isError: true);
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppUX.showSnackBar(context, '無法開啟管理訂閱頁面', isError: true);
    }
  }

  SubscriptionPlanOffer? _selectedOfferFor({
    required String selectedPlanId,
    required List<SubscriptionPlanOffer>? offers,
  }) {
    if (offers == null || offers.isEmpty) {
      return null;
    }

    for (final offer in offers) {
      if (offer.plan.id == selectedPlanId) {
        return offer;
      }
    }
    return offers.first;
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
              color:
                  HomeMeshReferenceColors.accentPurple.withValues(alpha: 0.18),
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
    final totalRemaining = trialState.remainingOf(TrialFeature.cameraSolve) +
        trialState.remainingOf(TrialFeature.similarPractice) +
        trialState.remainingOf(TrialFeature.bannerPromotion);
    final (backgroundColor, foregroundColor, label) =
        switch (entitlement.status) {
      EntitlementStatus.loading => (
          AppColors.surface.withValues(alpha: 0.9),
          AppColors.textSecondary,
          '正在同步訂閱狀態',
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
      EntitlementStatus.active => (
          const Color(0xFFEEF7F1),
          const Color(0xFF2D7A46),
          '已訂閱完整功能',
        ),
      EntitlementStatus.cancelled => (
          const Color(0xFFFFF6E8),
          const Color(0xFF9A6B00),
          '已取消續訂，目前仍可使用完整功能',
        ),
      EntitlementStatus.billingIssue => (
          const Color(0xFFFFECEC),
          AppColors.error,
          '付款異常，請前往商店更新付款方式',
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
    required this.offer,
    required this.currentPlanId,
    this.latestPendingPlanId,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlanOffer offer;
  final String? currentPlanId;
  final String? latestPendingPlanId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plan = offer.plan;
    final isCurrentPlan = currentPlanId == plan.id;
    final isLatestPendingPlan = latestPendingPlanId == plan.id;
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
        constraints: const BoxConstraints(minHeight: 172),
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
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          plan.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.resolve(TextStyle(
                            fontSize: AppFonts.sizeTitleLg,
                            fontWeight: AppFonts.weightSemibold,
                            color: selected
                                ? HomeMeshReferenceColors.accentPurple
                                : AppColors.textSecondary,
                            height: AppFonts.lineHeightTight,
                          )),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          offer.priceLabel,
                          textAlign: TextAlign.center,
                          style: AppFonts.resolve(const TextStyle(
                            fontSize: AppFonts.sizeDisplayMd,
                            fontWeight: AppFonts.weightBold,
                            color: AppColors.textPrimary,
                            height: AppFonts.lineHeightTight,
                          )),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '/${plan.unit}',
                          textAlign: TextAlign.center,
                          style: AppFonts.resolve(const TextStyle(
                            fontSize: AppFonts.sizeBodyLg,
                            fontWeight: AppFonts.weightMedium,
                            color: AppColors.textTertiary,
                          )),
                        ),
                        if (plan.promoCopy != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            plan.promoCopy!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.resolve(TextStyle(
                              fontSize: AppFonts.sizeBodySm,
                              fontWeight: AppFonts.weightSemibold,
                              color: HomeMeshReferenceColors.accentPurple
                                  .withValues(alpha: selected ? 0.92 : 0.72),
                              height: AppFonts.lineHeightBody,
                            )),
                          ),
                        ],
                        if (isCurrentPlan) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '目前方案',
                            textAlign: TextAlign.center,
                            style: AppFonts.resolve(const TextStyle(
                              fontSize: AppFonts.sizeCaption,
                              fontWeight: AppFonts.weightSemibold,
                              color: Color(0xFF2D7A46),
                            )),
                          ),
                        ],
                        if (!isCurrentPlan && isLatestPendingPlan) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '待生效',
                            textAlign: TextAlign.center,
                            style: AppFonts.resolve(const TextStyle(
                              fontSize: AppFonts.sizeCaption,
                              fontWeight: AppFonts.weightSemibold,
                              color: Color(0xFF9A6B00),
                            )),
                          ),
                        ],
                        if (plan.savingsNote != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            offer.resolvedSavingsNote!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.resolve(TextStyle(
                              fontSize: AppFonts.sizeCaption,
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
