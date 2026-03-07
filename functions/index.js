const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");

admin.initializeApp();

// 從環境變數讀取 SendGrid API Key（放在 functions/.env 裡）
const SENDGRID_KEY = process.env.SENDGRID_API_KEY;
if (!SENDGRID_KEY) {
  console.warn(
    "SENDGRID_API_KEY is not set. Wishlist emails will not be sent until you add it to functions/.env."
  );
} else {
  sgMail.setApiKey(SENDGRID_KEY);
}

exports.submitWishlistRequest = functions.https.onCall(async (data, context) => {
  // Support both v1 (data, context) and v2 (request with .data/.auth) callable payload
  let payload = data;
  let auth = context && context.auth;
  if (data && typeof data === "object" && "data" in data && typeof data.data === "object") {
    payload = data.data;
    auth = data.auth != null ? data.auth : auth;
  }
  payload = payload || {};

  console.log("WishlistRequest payload:", payload);

  let productName = (payload.productName || "").toString().trim();
  const description = (payload.description || "").toString().trim();
  const uid = (payload.uid || (auth && auth.uid) || "").toString();
  const email = (payload.email || (auth && auth.token && auth.token.email) || "").toString();
  const platform = (payload.platform || "").toString();
  const appVersion = (payload.appVersion || "").toString();
  const createdAt = (payload.createdAt || new Date().toISOString()).toString();

  if (!productName) {
    console.warn("Wishlist called without productName, using fallback label");
    productName = "(no title)";
  }

  const lines = [];
  lines.push(`Product / Topic: ${productName}`);
  if (description) lines.push(`Description: ${description}`);
  lines.push("");
  lines.push(`UID: ${uid || "(anonymous)"}`);
  lines.push(`User email: ${email || "(unknown)"}`);
  lines.push(`Platform: ${platform || "(unknown)"}`);
  lines.push(`App version: ${appVersion || "(unknown)"}`);
  lines.push(`Created at (client): ${createdAt}`);

  const textBody = lines.join("\n");

  const msg = {
    to: "dev.mimoom@gmail.com",
    from: "dev.mimoom@gmail.com",
    subject: `Wishlist: ${productName}`,
    text: textBody,
  };

  try {
    await sgMail.send(msg);
    return {ok: true};
  } catch (err) {
    console.error("Failed to send wishlist email", err);
    throw new functions.https.HttpsError("internal", "Failed to send wishlist email.");
  }
});
