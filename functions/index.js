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
// CUSTOM EMAIL VERIFICATION WITH SENDGRID
exports.sendCustomVerificationEmail = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    const { email, continueUrl } = request.data;
    
    if (!email || typeof email !== "string") {
      throw new HttpsError("invalid-argument", "Valid email required");
    }

    // Generate verification link
    const actionCodeSettings = {
      url: continueUrl || "https://naukariwala.web.app",
      handleCodeInApp: true,
    };

    const verificationLink = await admin.auth()
      .generateEmailVerificationLink(email, actionCodeSettings);

    // Create branded email template
    const emailTemplate = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify Your Email - Naukriwala</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f8f9fa;
            color: #333;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background-color: #4F46E5;
            padding: 30px 20px;
            text-align: center;
        }
        .logo-text {
            font-size: 32px;
            font-weight: bold;
            color: #ffffff;
            margin-bottom: 10px;
            letter-spacing: 2px;
        }
        .logo-subtitle {
            font-size: 14px;
            color: #e0e7ff;
            font-weight: 300;
        }
        .content {
            padding: 40px 30px;
        }
        .title {
            font-size: 24px;
            font-weight: 600;
            color: #1f2937;
            margin-bottom: 20px;
            text-align: center;
        }
        .message {
            font-size: 16px;
            line-height: 1.6;
            color: #6b7280;
            margin-bottom: 30px;
            text-align: center;
        }
        .verify-button {
            display: inline-block;
            background-color: #4F46E5;
            color: #ffffff;
            text-decoration: none;
            padding: 15px 30px;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            text-align: center;
            margin: 20px auto;
            display: block;
            max-width: 200px;
        }
        .verify-button:hover {
            background-color: #4338ca;
        }
        .footer {
            background-color: #f3f4f6;
            padding: 20px 30px;
            text-align: center;
            font-size: 14px;
            color: #6b7280;
        }
        .footer-note {
            margin-top: 15px;
            font-size: 12px;
            color: #9ca3af;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo-text">NAUKARIWALA</div>
            <div class="logo-subtitle">Your Career Journey Starts Here</div>
        </div>
        <div class="content">
            <h1 class="title">Verify Your Email Address</h1>
            <p class="message">
                Hi there!<br><br>
                Thanks for signing up on Naukriwala. To activate your account, please verify your email address by clicking the button below:
            </p>
            <a href="${verificationLink}" class="verify-button">Verify Email</a>
            <p class="message">
                Once your email is verified, return to the app and log in again to continue.
            </p>
        </div>
        <div class="footer">
            <p>Thanks,<br>Team Naukriwala</p>
            <p class="footer-note">
                If you did not create this account, you can safely ignore this email.
            </p>
        </div>
    </div>
</body>
</html>`;

    // Try to send email via direct API call (if configured)
    // For now, we'll use the default Firebase email verification
    // but return the branded template for manual review
    
    logger.info('Generated branded verification template', { email });
    
    // Return the template and verification link for testing
    return { 
      success: true, 
      message: "Branded email template generated",
      verificationLink,
      emailTemplate,
      note: "To actually send emails, configure SendGrid in Firebase Console"
    };

  } catch (error) {
    const msg = error?.message || String(error);
    logger.error("sendCustomVerificationEmail failed", { error: msg });
    
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed: ${msg}`);
  }
});

// MAIN FUNCTION
exports.sendNotification = onCall({ enforceAppCheck: false }, async (request) => {
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