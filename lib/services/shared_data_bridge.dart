import 'dart:io';
import 'package:flutter/services.dart';

/// 與 iOS App Groups 同步（Extension「已讀完成」寫入，主 App 讀取）
class SharedDataBridge {
  static const MethodChannel _channel = MethodChannel('com.onepop.shared_data');

  /// 是否已在 Extension 中標記為已讀完成
  static Future<bool> isCompleted(String itemId) async {
    if (!Platform.isIOS) return false;
    try {
      final r = await _channel.invokeMethod<bool>('isCompleted', {'itemId': itemId});
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 今日在 Extension 中完成的所有 itemId
  static Future<List<String>> getTodayCompleted() async {
    if (!Platform.isIOS) return [];
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('getTodayCompleted');
      if (list == null) return [];
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// 刪除 7 天前的 completed 資料
  static Future<void> cleanupOldData() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('cleanupOldData');
    } catch (_) {}
  }
}
