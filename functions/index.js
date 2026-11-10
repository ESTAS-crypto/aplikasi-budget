const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function onCreate pada path groups/{gid}/events/{eventId}
 * Mengirim pesan data-only ke FCM Topic berdasarkan jenis aktivitas.
 * 
 * Aturan Notifikasi Putar Jajan:
 * 1. Pesan dikirim sebagai DATA-ONLY (tanpa notification payload bawaan APNs/FCM)
 *    agar HP klien memiliki kontrol penuh untuk:
 *    - Mengabaikan pesan bila actorUid == uid sendiri (tanpa duplikasi notifikasi).
 *    - Mengagregasikan aktivitas dalam jendela 60 detik per-grup ("3 aktivitas baru di Date Jumat").
 * 2. Topic naming convention:
 *    - group_{gid}_expenses
 *    - group_{gid}_spin
 *    - group_{gid}_warning80
 *    - group_{gid}_members
 */
exports.onGroupEventCreated = functions.firestore
  .document("groups/{gid}/events/{eventId}")
  .onCreate(async (snapshot, context) => {
    const { gid, eventId } = context.params;
    const eventData = snapshot.data();

    if (!eventData) {
      console.log(`[onGroupEventCreated] Event ${eventId} empty data, skipping.`);
      return null;
    }

    const { type, actorUid, actorName, payload, createdAt } = eventData;

    // Tentukan topik berdasarkan tipe event
    let topicSuffix = "";
    switch (type) {
      case "expense":
        topicSuffix = "expenses";
        break;
      case "spin":
        topicSuffix = "spin";
        break;
      case "warning80":
        topicSuffix = "warning80";
        break;
      case "member_join":
      case "member_leave":
        topicSuffix = "members";
        break;
      default:
        topicSuffix = "all";
    }

    const topic = `group_${gid}_${topicSuffix}`;

    // Payload data-only untuk diproses oleh NotificationService di klien Flutter
    const message = {
      data: {
        gid: String(gid),
        eventId: String(eventId),
        type: String(type || ""),
        actorUid: String(actorUid || ""),
        actorName: String(actorName || "Anggota"),
        payloadJson: JSON.stringify(payload || {}),
        createdAtMillis: String(createdAt ? createdAt.toMillis() : Date.now()),
      },
      topic: topic,
      android: {
        priority: "high",
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`[onGroupEventCreated] Sent FCM data message to topic ${topic}: ${response}`);
      return response;
    } catch (error) {
      console.error(`[onGroupEventCreated] Error sending FCM message to topic ${topic}:`, error);
      return null;
    }
  });

