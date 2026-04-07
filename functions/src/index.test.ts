import test from "node:test";
import assert from "node:assert/strict";

import {
  buildStatusFromEvent,
  buildStatusFromSubscriber,
  planIdFromProductId,
  primaryUidFor,
  resolveCurrentSubscriptionSnapshot,
  resolveCurrentSubscriptionSnapshotFromEvent,
  resolveEntitlementActive,
  resolveWillRenew,
} from "./revenuecat_helpers.js";

test("primaryUidFor prefers app user id over aliases", () => {
  const uid = primaryUidFor({
    app_user_id: "firebase_uid",
    original_app_user_id: "original_uid",
    aliases: ["alias_uid"],
    transferred_to: ["transfer_uid"],
  });

  assert.equal(uid, "firebase_uid");
});

test("primaryUidFor falls back to transferred target", () => {
  const uid = primaryUidFor({
    app_user_id: " ",
    original_app_user_id: "",
    transferred_to: ["target_uid"],
    aliases: ["alias_uid"],
  });

  assert.equal(uid, "target_uid");
});

test("resolveEntitlementActive treats expiration as inactive", () => {
  assert.equal(
    resolveEntitlementActive({
      type: "EXPIRATION",
      expiration_at_ms: Date.now() + 60_000,
    }),
    false,
  );
});

test("resolveWillRenew keeps billing issue subscriptions renewable", () => {
  const entitlementActive = resolveEntitlementActive({
    type: "BILLING_ISSUE",
    expiration_at_ms: Date.now() + 60_000,
  });

  assert.equal(entitlementActive, true);
  assert.equal(
    resolveWillRenew(
      {
        type: "BILLING_ISSUE",
        expiration_at_ms: Date.now() + 60_000,
      },
      entitlementActive,
    ),
    true,
  );
});

test("planIdFromProductId maps known products", () => {
  assert.equal(planIdFromProductId("lucklab_premium_monthly"), "monthly");
  assert.equal(planIdFromProductId("lucklab_premium_yearly"), "yearly");
  assert.equal(planIdFromProductId("luckbuilder.monthly"), "monthly");
  assert.equal(planIdFromProductId("luckbuilder.yearly"), "yearly");
  assert.equal(planIdFromProductId("unknown_product"), null);
});

test("buildStatusFromEvent keeps current plan on product change", () => {
  const status = buildStatusFromEvent({
    type: "PRODUCT_CHANGE",
    product_id: "lucklab_premium_monthly",
    new_product_id: "lucklab_premium_yearly",
    expiration_at_ms: Date.now() + 60_000,
  });

  assert.equal(status.productId, "lucklab_premium_monthly");
  assert.equal(status.pendingProductId, "lucklab_premium_yearly");
  assert.equal(status.planId, "monthly");
});

test("buildStatusFromSubscriber maps active premium subscription", () => {
  const status = buildStatusFromSubscriber({
    uid: "user_123",
    subscriber: {
      original_app_user_id: "user_123",
      entitlements: {
        premium: {
          product_identifier: "lucklab_premium_yearly",
          purchase_date: "2026-03-29T00:00:00Z",
          expires_date: "2026-04-29T00:00:00Z",
        },
      },
      subscriptions: {
        lucklab_premium_yearly: {
          store: "app_store",
          purchase_date: "2026-03-29T00:00:00Z",
          expires_date: "2026-04-29T00:00:00Z",
          period_type: "normal",
          is_sandbox: true,
        },
      },
    },
    now: new Date("2026-03-30T00:00:00Z"),
  });

  assert.equal(status.entitlementActive, true);
  assert.equal(status.planId, "yearly");
  assert.equal(status.willRenew, true);
  assert.equal(status.environment, "SANDBOX");
});

test("resolveCurrentSubscriptionSnapshot preserves existing current plan before expiry", () => {
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.yearly",
      planId: "yearly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-03-31T08:00:00Z"),
      latestPurchaseAt: new Date("2026-03-31T07:59:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      expirationAt: new Date("2026-03-31T08:05:00Z"),
      latestPurchaseAt: new Date("2026-03-31T07:56:00Z"),
    },
    pendingChangeCount: 1,
    now: new Date("2026-03-31T08:00:00Z"),
  });

  assert.equal(resolved.productId, "luckbuilder.monthly");
  assert.equal(resolved.planId, "monthly");
  assert.equal(
    resolved.expirationAt?.toISOString(),
    "2026-03-31T08:05:00.000Z",
  );
});

test("resolveCurrentSubscriptionSnapshot switches to fetched plan after old expiry", () => {
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.yearly",
      planId: "yearly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-03-31T08:10:00Z"),
      latestPurchaseAt: new Date("2026-03-31T08:09:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      expirationAt: new Date("2026-03-31T08:05:00Z"),
    },
    pendingChangeCount: 1,
    now: new Date("2026-03-31T08:06:00Z"),
  });

  assert.equal(resolved.productId, "luckbuilder.yearly");
  assert.equal(resolved.planId, "yearly");
  assert.equal(
    resolved.expirationAt?.toISOString(),
    "2026-03-31T08:10:00.000Z",
  );
});

test("resolveCurrentSubscriptionSnapshot keeps existing even without pending changes", () => {
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-04-01T00:00:00Z"),
      latestPurchaseAt: new Date("2026-03-31T23:57:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.yearly",
      planId: "yearly",
      willRenew: true,
      expirationAt: new Date("2026-04-01T00:00:31Z"),
      latestPurchaseAt: new Date("2026-03-31T23:50:00Z"),
    },
    pendingChangeCount: 0,
    now: new Date("2026-03-31T23:58:00Z"),
  });

  assert.equal(resolved.productId, "luckbuilder.yearly");
  assert.equal(resolved.planId, "yearly");
  assert.equal(
    resolved.expirationAt?.toISOString(),
    "2026-04-01T00:00:31.000Z",
  );
});

