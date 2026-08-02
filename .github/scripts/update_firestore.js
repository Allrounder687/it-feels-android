const admin = require('firebase-admin');

// Parse environment variables passed by GitHub Actions
const serviceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT;
const latestVersion = process.env.LATEST_VERSION;
const latestVersionCode = parseInt(process.env.VERSION_CODE, 10);
const updateUrl = process.env.APK_URL;
const releaseNotes = process.env.RELEASE_NOTES || "A new update is available with performance improvements and bug fixes.";

if (!serviceAccountKey) {
  console.error('FATAL: FIREBASE_SERVICE_ACCOUNT is missing in environment.');
  process.exit(1);
}

// Initialize Firebase Admin
try {
  const credentials = JSON.parse(serviceAccountKey);
  admin.initializeApp({
    credential: admin.credential.cert(credentials)
  });
} catch (e) {
  console.error('FATAL: Failed to parse FIREBASE_SERVICE_ACCOUNT. Ensure it is valid JSON.', e);
  process.exit(1);
}

const db = admin.firestore();

async function updateConfig() {
  console.log(`Pushing OTA update to Firestore: v${latestVersion} (Code: ${latestVersionCode})`);
  
  try {
    const docRef = db.collection('client_config').doc('android');
    await docRef.set({
      latest_version: latestVersion,
      latest_version_code: latestVersionCode,
      update_url: updateUrl,
      release_notes: releaseNotes
    }, { merge: true }); // Merge preserves ios_update_url and min_version_code if present
    
    console.log('SUCCESS: OTA configuration updated successfully in Firestore.');
    process.exit(0);
  } catch (error) {
    console.error('FATAL: Failed to update Firestore document.', error);
    process.exit(1);
  }
}

updateConfig();
