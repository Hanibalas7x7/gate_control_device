# Gate Control - Versijų Palyginimas

## ✅ Atlikta

1. **v1.0 išsaugota** - Git tag `v1.0` su realtime listener implementacija
2. **v1.1 sukurta** - Git tag `v1.1` su FCM implementacija
3. **Edge Function** - Supabase function ready to deploy
4. **Database migracijos** - SQL failas sukurtas
5. **Dokumentacija** - Setup guide sukurtas

---

## 📊 v1.0 vs v1.1

| Aspektas | v1.0 (Realtime) | v1.1 (FCM) |
|----------|----------------|------------|
| **Background Service** | ✅ Foreground task | ❌ Nereikia |
| **Baterijos naudojimas** | 🔴 Didelis | 🟢 Minimalus |
| **Android sistema** | 🔴 Žudo app | 🟢 Neprieštarauja |
| **Crash recovery** | ❌ Nėra | ✅ Auto retry SMS |
| **Supabase connection** | 🔴 Nuolatinė | 🟢 Tik reikalui esant |
| **Stabilumas** | 🟡 Vidutinis | 🟢 Aukštas |
| **Setup sudėtingumas** | 🟢 Paprastas | 🟡 Reikia Firebase |

---

## 🚀 Kas toliau? (Setup žingsniai)

### 1️⃣ Firebase Setup (10 min)
```bash
# Firebase Console
1. Sukurti projektą: console.firebase.google.com
2. Add Android app: com.example.gate_control_device
3. Download google-services.json → android/app/
4. Copy FCM Server Key

# FlutterFire CLI
dart pub global activate flutterfire_cli
flutterfire configure --project=your-project-id
```

### 2️⃣ Supabase Setup (5 min)
```bash
# Run migration
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/002_fcm_support.sql

# Deploy Edge Function
cd supabase/functions
supabase functions deploy gate-notify

# Set secret
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key
```

### 3️⃣ Build & Deploy (5 min)
```bash
# Install dependencies
flutter pub get

# Build APK
flutter build apk

# Install to device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 4️⃣ Testing (2 min)
```bash
# Test gate open
curl -X POST https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"command": "open_gate", "deviceId": "device_1"}'

# Test SMS
curl -X POST https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"command": "send_sms", "phoneNumber": "+37069922987", "message": "Test", "deviceId": "device_1"}'
```

---

## 🎯 Pagrindiniai Privalumai v1.1

### 1. **Nereikia foreground service**
- Android sistema nebepriešinasi
- Mažiau baterijos
- Stabilesnis veikimas

### 2. **Auto SMS Retry**
```dart
// Paleidus aplikaciją:
1. Tikrina pending SMS
2. Automatiškai išsiunčia
3. Atnaujina status
```

### 3. **FCM Workflow**
```
Užklausa → Edge Function → FCM → Android "pabunda" → Atlieka veiksmą
```

---

## 📝 Failo struktūra

```
gate_control_device/
├── lib/
│   ├── main.dart              # v1.0 (realtime)
│   ├── main_v1_1.dart         # v1.1 (FCM) ⭐ NEW
│   ├── firebase_options.dart  # Firebase config ⭐ NEW
│   └── gate_control_service.dart
├── supabase/
│   ├── functions/
│   │   └── gate-notify/       # Edge Function ⭐ NEW
│   │       ├── index.ts
│   │       └── README.md
│   └── migrations/
│       └── 002_fcm_support.sql ⭐ NEW
├── SETUP_V1.1.md              # Setup guide ⭐ NEW
└── pubspec.yaml               # Updated deps
```

---

## ⚠️ Svarbu

### Prieš deploy:
1. ✅ Sukurti Firebase projektą
2. ✅ Gauti `google-services.json`
3. ✅ Run `flutterfire configure`
4. ✅ Pakeisti `firebase_options.dart` su tikrais duomenimis
5. ✅ Run database migration
6. ✅ Deploy edge function
7. ✅ Set FCM_SERVER_KEY secret

### Testing:
1. ✅ Patikrinti FCM token registraciją
2. ✅ Test gate open command
3. ✅ Test SMS command
4. ✅ Test crash recovery (force close app, reopen)
5. ✅ Test pending SMS auto-send

---

## 🔧 Troubleshooting

### FCM notifikacijos negaunamos:
```bash
# Check FCM token in device_tokens table
SELECT * FROM device_tokens;

# Check Edge Function logs
supabase functions logs gate-notify

# Check Android logs
adb logcat | grep -i "gate\|fcm"
```

### SMS nesiųsti:
```bash
# Check pending commands
SELECT * FROM gate_commands WHERE status = 'pending';

# Manually trigger retry
# App → "Siųsti laukiančius SMS" button
```

---

## 📚 Dokumentacija

- **SETUP_V1.1.md** - Pilnas setup guide
- **supabase/functions/gate-notify/README.md** - Edge Function docs
- **supabase/migrations/002_fcm_support.sql** - Database schema

---

## 🎉 Summary

✅ **v1.0** - Išsaugota kaip backup (git tag v1.0)  
✅ **v1.1** - Sukurta su FCM ir crash recovery  
✅ **Edge Function** - Ready to deploy  
✅ **Dokumentacija** - Išsami setup instrukcija  
✅ **Database** - Migration failas sukurtas  

**Sekantis žingsnis:** Firebase setup ir deployment! 🚀