test("resolveCurrentSubscriptionSnapshot switches when existing expired", () => {
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-04-30T00:00:00Z"),
      latestPurchaseAt: new Date("2026-04-01T00:01:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.yearly",
      planId: "yearly",
      willRenew: true,
      expirationAt: new Date("2026-04-01T00:00:31Z"),
    },
    pendingChangeCount: 0,
    now: new Date("2026-04-01T00:02:00Z"),
  });

  assert.equal(resolved.productId, "luckbuilder.monthly");
  assert.equal(resolved.planId, "monthly");
});

test("resolveCurrentSubscriptionSnapshot preserves cancellation signal on same product", () => {
  const unsubscribeDetectedAt = new Date("2026-04-01T00:00:00Z");
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-04-30T00:00:00Z"),
      latestPurchaseAt: new Date("2026-04-01T00:01:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: false,
      expirationAt: new Date("2026-04-30T00:00:00Z"),
      unsubscribeDetectedAt,
    },
    now: new Date("2026-04-10T00:00:00Z"),
    allowSameProductCancellationPreserve: true,
  });

  assert.equal(resolved.productId, "luckbuilder.monthly");
  assert.equal(resolved.willRenew, false);
  assert.equal(resolved.unsubscribeDetectedAt?.toISOString(), unsubscribeDetectedAt.toISOString());
});

test("resolveCurrentSubscriptionSnapshot webhook path trusts fetched on same product", () => {
  const unsubscribeDetectedAt = new Date("2026-04-01T00:00:00Z");
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-04-30T00:00:00Z"),
      latestPurchaseAt: new Date("2026-04-01T00:01:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: false,
      expirationAt: new Date("2026-04-30T00:00:00Z"),
      unsubscribeDetectedAt,
    },
    now: new Date("2026-04-10T00:00:00Z"),
  });

  assert.equal(resolved.willRenew, true);
  assert.equal(resolved.unsubscribeDetectedAt, null);
});

test("resolveCurrentSubscriptionSnapshotFromEvent keeps yearly current before expiry", () => {
  const eventStatus = buildStatusFromEvent({
    type: "PRODUCT_CHANGE",
    product_id: "luckbuilder.monthly",
    expiration_at_ms: new Date("2026-03-31T08:10:00Z").getTime(),
  });

  const resolved = resolveCurrentSubscriptionSnapshotFromEvent({
    event: {
      type: "PRODUCT_CHANGE",
      product_id: "luckbuilder.monthly",
      period_type: "normal",
      store: "app_store",
      environment: "SANDBOX",
      expiration_at_ms: new Date("2026-03-31T08:10:00Z").getTime(),
    },
    eventStatus,
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.yearly",
      planId: "yearly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-03-31T08:20:00Z"),
      latestPurchaseAt: new Date("2026-03-31T07:56:00Z"),
    },
    pendingChangeCount: 1,
    now: new Date("2026-03-31T08:00:00Z"),
  });

  assert.equal(resolved.productId, "luckbuilder.yearly");
  assert.equal(resolved.planId, "yearly");
  assert.equal(
    resolved.expirationAt?.toISOString(),
    "2026-03-31T08:20:00.000Z",
  );
});

test("resolveCurrentSubscriptionSnapshot uses fetched willRenew when keeping existing", () => {
  const resolved = resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: true,
      productId: "luckbuilder.monthly",
      planId: "monthly",
      willRenew: true,
      store: "app_store",
      environment: "SANDBOX",
      periodType: "normal",
      expirationAt: new Date("2026-04-01T00:00:00Z"),
      latestPurchaseAt: new Date("2026-03-31T23:57:00Z"),
      billingIssueDetectedAt: null,
      unsubscribeDetectedAt: null,
    },
    existingStatus: {
      entitlementActive: true,
      productId: "luckbuilder.yearly",
      planId: "yearly",
      willRenew: false,
      expirationAt: new Date("2026-04-01T00:00:31Z"),
      unsubscribeDetectedAt: new Date("2026-03-30T00:00:00Z"),
    },
    now: new Date("2026-03-31T23:58:00Z"),
  });

  assert.equal(resolved.productId, "luckbuilder.yearly");
  assert.equal(resolved.willRenew, true);
  assert.equal(resolved.unsubscribeDetectedAt, null);
});

test("resolveWillRenew returns true for PRODUCT_CHANGE", () => {
  const active = resolveEntitlementActive({
    type: "PRODUCT_CHANGE",
    expiration_at_ms: Date.now() + 60_000,
  });
  assert.equal(active, true);
  assert.equal(
    resolveWillRenew({ type: "PRODUCT_CHANGE", expiration_at_ms: Date.now() + 60_000 }, active),
    true,
  );
});

test("resolveWillRenew returns true for RENEWAL", () => {
  const active = resolveEntitlementActive({
    type: "RENEWAL",
    expiration_at_ms: Date.now() + 60_000,
  });
  assert.equal(active, true);
  assert.equal(
    resolveWillRenew({ type: "RENEWAL", expiration_at_ms: Date.now() + 60_000 }, active),
    true,
  );
});

test("resolveWillRenew returns false for CANCELLATION", () => {
  const active = resolveEntitlementActive({
    type: "CANCELLATION",
    expiration_at_ms: Date.now() + 60_000,
  });
  assert.equal(active, true);
  assert.equal(
    resolveWillRenew({ type: "CANCELLATION" }, active),
    false,
  );
});
