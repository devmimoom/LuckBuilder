import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_gate_page.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/subscription/presentation/subscription_page.dart';
import '../../features/subscription/providers/entitlement_provider.dart';
import '../../features/subscription/providers/feature_trial_provider.dart';
import 'app_ux.dart';

abstract final class PaywallGate {
  static Future<bool> guardFeatureAccess(
    BuildContext context,
    WidgetRef ref,
    TrialFeature feature,
  ) async {
    final authNotifier = ref.read(authSessionProvider.notifier);
    await authNotifier.ensureLoaded();
    if (!context.mounted) return false;
    if (!ref.read(authSessionProvider).isLoggedIn) {
      final loginResult = await Navigator.of(context).push<bool>(
        AppUX.fadeRoute(const LoginGatePage()),
      );
      if (!context.mounted || loginResult != true) {
        return false;
      }
    }

    final entitlementNotifier = ref.read(entitlementProvider.notifier);
    await entitlementNotifier.ensureFreshBackendVerification();
    if (!context.mounted) return false;
    final entitlement = ref.read(entitlementProvider);
    if (entitlement.isBackendVerified && entitlement.hasAccess) {
      return true;
    }
    if (!entitlement.isBackendVerified && entitlement.localHasAccess) {
      return true;
    }
    if (entitlement.isLoading) {
      AppUX.showSnackBar(context, '正在驗證訂閱狀態，請稍後再試');
      return false;
    }

    final canUse = await ref.read(featureTrialProvider.notifier).canUse(feature);
    if (canUse) {
      return true;
    }

    if (!context.mounted) return false;
    AppUX.showSnackBar(
      context,
      '${feature.label}的免費體驗次數已用完，訂閱後可不限次使用',
    );
    Navigator.of(context).push(
      AppUX.fadeRoute(const SubscriptionPage()),
    );
    return false;
  }

  static Future<bool> consumeTrialIfNeeded(
    BuildContext context,
    WidgetRef ref,
    TrialFeature feature,
  ) async {
    final authNotifier = ref.read(authSessionProvider.notifier);
    await authNotifier.ensureLoaded();
    if (!context.mounted) return false;
    if (!ref.read(authSessionProvider).isLoggedIn) {
      final loginResult = await Navigator.of(context).push<bool>(
        AppUX.fadeRoute(const LoginGatePage()),
      );
      if (!context.mounted || loginResult != true) {
        return false;
      }
    }

    final entitlementNotifier = ref.read(entitlementProvider.notifier);
    await entitlementNotifier.ensureFreshBackendVerification();
    if (!context.mounted) return false;
    final entitlement = ref.read(entitlementProvider);
    if (entitlement.isBackendVerified && entitlement.hasAccess) {
      return true;
    }
    if (!entitlement.isBackendVerified && entitlement.localHasAccess) {
      return true;
    }
    if (entitlement.isLoading) {
      AppUX.showSnackBar(context, '正在驗證訂閱狀態，請稍後再試');
      return false;
    }

    final consumed =
        await ref.read(featureTrialProvider.notifier).consume(feature);
    if (consumed) {
      return true;
    }

    if (!context.mounted) return false;
    AppUX.showSnackBar(
      context,
      '${feature.label}的免費體驗次數已用完，訂閱後可不限次使用',
    );
    Navigator.of(context).push(
      AppUX.fadeRoute(const SubscriptionPage()),
    );
    return false;
  }
}
