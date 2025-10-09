const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin SDK
admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

exports.sendNotification = onCall(
  { enforceAppCheck: true }, // Enable AppCheck enforcement
  async (request) => {
    // 🔐 Optional: Require auth
    if (!request.auth) {
      throw new Error("User must be authenticated to send notifications");
    }

    // Verify AppCheck token
    if (!request.app) {
      throw new Error("AppCheck verification failed");
    }

    const { token, title, body, data = {} } = request.data;

    if (!token) {
      throw new Error("FCM token is required");
    }

    try {
      const message = {
        token,
        notification: {
          title: title || "📢 New Notification",
          body: body || "You have a new message",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK", // for Android navigation
          type: data.type || "general",              // make sure "type" is present
          chatId: data.chatId || "",
          jobId: data.jobId || "",
          seekerId: data.seekerId || "",
          notificationId: data.notificationId || "", // Added for tracking
          message: data.message || "",              // Added for custom message
          ...data, // include any other custom data
        },
        android: {
          priority: "high",
          notification: {
            channelId: "fcm_default_channel",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            sound: "default",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              sound: "default",
              contentAvailable: true, // 📱 Ensures background delivery on iOS
            },
          },
        },
      };

      // 🚀 Send notification
      await admin.messaging().send(message);
      logger.info(`✅ Notification sent successfully to: ${token}`);

      return { success: true, message: "Notification sent successfully" };
    } catch (error) {
      logger.error("❌ Error sending notification:", error);
      throw new Error(`Failed to send notification: ${error.message}`);
    }
  }
);