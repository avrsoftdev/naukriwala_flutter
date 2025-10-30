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
    const { token, title, body, data = {}, recipientId, recipientRole, integrityToken } = request.data;

    // VALIDATE
    if (!token || typeof token !== "string") {
      throw new HttpsError("invalid-argument", "Valid FCM token required");
    }

    // PLAY INTEGRITY
    if (integrityToken === PLACEHOLDER_TOKEN) {
      logger.info("DEBUG MODE: Skipping Play Integrity");
    } else if (!integrityToken) {
      throw new HttpsError("failed-precondition", "integrityToken required");
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

    // SEND FCM
    const message = {
  token,
  notification: { title: title || "New Message", body: body || "Tap to view" },
  data: {
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    senderId: senderId,        // ← CHANGED
    notificationId: notificationId,
    chatId: widget.chatId,
    jobId: jobId,
    seekerId: _isRecruiter == true ? recipientId : senderId,
    type: 'message',
    recipientId: widget.recipientId,
    jobTitle: jobTitle ?? 'Unknown',
    message: title,
  },
  android: { priority: "high" },
};

    const fcmResponse = await admin.messaging().send(message);
    logger.info("FCM sent successfully", { response: fcmResponse });

    // SAVE TO FIRESTORE
    if (recipientId && ["recruiter", "seeker"].includes(recipientRole)) {
      try {
        await admin.firestore()
          .collection(recipientRole === "recruiter" ? "RecruiterNotifications" : "SeekerNotifications")
          .doc(recipientId)
          .collection("Notifications")
          .add({
            title, body, data: JSON.stringify(data),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (e) {
        logger.warn("Firestore save failed", { error: e.message });
      }
    }

    return { success: true, message: "Sent" };
  } catch (error) {
    // SAFE LOGGING
    const msg = error?.message || String(error);
    logger.error("sendNotification failed", { error: msg });

    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed: ${msg}`);
  }
});