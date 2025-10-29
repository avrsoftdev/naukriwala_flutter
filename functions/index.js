const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { google } = require("googleapis");

// --- GLOBAL INITIALIZATION ---

// 🚨 WARNING: Robustly load the Play Integrity service account key. 
// This try/catch helps diagnose HTTP 500 errors caused by a missing file 
// during cold start in the V2 runtime environment.
let playIntegrityServiceAccount;
try {
  // Use require for JSON file as it runs synchronously at initialization
  playIntegrityServiceAccount = require("./play-integrity-service-account-key.json");
} catch (e) {
  // Use console.error/throw as logger may not be fully initialized during global scope execution
  console.error("FATAL: Could not load Play Integrity Service Account Key. Check file existence and path.", e.message);
  throw new Error("Missing or invalid 'play-integrity-service-account-key.json' file.");
}

// Initialize Firebase Admin SDK (only once)
if (!admin.apps.length) {
  admin.initializeApp({
    // Using applicationDefault assumes the key is loaded via the environment or credential: admin.credential.cert(playIntegrityServiceAccount) is used for local development/testing with a file.
    credential: admin.credential.applicationDefault(),
  });
}

// Ensure the loaded key is valid before creating the client
if (!playIntegrityServiceAccount || !playIntegrityServiceAccount.private_key) {
    console.error("FATAL: Loaded Play Integrity key is missing required fields.");
    throw new Error("Invalid Play Integrity service account key structure.");
}


// Create GoogleAuth client for Play Integrity API
const auth = new google.auth.GoogleAuth({
  credentials: playIntegrityServiceAccount,
  scopes: ["https://www.googleapis.com/auth/playintegrity"],
});

const playintegrity = google.playintegrity({
  version: "v1",
  auth,
});

setGlobalOptions({ maxInstances: 10 });

/**
 * Cloud Function to send an FCM notification after performing input validation 
 * and optional Play Integrity verification.
 */
exports.sendNotification = onCall(
  { enforceAppCheck: true, region: "asia-south1" },
  async (request) => {
    try {
      // --- TEMPORARY DEBUG OVERRIDE REMOVED ---
      // Since the app is in closed testing, the function will now run the full
      // Play Integrity check by default.
      
      logger.info("📩 Received request", {
        hasAuth: !!request.auth,
        hasApp: !!request.app,
        data: request.data,
      });

      const {
        token,
        title,
        body,
        data = {},
        recipientId,
        recipientRole,
        integrityToken,
      } = request.data;

      // ✅ Input validation
      if (!token || typeof token !== 'string' || token.trim() === '') {
        throw new HttpsError('invalid-argument', 'FCM token is required and must be a non-empty string');
      }
      // If running in production (or closed testing), ensure the integrity token is provided by the client.
      if (!integrityToken && process.env.NODE_ENV !== 'development') {
        throw new HttpsError('failed-precondition', 'Integrity token is required in production');
      }

      // ✅ Verify Play Integrity Token (skip in development)
      if (process.env.NODE_ENV !== 'development') {
        const packageName = "com.naukariwala.avr"; // Your app package name

        const integrityResponse = await playintegrity.v1.decodeIntegrityToken({
          packageName,
          requestBody: { integrityToken },
        });

        const verdict = integrityResponse.data.tokenPayloadExternal || {};
        logger.info("Play Integrity verdict:", verdict);

        const integrityVerdict = verdict.deviceIntegrity?.deviceRecognitionVerdict || [];
        if (!integrityVerdict.includes("MEETS_DEVICE_INTEGRITY")) {
          throw new HttpsError('failed-precondition', 'Device integrity check failed');
        }

        logger.info("✅ Device integrity verified successfully");
      } else {
        logger.info("Skipping Play Integrity verification (development mode)");
      }

      // ✅ Prepare FCM message
      
      // FIX: Sanitize the incoming 'data' object to remove reserved FCM keys (like 'from')
      // and large, unnecessary keys (like 'integrityToken').
      const payloadData = { ...data };
      delete payloadData.integrityToken;
      // This is the key fix for the "Invalid data payload key: from" error
      delete payloadData.from; 

      const message = {
        token,
        notification: {
          title: title || "📢 New Notification",
          body: body || "You have a new message",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: payloadData.type || "general",
          ...payloadData, // Spread the sanitized data
          timestamp: new Date().toISOString(),
        },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { contentAvailable: true } },
        },
      };

      // ✅ Send FCM Notification
      const response = await admin.messaging().send(message);
      logger.info(`✅ Notification sent to ${token}, response: ${response}`);

      // ✅ Save in Firestore if recipient info provided (Now wrapped in try/catch and data is JSON stringified)
      if (recipientId && (recipientRole === "recruiter" || recipientRole === "seeker")) {
        try {
          const collectionName = recipientRole === "recruiter"
            ? "RecruiterNotifications"
            : "SeekerNotifications";
          
          const firestore = admin.firestore();

          // Convert the payload data to a JSON string for robust storage
          const payloadDataJson = JSON.stringify(payloadData);

          await firestore
            .collection(collectionName)
            .doc(recipientId)
            .collection("Notifications")
            .add({
              title: title || "",
              body: body || "",
              payloadDataJson: payloadDataJson, // Storing as JSON string
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              sentBy: request.auth?.uid || "anonymous",
            });
            logger.info(`✅ Notification saved to Firestore for recipient: ${recipientId}`);
        } catch (firestoreError) {
          // Log the Firestore error specifically, but do not fail the entire function
          // as the notification has already been sent successfully.
          logger.error(`⚠️ Failed to save notification to Firestore for ${recipientId}:`, firestoreError.message);
          // Continue execution
        }
      }

      return { success: true, message: "Notification sent successfully." };
    } catch (error) {
      logger.error("❌ Error sending notification:", {
        error: error.message,
        stack: error.stack,
      });

      // Handle expected errors
      if (error instanceof HttpsError) {
        throw error; // Re-throw HttpsError to preserve details
      } else if (error.message.includes("messaging/registration-token-not-registered")) {
        throw new HttpsError('invalid-argument', 'FCM token is invalid or unregistered');
      } else if (error.message.includes("Permission denied")) {
        throw new HttpsError('permission-denied', 'Insufficient permissions to send notification');
      } else {
        // Catch all other unexpected errors
        throw new HttpsError('internal', `Failed to send notification: ${error.message}`);
      }
    }
  }
);
