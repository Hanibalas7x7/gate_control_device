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

#### A. Firebase projektas
1. Eiti į [Firebase Console](https://console.firebase.google.com)
2. **Naudoti esamą "gate control device" projektą** ✅
   
   Arba sukurti naują:
   - Spausti **"Create a project"**
   - Įvesti pavadinimą
   - (Nebūtina) Google Analytics

**Pastaba:** Cloud Messaging jau įjungtas automatiškai! Nereikia papildomų veiksmų.

#### B. Pridėti Android app
1. Firebase Console → Project Settings → Add app → Android
2. Package name: `com.example.gate_control_device`
3. Atsisiųsti `google-services.json`
4. Įdėti failą į `android/app/google-services.json`

#### C. Gauti Service Account Key (FCM V1 API)
**Legacy API deprecated - naudojame naują V1 API**

1. Firebase Console → **Project Settings** (⚙️ icon)
2. Tab **"Service accounts"**
3. Spausti **"Generate new private key"**
4. Atsisiųsti JSON failą (pvz: `gate-control-firebase-adminsdk-xxxxx.json`)
5. **Saugoti šį failą!** - reikės Supabase

**Sender ID:**
- Tabs → **Cloud Messaging**
- Nukopijuoti **Sender ID** (pvz: `420596464288`)
- Reikės `flutterfire configure`

### 2. Android Konfigūracija

**✅ Jau padaryta!** Gradle failai jau sukonfigūruoti su Firebase:
- `android/build.gradle.kts` - pridėtas google-services plugin
- `android/app/build.gradle.kts` - pridėtas Firebase dependency

### 3. Firebase Options

**✅ Jau padaryta!** `lib/firebase_options.dart` sukonfigūruotas su projekto duomenimis:
- Project ID: `gate-control-device`
- Sender ID: `420596464288`
- API Key ir kiti parametrai iš `google-services.json`

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

**Per Supabase Dashboard (paprasčiausias būdas):**

1. Eiti į [Supabase Dashboard](https://supabase.com/dashboard)
2. Pasirinkti savo projektą
3. **Edge Functions** → **Deploy a new function**
4. Function name: `gate-notify`
5. Nukopijuoti kodą iš `supabase/functions/gate-notify/index.ts`
6. Paste į editorių
7. Deploy

**Arba per CLI (jei turite įdiegtą):**
```bash
cd supabase/functions
supabase functions deploy gate-notify
```

#### C. Nustatyti Secrets

**1. Gauti Service Account JSON iš Firebase:**
- Firebase Console → Project Settings (⚙️) → **Service accounts**
- Spausti **"Generate new private key"**
- Download JSON failą

**2. Set Secret per Supabase Dashboard:**
1. Supabase Dashboard → **Project Settings** → **Edge Functions**
2. Section **"Function Secrets"**
3. Spausti **"Add secret"**
4. Name: `FIREBASE_SERVICE_ACCOUNT`
5. Value: Atidaryti JSON failą ir **nukopijuoti visą turinį**
6. Save

**Pavyzdys kaip turėtų atrodyti JSON:**
```json
{
  "type": "service_account",
  "project_id": "gate-control-device",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@gate-control-device.iam.gserviceaccount.com",
  ...
}
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
