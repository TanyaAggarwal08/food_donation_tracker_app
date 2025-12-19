const admin = require('firebase-admin');

const serviceAccount = require('./SecretKey.json');
const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
// --------------------------------------
// INITIALIZE FIREBASE ADMIN
// --------------------------------------
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// POST /notifyVolunteer
app.post("/notifyVolunteer", async (req, res) => {
  const { token, title, body } = req.body;

  if (!token) {
    return res.status(400).send("Missing token");
  }

  const message = {
    notification: { title, body },
    token: token,
  };

  try {
    const response = await admin.messaging().send(message);
    res.send({ success: true, response });
  } catch (error) {
    console.error("Error sending message:", error);
    res.status(500).send(error);
  }
});

// Start server
app.listen(PORT, () => {
  console.log("FCM Server running on port " + PORT);
});

const db = admin.firestore();

// --------------------------------------
// SEND NOTIFICATION USING FCM TOKEN
// --------------------------------------
async function sendNotificationToVolunteer(token, title, body) {
  const message = {
    notification: { title, body },
    token,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("Notification sent:", response);
  } catch (e) {
    console.error("Error sending notification:", e);
  }
}

// --------------------------------------
// GET VOLUNTEER TOKEN BY DELIVERY ID
// --------------------------------------
async function getVolunteerTokenByDelivery(deliveryId) {
  // 1. Get delivery document
  const deliveryDoc = await db.collection("deliveries").doc(deliveryId).get();

  if (!deliveryDoc.exists) {
    console.log("Delivery not found");
    return null;
  }

  const deliveryData = deliveryDoc.data();
  const deliveryUserName = deliveryData.user_name;

  console.log("Volunteer name in delivery:", deliveryUserName);

  // 2. Match user_name → users.user_name
  const userSnap = await db.collection("users")
    .where("user_name", "==", deliveryUserName)
    .limit(1)
    .get();

  if (userSnap.empty) {
    console.log("No matching user for user_name:", deliveryUserName);
    return null;
  }

  const userData = userSnap.docs[0].data();
  const token = userData.fcmToken;

  console.log("User found:", userData.email);
  console.log("FCM Token:", token);

  if (!token) {
    console.log("User has no FCM token.");
    return null;
  }

  return token;
}

// --------------------------------------
// TYPE 1: NEW PICKUP NOTIFICATION
// --------------------------------------
async function sendNotificationByDelivery(deliveryId) {
  try {
    const token = await getVolunteerTokenByDelivery(deliveryId);
    if (!token) return;

    await sendNotificationToVolunteer(
      token,
      "New Pickup Assigned",
      "You have a new pickup task!"
    );

    console.log("New pickup notification sent.");
  } catch (error) {
    console.error("Error:", error);
  }
}

// --------------------------------------
// TYPE 2: PICKUP DATA REMINDER
// --------------------------------------
async function sendReminderByDelivery(deliveryId) {
  try {
    const token = await getVolunteerTokenByDelivery(deliveryId);
    if (!token) return;

    await sendNotificationToVolunteer(
      token,
      "Pickup Data Reminder",
      "Please remember to input your pickup data."
    );

    console.log("Reminder notification sent.");
  } catch (error) {
    console.error("Error:", error);
  }
}

// --------------------------------------
// TEST CALLS (UNCOMMENT TO USE)
// --------------------------------------

 //sendNotificationByDelivery("NoQZLaczgEWwHt4tYDOb");  // New Pickup
//sendReminderByDelivery("NoQZLaczgEWwHt4tYDOb");     // Pickup Data Reminder

module.exports = {
  sendNotificationByDelivery,
  sendReminderByDelivery
};
