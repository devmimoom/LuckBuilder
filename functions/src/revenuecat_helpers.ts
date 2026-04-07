export type RevenueCatEventType =
  | "TEST"
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "CANCELLATION"
  | "UNCANCELLATION"
  | "EXPIRATION"
  | "BILLING_ISSUE"
  | "PRODUCT_CHANGE"
  | "TRANSFER"
  | "SUBSCRIPTION_EXTENDED"
  | "TEMPORARY_ENTITLEMENT_GRANT";

export type RevenueCatEvent = {
  id?: string;
  type?: RevenueCatEventType;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  transferred_from?: string[];
  transferred_to?: string[];
  entitlement_ids?: string[] | null;
  product_id?: string;
  new_product_id?: string;
  store?: string;
  environment?: string;
  period_type?: string;
  purchased_at_ms?: number;
  expiration_at_ms?: number;
  grace_period_expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
  cancel_reason?: string;
  expiration_reason?: string;
  original_transaction_id?: string;
  transaction_id?: string;
};

export type RevenueCatSubscriberEntitlement = {
  product_identifier?: string | null;
  purchase_date?: string | null;
  expires_date?: string | null;
};

export type RevenueCatSubscriberSubscription = {
  store?: string | null;
  purchase_date?: string | null;
  expires_date?: string | null;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
  period_type?: string | null;
  is_sandbox?: boolean | null;
};

export type RevenueCatSubscriber = {
  original_app_user_id?: string | null;
  entitlements?: Record<string, RevenueCatSubscriberEntitlement> | null;
  subscriptions?: Record<string, RevenueCatSubscriberSubscription> | null;
};

export type SubscriptionStatusCoreSnapshot = {
  entitlementActive: boolean;
  productId: string | null;
  planId: string | null;
  willRenew: boolean;
  store: string | null;
  environment: string | null;
  periodType: string | null;
  expirationAt: Date | null;
  latestPurchaseAt: Date | null;
  billingIssueDetectedAt: Date | null;
  unsubscribeDetectedAt: Date | null;
};

export type SubscriptionStatusSnapshot = {
  uid: string;
  appUserId: string;
  entitlementActive: boolean;
  entitlementIds: string[];
  productId: string | null;
  pendingProductId: null;
  planId: string | null;
  store: string | null;
  environment: string | null;
  willRenew: boolean;
  periodType: string | null;
  expirationAt: Date | null;
  latestPurchaseAt: Date | null;
  billingIssueDetectedAt: Date | null;
  gracePeriodExpirationAt: null;
  latestEventType: string;
  latestEventId: null;
  latestCancelReason: string | null;
  latestExpirationReason: null;
  originalTransactionId: null;
  transactionId: null;
  unsubscribeDetectedAt: Date | null;
};

export type SubscriptionStatusEventSnapshot = {
  entitlementActive: boolean;
  productId: string | null;
  pendingProductId: string | null;
  planId: string | null;
  willRenew: boolean;
  billingIssueDetectedAt: Date | null;
  gracePeriodExpirationAt: Date | null;
  latestEventType: string | null;
  latestEventId: string | null;
  latestCancelReason: string | null;
  latestExpirationReason: string | null;
  originalTransactionId: string | null;
  transactionId: string | null;
  latestPurchaseAt: Date | null;
  expirationAt: Date | null;
  unsubscribeDetectedAt: Date | null;
};

