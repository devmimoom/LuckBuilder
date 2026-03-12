import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_scaffold.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_constants.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/rich_sections/sections/me_interest_tags_section.dart';
import '../widgets/rich_sections/learning_metrics_providers.dart';
import '../services/reset_service.dart';
import '../bubble_library/providers/providers.dart';
import '../bubble_library/ui/push_center_page.dart';
import '../localization/app_language.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';
import 'ios_notification_guide_page.dart';
import 'wallet_page.dart';
import 'auth/login_page.dart';
import '../bubble_library/ui/bubble_library_page.dart';

// ══════════════════════════════════════════════════════════
// Settings 靜態資料（僅標題與行為類型，顏色用 tokens）
// ══════════════════════════════════════════════════════════
enum _SettingAction { chevron, toggle, external }

class _SettingData {
  final String rowKey;
  final String emoji;
  final String? subtitleKey;
  final _SettingAction action;
  const _SettingData(this.rowKey, this.emoji, this.subtitleKey, this.action);
}

const _kSettingRows = [
  _SettingData('notifications', '🔔', 'notifications_subtitle', _SettingAction.chevron),
  _SettingData('theme', '🎨', 'theme_subtitle', _SettingAction.toggle),
  _SettingData('language', '🌐', null, _SettingAction.chevron),
  _SettingData('about', 'ℹ️', 'about_subtitle', _SettingAction.chevron),
  _SettingData('privacy_policy', '🛡', null, _SettingAction.external),
  _SettingData('terms_of_use', '📄', null, _SettingAction.external),
];

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final showAccountAndDelete = authUser != null && !authUser.isAnonymous;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: null,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: tokens.textSecondary),
            onPressed: () {
              final themeController = ref.read(themeControllerProvider);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MeSettingsPage(themeController: themeController),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _AccountWithUnlockCard(lang: lang),
            const SizedBox(height: AppSpacing.sm),
            _sectionLabel(context, tokens, uiString(lang, 'interest_tags'), action: uiString(lang, 'edit')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
              child: MeInterestTagsSection(),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (showAccountAndDelete)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
                child: _AccountSection(tokens: tokens, lang: lang),
              ),
            if (showAccountAndDelete)
              Padding(
                padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, 8, kPageHorizontalPadding, 0),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: Text(uiString(lang, 'delete_account'), style: const TextStyle(color: Colors.red)),
                  subtitle: Text(
                    uiString(lang, 'delete_account_subtitle'),
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                  onTap: () => _showDeleteAccountDialog(context, ref),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionLabel(BuildContext context, AppTokens tokens, String title, {String? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.md, kPageHorizontalPadding, AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 8,
            height: AppSpacing.sm,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              gradient: LinearGradient(
                colors: [tokens.primary, tokens.primary.withValues(alpha: 0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (action != null)
            Text(action, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ignore: unused_element - 配合 Reset all data 隱藏，還原時可移除
  void _showResetDialog(BuildContext context, WidgetRef ref) {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiString(lang, 'reset_all_data_title')),
        content: Text(uiString(lang, 'reset_all_data_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiString(lang, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performReset(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(uiString(lang, 'reset')),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(appLanguageProvider);
    final progressNotifier = ValueNotifier<String>(uiString(lang, 'preparing_reset'));
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ValueListenableBuilder<String>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(progress),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final resetService = ResetService();
      
      progressNotifier.value = uiString(lang, 'clearing_cloud_data');
      await Future.delayed(const Duration(milliseconds: 100));
      
      await resetService.resetAll();
      
      progressNotifier.value = uiString(lang, 'refreshing');

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiString(lang, 'reset_complete')),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // 刷新所有 provider
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(wishlistProvider);
      ref.invalidate(savedItemsProvider);
      ref.invalidate(globalPushSettingsProvider);
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${uiString(lang, 'reset_failed')}$e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (kDebugMode) {
        debugPrint('Reset failed: $e');
      }
    } finally {
      // 释放资源
      progressNotifier.dispose();
    }
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiString(lang, 'delete_account_title')),
        content: Text(uiString(lang, 'delete_account_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiString(lang, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteAccount(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(uiString(lang, 'delete_permanently')),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(appLanguageProvider);
    final progressNotifier = ValueNotifier<String>(uiString(lang, 'deleting_account'));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ValueListenableBuilder<String>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(progress),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final resetService = ResetService();

      progressNotifier.value = uiString(lang, 'clearing_cloud_data');
      await Future.delayed(const Duration(milliseconds: 100));
      await resetService.resetAll();

      progressNotifier.value = uiString(lang, 'deleting_account');
      await Future.delayed(const Duration(milliseconds: 100));
      await FirebaseAuth.instance.currentUser?.delete();

      progressNotifier.value = uiString(lang, 'signing_in_as_guest');
      await FirebaseAuth.instance.signInAnonymously();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      ref.invalidate(libraryProductsProvider);
      ref.invalidate(wishlistProvider);
      ref.invalidate(savedItemsProvider);
      ref.invalidate(globalPushSettingsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiString(lang, 'account_deleted_guest')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        final message = e.code == 'requires-recent-login'
            ? uiString(lang, 'delete_account_requires_recent_login')
            : '${uiString(lang, 'failed_to_delete_account')}${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${uiString(lang, 'failed_to_delete_account')}$e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      if (kDebugMode) {
        debugPrint('Delete account failed: $e');
      }
    } finally {
      progressNotifier.dispose();
    }
  }

  static void _showAboutDialog(BuildContext context, AppLanguage lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiString(lang, 'about_title')),
        content: Text(
          uiString(lang, 'about_content'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiString(lang, 'ok')),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchUrl(BuildContext context, String url, AppLanguage lang) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${uiString(lang, 'could_not_open')}$url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${uiString(lang, 'could_not_open_link')}$e')),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════
// Settings 頁（由 Me 頁右上角圖示進入，ThemeController 由 Me 傳入）
// ══════════════════════════════════════════════════════════
class _MeSettingsPage extends ConsumerWidget {
  const _MeSettingsPage({required this.themeController});
  final ThemeController themeController;

  static const _privacyUrl =
      'https://immediate-beast-f57.notion.site/OnePop-Privacy-Policy-2fb560db78bf80f0a4ccdd9ad7e34e7e?source=copy_link';
  static const _termsUrl =
      'https://immediate-beast-f57.notion.site/OnePop-Terms-of-Use-2fb560db78bf80ff9f7cd030e0b646d8?source=copy_link';

  static void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.read(appLanguageProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  uiString(lang, 'language'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  title: Text(uiString(lang, 'english')),
                  onTap: () {
                    ref.read(appLanguageProvider.notifier).state = AppLanguage.en;
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  title: Text(uiString(lang, 'traditional_chinese')),
                  onTap: () {
                    ref.read(appLanguageProvider.notifier).state = AppLanguage.zhTw;
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    final languageLabel = appLanguageDisplayName(lang);

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final isDark = themeController.id.name == 'darkNeon';
        return Scaffold(
          backgroundColor: tokens.bg,
          appBar: AppBar(
            backgroundColor: tokens.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: tokens.textPrimary,
            title: Text(uiString(lang, 'settings')),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _SettingsCard(
                tokens: tokens,
                rows: _kSettingRows,
                lang: lang,
                languageLabel: languageLabel,
                darkMode: !isDark,
                onToggle: () => themeController.toggle(),
                onNotifications: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PushCenterPage()),
                ),
                onTheme: () => themeController.toggle(),
                onLanguage: () => _MeSettingsPage._showLanguagePicker(context, ref),
                onPrivacy: () => MePage._launchUrl(context, _privacyUrl, lang),
                onTerms: () => MePage._launchUrl(context, _termsUrl, lang),
                onAbout: () => MePage._showAboutDialog(context, lang),
              ),
              if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
                  child: _SettingRow(
                    tokens: tokens,
                    emoji: '⚙️',
                    iconColor: tokens.primary,
                    title: uiString(lang, 'notification_setup_tips'),
                    subtitle: uiString(lang, 'notification_setup_tips_subtitle'),
                    action: _SettingAction.chevron,
                    isLast: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IosNotificationGuidePage()),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// Hero Section（頭像、名稱、credits、stats 皆來自 providers）
// ══════════════════════════════════════════════════════════
class _HeroSectionContent extends ConsumerWidget {
  const _HeroSectionContent({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final user = ref.watch(authStateProvider).valueOrNull;
    final balance = ref.watch(creditsBalanceProvider).valueOrNull ?? 0;
    final streakAsync = ref.watch(globalStreakProvider);
    final streak = streakAsync.valueOrNull ?? 0;

    int cardsRead = 0;
    int topicsCount = 0;
    try {
      final saved = ref.watch(savedItemsProvider).valueOrNull ?? {};
      cardsRead = saved.values.where((s) => s.learned).length;
      final lib = ref.watch(libraryProductsProvider).valueOrNull ?? [];
      topicsCount = lib.where((p) => !p.isHidden).length;
    } catch (_) {}

    final isGuest = user == null || user.isAnonymous;
    final String avatarLetter;
    final String displayName;
    String? photoUrl;

    if (isGuest) {
      avatarLetter = 'G';
      displayName = uiString(lang, 'guest');
      photoUrl = null;
    } else {
      final u = user;
      if (u.photoURL != null && u.photoURL!.isNotEmpty) {
        photoUrl = u.photoURL;
      } else {
        photoUrl = null;
      }
      avatarLetter = (u.displayName != null && u.displayName!.isNotEmpty)
          ? u.displayName!.substring(0, 1).toUpperCase()
          : (u.email != null && u.email!.isNotEmpty
              ? u.email!.substring(0, 1).toUpperCase()
              : 'G');
      displayName = (u.displayName != null && u.displayName!.isNotEmpty)
          ? u.displayName!
          : (u.email != null && u.email!.isNotEmpty ? u.email! : uiString(lang, 'signed_in'));
    }
    final String creditsLabel = uiString(lang, 'credits');
    final String subtitle = isGuest
        ? '${uiString(lang, 'guest')} · $balance $creditsLabel'
        : '$displayName · $balance $creditsLabel';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -24,
          top: -32,
          child: _GlowBlob(color: tokens.primary, size: 160, opacity: 0.3),
        ),
        Positioned(
          left: -24,
          top: 40,
          child: _GlowBlob(color: tokens.primary, size: 120, opacity: 0.15),
        ),
        Column(
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [tokens.primary, tokens.primary.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.cardBg,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipOval(
                            child: photoUrl != null
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: Text(
                                          avatarLetter,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        avatarLetter,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      avatarLetter,
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (isGuest)
                          Positioned(
                            bottom: AppSpacing.xs,
                            right: AppSpacing.xs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: tokens.bg.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: tokens.cardBorder),
                              ),
                              child: Text(
                                uiString(lang, 'guest'),
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBox(
                  tokens: tokens,
                  value: '$cardsRead',
                  label: uiString(lang, 'cards_read'),
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatBox(
                  tokens: tokens,
                  value: '$streak',
                  label: uiString(lang, 'streak'),
                  accent: tokens.primary,
                  icon: Icons.local_fire_department,
                  highlight: streak > 0,
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatBox(
                  tokens: tokens,
                  value: '$topicsCount',
                  label: uiString(lang, 'topics'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final AppTokens tokens;
  final String value;
  final String label;
  final Color? accent;
  final IconData? icon;
  final bool highlight;

  const _StatBox({
    required this.tokens,
    required this.value,
    required this.label,
    this.accent,
    this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: highlight ? tokens.primary.withValues(alpha: 0.12) : tokens.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: highlight ? tokens.primary.withValues(alpha: 0.6) : tokens.cardBorder,
          ),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: accent ?? tokens.primary,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              value,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: accent ?? tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Unlock row（用於帳號卡片內，整列可點擊導向登入頁）
// ══════════════════════════════════════════════════════════
class _UnlockRow extends StatelessWidget {
  const _UnlockRow({required this.tokens, required this.lang});
  final AppTokens tokens;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uiString(lang, 'unlock_everything'),
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  uiString(lang, 'upgrade_for_full_library'),
                  style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: tokens.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: tokens.primary.withValues(alpha: 0.5)),
            ),
            child: Text(
              uiString(lang, 'upgrade'),
              style: TextStyle(
                color: tokens.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 並排入口卡（我的圖書館、我的錢包）
// ══════════════════════════════════════════════════════════
class _MeEntryCard extends StatelessWidget {
  const _MeEntryCard({
    required this.tokens,
    required this.lang,
    required this.titleKey,
    required this.subtitleKey,
    required this.emoji,
    required this.onTap,
  });

  final AppTokens tokens;
  final AppLanguage lang;
  final String titleKey;
  final String subtitleKey;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.cardBg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: SizedBox(
          height: 110,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Text(
                  uiString(lang, titleKey),
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  uiString(lang, subtitleKey),
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Account + Unlock 單一卡片
// ══════════════════════════════════════════════════════════
class _AccountWithUnlockCard extends ConsumerWidget {
  const _AccountWithUnlockCard({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kPageHorizontalPadding, AppSpacing.md, kPageHorizontalPadding, AppSpacing.sm),
              child: _HeroSectionContent(lang: lang),
            ),
            Divider(
              height: 1,
              color: tokens.cardBorder.withValues(alpha: 0.5),
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: _MeEntryCard(
                      tokens: tokens,
                      lang: lang,
                      titleKey: 'my_library',
                      subtitleKey: 'my_library_subtitle',
                      emoji: '📚',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _MeEntryCard(
                      tokens: tokens,
                      lang: lang,
                      titleKey: 'my_wallet',
                      subtitleKey: 'my_wallet_subtitle',
                      emoji: '💳',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalletPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: tokens.cardBorder.withValues(alpha: 0.5),
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _UnlockRow(tokens: tokens, lang: lang),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Settings Card
// ══════════════════════════════════════════════════════════
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.tokens,
    required this.rows,
    required this.lang,
    required this.languageLabel,
    required this.darkMode,
    required this.onToggle,
    required this.onNotifications,
    required this.onTheme,
    required this.onLanguage,
    required this.onPrivacy,
    required this.onTerms,
    required this.onAbout,
  });

  final AppTokens tokens;
  final List<_SettingData> rows;
  final AppLanguage lang;
  final String languageLabel;
  final bool darkMode;
  final VoidCallback onToggle;
  final VoidCallback onNotifications;
  final VoidCallback onTheme;
  final VoidCallback onLanguage;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onAbout;

  VoidCallback? _onTapFor(_SettingData d) {
    switch (d.rowKey) {
      case 'notifications': return onNotifications;
      case 'theme': return onTheme;
      case 'language': return onLanguage;
      case 'about': return onAbout;
      case 'privacy_policy': return onPrivacy;
      case 'terms_of_use': return onTerms;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Column(
          children: rows.asMap().entries.map((e) {
            final d = e.value;
            final isLast = e.key == rows.length - 1;
            final onTap = _onTapFor(d);
            final title = uiString(lang, d.rowKey);
            final subtitle = d.rowKey == 'language'
                ? languageLabel
                : (d.subtitleKey != null ? uiString(lang, d.subtitleKey!) : null);
            return _SettingRow(
              tokens: tokens,
              emoji: d.emoji,
              iconColor: tokens.primary,
              title: title,
              subtitle: subtitle,
              action: d.action,
              isLast: isLast,
              darkMode: d.action == _SettingAction.toggle ? darkMode : null,
              onToggle: d.action == _SettingAction.toggle ? onToggle : null,
              onTap: onTap,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.tokens,
    required this.emoji,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.action,
    this.isLast = false,
    this.darkMode,
    this.onToggle,
    this.onTap,
  });

  final AppTokens tokens;
  final String emoji;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final _SettingAction action;
  final bool isLast;
  final bool? darkMode;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (action == _SettingAction.toggle ? onToggle : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: tokens.cardBorder.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                border: Border.all(color: iconColor.withValues(alpha: 0.25)),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle!, style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
            _buildRight(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRight(BuildContext context) {
    switch (action) {
      case _SettingAction.chevron:
        return Icon(Icons.chevron_right, color: tokens.textSecondary, size: 24);
      case _SettingAction.external:
        return Icon(Icons.open_in_new, color: tokens.textSecondary, size: 16);
      case _SettingAction.toggle:
        return GestureDetector(
          onTap: () => onToggle?.call(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              color: (darkMode ?? false) ? tokens.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: (darkMode ?? false) ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.xs),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// Account 列（登出 / 升級帳號）
class _AccountSection extends ConsumerWidget {
  const _AccountSection({required this.tokens, required this.lang});
  final AppTokens tokens;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user?.isAnonymous ?? true;
    final subtitle = user == null
        ? uiString(lang, 'not_signed_in')
        : (isAnonymous
            ? uiString(lang, 'guest')
            : (user.email != null && user.email!.isNotEmpty ? user.email! : uiString(lang, 'signed_in')));
    return _AccountSectionInner(
      tokens: tokens,
      lang: lang,
      isAnonymous: isAnonymous,
      subtitle: subtitle,
      onUpgrade: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      ),
      onSignOut: () => _signOutAndResign(context, ref),
    );
  }
}

class _AccountSectionInner extends ConsumerStatefulWidget {
  const _AccountSectionInner({
    required this.tokens,
    required this.lang,
    required this.isAnonymous,
    required this.subtitle,
    required this.onUpgrade,
    required this.onSignOut,
  });
  final AppTokens tokens;
  final AppLanguage lang;
  final bool isAnonymous;
  final String subtitle;
  final VoidCallback onUpgrade;
  final Future<void> Function() onSignOut;

  @override
  ConsumerState<_AccountSectionInner> createState() => _AccountSectionInnerState();
}

class _AccountSectionInnerState extends ConsumerState<_AccountSectionInner> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: ListTile(
        leading: Icon(Icons.person_outline, color: tokens.primary),
        title: Text(uiString(widget.lang, 'account'), style: TextStyle(color: tokens.textPrimary)),
        subtitle: Text(widget.subtitle, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
        trailing: widget.isAnonymous
            ? TextButton(
                onPressed: widget.onUpgrade,
                child: Text(uiString(widget.lang, 'upgrade_account'), style: TextStyle(color: tokens.primary)),
              )
            : TextButton(
                onPressed: _isSigningOut ? null : _handleSignOut,
                child: _isSigningOut
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tokens.primary),
                      )
                    : Text(uiString(widget.lang, 'sign_out'), style: TextStyle(color: tokens.primary)),
              ),
        onTap: widget.isAnonymous ? widget.onUpgrade : null,
      ),
    );
  }
}

Future<void> _signOutAndResign(BuildContext context, WidgetRef ref) async {
  final lang = ref.read(appLanguageProvider);
  await FirebaseAuth.instance.signOut();
  const maxAttempts = 2;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      ref.invalidate(uidProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiString(lang, 'signed_out_guest'))),
        );
      }
      return;
    } catch (_) {
      if (attempt == maxAttempts && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiString(lang, 'signed_out_guest_failed')),
          ),
        );
      }
    }
  }
}

/// Account & My Wallet 整合卡片（舊版，保留供參考或還原）
// ignore: unused_element
class _AccountAndWalletCard extends ConsumerWidget {
  const _AccountAndWalletCard({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(creditsBalanceProvider).valueOrNull ?? 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_wallet_outlined, color: tokens.primary),
            title: Text('My Wallet', style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text(
              '$balance credits · Balance & history',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletPage()),
            ),
          ),
          Divider(height: 1, color: tokens.textSecondary.withValues(alpha: 0.3)),
          _AccountSectionLegacy(tokens: tokens, contentPadding: EdgeInsets.zero),
        ],
      ),
    );
  }
}

/// Account section（舊版）：匿名時顯示「升級帳號」；已登入時顯示「登出」。供 _AccountAndWalletCard 使用。
class _AccountSectionLegacy extends ConsumerStatefulWidget {
  const _AccountSectionLegacy({required this.tokens, this.contentPadding});

  final AppTokens tokens;
  final EdgeInsets? contentPadding;

  @override
  ConsumerState<_AccountSectionLegacy> createState() => _AccountSectionLegacyState();
}

class _AccountSectionLegacyState extends ConsumerState<_AccountSectionLegacy> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await _signOutAndResign(context, ref);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user?.isAnonymous ?? true;

    return ListTile(
      contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
      leading: Icon(Icons.person_outline, color: tokens.primary),
      title: Text('Account', style: TextStyle(color: tokens.textPrimary)),
      subtitle: Text(
        user == null
            ? 'Not signed in'
            : (isAnonymous
                ? 'Guest'
                : (user.email != null && user.email!.isNotEmpty
                    ? user.email!
                    : 'Signed in')),
        style: TextStyle(color: tokens.textSecondary, fontSize: 12),
      ),
      trailing: isAnonymous
          ? TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginPage(),
                ),
              ),
              child: Text('Upgrade account', style: TextStyle(color: tokens.primary)),
            )
          : TextButton(
              onPressed: _isSigningOut ? null : _handleSignOut,
              child: _isSigningOut
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.primary,
                      ),
                    )
                  : Text('Sign out', style: TextStyle(color: tokens.primary)),
            ),
      onTap: isAnonymous
          ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginPage(),
                ),
              )
          : null,
    );
  }
}
