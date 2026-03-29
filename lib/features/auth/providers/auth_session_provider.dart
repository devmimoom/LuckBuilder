import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthSessionState {
  const AuthSessionState({
    required this.isLoggedIn,
    required this.isLoaded,
    required this.isFirebaseReady,
    this.uid,
    this.displayName,
    this.email,
    this.providerLabel,
    this.errorMessage,
  });

  final bool isLoggedIn;
  final bool isLoaded;
  final bool isFirebaseReady;
  final String? uid;
  final String? displayName;
  final String? email;
  final String? providerLabel;
  final String? errorMessage;

  const AuthSessionState.initial()
      : isLoggedIn = false,
        isLoaded = false,
        isFirebaseReady = false,
        uid = null,
        displayName = null,
        email = null,
        providerLabel = null,
        errorMessage = null;

  AuthSessionState copyWith({
    bool? isLoggedIn,
    bool? isLoaded,
    bool? isFirebaseReady,
    String? uid,
    String? displayName,
    String? email,
    String? providerLabel,
    String? errorMessage,
  }) {
    return AuthSessionState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoaded: isLoaded ?? this.isLoaded,
      isFirebaseReady: isFirebaseReady ?? this.isFirebaseReady,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      providerLabel: providerLabel ?? this.providerLabel,
      errorMessage: errorMessage,
    );
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>(
  (ref) => AuthSessionNotifier(),
);

class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  AuthSessionNotifier() : super(const AuthSessionState.initial()) {
    unawaited(_load());
  }

  StreamSubscription<User?>? _authSub;
  Future<void>? _loadingFuture;
  var _googleInitialized = false;

  Future<void> _load() async {
    if (_loadingFuture != null) return _loadingFuture;
    _loadingFuture = _loadInternal();
    await _loadingFuture;
  }

  Future<void> _loadInternal() async {
    try {
      final isFirebaseReady = Firebase.apps.isNotEmpty;
      if (!isFirebaseReady) {
        state = const AuthSessionState(
          isLoggedIn: false,
          isLoaded: true,
          isFirebaseReady: false,
          errorMessage: 'Firebase 尚未完成設定',
        );
        return;
      }

      await _initializeGoogleSignIn();
      _syncFromUser(FirebaseAuth.instance.currentUser);
      _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_syncFromUser);
    } catch (e) {
      state = AuthSessionState(
        isLoggedIn: false,
        isLoaded: true,
        isFirebaseReady: Firebase.apps.isNotEmpty,
        errorMessage: '登入初始化失敗：$e',
      );
    }
  }

  Future<void> ensureLoaded() async {
    if (state.isLoaded) return;
    await _load();
  }

  Future<void> signInWithGoogle() async {
    await ensureLoaded();
    _requireFirebaseReady();
    await _initializeGoogleSignIn();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('目前平台不支援 Google 登入');
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google 登入未取得可用憑證');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    _syncFromUser(userCredential.user);
  }

  Future<void> signInWithApple() async {
    await ensureLoaded();
    _requireFirebaseReady();

    if (!(Platform.isIOS || Platform.isMacOS)) {
      throw StateError('Sign in with Apple 目前僅在 Apple 裝置上提供');
    }

    if (!await SignInWithApple.isAvailable()) {
      throw StateError(
        '此裝置或系統版本不支援 Sign in with Apple（需 iOS 13+，且須在 Apple Developer 為 App ID 開啟該能力）。',
      );
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple 登入未取得 identity token，請重試或改用具體 Apple ID 登入 iCloud 後再試。');
    }

    // Firebase 驗證 Apple 時常需要 authorization code 當作 OAuth accessToken。
    final authCode = appleCredential.authorizationCode.trim();
    final AuthCredential oauthCredential = authCode.isNotEmpty
        ? OAuthProvider('apple.com').credential(
            idToken: identityToken,
            rawNonce: rawNonce,
            accessToken: authCode,
          )
        : OAuthProvider('apple.com').credential(
            idToken: identityToken,
            rawNonce: rawNonce,
          );

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      final displayName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');

      if (displayName.isNotEmpty &&
          (userCredential.user?.displayName ?? '').isEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
      }

      await userCredential.user?.reload();
      _syncFromUser(FirebaseAuth.instance.currentUser);
    } on FirebaseAuthException catch (e) {
      throw StateError(_appleFirebaseAuthMessage(e));
    }
  }

  String _appleFirebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Apple 登入憑證被拒絕。請到 Firebase Console → Authentication → 登入方法，啟用「Apple」；'
            '並確認 iOS App 的 Bundle ID（com.mimoom.lucklab）已註冊在同一個 Firebase 專案。';
      case 'operation-not-allowed':
        return 'Firebase 尚未允許 Apple 登入：請在 Authentication → 登入方法中啟用「Apple」。';
      case 'user-disabled':
        return '此帳號已被停用。';
      default:
        return 'Apple 登入失敗（${e.code}）：${e.message ?? "未知錯誤"}';
    }
  }

  Future<void> signOut() async {
    await ensureLoaded();
    if (!state.isFirebaseReady) return;
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Ignore Google disconnect failures; Firebase sign-out already succeeded.
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  void _requireFirebaseReady() {
    if (!state.isFirebaseReady) {
      throw StateError(
        'Firebase 尚未設定完成。請先加入 google-services.json、GoogleService-Info.plist，並完成 Firebase Console 的 Google / Apple 登入設定。',
      );
    }
  }

  void _syncFromUser(User? user) {
    if (user == null) {
      state = AuthSessionState(
        isLoggedIn: false,
        isLoaded: true,
        isFirebaseReady: Firebase.apps.isNotEmpty,
      );
      return;
    }

    state = AuthSessionState(
      isLoggedIn: true,
      isLoaded: true,
      isFirebaseReady: true,
      uid: user.uid,
      displayName: _displayNameFor(user),
      email: user.email,
      providerLabel: _providerLabelFor(user),
    );
  }

  String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final email = user.email?.trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'LuckLab 使用者';
  }

  String _providerLabelFor(User user) {
    final providerIds = user.providerData.map((item) => item.providerId).toSet();
    if (providerIds.contains('apple.com')) return 'Apple';
    if (providerIds.contains('google.com')) return 'Google';
    return 'Firebase';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

String _sha256OfString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