export function resolveCurrentSubscriptionSnapshotFromEvent({
  event,
  eventStatus,
  existingStatus,
  pendingChangeCount,
  now = new Date(),
}: {
  event: RevenueCatEvent;
  eventStatus: SubscriptionStatusEventSnapshot;
  existingStatus?: Partial<SubscriptionStatusCoreSnapshot> | null;
  pendingChangeCount: number;
  now?: Date;
}): SubscriptionStatusCoreSnapshot {
  // RevenueCat PRODUCT_CHANGE payloads are inconsistent across environments:
  // some payloads report `product_id` as the current product, others as the
  // target product. Normalize both forms into the "next" product, then let the
  // existing current snapshot win until the old term actually expires.
  const incomingProductId =
    event.type === "PRODUCT_CHANGE"
      ? (eventStatus.pendingProductId ?? eventStatus.productId)
      : eventStatus.productId;

  return resolveCurrentSubscriptionSnapshot({
    fetchedStatus: {
      entitlementActive: eventStatus.entitlementActive,
      productId: incomingProductId,
      planId: planIdFromProductId(incomingProductId),
      willRenew: eventStatus.willRenew,
      store: event.store ?? null,
      environment: event.environment ?? null,
      periodType: event.period_type ?? null,
      expirationAt: eventStatus.expirationAt,
      latestPurchaseAt: eventStatus.latestPurchaseAt,
      billingIssueDetectedAt: eventStatus.billingIssueDetectedAt,
      unsubscribeDetectedAt: eventStatus.unsubscribeDetectedAt,
    },
    existingStatus,
    pendingChangeCount,
    now,
  });
}

export function resolveCurrentSubscriptionSnapshot({
  fetchedStatus,
  existingStatus,
  now = new Date(),
  /** Only for subscriber API sync: RC can briefly still report willRenew after cancel. */
  allowSameProductCancellationPreserve = false,
}: {
  fetchedStatus: SubscriptionStatusCoreSnapshot;
  existingStatus?: Partial<SubscriptionStatusCoreSnapshot> | null;
  /** @deprecated no longer used — kept for call-site compat */
  pendingChangeCount?: number;
  now?: Date;
  allowSameProductCancellationPreserve?: boolean;
}): SubscriptionStatusCoreSnapshot {
  if (existingStatus?.productId == null || fetchedStatus.productId == null) {
    return fetchedStatus;
  }

  if (
    allowSameProductCancellationPreserve &&
    existingStatus.productId === fetchedStatus.productId
  ) {
    const existingExpirationAt = existingStatus.expirationAt ?? null;
    const shouldPreserveCancellationSignal =
      existingExpirationAt != null &&
      existingExpirationAt.getTime() > now.getTime() &&
      existingStatus.unsubscribeDetectedAt != null &&
      fetchedStatus.unsubscribeDetectedAt == null &&
      fetchedStatus.willRenew;

    if (!shouldPreserveCancellationSignal) {
      return fetchedStatus;
    }

    return {
      ...fetchedStatus,
      willRenew: false,
      unsubscribeDetectedAt: existingStatus.unsubscribeDetectedAt ?? null,
    };
  }

  if (existingStatus.productId === fetchedStatus.productId) {
    return fetchedStatus;
  }

  const existingExpirationAt = existingStatus.expirationAt ?? null;
  if (existingExpirationAt == null || existingExpirationAt.getTime() <= now.getTime()) {
    return fetchedStatus;
  }

  return {
    entitlementActive: existingExpirationAt.getTime() > now.getTime(),
    productId: existingStatus.productId,
    planId: existingStatus.planId ?? planIdFromProductId(existingStatus.productId),
    // Event-driven fields always use the latest signal (fetched), not the
    // stale existing value.  Otherwise a prior CANCELLATION's willRenew=false
    // would persist even after a PRODUCT_CHANGE re-activates renewal.
    willRenew: fetchedStatus.willRenew,
    store: existingStatus.store ?? fetchedStatus.store,
    environment: existingStatus.environment ?? fetchedStatus.environment,
    periodType: existingStatus.periodType ?? fetchedStatus.periodType,
    expirationAt: existingExpirationAt,
    latestPurchaseAt: existingStatus.latestPurchaseAt ?? fetchedStatus.latestPurchaseAt,
    billingIssueDetectedAt: fetchedStatus.billingIssueDetectedAt,
    unsubscribeDetectedAt: fetchedStatus.unsubscribeDetectedAt,
  };
}

