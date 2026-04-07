import { initializeApp } from "firebase-admin/app";
import {
  FieldValue,
  Firestore,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import * as functions from "firebase-functions/v1";
import { defineSecret } from "firebase-functions/params";
import {
  buildStatusFromSubscriber,
  buildStatusFromEvent,
  planIdFromProductId,
  primaryUidFor,
  resolveCurrentSubscriptionSnapshot,
  resolveCurrentSubscriptionSnapshotFromEvent,
  type SubscriptionStatusCoreSnapshot,
  type RevenueCatEvent,
  type RevenueCatSubscriber,
} from "./revenuecat_helpers.js";

initializeApp();

const revenueCatWebhookAuth = defineSecret("REVENUECAT_WEBHOOK_AUTH");
const revenueCatSecretApiKey = defineSecret("REVENUECAT_SECRET_API_KEY");

type RevenueCatEnvelope = {
  api_version?: string;
  event?: RevenueCatEvent;
};

const db = getFirestore();
const trialStatusCollection = "feature_trial_status";
const defaultTrialQuota = 3;

type TrialFeatureKey =
  | "cameraSolve"
  | "similarPractice"
  | "bannerPromotion";

type TrialStatusSnapshot = {
  uid: string;
  cameraSolveRemaining: number;
  similarPracticeRemaining: number;
  bannerPromotionRemaining: number;
};

type PendingSubscriptionChange = {
  eventId: string | null;
  productId: string;
  planId: string | null;
  requestedAtMs: number | null;
};

type FirestoreSubscriptionStatusDocument = Record<string, unknown> | undefined;

export const syncSubscriptionStatus = onCall(
  {
    region: "asia-east1",
    memory: "256MiB",
    timeoutSeconds: 60,
    secrets: [revenueCatSecretApiKey],
  },
  async (request) => {
    const uid = request.auth?.uid?.trim();
    if (!uid) {
      throw new HttpsError("unauthenticated", "必須先登入才能同步訂閱狀態");
    }

    const secretApiKey = revenueCatSecretApiKey.value().trim();
    if (!secretApiKey) {
      logger.error("REVENUECAT_SECRET_API_KEY is not configured");
      throw new HttpsError("failed-precondition", "訂閱同步金鑰尚未設定");
    }

    const subscriber = await fetchRevenueCatSubscriber(uid, secretApiKey);
    const statusPayload = buildStatusFromSubscriber({
      uid,
      subscriber,
    });
    const existingStatusSnapshot = await db
      .collection("subscription_status")
      .doc(uid)
      .get();
    const existingData = existingStatusSnapshot.data();
    const existingCurrentStatus = subscriptionStatusFromDocument(existingData);
    const existingCurrentProductId = existingCurrentStatus.productId;
    const existingExpirationAt = existingCurrentStatus.expirationAt;
    const existingPendingChanges = normalizePendingChanges(existingData?.pendingChanges);
    const now = new Date();
    const effectiveCurrentStatus = resolveCurrentSubscriptionSnapshot({
      fetchedStatus: coreSubscriptionStatusFromSnapshot(statusPayload),
      existingStatus: existingCurrentStatus,
      pendingChangeCount: existingPendingChanges.length,
      now,
      allowSameProductCancellationPreserve: true,
    });
    const fetchedProductId = statusPayload.productId;
    const keptExisting = effectiveCurrentStatus.productId !== fetchedProductId &&
      fetchedProductId != null;
    let remainingPendingChanges = consumePendingChangesThroughProduct(
      existingPendingChanges,
      effectiveCurrentStatus.productId,
      {
        consumeMatchedEntries:
          existingExpirationAt == null || existingExpirationAt.getTime() <= now.getTime(),
      },
    );
    if (keptExisting && fetchedProductId != null) {
      remainingPendingChanges = appendPendingChange(remainingPendingChanges, {
        eventId: null,
        productId: fetchedProductId,
        planId: planIdFromProductId(fetchedProductId),
        requestedAtMs: null,
      });
    }
    if (!effectiveCurrentStatus.entitlementActive) {
      remainingPendingChanges = [];
    }
    const syncPayload: Record<string, unknown> = {
      uid: statusPayload.uid,
      appUserId: statusPayload.appUserId,
      entitlementActive: effectiveCurrentStatus.entitlementActive,
      entitlementIds: statusPayload.entitlementIds,
      productId: effectiveCurrentStatus.productId,
      planId: effectiveCurrentStatus.planId,
      pendingChanges: pendingChangesToFirestore(remainingPendingChanges),
      store: effectiveCurrentStatus.store,
      environment: effectiveCurrentStatus.environment,
      willRenew: effectiveCurrentStatus.willRenew,
      periodType: effectiveCurrentStatus.periodType,
      expirationAt: timestampFromDate(effectiveCurrentStatus.expirationAt),
      latestPurchaseAt: timestampFromDate(effectiveCurrentStatus.latestPurchaseAt),
      billingIssueDetectedAt: timestampFromDate(
        effectiveCurrentStatus.billingIssueDetectedAt,
      ),
      gracePeriodExpirationAt: timestampFromDate(
        statusPayload.gracePeriodExpirationAt,
      ),
      unsubscribeDetectedAt: timestampFromDate(
        effectiveCurrentStatus.unsubscribeDetectedAt,
      ),
      updatedAt: FieldValue.serverTimestamp(),
    };
    syncPayload.pendingProductId =
      remainingPendingChanges.length === 0
        ? FieldValue.delete()
        : remainingPendingChanges[remainingPendingChanges.length - 1].productId;

    await db.collection("subscription_status").doc(uid).set(
      syncPayload,
      { merge: true },
    );

    logger.info("RevenueCat subscriber synced", {
      uid,
      hasAccess: effectiveCurrentStatus.entitlementActive,
      productId: effectiveCurrentStatus.productId,
    });

    return {
      ok: true,
      hasAccess: effectiveCurrentStatus.entitlementActive,
      planId: effectiveCurrentStatus.planId,
      status: {
        entitlementActive: effectiveCurrentStatus.entitlementActive,
        willRenew: effectiveCurrentStatus.willRenew,
        productId: effectiveCurrentStatus.productId,
        planId: effectiveCurrentStatus.planId,
        pendingChanges: pendingChangesToResponse(remainingPendingChanges),
        expirationAtMs: effectiveCurrentStatus.expirationAt?.getTime() ?? null,
        latestPurchaseAtMs: effectiveCurrentStatus.latestPurchaseAt?.getTime() ?? null,
        unsubscribeDetectedAtMs:
          effectiveCurrentStatus.unsubscribeDetectedAt?.getTime() ?? null,
        billingIssueDetectedAtMs:
          effectiveCurrentStatus.billingIssueDetectedAt?.getTime() ?? null,
        updatedAtMs: Date.now(),
      },
    };
  },
);

export const getTrialStatus = onCall(
  {
    region: "asia-east1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    const uid = request.auth?.uid?.trim();
    if (!uid) {
      throw new HttpsError("unauthenticated", "必須先登入才能取得免費體驗狀態");
    }

    const docRef = db.collection(trialStatusCollection).doc(uid);
    const snapshot = await docRef.get();
    const trialStatus = snapshot.exists
      ? normalizeTrialStatus(uid, snapshot.data())
      : buildDefaultTrialStatus(uid);

    if (!snapshot.exists) {
      await docRef.set({
        ...trialStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      ok: true,
      status: toTrialStatusResponse(trialStatus),
    };
  },
);

export const consumeTrialQuota = onCall(
  {
    region: "asia-east1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    const uid = request.auth?.uid?.trim();
    if (!uid) {
      throw new HttpsError("unauthenticated", "必須先登入才能使用免費體驗");
    }

    const feature = normalizeTrialFeature(request.data?.feature);
    if (feature == null) {
      throw new HttpsError("invalid-argument", "未知的免費體驗功能");
    }

    const docRef = db.collection(trialStatusCollection).doc(uid);
    const result = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(docRef);
      const currentStatus = snapshot.exists
        ? normalizeTrialStatus(uid, snapshot.data())
        : buildDefaultTrialStatus(uid);
      const updatedStatus = decrementTrialQuota(currentStatus, feature);
      const consumed =
        trialRemainingFor(updatedStatus, feature) <
        trialRemainingFor(currentStatus, feature);

      transaction.set(
        docRef,
        {
          ...updatedStatus,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return { consumed, status: updatedStatus };
    });

    return {
      ok: true,
      consumed: result.consumed,
      status: toTrialStatusResponse(result.status),
    };
  },
);

export const revenueCatWebhook = onRequest(
  {
    region: "asia-east1",
    memory: "256MiB",
    timeoutSeconds: 60,
    cors: false,
    secrets: [revenueCatWebhookAuth],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({ error: "method_not_allowed" });
      return;
    }

    if (!isAuthorized(request.header("authorization"))) {
      response.status(401).json({ error: "unauthorized" });
      return;
    }

    const payload = request.body as RevenueCatEnvelope;
    const event = payload?.event;
    if (!event?.type) {
      response.status(400).json({ error: "missing_event_type" });
      return;
    }

    const eventId =
      event.id ??
      `${event.type}_${event.original_transaction_id ?? event.transaction_id ?? Date.now()}`;

    await db.collection("subscription_events").doc(eventId).set({
      id: eventId,
      apiVersion: payload.api_version ?? null,
      type: event.type,
      uid: primaryUidFor(event),
      appUserId: event.app_user_id ?? null,
      originalAppUserId: event.original_app_user_id ?? null,
      aliases: event.aliases ?? [],
      productId: event.product_id ?? null,
      newProductId: event.new_product_id ?? null,
      store: event.store ?? null,
      environment: event.environment ?? null,
      periodType: event.period_type ?? null,
      purchasedAt: timestampFromMs(event.purchased_at_ms),
      expirationAt: timestampFromMs(event.expiration_at_ms),
      eventAt: timestampFromMs(event.event_timestamp_ms),
      cancelReason: event.cancel_reason ?? null,
      expirationReason: event.expiration_reason ?? null,
      transferredFrom: event.transferred_from ?? [],
      transferredTo: event.transferred_to ?? [],
      rawEvent: event,
      createdAt: FieldValue.serverTimestamp(),
    });

    const targetUid = primaryUidFor(event);
    if (targetUid) {
      await writeSubscriptionStatus(db, targetUid, event);
    }

    if (event.type === "TRANSFER") {
      for (const sourceUid of event.transferred_from ?? []) {
        if (!sourceUid || sourceUid === targetUid) {
          continue;
        }
        await db.collection("subscription_status").doc(sourceUid).set(
          {
            uid: sourceUid,
            appUserId: sourceUid,
            latestEventType: "TRANSFER",
            transferredAwayAt: timestampFromMs(event.event_timestamp_ms),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }

    logger.info("RevenueCat webhook processed", {
      id: eventId,
      type: event.type,
      targetUid,
    });

    response.status(200).json({ ok: true, id: eventId });
  },
);

async function writeSubscriptionStatus(
  firestore: Firestore,
  uid: string,
  event: RevenueCatEvent,
): Promise<void> {
  const eventStatus = buildStatusFromEvent(event);
  const docRef = firestore.collection("subscription_status").doc(uid);
  const existingSnapshot = await docRef.get();
  const existingCurrentStatus = subscriptionStatusFromDocument(existingSnapshot.data());
  const existingPendingChanges = normalizePendingChanges(
    existingSnapshot.data()?.pendingChanges,
  );
  let nextPendingChanges = existingPendingChanges;
  const pendingProductIdForChange =
    event.type === "PRODUCT_CHANGE"
      ? (eventStatus.pendingProductId ?? eventStatus.productId)
      : null;

  if (event.type === "PRODUCT_CHANGE" && pendingProductIdForChange != null) {
    nextPendingChanges = appendPendingChange(nextPendingChanges, {
      eventId: eventStatus.latestEventId,
      productId: pendingProductIdForChange,
      planId: planIdFromProductId(pendingProductIdForChange),
      requestedAtMs: event.event_timestamp_ms ?? null,
    });
  } else {
    nextPendingChanges = consumePendingChangesThroughProduct(
      nextPendingChanges,
      eventStatus.productId,
      { consumeMatchedEntries: true },
    );
  }
  if (!eventStatus.entitlementActive) {
    nextPendingChanges = [];
  }
  const effectiveCurrentStatus = resolveCurrentSubscriptionSnapshotFromEvent({
    event,
    eventStatus,
    existingStatus: existingCurrentStatus,
    pendingChangeCount: nextPendingChanges.length,
  });

  const statusPayload: Record<string, unknown> = {
    uid,
    appUserId: event.app_user_id ?? uid,
    entitlementActive: effectiveCurrentStatus.entitlementActive,
    entitlementIds: event.entitlement_ids ?? [],
    productId: effectiveCurrentStatus.productId,
    planId: effectiveCurrentStatus.planId,
    store: effectiveCurrentStatus.store,
    environment: effectiveCurrentStatus.environment,
    willRenew: effectiveCurrentStatus.willRenew,
    periodType: effectiveCurrentStatus.periodType,
    expirationAt: timestampFromDate(effectiveCurrentStatus.expirationAt),
    latestPurchaseAt: timestampFromDate(effectiveCurrentStatus.latestPurchaseAt),
    billingIssueDetectedAt:
      effectiveCurrentStatus.billingIssueDetectedAt != null
        ? timestampFromDate(effectiveCurrentStatus.billingIssueDetectedAt)
        : FieldValue.delete(),
    gracePeriodExpirationAt: timestampFromDate(eventStatus.gracePeriodExpirationAt),
    latestEventType: eventStatus.latestEventType,
    latestEventId: eventStatus.latestEventId,
    latestCancelReason: eventStatus.latestCancelReason,
    latestExpirationReason: eventStatus.latestExpirationReason,
    originalTransactionId: eventStatus.originalTransactionId,
    transactionId: eventStatus.transactionId,
    pendingChanges: pendingChangesToFirestore(nextPendingChanges),
    pendingProductId:
      nextPendingChanges.length === 0
        ? FieldValue.delete()
        : nextPendingChanges[nextPendingChanges.length - 1].productId,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (eventStatus.unsubscribeDetectedAt != null) {
    statusPayload.unsubscribeDetectedAt = timestampFromDate(eventStatus.unsubscribeDetectedAt);
  } else if (eventStatus.willRenew) {
    // Any event that (re-)activates willRenew must clear unsubscribeDetectedAt.
    // Covers: UNCANCELLATION, RENEWAL, PRODUCT_CHANGE, INITIAL_PURCHASE, etc.
    statusPayload.unsubscribeDetectedAt = FieldValue.delete();
  }

  await docRef.set(statusPayload, {
    merge: true,
  });
}

function normalizePendingChanges(value: unknown): PendingSubscriptionChange[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const items: PendingSubscriptionChange[] = [];
  for (const entry of value) {
    if (entry == null || typeof entry !== "object") {
      continue;
    }
    const record = entry as Record<string, unknown>;
    const productId = typeof record.productId === "string" ? record.productId.trim() : "";
    if (!productId) {
      continue;
    }
    items.push({
      eventId: typeof record.eventId === "string" ? record.eventId : null,
      productId,
      planId:
        typeof record.planId === "string"
          ? record.planId
          : planIdFromProductId(productId),
      requestedAtMs: timestampLikeToMillis(record.requestedAt ?? record.requestedAtMs),
    });
  }
  return items;
}

function coreSubscriptionStatusFromSnapshot(
  snapshot: {
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
  },
): SubscriptionStatusCoreSnapshot {
  return {
    entitlementActive: snapshot.entitlementActive,
    productId: snapshot.productId,
    planId: snapshot.planId,
    willRenew: snapshot.willRenew,
    store: snapshot.store,
    environment: snapshot.environment,
    periodType: snapshot.periodType,
    expirationAt: snapshot.expirationAt,
    latestPurchaseAt: snapshot.latestPurchaseAt,
    billingIssueDetectedAt: snapshot.billingIssueDetectedAt,
    unsubscribeDetectedAt: snapshot.unsubscribeDetectedAt,
  };
}

function subscriptionStatusFromDocument(
  data: FirestoreSubscriptionStatusDocument,
): Partial<SubscriptionStatusCoreSnapshot> {
  return {
    entitlementActive: data?.entitlementActive == true,
    productId: typeof data?.productId === "string" ? data.productId : null,
    planId:
      typeof data?.planId === "string"
        ? data.planId
        : planIdFromProductId(typeof data?.productId === "string" ? data.productId : null),
    willRenew: data?.willRenew == true,
    store: typeof data?.store === "string" ? data.store : null,
    environment: typeof data?.environment === "string" ? data.environment : null,
    periodType: typeof data?.periodType === "string" ? data.periodType : null,
    expirationAt: timestampToDate(data?.expirationAt),
    latestPurchaseAt: timestampToDate(data?.latestPurchaseAt),
    billingIssueDetectedAt: timestampToDate(data?.billingIssueDetectedAt),
    unsubscribeDetectedAt: timestampToDate(data?.unsubscribeDetectedAt),
  };
}

function appendPendingChange(
  pendingChanges: PendingSubscriptionChange[],
  change: PendingSubscriptionChange,
): PendingSubscriptionChange[] {
  if (change.productId.trim().length === 0) {
    return pendingChanges;
  }
  if (change.eventId != null && pendingChanges.some((item) => item.eventId === change.eventId)) {
    return pendingChanges;
  }
  const filtered = pendingChanges.filter((item) => item.productId !== change.productId);
  return [...filtered, change];
}

function consumePendingChangesThroughProduct(
  pendingChanges: PendingSubscriptionChange[],
  currentProductId: string | null,
  options: { consumeMatchedEntries: boolean },
): PendingSubscriptionChange[] {
  if (!options.consumeMatchedEntries || currentProductId == null) {
    return pendingChanges;
  }
  let matchedIndex = -1;
  for (let index = pendingChanges.length - 1; index >= 0; index -= 1) {
    if (pendingChanges[index]?.productId === currentProductId) {
      matchedIndex = index;
      break;
    }
  }
  if (matchedIndex < 0) {
    return pendingChanges;
  }
  return pendingChanges.slice(matchedIndex + 1);
}

function pendingChangesToFirestore(
  pendingChanges: PendingSubscriptionChange[],
): Array<Record<string, unknown>> {
  return pendingChanges.map((change) => ({
    eventId: change.eventId,
    productId: change.productId,
    planId: change.planId,
    requestedAt: timestampFromMs(change.requestedAtMs),
  }));
}

function pendingChangesToResponse(
  pendingChanges: PendingSubscriptionChange[],
): Array<Record<string, unknown>> {
  return pendingChanges.map((change) => ({
    eventId: change.eventId,
    productId: change.productId,
    planId: change.planId,
    requestedAtMs: change.requestedAtMs,
  }));
}

async function fetchRevenueCatSubscriber(
  appUserId: string,
  secretApiKey: string,
): Promise<RevenueCatSubscriber> {
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${secretApiKey}`,
        Accept: "application/json",
      },
    },
  );

  if (!response.ok) {
    const detail = await response.text();
    logger.error("RevenueCat subscriber fetch failed", {
      appUserId,
      status: response.status,
      detail,
    });
    throw new HttpsError("internal", "無法向 RevenueCat 同步訂閱狀態");
  }

  const payload = (await response.json()) as {
    subscriber?: RevenueCatSubscriber;
  };
  return payload.subscriber ?? {};
}

function timestampFromMs(value?: number | null): Timestamp | null {
  if (typeof value !== "number") {
    return null;
  }
  return Timestamp.fromMillis(value);
}

function timestampToDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  return null;
}

function timestampFromDate(value: Date | null): Timestamp | null {
  if (value == null) {
    return null;
  }
  return Timestamp.fromDate(value);
}

function timestampLikeToMillis(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (value instanceof Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
}

function isAuthorized(headerValue?: string): boolean {
  const expectedToken = revenueCatWebhookAuth.value().trim();
  if (!expectedToken) {
    logger.error("REVENUECAT_WEBHOOK_AUTH is not configured");
    return false;
  }

  const actual = headerValue?.trim();
  if (!actual) {
    return false;
  }

  return actual === expectedToken || actual === `Bearer ${expectedToken}`;
}

function buildDefaultTrialStatus(uid: string): TrialStatusSnapshot {
  return {
    uid,
    cameraSolveRemaining: defaultTrialQuota,
    similarPracticeRemaining: defaultTrialQuota,
    bannerPromotionRemaining: defaultTrialQuota,
  };
}

function normalizeTrialStatus(
  uid: string,
  data: Record<string, unknown> | undefined,
): TrialStatusSnapshot {
  return {
    uid,
    cameraSolveRemaining: normalizeQuota(data?.cameraSolveRemaining),
    similarPracticeRemaining: normalizeQuota(data?.similarPracticeRemaining),
    bannerPromotionRemaining: normalizeQuota(data?.bannerPromotionRemaining),
  };
}

function normalizeQuota(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return defaultTrialQuota;
  }
  return Math.max(0, Math.floor(value));
}

function normalizeTrialFeature(value: unknown): TrialFeatureKey | null {
  if (
    value === "cameraSolve" ||
    value === "similarPractice" ||
    value === "bannerPromotion"
  ) {
    return value;
  }
  return null;
}

function decrementTrialQuota(
  status: TrialStatusSnapshot,
  feature: TrialFeatureKey,
): TrialStatusSnapshot {
  const remaining = trialRemainingFor(status, feature);
  if (remaining <= 0) {
    return status;
  }
  switch (feature) {
    case "cameraSolve":
      return {
        ...status,
        cameraSolveRemaining: status.cameraSolveRemaining - 1,
      };
    case "similarPractice":
      return {
        ...status,
        similarPracticeRemaining: status.similarPracticeRemaining - 1,
      };
    case "bannerPromotion":
      return {
        ...status,
        bannerPromotionRemaining: status.bannerPromotionRemaining - 1,
      };
  }
}

function trialRemainingFor(
  status: TrialStatusSnapshot,
  feature: TrialFeatureKey,
): number {
  switch (feature) {
    case "cameraSolve":
      return status.cameraSolveRemaining;
    case "similarPractice":
      return status.similarPracticeRemaining;
    case "bannerPromotion":
      return status.bannerPromotionRemaining;
  }
}

function toTrialStatusResponse(status: TrialStatusSnapshot) {
  return {
    cameraSolveRemaining: status.cameraSolveRemaining,
    similarPracticeRemaining: status.similarPracticeRemaining,
    bannerPromotionRemaining: status.bannerPromotionRemaining,
    updatedAtMs: Date.now(),
  };
}

/** Firebase Auth 帳號刪除後，清除使用者相關 Firestore 文件（規則不允許客戶端寫入）。 */
export const cleanupUserDataOnDelete = functions.auth.user().onDelete(
  async (user) => {
    const uid = user.uid;
    const batch = db.batch();
    batch.delete(db.collection("subscription_status").doc(uid));
    batch.delete(db.collection("feature_trial_status").doc(uid));
    await batch.commit();
    logger.info("cleanupUserDataOnDelete: removed user documents", { uid });
  },
);
