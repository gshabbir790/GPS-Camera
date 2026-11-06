# GPS Camera (جی پی ایس کیمرہ)

GPS Map Camera جیسی ایپ: ہر تصویر پر نقشہ، جگہ کا نام، پتہ، Plus Code، Lat/Long، تاریخ، وقت اور نوٹ کا اسٹیمپ۔
Flutter میں بنی ہے، کوئی Firebase/اشتہارات نہیں، اس لیے APK چھوٹا رہتا ہے۔

## خصوصیات
- اسپلیش اسکرین + ڈویلپر کریڈٹ بینر (اینیمیشن)، English ڈیفالٹ اور اردو (Settings → Language)
- 5 ٹیمپلیٹ: ایڈوانس، تاریخ و وقت، رپورٹنگ (Check In)، کمپاس، اسکین لوکیشن (QR)
- سیٹلائٹ نقشہ (Esri، بغیر API Key)، پتہ (Android Geocoder / OpenStreetMap)
- ریشو 4:3 / 16:9 / 1:1، فلیش، ٹائمر، گرڈ، زوم، ٹیپ سے فوکس، مرر
- فائل کا نام اپنی مرضی کا: 20261106_31743PM_ByGPSMapCamera.jpg
- گیلری (البم GPS Camera) + ایپ سٹوریج، شیئر، اصل تصویر بھی محفوظ کرنے کا آپشن
- تصویر کا معیار: ہائی / درمیانی / کم (فائل کا سائز کنٹرول)

## GitHub پر APK بنانے کا طریقہ
1. GitHub پر نئی repository بنائیں (مثلاً `gps-camera`)۔
2. اس ZIP کے اندر کی **تمام فائلیں** (فولڈر `.github` سمیت) repository میں اپلوڈ کریں۔
3. اپلوڈ کے بعد خودبخود **Actions** ٹیب میں "Build APK" چلے گا (7-12 منٹ)۔
   خود چلانا ہو تو: Actions → Build APK → Run workflow۔
4. مکمل ہونے پر اسی رن کے پیج کے آخر میں **Artifacts → GPS-Camera-APK** ڈاؤن لوڈ کریں۔
5. ZIP کھولیں، اندر دو APK ہوں گی:
   - `GPS-Camera-arm64-v8a-release.apk` ← تقریباً تمام نئے فونز کے لیے (یہی انسٹال کریں)
   - `GPS-Camera-armeabi-v7a-release.apk` ← صرف بہت پرانے 32-bit فونز کے لیے
6. فون میں انسٹال کریں (Unknown sources کی اجازت دینی پڑ سکتی ہے)۔

## ضروری باتیں
- `android/` فولڈر اپلوڈ کرنے کی ضرورت نہیں؛ workflow ہر بار تازہ بنا لیتا ہے۔
- `ci/debug.keystore` ہر بار ایک ہی سائننگ کی دیتی ہے، اس لیے نیا ورژن پرانی ایپ کے اوپر انسٹال ہو جاتا ہے۔
- نام/آئیکن/ورژن بدلنے کے لیے: `android_overrides/AndroidManifest.xml` (نام)، `assets/icon/icon.png` (آئیکن)، `pubspec.yaml` (ورژن)۔
- Release کے طور پر APK چاہیے ہو تو tag لگائیں: `git tag v1.0.0 && git push --tags`۔

## فولڈر
```
lib/main.dart                      ایپ شروع
lib/models/app_settings.dart       سیٹنگز + فائل کا نام
lib/models/stamp_data.dart         اسٹیمپ کا ڈیٹا، تاریخ/وقت کی فارمیٹنگ
lib/services/location_service.dart GPS، پتہ، Plus Code، نقشے کا ٹکڑا
lib/services/photo_processor.dart  کراپ + سائز + اسٹیمپ جوڑنا + JPG
lib/widgets/stamp_widget.dart      پانچوں ٹیمپلیٹ
lib/screens/                       کیمرہ، سیٹنگز، ٹیمپلیٹ، سٹوریج
.github/workflows/build-apk.yml    خودکار APK بنانے کا workflow
```
