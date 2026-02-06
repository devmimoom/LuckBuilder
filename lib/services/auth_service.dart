import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

/// 登入結果：供 UI 區分「連結匿名升級」與「以既有帳號登入」。
enum SignInResult {
  /// 匿名帳號已連結為正式帳號（uid 不變）
  linked,
  /// 以既有帳號登入（信箱已綁定其他帳號，先登出匿名再登入）
  signedInToExisting,
  /// 非匿名狀態下的一般登入
  signedIn,
}

/// 登入/註冊/連結帳號服務：封裝 Firebase Auth，支援匿名連結與錯誤訊息轉換。
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  /// 登入（email/密碼）。若當前為匿名則改為 linkWithCredential 升級，uid 不變。
  /// 若該信箱已綁定其他帳號（credential-already-in-use），改為先登出匿名再以信箱密碼登入，讓使用者取回既有帳號。
  Future<SignInResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (currentUser?.isAnonymous == true) {
      final cred = EmailAuthProvider.credential(
        email: trimmedEmail,
        password: password,
      );
      try {
        await currentUser!.linkWithCredential(cred);
        await _auth.currentUser?.reload();
        return SignInResult.linked;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          await _auth.signOut();
          try {
            await _auth.signInWithEmailAndPassword(
              email: trimmedEmail,
              password: password,
            );
            await _auth.currentUser?.reload();
            return SignInResult.signedInToExisting;
          } catch (_) {
            // 既有帳號登入失敗（密碼錯誤、網路等）：恢復匿名，再拋出讓 UI 顯示錯誤
            await _auth.signInAnonymously();
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } else {
      await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      await _auth.currentUser?.reload();
      return SignInResult.signedIn;
    }
  }

  /// 註冊（email/密碼）。若當前為匿名則改為 linkWithCredential 升級，uid 不變。
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (currentUser?.isAnonymous == true) {
      final cred = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await currentUser!.linkWithCredential(cred);
    } else {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  /// 以 Google 帳號登入／註冊。若當前為匿名則 link 升級；若 credential-already-in-use 則登出匿名後以既有帳號登入。
  Future<SignInResult> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'sign_in_canceled',
        message: 'Canceled',
      );
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;
    if (idToken == null || accessToken == null) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Could not get Google sign-in info. Please try again.',
      );
    }
    final cred = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    return _signInOrLinkWithCredential(cred);
  }

  /// 以 Apple ID 登入／註冊。若當前為匿名則 link 升級；若 credential-already-in-use 則登出匿名後以既有帳號登入。
  Future<SignInResult> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonceHash = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonceHash,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Could not get Apple sign-in info. Please try again.',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode.isNotEmpty
          ? appleCredential.authorizationCode
          : null,
    );
    return _signInOrLinkWithCredential(oauthCredential);
  }

  static String _generateNonce([int length = 32]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<SignInResult> _signInOrLinkWithCredential(OAuthCredential cred) async {
    if (currentUser?.isAnonymous == true) {
      try {
        await currentUser!.linkWithCredential(cred);
        await _auth.currentUser?.reload();
        return SignInResult.linked;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          await _auth.signOut();
          try {
            await _auth.signInWithCredential(cred);
            await _auth.currentUser?.reload();
            return SignInResult.signedInToExisting;
          } catch (_) {
            // 既有帳號登入失敗（網路等）：恢復匿名，再拋出讓 UI 顯示錯誤
            await _auth.signInAnonymously();
            rethrow;
          }
        }
        rethrow;
      }
    } else {
      await _auth.signInWithCredential(cred);
      await _auth.currentUser?.reload();
      return SignInResult.signedIn;
    }
  }

  /// 送出重設密碼信。
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter your email',
      );
    }
    await _auth.sendPasswordResetEmail(email: trimmed);
  }

  /// 登出。可選是否再匿名登入（維持 App 可用）。
  Future<void> signOut({bool signInAnonymouslyAfter = true}) async {
    await _auth.signOut();
    if (signInAnonymouslyAfter) {
      await _auth.signInAnonymously();
    }
  }

  /// 將 Firebase Auth 錯誤轉成使用者可讀訊息。
  static String messageFromAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use. Sign in or use another email.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Enable it in Firebase Console: Authentication → Sign-in method.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'credential-already-in-use':
        return 'This email is linked to another account. Use sign in instead.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'sign_in_canceled':
        return 'Canceled';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
