import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// 額度包 IAP：RevenueCat 購買 credits_1 / credits_3 / credits_10，成功後由 caller 呼叫 CreditsRepo.addCredits
/// 在 RevenueCat Dashboard 建立對應 Product ID。
/// 生產環境：到 https://app.revenuecat.com → Project → API Keys → 複製 Apple Public API Key 貼到下方。
const String _revenueCatAppleApiKey = 'appl_dZHavXTVfYphPHBbWqmWItspNOI'; // 生產環境：貼上 RevenueCat Apple Public API Key（非 test_ 開頭）

const Map<String, int> _productIdToCredits = {
  'credits_1': 1,
  'credits_3': 3,
  'credits_10': 10,
};

int creditsForProductId(String productId) =>
    _productIdToCredits[productId] ?? 0;

class CreditsIAPService {
  static bool _configured = false;

  static Future<void> configure(String? appUserId) async {
    if (_revenueCatAppleApiKey.isEmpty) return;
    if (_configured) return;
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    final config = PurchasesConfiguration(_revenueCatAppleApiKey);
    if (appUserId != null && appUserId.isNotEmpty) {
      config.appUserID = appUserId;
    }
    await Purchases.configure(config);
    _configured = true;
    if (kDebugMode) {
      debugPrint('[IAP] RevenueCat configured, appUserId=$appUserId');
    }
  }

  static Future<void> logIn(String appUserId) async {
    if (!_configured) return;
    await Purchases.logIn(appUserId);
  }

  /// 取得額度包產品列表（用於商店 UI）
  static Future<List<StoreProduct>> getCreditProducts() async {
    if (!_configured) {
      if (kDebugMode) debugPrint('[IAP] getCreditProducts: not configured!');
      return [];
    }
    try {
      final ids = _productIdToCredits.keys.toList();
      if (kDebugMode) debugPrint('[IAP] Fetching products: $ids');
      final products = await Purchases.getProducts(ids);
      if (kDebugMode) {
        debugPrint('[IAP] Got ${products.length} products:');
        for (final p in products) {
          debugPrint('  - ${p.identifier}: ${p.priceString} (price=${p.price})');
        }
      }
      return products;
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] getCreditProducts error: $e');
      return [];
    }
  }

  /// 購買指定產品，成功回傳獲得額度數；失敗拋錯
  static Future<int> purchase(StoreProduct product) async {
    if (kDebugMode) {
      debugPrint('[IAP] purchase start: ${product.identifier}');
    }
    try {
      final customerInfo = await Purchases.purchaseStoreProduct(product);
      if (kDebugMode) {
        debugPrint('[IAP] purchase SUCCESS: ${product.identifier}');
        debugPrint('[IAP] customerInfo entitlements: ${customerInfo.entitlements.active.keys}');
      }
      final credits = creditsForProductId(product.identifier);
      if (kDebugMode) {
        debugPrint('[IAP] credits mapped: $credits (from ${product.identifier})');
      }
      return credits;
    } on PlatformException catch (e) {
      // 檢查是否為用戶取消
      final userCancelled = e.details is Map
          ? (e.details as Map)['userCancelled'] == true
          : false;
      if (kDebugMode) {
        debugPrint('[IAP] purchase PlatformException:');
        debugPrint('  code: ${e.code}');
        debugPrint('  message: ${e.message}');
        debugPrint('  details: ${e.details}');
        debugPrint('  userCancelled: $userCancelled');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] purchase error: $e');
        debugPrint('[IAP] error type: ${e.runtimeType}');
      }
      rethrow;
    }
  }
}
