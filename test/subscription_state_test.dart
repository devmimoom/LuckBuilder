import 'package:flutter_test/flutter_test.dart';
import 'package:lucklab/core/services/subscription_backend_service.dart';
import 'package:lucklab/features/subscription/providers/entitlement_provider.dart';
import 'package:lucklab/features/subscription/providers/subscription_ui_provider.dart';

void main() {
  group('Subscription plan catalog', () {
    test('main paywall shows monthly only', () {
      final planIds = kMainPaywallPlans.map((plan) => plan.id).toList();

      expect(planIds, equals(<String>['monthly']));
    });

    test('product id maps back to plan id', () {
      final plan = subscriptionPlanByProductId('lucklab_premium_yearly');

      expect(plan?.id, 'yearly');
    });

    test('legacy product id alias maps back to plan id', () {
      final plan = subscriptionPlanByProductId('luckbuilder.yearly');

      expect(plan?.id, 'yearly');
    });

    test('unknown plan id falls back to monthly', () {
      final plan = subscriptionPlanById('nonexistent');

      expect(plan.id, 'monthly');
    });
  });

  group('Entitlement state getters', () {
    test('cancelled subscription remains switchable while active', () {
      const state = EntitlementState(
        status: EntitlementStatus.cancelled,
        hasAccess: true,
        isLoading: false,
        currentPlanId: 'monthly',
        willRenew: false,
      );

      expect(state.isCancelledButActive, isTrue);
      expect(state.canSwitchPlan, isTrue);
      expect(state.statusLabel, '已取消續訂，權限仍有效');
    });

    test('billing issue implies grace period when access remains', () {
      final state = EntitlementState(
        status: EntitlementStatus.billingIssue,
        hasAccess: true,
        isLoading: false,
        billingIssueDetectedAt: DateTime(2026, 3, 29),
      );

      expect(state.isInGracePeriod, isTrue);
      expect(state.renewalDescription, contains('付款異常'));
    });
  });

  group('Entitlement status resolution', () {
    test('active access without renewal becomes cancelled', () {
      final status = resolveEntitlementStatus(
        hasAccess: true,
        willRenew: false,
        unsubscribeDetectedAt: null,
        billingIssueDetectedAt: null,
      );

      expect(status, EntitlementStatus.cancelled);
    });

    test('billing issue takes precedence over cancellation', () {
      final status = resolveEntitlementStatus(
        hasAccess: true,
        willRenew: false,
        unsubscribeDetectedAt: DateTime(2026, 3, 29),
        billingIssueDetectedAt: DateTime(2026, 3, 30),
      );

      expect(status, EntitlementStatus.billingIssue);
    });
  });

  group('Effective entitlement state', () {
    test('logged-in users wait for backend verification', () {
      const baseState = EntitlementState(
        status: EntitlementStatus.active,
        hasAccess: true,
        isLoading: false,
      );

      final state = resolveEffectiveEntitlementState(
        baseState: baseState,
        isLoggedIn: true,
        backendSyncInFlight: true,
        backendStatus: null,
        backendLastError: null,
      );

      expect(state.hasAccess, isFalse);
      expect(state.status, EntitlementStatus.loading);
      expect(state.isBackendVerified, isFalse);
      expect(state.isLoading, isTrue);
    });

    test('verified backend status overrides local SDK state', () {
      const baseState = EntitlementState(
        status: EntitlementStatus.expired,
        hasAccess: false,
        isLoading: false,
      );
      final backendStatus = BackendSubscriptionStatus(
        hasAccess: true,
        willRenew: true,
        currentProductId: 'lucklab_premium_yearly',
        currentPlanId: 'yearly',
        updatedAt: DateTime(2026, 3, 30),
      );

      final state = resolveEffectiveEntitlementState(
        baseState: baseState,
        isLoggedIn: true,
        backendSyncInFlight: false,
        backendStatus: backendStatus,
        backendLastError: null,
      );

      expect(state.hasAccess, isTrue);
      expect(state.currentPlanId, 'yearly');
      expect(state.isBackendVerified, isTrue);
      expect(state.status, EntitlementStatus.active);
    });

    test('expired backend status clears stale plan details', () {
      const baseState = EntitlementState(
        status: EntitlementStatus.active,
        hasAccess: true,
        isLoading: false,
        currentProductId: 'lucklab_premium_yearly',
        currentPlanId: 'yearly',
        pendingChanges: [
          PendingSubscriptionChange(
            productId: 'lucklab_premium_monthly',
            planId: 'monthly',
          ),
        ],
      );
      final backendStatus = BackendSubscriptionStatus(
        hasAccess: false,
        willRenew: false,
        currentProductId: 'lucklab_premium_yearly',
        currentPlanId: 'yearly',
        pendingChanges: const [
          PendingSubscriptionChange(
            productId: 'lucklab_premium_monthly',
            planId: 'monthly',
          ),
        ],
        updatedAt: DateTime(2026, 3, 31),
      );

      final state = resolveEffectiveEntitlementState(
        baseState: baseState,
        isLoggedIn: true,
        backendSyncInFlight: false,
        backendStatus: backendStatus,
        backendLastError: null,
      );

      expect(state.hasAccess, isFalse);
      expect(state.currentPlanId, isNull);
      expect(state.currentProductId, isNull);
      expect(state.pendingChanges, isEmpty);
      expect(state.status, EntitlementStatus.expired);
    });

    test('user switch clears stale localHasAccess before backend verifies', () {
      // Simulates: user A (subscribed) logs out, user B logs in.
      // _baseState is reset to initial before backend sync completes.
      const freshBase = EntitlementState(
        status: EntitlementStatus.loading,
        hasAccess: false,
        isLoading: true,
      );

      // Backend not yet verified (sync in flight)
      final state = resolveEffectiveEntitlementState(
        baseState: freshBase,
        isLoggedIn: true,
        backendSyncInFlight: true,
        backendStatus: null,
        backendLastError: null,
      );

      expect(state.hasAccess, isFalse);
      expect(state.localHasAccess, isFalse);
      expect(state.isBackendVerified, isFalse);
      expect(state.status, EntitlementStatus.loading);
    });
  });
}
