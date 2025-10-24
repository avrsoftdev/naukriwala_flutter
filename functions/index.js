const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const serviceAccount = require("./fcm-service-account-key.json");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

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

      const { token, title, body, data = {}, recipientId, role } = request.data;

      if (!token) {
        throw new Error("FCM token is required.");
      }

      const message = {
        token,
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: data.type || "general",
          jobId: data.jobId || "",
          seekerId: data.seekerId || "",
          recruiterId: data.recruiterId || "",
          message: data.message || "",
          timestamp: new Date().toISOString(),
          title: title || "📢 New Notification",
          body: body || "You have a new message",
          ...data,
        },
        android: {
          priority: "high",
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              contentAvailable: true,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      logger.info(`✅ Notification sent successfully to token: ${token}`);

      if (recipientId) {
        const collectionName =
          role === "recruiter"
            ? "RecruiterNotifications"
            : "SeekerNotifications";

        await admin
          .firestore()
          .collection(collectionName)
          .doc(recipientId)
          .collection("Notifications")
          .add({
            title: title,
            body: body,
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