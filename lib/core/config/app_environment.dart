/// 執行期設定：優先使用編譯期 `--dart-define` / `--dart-define-from-file`，
/// 避免把 `.env` 打進 App 資產。
///
/// 本機開發：
/// ```bash
/// flutter run --dart-define-from-file=.env
/// ```
///
/// Release 建置（範例）：
/// ```bash
/// flutter build ipa --dart-define-from-file=.env
/// ```
///
/// 或單獨注入：
/// ```bash
/// flutter build ipa --dart-define=GEMINI_API_KEY=你的金鑰
/// ```
class AppEnvironment {
  AppEnvironment._();

  static const String _empty = '';

  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: _empty);

  static String get geminiSolveModelMath =>
      const String.fromEnvironment('GEMINI_SOLVE_MODEL_MATH', defaultValue: _empty)
          .trim();

  static String get geminiSolveModelMathWithImage =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_MODEL_MATH_WITH_IMAGE',
        defaultValue: _empty,
      ).trim();

  static String get geminiSolveModelGeometryWithImage =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_MODEL_GEOMETRY_WITH_IMAGE',
        defaultValue: _empty,
      ).trim();

  static String get geminiSolveAlwaysAttachImage =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE',
        defaultValue: _empty,
      ).trim();

  static String get geminiSolveAlwaysAttachImageForMath =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_ALWAYS_ATTACH_IMAGE_FOR_MATH',
        defaultValue: _empty,
      ).trim();

  static String get geminiSolveOmitImageWhenTextComplete =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_OMIT_IMAGE_WHEN_TEXT_COMPLETE',
        defaultValue: _empty,
      ).trim();

  static String get geminiSolveValidateMathWithImage =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_VALIDATE_MATH_WITH_IMAGE',
        defaultValue: _empty,
      ).trim();

  static String get geminiSolveValidationModel =>
      const String.fromEnvironment(
        'GEMINI_SOLVE_VALIDATION_MODEL',
        defaultValue: _empty,
      ).trim();

  static String get revenuecatIosApiKey =>
      const String.fromEnvironment(
        'REVENUECAT_IOS_API_KEY',
        defaultValue: _empty,
      ).trim();

  static String get revenuecatAndroidApiKey =>
      const String.fromEnvironment(
        'REVENUECAT_ANDROID_API_KEY',
        defaultValue: _empty,
      ).trim();

  /// 未設定時與原本 `dotenv` fallback 一致。
  static String get revenuecatEntitlementId =>
      const String.fromEnvironment(
        'REVENUECAT_ENTITLEMENT_ID',
        defaultValue: _empty,
      ).trim();

  static String get mathOcrProvider =>
      const String.fromEnvironment(
        'MATH_OCR_PROVIDER',
        defaultValue: 'auto',
      ).trim();

  static String get mathpixAppId =>
      const String.fromEnvironment('MATHPIX_APP_ID', defaultValue: _empty).trim();

  static String get mathpixAppKey =>
      const String.fromEnvironment('MATHPIX_APP_KEY', defaultValue: _empty).trim();
}
