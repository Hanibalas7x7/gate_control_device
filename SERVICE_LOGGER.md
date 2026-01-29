# ✅ Service Logger - Crash & Kill Logs Dokumentacija

## 📝 Kas įdiegta?

Sukurta **crash/kill log sistema** kuri:
- ✅ Įrašo visus service events (start, stop, crash, restart)
- ✅ Įrašo FCM events (received, restart attempts, success/failures)
- ✅ Įrašo komandas (gate open, SMS)
- ✅ Rodo UI su log history
- ✅ Išsaugo iki 500 paskutinių įvykių
- ✅ Automatiškai trim'ina senus logs

---

## 📋 Nauji failai:

### 1. `service_logger.dart`
Log storage ir management sistema:
- Rašo į `service_logs.txt` app documents directory
- Auto-trim (max 500 lines)
- Timestamp su kiekvienu įrašu
- Predefined log funkcijos

### 2. `service_logs_screen.dart`
UI ekranas su:
- Chronological log sąrašu (newest first)
- Filtrai: All / Crashes / FCM / Commands
- Export (copy to clipboard)
- Clear logs funkcionalumas
- Color-coded (red = error, green = success)
- Icons pagal event tipą

---

## 🎯 Kas log'inama?

### App Lifecycle
```dart
APP_STARTED        🚀 - App paleidimas
```

### Service Lifecycle
```dart
SERVICE_STARTED    ✅ - User paleido service
SERVICE_STOPPED    🛑 - User sustabdė service
SERVICE_CRASHED    💥 - Health check detected dead service
SERVICE_RESTARTED  🔄 - Auto-restart after crash
```

### FCM Events
```dart
FCM_RECEIVED           🔔 - FCM push gautas
FCM_RESTART_ATTEMPT    ⚠️ - Bandymas perkrauti service
FCM_RESTART_SUCCESS    ✅ - Service sėkmingai perkrautas
FCM_RESTART_FAILED     ❌ - Nepavyko perkrauti (Android 12+)
```

### Commands
```dart
GATE_COMMAND       🚪 - Gate open command (ID: xxx)
SMS_COMMAND        📱 - SMS send command (ID: xxx, Phone: xxx)
```

### System
```dart
BOOT_COMPLETED     🔋 - Device restart (if implemented)
LOGS_CLEARED       🗑️ - User išvalė logs
```

---

## 🖥️ UI Naudojimas

### Main Screen:
```
[Paleisti servisą]
[Service Logs]  ← NAUJAS mygtukas
```

### Logs Screen:
- **Filter Icon** (viršuje) - filtruoti logs
  - 🔍 Visi
  - 💥 Crashes
  - 🔔 FCM
  - 📋 Komandos

- **Copy Icon** - nukopijuoti visus logs į clipboard
- **Delete Icon** - išvalyti visus logs
- **Refresh Icon** - atnaujinti sąrašą

### Log Entry Pavyzdžiai:
```
💥 Servisas Krito                    15:30:45
   Detected dead service
   2026-01-29

✅ FCM Restart Sėkmė                 15:30:47
   Service revived
   2026-01-29

🚪 Vartų Komanda                     15:31:20
   ID: 123
   2026-01-29
```

---

## 🔍 Debug Scenarijai

### Scenario 1: Service crash
```
1. Service veikia
2. Android užmuša service
3. Health check aptinka (30s interval)
4. LOG: SERVICE_CRASHED
5. Auto-restart
6. LOG: SERVICE_RESTARTED
```

### Scenario 2: FCM restart sėkmė
```
1. Service miręs
2. FCM push ateina
3. LOG: FCM_RECEIVED
4. LOG: FCM_RESTART_ATTEMPT
5. Service paleidžiamas
6. LOG: FCM_RESTART_SUCCESS
```

### Scenario 3: FCM restart klaida (Android 12+)
```
1. Service miręs
2. FCM push ateina (delayed delivery)
3. LOG: FCM_RECEIVED
4. LOG: FCM_RESTART_ATTEMPT
5. Android blokuoja FGS start
6. LOG: FCM_RESTART_FAILED: ForegroundServiceStartNotAllowedException
```

