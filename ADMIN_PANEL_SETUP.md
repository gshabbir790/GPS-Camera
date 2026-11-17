# Admin panel + Support chat — setup

## 0) Firestore database banayein (SAB SE PEHLE — iske baghair "404" aata hai)
Firebase Console → **Build → Firestore Database → Create database** → Edition: Standard → Database ID: `(default)` → Location (koi bhi, jaise `asia-south1`) → **Production mode** → Create.

## 1) Admin user banayein (Firebase Console)
1. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable**.
2. **Users → Add user** → apna email + password.
3. **Authentication → Settings → Authorized domains → Add domain**: `gshabbir790.github.io`

## 2) Firestore Rules (poori purani rules ki jagah paste karke Publish)
`YOUR_ADMIN_EMAIL@example.com` ki jagah wahi email likhein jo upar user banaya.
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAdmin() {
      return request.auth != null
        && request.auth.token.email == 'YOUR_ADMIN_EMAIL@example.com';
    }

    // Admin sab kuch parh/likh sakta hai
    match /{document=**} {
      allow read, write: if isAdmin();
    }

    // usage stats
    match /installs/{id} {
      allow create, update: if request.resource.data.keys().hasOnly(
        ['version','model','android','lat','lon','place','firstSeen','lastSeen','sessions','deviceId']);
    }

    // app settings (sirf parhna)
    match /config/{doc} {
      allow read: if true;
    }

    // device license
    match /devices/{id} {
      allow get: if true;
      allow create: if request.resource.data.allowed == false
        && request.resource.data.keys().hasOnly(
            ['allowed','model','android','appVersion','lastSeen','sessions']);
      allow update: if request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['model','android','appVersion','lastSeen','sessions']);
    }

    // support chat: ticket ID = device ID
    match /tickets/{id} {
      allow get: if true;
      allow create: if request.resource.data.lastFrom == 'user'
        && request.resource.data.keys().hasOnly(
            ['deviceId','model','android','appVersion','contact','lastText','lastFrom','lastAt','unreadAdmin','unreadUser']);
      allow update: if request.resource.data.diff(resource.data).affectedKeys().hasOnly(['unreadUser'])
        || (request.resource.data.lastFrom == 'user'
            && request.resource.data.diff(resource.data).affectedKeys().hasOnly(
               ['deviceId','model','android','appVersion','contact','lastText','lastFrom','lastAt','unreadAdmin','unreadUser']));

      match /messages/{mid} {
        allow read: if true;
        allow create: if request.resource.data.from == 'user'
          && request.resource.data.text is string
          && request.resource.data.text.size() <= 2000;
      }
    }
  }
}
```

## 3) Admin panel kholna
`docs/admin/index.html` ko GitHub par upload karein (Pages /docs se). Link:
**https://gshabbir790.github.io/GPS-Camera/admin/**
Email/password se login karein. Phone par "Add to Home screen" kar lein to app jaisa chalta hai.

Tabs:
- **Dashboard**: total installs, active 24h/7d/30d, versions, top places, naqsha (map) par sab users, poori list.
- **Support**: users ke messages, jawab dein (user ke phone par Settings/Gear icon par laal nuqta aata hai).
- **Devices**: license — allow/block, expiry date, ID se allow.
- **Settings**: minVersion, updateUrl, licenseRequired, trialDays, price, WhatsApp number wagaira (app ko dobara banaye baghair).

## 4) Agar Dashboard khali ho
- Console → Firestore mein `installs` collection hai? Nahi to app ke Support screen ke upar "network" icon (Connection test) dabayein:
  `OK` = theek, `Rejected (403)` = rules/key ka masla, `No connection` = internet.
- Login ke baad "Cannot read installs: permission-denied" aaye to rules mein admin email theek likhein.

## 5) Licensing kaise chalayein (kisi ko app share karne se pehle)
- Jab tak Settings tab mein **License required** tick nahi hota, app **har phone par bina approval** chalti hai (aur Devices list khali rehti hai).
- Apne phone ki Device ID: app mein Settings → neeche **Device ID** (tap kar ke copy). Pehle usay Devices tab mein "Approve a device by ID" se allow karein.
- Phir Settings tab mein **License required** tick kar ke Save karein. Ab naye phone par "This device is not activated" aayegi (Device ID + WhatsApp button); wo ID bhejega, aap Devices tab mein Allowed tick kar ke Save karein.
- Trial dena ho to **Free trial days** likhein.

## 6) Messages delete karna
- User app: kisi message ko dair tak dabayein → "Delete for me" (sirf us phone se). Chat screen ke upar jhadu icon se poori chat us phone se saaf.
- Admin panel: message ke saath ⋯ → "Delete for me" ya (sirf apne bheje hue ke liye) "Delete for everyone (unsend)": user ke phone par "This message was deleted" likha aata hai.
