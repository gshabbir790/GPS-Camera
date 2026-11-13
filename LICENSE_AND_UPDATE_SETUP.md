# Zaroori update + Device license (Firebase) — setup

Ye dono features Firestore REST se chalte hain (naya SDK nahi). Sab kuch Firebase Console se control hota hai, app dobara bananay ki zaroorat nahi.

## 1) Firestore Rules (purani rules ki jagah ye paste karke Publish)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // usage stats (pehle jaisa)
    match /installs/{id} {
      allow create, update: if request.resource.data.keys().hasOnly(
        ['version','model','android','lat','lon','place','firstSeen','lastSeen','sessions']);
      allow read, delete: if false;
    }

    // app settings: sab parh sakte hain, sirf aap likh sakte hain (Console se)
    match /config/{doc} {
      allow read: if true;
      allow write: if false;
    }

    // device license
    match /devices/{id} {
      allow get: if true;                 // device apni hi ID se parhta hai
      allow list, delete: if false;
      allow create: if request.resource.data.allowed == false
        && request.resource.data.keys().hasOnly(
            ['allowed','model','android','appVersion','lastSeen','sessions']);
      allow update: if request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['model','android','appVersion','lastSeen','sessions']);
      // 'allowed' aur 'expiry' koi app badal nahi sakti — sirf aap Console se
    }
  }
}
```

## 2) Settings document banayein
Firestore → **Start collection** → ID: `config` → Document ID: `app` → fields (sab *string* siwaye jahan likha ho):

| Field | Type | Misal | Matlab |
|---|---|---|---|
| `minVersion` | string | `2.7.9` | Isse purana version khulega hi nahi (zabardasti update) |
| `latestVersion` | string | `2.8.0` | (maloomat ke liye) |
| `updateUrl` | string | GitHub Release / Drive link | "Update now" button yahan le jata hai |
| `updateMessage` | string | `Naya version aa gaya hai` | Update screen ka paigham |
| `licenseRequired` | **boolean** | `false` | `true` karte hi sirf approved devices chalenge |
| `trialDays` | **number** | `3` | Naye device ko itne din muft (0 = koi trial nahi) |
| `whatsapp` | string | `923001234567` | Khareedne ke liye WhatsApp number (country code ke saath, + ke baghair) |
| `priceText` | string | `Rs 1500 / saal` | Locked screen par dikhega |
| `contactMessage` | string | `Mujhe GPS Camera activate karwani hai` | WhatsApp message ka shuru |

**Shuru mein `licenseRequired = false` rakhein** — sab chalti rahegi. Jab tayyar hon tab `true` karein.

## 3) Naya update dena (zabardasti)
1. Naya APK GitHub Release mein upload karein.
2. `config/app` mein `updateUrl` = release ka link, `minVersion` = naya version (jaise `2.8.0`).
3. Purane version wale app kholte hi "Update required" screen dekhenge — ye screen band nahi hoti.

## 4) Kisi device ko allow karna (khareedne walay)
1. User ki app "This device is not activated" dikhati hai, Device ID aur WhatsApp button ke saath.
2. User payment kar ke Device ID aap ko bhejta hai.
3. Firestore → `devices` collection → us ID ka document → `allowed` = **true** (boolean).
   Muddat chahiye to `expiry` field (timestamp) lagayein; us tareekh ke baad "License expired" aayega.
4. User "check again" dabata hai aur app khul jati hai.
Block karna ho to `allowed` = false. Naye devices khud `devices` mein `allowed=false` ke saath aa jate hain (model bhi likha hota hai).

## 5) Anti-share (APK doosre ko dene par)
- Device ID (Android ID) har phone ki alag hoti hai, to doosre phone par APK chalane se wo "not activated" screen dekhega.
- Ek phone allow hone ke baad uski APK doosre ko di jaye to bhi doosra phone allow nahi hoga.
- App apna signing certificate check karti hai (`expectedCertSha1`): kisi ne APK badal kar dobara sign ki to "Unofficial copy" aayega.
- Internet na ho ya Firebase na mile to pichli kamyab jaanch ke baad 72 ghante tak app chal jati hai (`graceHours`).

## Hadood (sach)
Ye client-side hifazat hai. Koi maahir banda APK ko decompile kar ke check hata sakta hai. Zyada mazboot hifazat ke liye Play Store + Google Play Integrity API chahiye (alag SDK aur Play listing). Roz-marra "dosto ke sath share" rokne ke liye ye kaafi hai.
