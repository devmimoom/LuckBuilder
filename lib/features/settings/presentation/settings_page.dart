import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/image_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/home_background_preset.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/legal_links.dart';
import '../../../core/widgets/premium_card.dart';
import '../providers/home_background_preset_provider.dart';
import '../providers/user_display_name_provider.dart';
import '../providers/user_encouragement_message_provider.dart';
import '../providers/user_profile_photo_provider.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../../subscription/presentation/subscription_page.dart';

final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

/// App 設定與關於資訊（版本號等）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const String _appDisplayName = 'LuckLab';
  static const double _cardOpacity = 0.52;

  static const List<({IconData icon, String title, String? subtitle})>
      _legalSupportItems = [
    (icon: Icons.privacy_tip_outlined, title: '隱私權政策', subtitle: null),
    (icon: Icons.gavel_outlined, title: '服務條款', subtitle: null),
    (
      icon: Icons.mail_outline_rounded,
      title: '聯絡我們',
      subtitle: 'dev.mimoom@gmail.com',
    ),
  ];

  Future<void> _handleLegalSupportTap(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) async {
    AppUX.feedbackClick();

    if (title == '聯絡我們' && subtitle != null && subtitle.isNotEmpty) {
      final uri = Uri(
        scheme: 'mailto',
        path: subtitle,
      );
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        AppUX.showSnackBar(context, '無法開啟郵件 App', isError: true);
      }
      return;
    }

    if (title == '隱私權政策') {
      final launched = await launchUrl(
        LegalLinks.privacyPolicy,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppUX.showSnackBar(context, '無法開啟隱私權政策連結', isError: true);
      }
      return;
    }

    if (title == '服務條款') {
      final launched = await launchUrl(
        LegalLinks.termsOfService,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppUX.showSnackBar(context, '無法開啟服務條款連結', isError: true);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPreset = ref.watch(homeBackgroundPresetProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            '關於',
            style: AppFonts.resolve(
              const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                letterSpacing: AppFonts.letterSpacingTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            backgroundOpacity: _cardOpacity,
            padding: AppSpacing.cardPaddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appDisplayName,
                  style: AppFonts.resolve(
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFonts.sizeTitleLg,
                      fontWeight: AppFonts.weightSemibold,
                      height: AppFonts.lineHeightTight,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '整理錯題、複習與練習，讓準備考試更有方向。',
                  style: AppFonts.resolve(
                    const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFonts.sizeBodyLg,
                      height: AppFonts.lineHeightBody,
                      fontWeight: AppFonts.weightRegular,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      '版本',
                      style: AppFonts.resolve(
                        const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFonts.sizeBodySm,
                          fontWeight: AppFonts.weightRegular,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FutureBuilder<PackageInfo>(
                        future: _packageInfoFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return Text(
                              '無法讀取版本',
                              style: AppFonts.resolve(
                                const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: AppFonts.sizeBodySm,
                                  fontWeight: AppFonts.weightRegular,
                                ),
                              ),
                            );
                          }
                          final info = snapshot.data!;
                          return Text(
                            '${info.version} (${info.buildNumber})',
                            style: AppFonts.resolve(
                              const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppFonts.sizeBodySm,
                                fontWeight: AppFonts.weightMedium,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _AccountSection(),
          const SizedBox(height: AppSpacing.xxl),
          const _UserDisplayNameField(),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '首頁背景',
            style: AppFonts.resolve(
              const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                letterSpacing: AppFonts.letterSpacingTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            backgroundOpacity: _cardOpacity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < HomeBackgroundPresets.all.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    _BackgroundSwatch(
                      preset: HomeBackgroundPresets.all[i],
                      selected:
                          selectedPreset.id == HomeBackgroundPresets.all[i].id,
                      onTap: () => ref
                          .read(homeBackgroundPresetProvider.notifier)
                          .select(HomeBackgroundPresets.all[i].id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '訂閱',
            style: AppFonts.resolve(
              const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                letterSpacing: AppFonts.letterSpacingTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            backgroundOpacity: _cardOpacity,
            padding: EdgeInsets.zero,
            onTap: () {
              AppUX.feedbackClick();
              Navigator.of(context).push(
                AppUX.fadeRoute(const SubscriptionPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC49AAC).withValues(alpha: 0.18),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusIcon),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 20,
                    color: Color(0xFFC49AAC),
                  ),
                ),
                title: Text(
                  '訂閱方案',
                  style: AppFonts.resolve(
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFonts.sizeBodyLg,
                      fontWeight: AppFonts.weightMedium,
                    ),
                  ),
                ),
                subtitle: Text(
                  '解鎖 AI 無限次使用等完整功能',
                  style: AppFonts.resolve(
                    const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFonts.sizeBodySm,
                      fontWeight: AppFonts.weightRegular,
                    ),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '法律',
            style: AppFonts.resolve(
              const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.sizeCaption,
                fontWeight: AppFonts.weightSemibold,
                letterSpacing: AppFonts.letterSpacingTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            backgroundOpacity: _cardOpacity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < _legalSupportItems.length; i++) ...[
                  _SupportEntryTile(
                    icon: _legalSupportItems[i].icon,
                    title: _legalSupportItems[i].title,
                    subtitle: _legalSupportItems[i].subtitle,
                    onTap: () => _handleLegalSupportTap(
                      context,
                      title: _legalSupportItems[i].title,
                      subtitle: _legalSupportItems[i].subtitle,
                    ),
                  ),
                  if (i != _legalSupportItems.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 0.6,
                      color: AppColors.border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionProvider);
    if (!auth.isFirebaseReady || !auth.isLoaded || !auth.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final emailLine = auth.email?.trim();
    final hasEmail = emailLine != null && emailLine.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '帳號',
          style: AppFonts.resolve(
            const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFonts.sizeCaption,
              fontWeight: AppFonts.weightSemibold,
              letterSpacing: AppFonts.letterSpacingTitle,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumCard(
          backgroundOpacity: SettingsPage._cardOpacity,
          padding: AppSpacing.cardPaddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusIcon),
                    ),
                    child: Icon(
                      auth.providerLabel == 'Apple'
                          ? Icons.apple_rounded
                          : (auth.providerLabel == 'Google'
                              ? Icons.mail_outline_rounded
                              : Icons.account_circle_outlined),
                      size: 20,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.displayName ?? '已登入',
                          style: AppFonts.resolve(
                            const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: AppFonts.sizeBodyLg,
                              fontWeight: AppFonts.weightMedium,
                            ),
                          ),
                        ),
                        if (hasEmail) ...[
                          const SizedBox(height: 2),
                          Text(
                            emailLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.resolve(
                              const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: AppFonts.sizeBodySm,
                                fontWeight: AppFonts.weightRegular,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '透過 ${auth.providerLabel ?? 'Firebase'} 登入',
                          style: AppFonts.resolve(
                            const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: AppFonts.sizeCaption,
                              fontWeight: AppFonts.weightRegular,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () async {
                  AppUX.feedbackClick();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('登出'),
                      content: const Text('確定要登出嗎？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('登出'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  try {
                    await ref.read(authSessionProvider.notifier).signOut();
                    if (context.mounted) {
                      AppUX.showSnackBar(context, '已登出');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppUX.showSnackBar(
                        context,
                        '登出失敗：$e',
                        isError: true,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('登出'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserDisplayNameField extends ConsumerStatefulWidget {
  const _UserDisplayNameField();

  @override
  ConsumerState<_UserDisplayNameField> createState() =>
      _UserDisplayNameFieldState();
}

class _UserDisplayNameFieldState extends ConsumerState<_UserDisplayNameField> {
  late final TextEditingController _controller;
  late final TextEditingController _encouragementController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _encouragementController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _encouragementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(userDisplayNameProvider);
    final photoPath = ref.watch(userProfilePhotoPathProvider);
    final avatarInitial = displayName.trim().isEmpty
        ? 'A'
        : displayName.trim().characters.first.toUpperCase();
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;

    if (_controller.text != displayName) {
      _controller.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
    }

    final encouragement = ref.watch(userEncouragementMessageProvider);
    if (_encouragementController.text != encouragement) {
      _encouragementController.value = TextEditingValue(
        text: encouragement,
        selection:
            TextSelection.collapsed(offset: encouragement.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '個人化',
          style: AppFonts.resolve(
            const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFonts.sizeCaption,
              fontWeight: AppFonts.weightSemibold,
              letterSpacing: AppFonts.letterSpacingTitle,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumCard(
          backgroundOpacity: SettingsPage._cardOpacity,
          padding: AppSpacing.cardPaddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '頭像',
                style: AppFonts.resolve(
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.sizeBodyLg,
                    fontWeight: AppFonts.weightMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEAF1FF),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasPhoto
                        ? Image.file(
                            File(photoPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                avatarInitial,
                                style: AppFonts.resolve(
                                  const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: AppFonts.sizeBodyLg,
                                    fontWeight: AppFonts.weightSemibold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              avatarInitial,
                              style: AppFonts.resolve(
                                const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: AppFonts.sizeBodyLg,
                                  fontWeight: AppFonts.weightSemibold,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final image =
                                await ImageService().pickAndCompressImage(
                              context,
                              fromCamera: false,
                            );
                            if (image == null) return;
                            await ref
                                .read(userProfilePhotoPathProvider.notifier)
                                .setPhotoPath(image.path);
                          },
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18),
                          label: const Text('加入照片'),
                        ),
                        if (hasPhoto)
                          TextButton(
                            onPressed: () => ref
                                .read(userProfilePhotoPathProvider.notifier)
                                .clear(),
                            child: const Text('移除'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '首頁顯示姓名',
                style: AppFonts.resolve(
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.sizeBodyLg,
                    fontWeight: AppFonts.weightMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '例如 Ariel',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: (value) => ref
                    .read(userDisplayNameProvider.notifier)
                    .setName(value),
                onSubmitted: (value) => ref
                    .read(userDisplayNameProvider.notifier)
                    .setName(value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '自我鼓勵的話',
                style: AppFonts.resolve(
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.sizeBodyLg,
                    fontWeight: AppFonts.weightMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _encouragementController,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: defaultUserEncouragementMessage,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: (value) => ref
                    .read(userEncouragementMessageProvider.notifier)
                    .setMessage(value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportEntryTile extends StatelessWidget {
  const _SupportEntryTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: AppFonts.resolve(
          const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFonts.sizeBodyLg,
            fontWeight: AppFonts.weightMedium,
          ),
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppFonts.resolve(
                const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFonts.sizeBodySm,
                  fontWeight: AppFonts.weightRegular,
                ),
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final HomeBackgroundPreset preset;
  final bool selected;
  final VoidCallback onTap;

  static const double _sizeNormal = 40;
  static const double _sizeSelected = 50;

  @override
  Widget build(BuildContext context) {
    final size = selected ? _sizeSelected : _sizeNormal;
    return Semantics(
      label: preset.label,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preset.previewColor,
              border: Border.all(
                color: Colors.white,
                width: selected ? 3 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
