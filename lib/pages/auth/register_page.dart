import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../theme/app_tokens.dart';
import '../../bubble_library/providers/providers.dart';
import '../../services/auth_service.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final wasAnonymous = auth.isAnonymous;
      await auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      ref.invalidate(uidProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAnonymous ? uiString(ref.read(appLanguageProvider), 'account_upgraded_msg') : uiString(ref.read(appLanguageProvider), 'signed_up_msg'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      // 目前註冊頁僅由「登入頁」進入，堆疊為 Me → Login → Register，故 pop 兩次回到 Me。
      // 若日後改為可從 Me 直接進註冊，需改為依進入路徑決定 pop 次數。
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.messageFromAuthException(e, ref.read(appLanguageProvider))),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiString(ref.read(appLanguageProvider), 'auth_something_wrong')),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 等 auth 在客戶端變成非匿名再返回，避免 Me 頁仍讀到舊的匿名 user。
  Future<void> _waitForAuthNonAnonymous() async {
    final firebaseAuth = ref.read(firebaseAuthProvider);
    try {
      await firebaseAuth.authStateChanges()
          .where((u) => u != null && !u.isAnonymous)
          .first
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Timeout or stream error: proceed anyway so we don't block forever
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final result = await auth.signInWithGoogle();
      if (!mounted) return;
      await _waitForAuthNonAnonymous();
      if (!mounted) return;
      ref.invalidate(uidProvider);
      final message = switch (result) {
        SignInResult.linked => 'Account upgraded.',
        SignInResult.signedInToExisting => 'Signed in with existing account.',
        SignInResult.signedIn => uiString(ref.read(appLanguageProvider), 'signed_in_msg'),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'sign_in_canceled') {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.messageFromAuthException(e, ref.read(appLanguageProvider))),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiString(ref.read(appLanguageProvider), 'auth_something_wrong')),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final result = await auth.signInWithApple();
      if (!mounted) return;
      await _waitForAuthNonAnonymous();
      if (!mounted) return;
      ref.invalidate(uidProvider);
      final message = switch (result) {
        SignInResult.linked => 'Account upgraded.',
        SignInResult.signedInToExisting => 'Signed in with existing account.',
        SignInResult.signedIn => uiString(ref.read(appLanguageProvider), 'signed_in_msg'),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'sign_in_canceled') {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.messageFromAuthException(e, ref.read(appLanguageProvider))),
          duration: const Duration(seconds: 4),
        ),
      );
    }     on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      final message = e.message.isNotEmpty
          ? e.message
          : uiString(ref.read(appLanguageProvider), 'auth_something_wrong');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiString(ref.read(appLanguageProvider), 'auth_something_wrong')),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(uiString(lang, 'sign_up_page_title'), style: TextStyle(color: tokens.textPrimary)),
        backgroundColor: tokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: uiString(lang, 'email_label'),
                    hintText: uiString(lang, 'email_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: tokens.cardBg,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return uiString(lang, 'enter_email_validator');
                    if (!v.contains('@')) return uiString(lang, 'valid_email_validator');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: uiString(lang, 'password_label'),
                    hintText: uiString(lang, 'password_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: tokens.cardBg,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: tokens.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return uiString(lang, 'enter_password_validator');
                    if (v.length < 6) return uiString(lang, 'password_too_short_validator');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: uiString(lang, 'confirm_password_label'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: tokens.cardBg,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: tokens.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return uiString(lang, 'enter_confirm_validator');
                    if (v != _passwordController.text) return uiString(lang, 'passwords_no_match');
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tokens.primary,
                            ),
                          )
                        : Text(
                            ref.watch(authServiceProvider).isAnonymous
                                ? uiString(lang, 'upgrade_sign_up_cta')
                                : uiString(lang, 'sign_up_cta'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        uiString(lang, 'or_sign_with'),
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: tokens.cardBorder),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: Text(uiString(lang, 'sign_up_google')),
                  ),
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithApple,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: tokens.cardBorder),
                      ),
                      icon: const Icon(Icons.apple, size: 24),
                      label: Text(uiString(lang, 'sign_up_apple')),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      uiString(lang, 'already_have_account'),
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(uiString(lang, 'sign_in_cta'), style: TextStyle(color: tokens.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
