import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_environment.dart';
import '../utils/subscription_debug.dart';

const bool _enableVerboseRevenueCatNativeLogs = bool.fromEnvironment(
  'LB_VERBOSE_REVENUECAT_NATIVE_LOGS',
  defaultValue: false,
);

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const Duration _configureTimeout = Duration(seconds: 12);
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<void>? _configureFuture;

  String _lastKnownAppUserId = '';

  String? get lastKnownAppUserId {
    final trimmed = _lastKnownAppUserId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _log(String message) => subscriptionDebugLog('RevenueCat', message);

  /// 未設定 API Key 或尚未成功 [Purchases.configure] 時，不可呼叫任何 Purchases 原生方法（會 iOS fatal）。
  Future<void> _requirePurchasesReady(String operation) async {
    await configure();
    if (_apiKey.isEmpty || !await Purchases.isConfigured) {
      _log('$operation:skipped purchases_not_configured');
      throw StateError('RevenueCat 未設定或未完成初始化');
    }
  }

  Future<void> configure() async {
    _configureFuture ??= _configureInternal().timeout(
      _configureTimeout,
      onTimeout: () => throw TimeoutException('RevenueCat 初始化逾時'),
    );
    try {
      await _configureFuture;
    } catch (_) {
      _configureFuture = null;
      rethrow;
    }
  }

  Future<void> _configureInternal() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (await Purchases.isConfigured) {
        _lastKnownAppUserId = await Purchases.appUserID;
        _log('configure:already_configured appUserId=$_lastKnownAppUserId');
        return;
      }

      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        debugPrint('⚠️ RevenueCat API Key 未設定，略過初始化');
        _log('configure:skipped missing_api_key');
        return;
      }

      // RevenueCat / StoreKit debug logs may include very long signed transaction
      // payloads. Keep SDK-native logs quiet by default and rely on our own
      // structured subscription logs instead.
      await Purchases.setLogLevel(
        _enableVerboseRevenueCatNativeLogs && !kReleaseMode
            ? LogLevel.debug
            : LogLevel.warn,
      );
      _log('configure:start platform=${Platform.operatingSystem}');
      await Purchases.configure(PurchasesConfiguration(apiKey)).timeout(
        _configureTimeout,
        onTimeout: () => throw TimeoutException('RevenueCat 設定逾時'),
      );
      _lastKnownAppUserId = await Purchases.appUserID;
      debugPrint('✅ RevenueCat 初始化完成');
      _log(
        'configure:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'appUserId=$_lastKnownAppUserId',
      );
    } catch (e) {
      debugPrint('❌ RevenueCat 初始化失敗: $e');
      _log('configure:error elapsedMs=${stopwatch.elapsedMilliseconds} error=$e');
      rethrow;
    }
  }

  Future<void> syncAppUser({
    required String? uid,
    String? email,
    String? displayName,
  }) async {
    final stopwatch = Stopwatch()..start();
    await configure();
    if (_apiKey.isEmpty || !await Purchases.isConfigured) {
      _log('syncAppUser:skipped configured=false uid=${uid ?? "null"}');
      return;
    }

    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) {
      final isAnonymous = await Purchases.isAnonymous;
      if (isAnonymous) {
        _lastKnownAppUserId = await Purchases.appUserID;
        _log(
          'syncAppUser:anonymous elapsedMs=${stopwatch.elapsedMilliseconds} '
          'appUserId=$_lastKnownAppUserId',
        );
        return;
      }

      final customerInfo = await Purchases.logOut();
      _lastKnownAppUserId = customerInfo.originalAppUserId;
      _log(
        'syncAppUser:logout elapsedMs=${stopwatch.elapsedMilliseconds} '
        'appUserId=$_lastKnownAppUserId',
      );
      return;
    }

    final currentAppUserId = await Purchases.appUserID;
    if (currentAppUserId != normalizedUid) {
      final result = await Purchases.logIn(normalizedUid);
      _lastKnownAppUserId = result.customerInfo.originalAppUserId;
    } else {
      _lastKnownAppUserId = currentAppUserId;
    }

    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      await Purchases.setEmail(trimmedEmail);
    }

    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      await Purchases.setDisplayName(trimmedName);
    }
    _log(
      'syncAppUser:success elapsedMs=${stopwatch.elapsedMilliseconds} '
      'uid=$normalizedUid currentAppUserId=$currentAppUserId '
      'lastKnownAppUserId=$_lastKnownAppUserId',
    );
  }

  Future<CustomerInfo> getCustomerInfo({bool invalidateCache = false}) async {
    final stopwatch = Stopwatch()..start();
    _log('getCustomerInfo:start invalidateCache=$invalidateCache');
    await _requirePurchasesReady('getCustomerInfo');
    try {
      if (invalidateCache) {
        await Purchases.invalidateCustomerInfoCache().timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException('RevenueCat 快取更新逾時'),
        );
      }
      final customerInfo = await Purchases.getCustomerInfo().timeout(
        _requestTimeout,
        onTimeout: () => throw TimeoutException('讀取訂閱資訊逾時'),
      );
      _lastKnownAppUserId = await Purchases.appUserID;
      _log(
        'getCustomerInfo:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'appUserId=$_lastKnownAppUserId '
        'activeEntitlements=${customerInfo.entitlements.active.keys.join(",")}',
      );
      return customerInfo;
    } catch (e) {
      _log(
        'getCustomerInfo:error elapsedMs=${stopwatch.elapsedMilliseconds} '
        'error=$e',
      );
      rethrow;
    }
  }

  Future<Offerings> getOfferings() async {
    final stopwatch = Stopwatch()..start();
    _log('getOfferings:start');
    await _requirePurchasesReady('getOfferings');
    try {
      final offerings = await Purchases.getOfferings().timeout(
        _requestTimeout,
        onTimeout: () => throw TimeoutException('載入訂閱方案逾時'),
      );
      _log(
        'getOfferings:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'current=${offerings.current?.identifier ?? "null"} '
        'packageCount=${offerings.current?.availablePackages.length ?? 0}',
      );
      return offerings;
    } catch (e) {
      _log('getOfferings:error elapsedMs=${stopwatch.elapsedMilliseconds} error=$e');
      rethrow;
    }
  }

  Future<PurchaseResult> purchasePackage(Package package) async {
    final stopwatch = Stopwatch()..start();
    await _requirePurchasesReady('purchasePackage');
    _log(
      'purchase:start packageId=${package.identifier} '
      'productId=${package.storeProduct.identifier}',
    );
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _log(
        'purchase:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'packageId=${package.identifier}',
      );
      return result;
    } catch (e) {
      _log(
        'purchase:error elapsedMs=${stopwatch.elapsedMilliseconds} '
        'packageId=${package.identifier} error=$e',
      );
      rethrow;
    }
  }

  Future<CustomerInfo> restorePurchases() async {
    final stopwatch = Stopwatch()..start();
    await _requirePurchasesReady('restorePurchases');
    _log('restore:start');
    try {
      final customerInfo = await Purchases.restorePurchases();
      _log(
        'restore:success elapsedMs=${stopwatch.elapsedMilliseconds} '
        'activeEntitlements=${customerInfo.entitlements.active.keys.join(",")}',
      );
      return customerInfo;
    } catch (e) {
      _log('restore:error elapsedMs=${stopwatch.elapsedMilliseconds} error=$e');
      rethrow;
    }
  }

  Future<String> currentAppUserId() async {
    await configure();
    if (_apiKey.isEmpty || !await Purchases.isConfigured) {
      return '';
    }
    _lastKnownAppUserId = await Purchases.appUserID;
    return _lastKnownAppUserId;
  }

  String get _apiKey {
    final iosKey = AppEnvironment.revenuecatIosApiKey;
    final androidKey = AppEnvironment.revenuecatAndroidApiKey;
    if (Platform.isIOS) return iosKey;
    if (Platform.isAndroid) return androidKey;
    return '';
  }
}
