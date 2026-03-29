import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_ux.dart';
import '../../settings/providers/user_display_name_provider.dart';
import '../providers/auth_session_provider.dart';

class LoginGatePage extends ConsumerStatefulWidget {
  const LoginGatePage({super.key});

  @override
  ConsumerState<LoginGatePage> createState() => _LoginGatePageState();
}

class _LoginGatePageState extends ConsumerState<LoginGatePage> {
  var _isSubmitting = false;

  Future<void> _runLogin(Future<void> Function() action) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
      final authState = ref.read(authSessionProvider);
      final nextName = authState.displayName?.trim();
      if (nextName != null && nextName.isNotEmpty) {
        await ref.read(userDisplayNameProvider.notifier).setName(nextName);
      }
      if (!mounted) return;
      AppUX.feedbackSuccess();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppUX.showSnackBar(context, '登入失敗：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);
    final firebaseReady = authState.isFirebaseReady;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('登入後開始體驗'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '先登入，再開始免費體驗',
                    textAlign: TextAlign.center,
                    style: AppFonts.resolve(const TextStyle(
                      fontSize: AppFonts.sizeDisplayMd,
                      fontWeight: AppFonts.weightBold,
                      color: AppColors.textPrimary,
                    )),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '登入後即可啟用 AI 拍照解題、AI 相似題練習與學習橫幅推播，各 3 次免費體驗。',
                    textAlign: TextAlign.center,
                    style: AppFonts.resolve(const TextStyle(
                      fontSize: AppFonts.sizeBodyLg,
                      fontWeight: AppFonts.weightRegular,
                      color: AppColors.textSecondary,
                      height: AppFonts.lineHeightBody,
                    )),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (!firebaseReady) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E8),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: const Color(0xFFFFD7A8)),
                      ),
                      child: Text(
                        authState.errorMessage ??
                            'Firebase 尚未設定完成。請先加入 `google-services.json`、`GoogleService-Info.plist`，並在 Firebase Console 啟用 Google / Apple 登入。',
                        style: AppFonts.resolve(const TextStyle(
                          fontSize: AppFonts.sizeBodySm,
                          fontWeight: AppFonts.weightMedium,
                          color: AppColors.textPrimary,
                          height: AppFonts.lineHeightBody,
                        )),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  ElevatedButton.icon(
                    onPressed: _isSubmitting || !firebaseReady
                        ? null
                        : () => _runLogin(
                              () => ref
                                  .read(authSessionProvider.notifier)
                                  .signInWithGoogle(),
                            ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_isSubmitting ? '登入中...' : '使用 Google 登入'),
                  ),
                  if (Platform.isIOS || Platform.isMacOS) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting || !firebaseReady
                          ? null
                          : () => _runLogin(
                                () => ref
                                    .read(authSessionProvider.notifier)
                                    .signInWithApple(),
                              ),
                      icon: const Icon(Icons.apple),
                      label: const Text('使用 Apple 登入'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('稍後再說'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
