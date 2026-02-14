import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_scaffold.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/rich_sections/sections/me_dashboard_section.dart';
import '../widgets/rich_sections/sections/me_interest_tags_section.dart';
import '../widgets/rich_sections/sections/me_achievements_section.dart';
import '../services/reset_service.dart';
import '../bubble_library/providers/providers.dart';
import '../bubble_library/ui/push_center_page.dart';
import 'ios_notification_guide_page.dart';
import 'wallet_page.dart';
import 'auth/login_page.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final themeController = ref.watch(themeControllerProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Me',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.textPrimary,
                ),
          ),
          const SizedBox(height: 16),

          // Account & My Wallet 整合卡片（置頂）
          _AccountAndWalletCard(tokens: tokens),
          const SizedBox(height: 14),

          // 學習儀表板
          const MeDashboardSection(),
          const SizedBox(height: 14),

          // 興趣標籤
          const MeInterestTagsSection(),
          const SizedBox(height: 14),

          // 里程碑/成就
          const MeAchievementsSection(),
          const SizedBox(height: 18),

          // Notifications
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: tokens.primary),
            title: Text('Notifications', style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text(
              'Schedule, quiet hours, daily cap',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushCenterPage()),
            ),
          ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            ListTile(
              leading: Icon(CupertinoIcons.settings, color: tokens.primary),
              title: Text('Notification setup tips', style: TextStyle(color: tokens.textPrimary)),
              subtitle: Text(
                'Banner & preview settings',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IosNotificationGuidePage(),
                ),
              ),
            ),
          const Divider(),

          ListTile(
            leading: Icon(Icons.color_lens_outlined, color: tokens.primary),
            title: Text('Theme', style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text(
              themeController.id.name == 'darkNeon' ? 'Dark Neon' : 'White Mint',
              style: TextStyle(color: tokens.textSecondary),
            ),
            trailing: Switch(
              value: themeController.id.name == 'whiteMint',
              onChanged: (_) => themeController.toggle(),
            ),
            onTap: () => themeController.toggle(),
          ),
          ListTile(
            leading: Icon(Icons.language, color: tokens.primary),
            title: Text('Language', style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text(
              'English',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: tokens.primary),
            title: Text('About', style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text(
              'OnePop 1.0.0',
              style: TextStyle(color: tokens.textSecondary),
            ),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: tokens.primary),
            title: Text('Privacy policy', style: TextStyle(color: tokens.textPrimary)),
            trailing: Icon(Icons.open_in_new, size: 18, color: tokens.textSecondary),
            onTap: () => _launchUrl(context, 'https://immediate-beast-f57.notion.site/OnePop-Privacy-Policy-2fb560db78bf80f0a4ccdd9ad7e34e7e?source=copy_link'),
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: tokens.primary),
            title: Text('Terms of use', style: TextStyle(color: tokens.textPrimary)),
            trailing: Icon(Icons.open_in_new, size: 18, color: tokens.textSecondary),
            onTap: () => _launchUrl(context, 'https://immediate-beast-f57.notion.site/OnePop-Terms-of-Use-2fb560db78bf80ff9f7cd030e0b646d8?source=copy_link'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore_outlined, color: Colors.red),
            title: const Text(
              'Reset all data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: Text(
              'Clear all progress, settings, and local data. This cannot be undone.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            onTap: () => _showResetDialog(context, ref),
          ),
          // Apple 審核要求：帳號刪除功能
          if (FirebaseAuth.instance.currentUser?.isAnonymous == false)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text(
                'Delete account',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: Text(
                'Permanently delete your account and all associated data.',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This will permanently remove:\n'
          '• All Firestore data (progress, settings, favorites, etc.)\n'
          '• All local data (notification schedule, cache, etc.)\n'
          '• All scheduled notifications\n\n'
          'This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performReset(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset(BuildContext context, WidgetRef ref) async {
    // 显示详细的加载对话框
    final progressNotifier = ValueNotifier<String>('Preparing reset...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder<String>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
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
      
      progressNotifier.value = 'Clearing cloud data...';
      await Future.delayed(const Duration(milliseconds: 100)); // 让 UI 更新
      
      await resetService.resetAll();
      
      progressNotifier.value = 'Refreshing...';

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示成功消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset complete. App has been restored to default state.'),
            duration: Duration(seconds: 3),
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

      // 显示错误消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and all data, including:\n'
          '• Your learning progress\n'
          '• All settings and preferences\n'
          '• Purchase history (credits are non-refundable)\n'
          '• All local data and notifications\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteAccount(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount(BuildContext context, WidgetRef ref) async {
    final progressNotifier = ValueNotifier<String>('Deleting account...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder<String>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
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

      progressNotifier.value = 'Clearing cloud data...';
      await Future.delayed(const Duration(milliseconds: 100));
      await resetService.resetAll();

      progressNotifier.value = 'Deleting account...';
      await Future.delayed(const Duration(milliseconds: 100));
      await FirebaseAuth.instance.currentUser?.delete();

      progressNotifier.value = 'Signing in as guest...';
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
          const SnackBar(
            content: Text('Account deleted. You are now signed in as a guest.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        final message = e.code == 'requires-recent-login'
            ? 'For security, please sign out and sign in again, then try deleting your account.'
            : 'Failed to delete account: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
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

  static void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Text(
          'OnePop\nVersion 1.0.0',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
}

/// Account & My Wallet 整合卡片：置頂，內含 My Wallet 與 Account 兩列。
class _AccountAndWalletCard extends ConsumerWidget {
  const _AccountAndWalletCard({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(creditsBalanceProvider).valueOrNull ?? 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          _AccountSection(tokens: tokens, contentPadding: EdgeInsets.zero),
        ],
      ),
    );
  }
}

/// Account section: 匿名時顯示「升級帳號」導向登入頁；已登入時顯示「登出」。
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection({required this.tokens, this.contentPadding});

  final AppTokens tokens;
  final EdgeInsets? contentPadding;

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
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

  Future<void> _signOutAndResign(BuildContext context, WidgetRef ref) async {
    await FirebaseAuth.instance.signOut();
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        ref.invalidate(uidProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Signed out. You are now signed in as a new guest.')),
          );
        }
        return;
      } catch (_) {
        if (attempt == maxAttempts && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out, but could not continue as guest. Please try again.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user?.isAnonymous ?? true;

    return ListTile(
      contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
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
                      width: 20,
                      height: 20,
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
