# Gate Control Device v1.1 - Setup Guide

## 🔄 Kas pasikeitė v1.1 versijoje?

### ✅ Privalumai
- **Nereikia foreground service** - Android sistema nebežudys aplikacijos
- **FCM (Firebase Cloud Messaging)** - aplikacija tik "pabunda" gavusi komandą
- **Mažesnis baterijos naudojimas** - aplikacija miega, kol negauna notifikacijos
- **Auto SMS retry** - paleidus aplikaciją po crash, automatiškai išsiunčia visus pending SMS
- **Stabilesnis veikimas** - Android sistema nebepriešinasi

### ❌ Kas pašalinta
- `flutter_foreground_task` - nebereikalingas
- Realtime listener - pakeistas į FCM
- Nuolatinis background procesas

---

## 🚀 Setup Instrukcijos

### 1. Firebase Setup

#### A. Sukurti Firebase projektą
1. Eiti į [Firebase Console](https://console.firebase.google.com)
2. Sukurti naują projektą arba naudoti esamą
3. Įjungti **Cloud Messaging**

#### B. Pridėti Android app
1. Firebase Console → Project Settings → Add app → Android
2. Package name: `com.example.gate_control_device`
3. Atsisiųsti `google-services.json`
4. Įdėti failą į `android/app/google-services.json`

#### C. Gauti FCM Server Key
1. Firebase Console → Project Settings → Cloud Messaging
2. Copy **Server Key** (legacy) arba **Cloud Messaging API key**
3. Išsaugoti - reikės Supabase Edge Function

### 2. Android Konfigūracija

Atidaryti `android/build.gradle.kts` ir pridėti:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

Atidaryti `android/app/build.gradle.kts` ir pridėti:

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

### 3. FlutterFire CLI Setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (sugeneruos firebase_options.dart)
flutterfire configure --project=your-firebase-project-id
```

### 4. Supabase Setup

#### A. Sukurti `device_tokens` lentelę

```sql
CREATE TABLE device_tokens (
  id BIGSERIAL PRIMARY KEY,
  device_id TEXT UNIQUE NOT NULL,
  fcm_token TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Service role can manage tokens"
  ON device_tokens FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "Users can manage their own tokens"
  ON device_tokens FOR ALL TO authenticated
  USING (true) WITH CHECK (true);
```

#### B. Deploy Edge Function

```bash
cd supabase/functions
supabase functions deploy gate-notify
```

#### C. Nustatyti Secrets

```bash
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key_from_firebase
```

### 5. Testing

#### A. Užregistruoti įrenginį
1. Paleisti aplikaciją
2. Leisti notifications
3. Patikrinti ar rodomas "FCM aktyvuotas ✓"
4. FCM token automatiškai išsaugomas į Supabase

#### B. Siųsti test komandą

**Atidaryti vartus:**
```bash
curl -X POST https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "command": "open_gate",
    "deviceId": "device_1"
  }'
```

**Siųsti SMS:**
```bash
curl -X POST https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "command": "send_sms",
    "phoneNumber": "+37069922987",
    "message": "Test SMS",
    "deviceId": "device_1"
  }'
```

---

## 🔧 Kaip veikia

### Workflow

1. **Klientas/Sistema** → Išsiunčia užklausą į Supabase Edge Function
2. **Edge Function** → Įrašo komandą į `gate_commands` lentelę
3. **Edge Function** → Gauna FCM token iš `device_tokens`
4. **Edge Function** → Siunčia FCM notifikaciją
5. **Android Įrenginys** → Gauna FCM notifikaciją (net jei aplikacija uždaryta!)
6. **Android App** → "Pabunda" ir atlieka veiksmą (skambutis/SMS)
7. **Android App** → Atnaujina komandos statusą į `completed`

### Auto SMS Retry

Kai aplikacija paleidžiama (po crash ar reboot):
1. Tikrina `gate_commands` lentelėje `pending` SMS
2. Automatiškai išsiunčia visus neišsiųstus SMS
3. Atnaujina status į `completed`

---

## 📱 Leidimai (Permissions)

Aplikacija reikalauja:
- `CALL_PHONE` - skambučiams į vartus
- `SEND_SMS` - SMS siuntimui klientams
- `POST_NOTIFICATIONS` - FCM notifikacijoms
- `INTERNET` - Supabase komunikacijai

---

## 🔄 Migravimas iš v1.0

1. **Backup** - v1.0 jau išsaugota kaip git tag
2. **Deploy** - Edge Function į Supabase
3. **Update** - Android APK į v1.1
4. **Test** - Patikrinti FCM veikimą
5. **Monitor** - Stebėti ar nėra crash'ų

---

## 🐛 Troubleshooting

### FCM notifikacijos negaunamos
- Patikrinti ar `google-services.json` teisingai įdėtas
- Patikrinti ar FCM Server Key teisingas Supabase secrets
- Patikrinti device_tokens lentelėje ar yra FCM token

### SMS nesiųsti po crash
- Paleisti aplikaciją rankiniu būdu
- Paspausti "Siųsti laukiančius SMS"
- Patikrinti logus

### "Device not registered"
- Paspausti "Patikrinti leidimus"
- Leisti notifications
- Restart aplikaciją

---

## 📊 Database Schema

```
gate_commands:
  - id (bigserial)
  - command (text): 'open_gate' | 'send_sms'
  - phone_number (text): kliento numeris
  - order_code (text): užsakymo kodas
  - sms_type (text): 'created' | 'ready_for_pickup'
  - device_id (text): įrenginio ID
  - status (text): 'pending' | 'completed' | 'failed'
  - created_at (timestamp)

device_tokens:
  - id (bigserial)
  - device_id (text): unique įrenginio ID
  - fcm_token (text): FCM registracijos token
  - created_at (timestamp)
  - updated_at (timestamp)
```

---

## 🎯 Next Steps

1. **Deploy edge function** → `supabase functions deploy gate-notify`
2. **Setup Firebase project** → Gauti google-services.json
3. **Run flutterfire configure** → Generuoti firebase_options.dart
4. **Build APK** → `flutter build apk`
5. **Install & Test** → Patikrinti veikimą

**Sėkmės! 🚀**