---

## 📊 Log File Format

File location: `/data/user/0/com.example.gate_control_device/app_flutter/service_logs.txt`

Format:
```
[2026-01-29 15:30:45] EVENT_NAME: details
[2026-01-29 15:30:47] EVENT_NAME: details
...
```

Pavyzdys:
```
[2026-01-29 15:30:45] SERVICE_CRASHED: Detected dead service
[2026-01-29 15:30:47] SERVICE_RESTARTED: Auto-restart after crash
[2026-01-29 15:31:20] FCM_RECEIVED: Command: open_gate
[2026-01-29 15:31:22] GATE_COMMAND: ID: 123
```

---

## 🧪 Testing

### Test 1: Crash detection
```dart
1. Paleisti service
2. Kill process: adb shell am kill com.example.gate_control_device
3. Atidaryti app
4. Žiūrėti logs → turėtų matyti SERVICE_CRASHED
```

### Test 2: FCM restart
```dart
1. Kill service
2. Siųsti FCM push
3. Atidaryti app
4. Žiūrėti logs → turėtų matyti:
   - FCM_RECEIVED
   - FCM_RESTART_ATTEMPT
   - FCM_RESTART_SUCCESS arba FCM_RESTART_FAILED
```

### Test 3: Health check
```dart
1. Paleisti service
2. Force kill: adb shell am force-stop com.example.gate_control_device
3. Atidaryti app (service auto-starts)
4. Palaukti 30s
5. Jei service vėl miršta → logs parodys SERVICE_CRASHED
```

---

## 💡 Kaip naudoti debug'inimui

### Kai service "neveikia":

1. **Atidaryti app → Service Logs**
2. **Žiūrėti paskutinius įrašus:**
   - `SERVICE_CRASHED` - service mirė, kada?
   - `FCM_RESTART_FAILED` - Android blokavo restart, kodėl?
   - `FCM_RECEIVED` - ar FCM push'ai ateina?

3. **Filter pagal kategoriją:**
   - Crashes - matai kiek kartų service krašino
   - FCM - matai ar push'ai ateina ir veikia
   - Commands - matai ar komandos vykdomos

4. **Export logs:**
   - Copy Icon → paste į žinutę tau
   - Analizuoji timeline

### Tipiniai patterns:

**Geras scenario:**
```
SERVICE_STARTED
FCM_RECEIVED (reguliariai)
GATE_COMMAND (kai reikia)
```

**Blogas scenario (Android 12+ problema):**
```
SERVICE_CRASHED
FCM_RECEIVED
FCM_RESTART_FAILED: ForegroundServiceStartNotAllowedException
SERVICE_CRASHED (vėl)
FCM_RESTART_FAILED (vėl)
```
→ **Sprendimas:** WorkManager implementation

**Blogas scenario (battery optimization):**
```
SERVICE_STARTED
(ilga pertrauka - nieko neįvyksta)
SERVICE_CRASHED
```
→ **Sprendimas:** User turi disable battery optimization

---

## 🚀 Next Steps

Ateityje galima pridėti:
- [ ] Boot receiver logging (`BOOT_COMPLETED`)
- [ ] Battery level logging (žiūrėti ar low battery įtakoja)
- [ ] Network state logging (offline mode)
- [ ] Command execution time (performance metrics)
- [ ] Auto-upload logs to Supabase (remote monitoring)

---

## ✅ TL;DR

**Pridėta:**
- 📝 Service logger su file storage
- 🖥️ Logs screen su filters
- 🔍 Export/clear funkcionalumas
- 📊 Automatiškas logging visų kritinių events

**Naudojimas:**
1. App → [Service Logs] mygtukas
2. Žiūri kas vyksta su service
3. Debug pagal patterns
4. Export logs jei reikia dalintis

**Kas matosi:**
- Kada service start/stop/crash
- Ar FCM push'ai ateina
- Ar restarts veikia
- Kokie errorai vyksta

Puiku debugging! 🎯
