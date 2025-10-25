const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { google } = require("googleapis");
const fs = require("fs");

// Load the Play Integrity service account key
const playIntegrityServiceAccount = require("./play-integrity-service-account-key.json");

// Initialize Firebase Admin SDK (use your main Firebase credentials)
if (!admin.apps.length) {
  admin.initializeApp();
}

// Create a GoogleAuth client for Play Integrity
const auth = new google.auth.GoogleAuth({
  credentials: playIntegrityServiceAccount,
  scopes: ["https://www.googleapis.com/auth/playintegrity"],
});

const playintegrity = google.playintegrity({
  version: "v1",
  auth,
});

setGlobalOptions({ maxInstances: 10 });

exports.sendNotification = onCall(
  { enforceAppCheck: true, region: "asia-south1" },
  async (request) => {
    try {
      if (!request.auth) {
        throw new Error("User must be authenticated to send notifications.");
      }
      if (!request.app) {
        throw new Error("App Check verification failed.");
      }

      const {
        token,
        title,
        body,
        data = {},
        recipientId,
        recipientRole,
        integrityToken,
      } = request.data;

      if (!token) throw new Error("FCM token is required.");
      if (!integrityToken) throw new Error("Integrity token is required.");

      // ✅ Verify Play Integrity token
      const packageName = "com.naukariwala.avr"; // Replace with your app's package name

      const integrityResponse = await playintegrity.v1.verify({
        packageName,
        requestBody: { integrityToken },
      });

      const verdict = integrityResponse.data;
      logger.info("Play Integrity verdict:", verdict);

      // Check for device integrity (basic example)
      const integrityVerdict =
        verdict.deviceIntegrity?.deviceRecognitionVerdict || [];

      if (!integrityVerdict.includes("MEETS_DEVICE_INTEGRITY")) {
        throw new Error("Device integrity check failed");
      }

      logger.info("✅ Device integrity verified successfully.");

      // Prepare FCM message
      const message = {
        token,
        notification: {
          title: title || "📢 New Notification",
          body: body || "You have a new message",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: data.type || "general",
          ...data,
          timestamp: new Date().toISOString(),
        },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { contentAvailable: true } },
        },
      };

      // Send FCM
      await admin.messaging().send(message);
      logger.info(`✅ Notification sent to ${token}`);

      // Save in Firestore if recipient details provided
      if (recipientId && recipientRole) {
        const collectionName =
          recipientRole === "recruiter"
            ? "RecruiterNotifications"
            : "SeekerNotifications";

        await admin
          .firestore()
          .collection(collectionName)
          .doc(recipientId)
          .collection("Notifications")
          .add({
            title,
            body,
            data,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            sentBy: request.auth.uid,
          });
      }

      return { success: true, message: "Notification sent successfully." };
    } catch (error) {
      logger.error("❌ Error sending notification:", error);
      throw new Error(`Failed to send notification: ${error.message}`);
    }
  }
);
