import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_tokens.dart';
import '../../bubble_library/providers/providers.dart';
import '../../services/auth_service.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiString(ref.read(appLanguageProvider), 'reset_link_sent_msg'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.messageFromAuthException(e, ref.read(appLanguageProvider))),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiString(ref.read(appLanguageProvider), 'auth_something_wrong')),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(uiString(lang, 'forgot_password_page_title'), style: TextStyle(color: tokens.textPrimary)),
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
                Text(
                  uiString(lang, 'forgot_password_desc'),
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
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
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading || _sent ? null : _submit,
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
                            _sent ? uiString(lang, 'sent_label') : uiString(lang, 'send_reset_link'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    uiString(lang, 'back_to_sign_in'),
                    style: TextStyle(color: tokens.primary),
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
