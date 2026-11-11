# Usage stats (Firebase) aur AdMob setup

## A) Kitne user / kahan install — Firebase Firestore (SDK ke baghair)

1. https://console.firebase.google.com → **Add project** (naam: GPS Camera).
2. **Build → Firestore Database → Create database** (production mode, koi bhi region).
3. **Firestore → Rules** mein ye paste karke Publish karein:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /installs/{id} {
      allow create, update: if request.resource.data.keys().hasOnly(
        ['version','model','android','lat','lon','place','firstSeen','lastSeen','sessions']);
      allow read, delete: if false;   // sirf aap Console mein dekh sakte hain
    }
  }
}
```
4. **Project settings (gear icon) → General**: `Project ID` copy karein.
   **Project settings → General → Your apps → Web API Key** (agar nahi dikhe to "Add app → Web" bana lein) — key copy karein.
   (Google Cloud Console → Credentials mein is key ko "Cloud Firestore API" tak restrict kar dein.)
5. `lib/config/app_config.dart` mein dono khali strings bharein, GitHub par upload karein, build chalayein.
6. App pehli dafa khulne par user se ijazat poochti hai. "Allow" karne walon ka data aata hai.
7. Dekhne ke liye: Firebase Console → Firestore Database → `installs` collection.
   - Documents ki ginti = kitne alag phone/install
   - `lastSeen` = aakhri dafa kab istemal hui, `sessions` = kitni dafa khuli
   - `place`, `lat`, `lon` = taqriban ilaqa (~1 km), `model`, `version`

## B) AdMob
1. https://admob.google.com par account → **Apps → Add app** (Android).
2. App ID (`ca-app-pub-xxxx~yyyy`) aur Banner/Interstitial **Ad unit IDs** copy karein.
3. Mujhe ye IDs den (ya test IDs se shuru karein) — main `google_mobile_ads` package, manifest ki App ID aur banner (Settings / Reports / Storage screens par) jod dunga. Camera screen par ad nahi lagana chahiye.
4. Zaroori: Privacy Policy, UMP (consent) message, aur AdMob mein app ki verification.

## C) Package name
Ab app ka package name `com.gsabbir.gps_camera` hai (workflow mein `--org com.gsabbir`).
Firebase mein bhi isi naam se Android app register hai. `google-services.json` is setup (REST) mein zaroori nahi.
Naya package naam hone ki wajah se ye purani `com.hassan.gps_camera` app ke upar update nahi hogi — alag app ki tarah install hogi.