export function primaryUidFor(event: RevenueCatEvent): string | null {
  const candidates = [
    event.app_user_id,
    event.original_app_user_id,
    ...(event.transferred_to ?? []),
    ...(event.aliases ?? []),
  ];

  for (const candidate of candidates) {
    const trimmed = candidate?.trim();
    if (trimmed) {
      return trimmed;
    }
  }
  return null;
}

export function resolveEntitlementActive(event: RevenueCatEvent): boolean {
  if (event.type === "EXPIRATION") {
    return false;
  }

  if (event.type === "CANCELLATION" && event.cancel_reason === "CUSTOMER_SUPPORT") {
    return false;
  }

  if (typeof event.expiration_at_ms === "number") {
    return event.expiration_at_ms > Date.now();
  }

  return [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "UNCANCELLATION",
    "PRODUCT_CHANGE",
    "SUBSCRIPTION_EXTENDED",
    "TEMPORARY_ENTITLEMENT_GRANT",
    "BILLING_ISSUE",
    "TRANSFER",
  ].includes(event.type ?? "");
}

export function resolveWillRenew(
  event: RevenueCatEvent,
  entitlementActive: boolean,
): boolean {
  if (!entitlementActive) {
    return false;
  }

  if (event.type === "CANCELLATION") {
    return false;
  }

  if (event.type === "BILLING_ISSUE") {
    return true;
  }

  return [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "UNCANCELLATION",
    "PRODUCT_CHANGE",
    "SUBSCRIPTION_EXTENDED",
    "TEMPORARY_ENTITLEMENT_GRANT",
  ].includes(event.type ?? "");
}

export function planIdFromProductId(productId: string | null): string | null {
  switch (productId) {
    case "lucklab_premium_monthly":
    case "luckbuilder.monthly":
      return "monthly";
    case "lucklab_premium_yearly":
    case "luckbuilder.yearly":
      return "yearly";
    case "lucklab_premium_weekly":
    case "luckbuilder.weekly":
      return "weekly";
    default:
      return null;
  }
}

export function buildStatusFromSubscriber({
  uid,
  subscriber,
  entitlementId = "premium",
  now = new Date(),
}: {
  uid: string;
  subscriber: RevenueCatSubscriber;
  entitlementId?: string;
  now?: Date;
}): SubscriptionStatusSnapshot {
  const entitlement = subscriber.entitlements?.[entitlementId] ?? null;
  const entitlementExpirationAt = parseRevenueCatDate(entitlement?.expires_date);
  const activeSubscription = resolveActiveSubscription(subscriber.subscriptions ?? null, now);
  const productId =
    entitlement?.product_identifier ?? activeSubscription?.productId ?? null;
  const subscription =
    (productId != null ? subscriber.subscriptions?.[productId] : null) ??
    activeSubscription?.subscription ??
    null;
  const unsubscribeDetectedAt = parseRevenueCatDate(
    subscription?.unsubscribe_detected_at,
  );
  const billingIssueDetectedAt = parseRevenueCatDate(
    subscription?.billing_issues_detected_at,
  );
  const expirationAt =
    entitlementExpirationAt ?? parseRevenueCatDate(subscription?.expires_date);
  const latestPurchaseAt =
    parseRevenueCatDate(entitlement?.purchase_date) ??
    parseRevenueCatDate(subscription?.purchase_date);
  const entitlementActive = expirationAt == null ? entitlement != null : expirationAt > now;
  const willRenew =
    entitlementActive &&
    unsubscribeDetectedAt == null &&
    !isExpired(subscription?.expires_date, now);

  const currentSnapshot: SubscriptionStatusCoreSnapshot = {
    entitlementActive,
    productId,
    planId: planIdFromProductId(productId),
    willRenew,
    store: subscription?.store ?? null,
    environment:
      subscription?.is_sandbox == null
        ? null
        : (subscription?.is_sandbox == true ? "SANDBOX" : "PRODUCTION"),
    periodType: subscription?.period_type ?? null,
    expirationAt,
    latestPurchaseAt,
    billingIssueDetectedAt,
    unsubscribeDetectedAt,
  };

  return {
    uid,
    appUserId: subscriber.original_app_user_id?.trim() || uid,
    entitlementActive: currentSnapshot.entitlementActive,
    entitlementIds: entitlement == null ? [] : [entitlementId],
    productId: currentSnapshot.productId,
    pendingProductId: null,
    planId: currentSnapshot.planId,
    store: currentSnapshot.store,
    environment: currentSnapshot.environment,
    willRenew: currentSnapshot.willRenew,
    periodType: currentSnapshot.periodType,
    expirationAt: currentSnapshot.expirationAt,
    latestPurchaseAt: currentSnapshot.latestPurchaseAt,
    billingIssueDetectedAt: currentSnapshot.billingIssueDetectedAt,
    gracePeriodExpirationAt: null,
    latestEventType: "SYNC",
    latestEventId: null,
    latestCancelReason:
      unsubscribeDetectedAt == null ? null : "UNSUBSCRIBE",
    latestExpirationReason: null,
    originalTransactionId: null,
    transactionId: null,
    unsubscribeDetectedAt: currentSnapshot.unsubscribeDetectedAt,
  };
}

