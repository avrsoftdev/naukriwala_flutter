import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

initializeApp();

export const setUserRole = onCall({ region: "asia-south1" }, async (request) => {
  const uid = request.data.uid;
  const role = request.data.role;

  try {
    await getAuth().setCustomUserClaims(uid, { role });
    logger.info(`Custom claim '${role}' set for user ${uid}`);
    return { message: `Custom claim '${role}' set for user ${uid}` };
  } catch (error) {
    logger.error("Error setting custom claim", error);
    throw new Error(`Failed to set role: ${error.message}`);
  }
});