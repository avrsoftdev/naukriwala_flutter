const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// CONFIG
const PACKAGE_NAME = "com.naukariwala.avr";
const TARGET_REGION = "asia-south1";
const PLACEHOLDER_TOKEN = "DEVELOPMENT_PLACEHOLDER_TOKEN";

// INITIALIZE
let playIntegrityServiceAccount;
try {
  playIntegrityServiceAccount = require("./play-integrity-service-account-key.json");
} catch (e) {
  throw new Error("play-integrity-service-account-key.json missing");
}

if (!admin.apps.length) {
  admin.initializeApp();
}

const { google } = require("googleapis");
const auth = new google.auth.GoogleAuth({
  credentials: playIntegrityServiceAccount,
  scopes: ["https://www.googleapis.com/auth/playintegrity"],
});
const playintegrity = google.playintegrity({ version: "v1", auth });

setGlobalOptions({ region: TARGET_REGION, maxInstances: 10 });

// RETRY
async function retry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === maxRetries - 1) throw err;
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000));
    }
  }
}

// MAIN FUNCTION
exports.sendNotification = onCall({ enforceAppCheck: true }, async (request) => {
  try {
    const {
      token,
      title,
      body,
      data = {},
      recipientId,
      recipientRole,
      integrityToken
    } = request.data;

    // VALIDATE
    if (!token || typeof token !== "string") {
      throw new HttpsError("invalid-argument", "Valid FCM token required");
    }

    // PLAY INTEGRITY
    // PLAY INTEGRITY
if (integrityToken === PLACEHOLDER_TOKEN || !integrityToken) {
  logger.info("DEVELOPMENT MODE: Skipping Play Integrity");
} else {
  logger.info("Verifying Play Integrity token...");
  await retry(async () => {
    const resp = await playintegrity.v1.decodeIntegrityToken({
      packageName: PACKAGE_NAME,
      requestBody: { integrityToken },
    });
    const verdict = resp.data.tokenPayloadExternal?.deviceIntegrity?.deviceRecognitionVerdict || [];
    if (!verdict.includes("MEETS_DEVICE_INTEGRITY")) {
      throw new HttpsError("failed-precondition", "Device integrity failed");
    }
    logger.info("Play Integrity PASSED");
  }, 3);
}

    // EXTRACT VALUES SAFELY
    const senderId = data.senderId || request.auth?.uid || "";
    const notificationId = data.notificationId || "";
    const chatId = data.chatId || "";
    const jobId = data.jobId || "";
    const seekerId = data.seekerId || "";
    const jobTitle = data.jobTitle || "Unknown";

    // BUILD FCM MESSAGE
    // Build a data-only message and include explicit `title`/`body`
    // so the client background/foreground handlers can show the exact text
    // and avoid fallback text such as "New Message".
    const message = {
      token,
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        // explicit title/body for client use
        title: String(title || "Naukariwala"),
        body: String(body || ""),
        // preserve useful metadata
        senderId: String(senderId),
        notificationId: String(notificationId),
        chatId: String(chatId),
        jobId: String(jobId),
        seekerId: String(seekerId),
        type: "message",
        recipientId: String(recipientId),
        jobTitle: String(jobTitle),
        // message should carry the actual body text (not a default title)
        message: String(body || title || ""),
      },
      android: { priority: "high" },
    };

    // SEND FCM
    let fcmResponse;
    try {
      fcmResponse = await admin.messaging().send(message);
      logger.info("FCM sent successfully", { response: fcmResponse });
    } catch (error) {
      logger.error("FCM send failed", { error: error.message });
      throw new HttpsError("internal", `FCM failed: ${error.message}`);
    }

    // SAVE TO FIRESTORE
    if (recipientId && ["recruiter", "seeker"].includes(recipientRole)) {
      try {
        const coll = recipientRole === "recruiter" ? "RecruiterNotifications" : "SeekerNotifications";
        await admin.firestore()
          .collection(coll)
          .doc(recipientId)
          .collection("Notifications")
          .add({
            title: title || "New Message",
            body: body || "Tap to view",
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              title: String(title || "Naukariwala"),
              body: String(body || ""),
              senderId: String(senderId),
              notificationId: String(notificationId),
              chatId: String(chatId),
              jobId: String(jobId),
              seekerId: String(seekerId),
              type: "message",
              recipientId: String(recipientId),
              jobTitle: String(jobTitle),
              message: String(body || title || ""),
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          });
        logger.info("Saved notification to Firestore");
      } catch (e) {
        logger.warn("Firestore save failed", { error: e.message });
      }
    }

    return { success: true, message: "Sent", fcmMessageId: fcmResponse };

  } catch (error) {
    const msg = error?.message || String(error);
    logger.error("sendNotification failed", { error: msg });

    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed: ${msg}`);
  }
});