export function buildStatusFromEvent(
  event: RevenueCatEvent,
): SubscriptionStatusEventSnapshot {
  const currentProductId = event.product_id ?? null;
  const entitlementActive = resolveEntitlementActive(event);
  const willRenew = resolveWillRenew(event, entitlementActive);
  const unsubscribeDetectedAt =
    event.type === "CANCELLATION" && event.cancel_reason === "UNSUBSCRIBE"
      ? fromMilliseconds(event.event_timestamp_ms)
      : null;

  return {
    entitlementActive,
    productId: currentProductId,
    pendingProductId: event.type === "PRODUCT_CHANGE" ? event.new_product_id ?? null : null,
    planId: planIdFromProductId(currentProductId),
    willRenew,
    billingIssueDetectedAt:
      event.type === "BILLING_ISSUE" ? fromMilliseconds(event.event_timestamp_ms) : null,
    gracePeriodExpirationAt: fromMilliseconds(event.grace_period_expiration_at_ms),
    latestEventType: event.type ?? null,
    latestEventId: event.id ?? null,
    latestCancelReason: event.cancel_reason ?? null,
    latestExpirationReason: event.expiration_reason ?? null,
    originalTransactionId: event.original_transaction_id ?? null,
    transactionId: event.transaction_id ?? null,
    latestPurchaseAt: fromMilliseconds(event.purchased_at_ms),
    expirationAt: fromMilliseconds(event.expiration_at_ms),
    unsubscribeDetectedAt,
  };
}

function resolveActiveSubscription(
  subscriptions: Record<string, RevenueCatSubscriberSubscription> | null,
  now: Date,
): {
  productId: string;
  subscription: RevenueCatSubscriberSubscription;
} | null {
  if (subscriptions == null) {
    return null;
  }

  for (const [productId, subscription] of Object.entries(subscriptions)) {
    if (!isExpired(subscription.expires_date, now)) {
      return { productId, subscription };
    }
  }
  return null;
}

function isExpired(rawDate: string | null | undefined, now: Date): boolean {
  const parsed = parseRevenueCatDate(rawDate);
  if (parsed == null) {
    return false;
  }
  return parsed <= now;
}

function parseRevenueCatDate(rawDate: string | null | undefined): Date | null {
  if (rawDate == null || rawDate.trim().length === 0) {
    return null;
  }
  const parsed = new Date(rawDate);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function fromMilliseconds(value?: number | null): Date | null {
  if (typeof value !== "number") {
    return null;
  }
  return new Date(value);
}
