import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/latex_helper.dart';
import 'gemini_service.dart' hide debugPrint;

const bool _enableVerboseMathOcrLogs =
    bool.fromEnvironment('LB_VERBOSE_MATH_OCR_LOGS', defaultValue: false);

void _logMathOcr(String? message, {int? wrapWidth}) {
  if (!foundation.kDebugMode || !_enableVerboseMathOcrLogs) return;
  foundation.debugPrint(message, wrapWidth: wrapWidth);
}

enum MathOcrBackend { auto, mathpix, gemini }

class MathOcrService {
  static final MathOcrService _instance = MathOcrService._();
  factory MathOcrService() => _instance;
  MathOcrService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ),
  );

  String get _providerSetting =>
      dotenv.get('MATH_OCR_PROVIDER', fallback: 'auto').trim().toLowerCase();

  String get _mathpixAppId => dotenv.get('MATHPIX_APP_ID', fallback: '').trim();

  String get _mathpixAppKey =>
      dotenv.get('MATHPIX_APP_KEY', fallback: '').trim();

  bool get _hasMathpixConfig =>
      _mathpixAppId.isNotEmpty && _mathpixAppKey.isNotEmpty;

  Future<String?> recognizeImage(File imageFile) async {
    final backends = _resolveBackends();

    for (final backend in backends) {
      final result = await switch (backend) {
        MathOcrBackend.mathpix => _recognizeWithMathpix(imageFile),
        MathOcrBackend.gemini => _recognizeWithGemini(imageFile),
        MathOcrBackend.auto => _recognizeWithGemini(imageFile),
      };

      final normalized = _normalizeResult(result);
      if (normalized != null) {
        _logMathOcr('✅ OCR 成功，來源: ${backend.name}');
        return normalized;
      }
    }

    _logMathOcr('❌ 所有 OCR backend 都失敗');
    return null;
  }

  List<MathOcrBackend> _resolveBackends() {
    final configured = switch (_providerSetting) {
      'mathpix' => MathOcrBackend.mathpix,
      'gemini' => MathOcrBackend.gemini,
      _ => MathOcrBackend.auto,
    };

    switch (configured) {
      case MathOcrBackend.mathpix:
        return _hasMathpixConfig
            ? const [MathOcrBackend.mathpix, MathOcrBackend.gemini]
            : const [MathOcrBackend.gemini];
      case MathOcrBackend.gemini:
        return const [MathOcrBackend.gemini];
      case MathOcrBackend.auto:
        return _hasMathpixConfig
            ? const [MathOcrBackend.mathpix, MathOcrBackend.gemini]
            : const [MathOcrBackend.gemini];
    }
  }

  Future<String?> _recognizeWithGemini(File imageFile) {
    _logMathOcr('🔁 使用 Gemini OCR');
    return GeminiService().recognizeImage(imageFile);
  }

  Future<String?> _recognizeWithMathpix(File imageFile) async {
    if (!_hasMathpixConfig) {
      _logMathOcr('⚠️ Mathpix 未設定，跳過');
      return null;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(imageBytes);

      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.mathpix.com/v3/latex',
        data: <String, dynamic>{
          'src': 'data:image/jpeg;base64,$imageBase64',
          'ocr': ['math', 'text'],
          'formats': ['text', 'latex_styled'],
          'skip_recrop': false,
        },
        options: Options(
          headers: <String, String>{
            'app_id': _mathpixAppId,
            'app_key': _mathpixAppKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        _logMathOcr('⚠️ Mathpix 回傳空內容');
        return null;
      }

      final candidates = <String?>[
        data['text']?.toString(),
        data['latex_styled']?.toString(),
        data['latex_normal']?.toString(),
        data['latex']?.toString(),
      ];

      for (final candidate in candidates) {
        final normalized = _normalizeResult(candidate);
        if (normalized != null) {
          return normalized;
        }
      }

      _logMathOcr('⚠️ Mathpix 沒有可用辨識結果: ${data.keys.toList()}');
      return null;
    } catch (e) {
      _logMathOcr('❌ Mathpix OCR 失敗: $e');
      return null;
    }
  }

  String? _normalizeResult(String? rawText) {
    if (rawText == null || rawText.trim().isEmpty) return null;
    final normalized = LatexHelper.normalizeModelText(
      rawText,
      preserveLineBreaks: true,
    );
    return normalized.isEmpty ? null : normalized;
  }
}
