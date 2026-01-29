# FCM + Foreground Service Analizė ir Rekomendacijos

## 🔍 Dabartinė Situacija

### Kas veikia dabar:
1. **FCM** gauna high-priority push
2. **_firebaseMessagingBackgroundHandler** prikelia app'ą background'e
3. Patikrina ar foreground service veikia
4. Jei ne → bando paleisti `FlutterForegroundTask.startService()`

### ⚠️ PROBLEMOS (ChatGPT TEISUS):

#### 1. **ForegroundServiceStartNotAllowedException** (Android 12+)
Android 12+ uždraudė FGS startą iš background, nebent:
- ✅ High-priority FCM gautas pastarųjų ~10 sekundžių
- ✅ User interaction (tap, launch)
- ✅ Exact alarm triggered
- ✅ Bluetooth/location exemptions
- ❌ **Bet jei Android vėluoja FCM delivery → NO EXEMPTION!**

**Rezultatas:** `ForegroundServiceStartNotAllowedException` → service nepaleidžia

#### 2. **ForegroundServiceDidNotStartInTimeException**
Kai `startForegroundService()` iškviečiamas, Android reikalauja:
- Per ~5 sekundžių turi būti iškviesta `startForeground()` su notification
- `flutter_foreground_task` gali užtrukti (Dart VM, initialization)
- **Rezultatas:** Android kills process

#### 3. **FCM Priority**
Jei FCM message turi `"priority": "normal"` arba neturi priority:
- Android vėluoja delivery (iki 15+ minučių)
- Negauname FGS exemption
- **Rezultatas:** Service nepaleidžia

---

## ✅ Trumpalaikis Sprendimas (Dabar Implementuota)

### Kas padaryta:
1. **Pridėtas error handling** su specifinėmis error žinutėmis
2. **Logina FCM priority** kad matytum ar high-priority
3. **Aiškios instrukcijos** ką daryti jei nepavyksta

### Kodas:
```dart
print('⚠️ Note: Android 12+ may block FGS start from background');

try {
  await FlutterForegroundTask.startService(...);
  print('✅ Service restarted successfully!');
} catch (restartError) {
  // Detailed error logging
  if (restartError.toString().contains('ForegroundServiceStartNotAllowedException')) {
    print('🚫 Confirmed: Android 12+ blocked FGS start');
  }
}
```

### Reikalavimai FCM message:
```json
{
  "message": {
    "token": "device_fcm_token",
    "data": {
      "command": "open_gate"
    },
    "android": {
      "priority": "high"  // ⚠️ BŪTINA!
    }
  }
}
```

---

## 🚀 Ilgalaikis Sprendimas (WorkManager)

ChatGPT rekomendacija **TEISINGA** - WorkManager yra patikimesnis.

### Architektūra:

```
FCM high-priority push
    ↓
FirebaseMessagingService.onMessageReceived()
    ↓
WorkManager.enqueueUniqueWork(ExpeditedWorkRequest)
    ↓
Worker patikrina Supabase commands
    ↓
Jei reikia long-running → startForegroundService()
```

### Privalumai:
✅ **Android neblokuoja WorkManager** taip agresyviai kaip FGS
✅ **ExpeditedWorkRequest** vykdomas iškart (kaip FGS)
✅ **Automatic retry** jei nepavyksta
✅ **setForeground()** viduje Worker → leistinas FGS startas
✅ **Battery-friendly** - Android žino kad tai system-managed

### Trūkumai:
❌ Kompleksiškesnis implementation
❌ Reikia native Android kodo (Java/Kotlin)
❌ Dar vienas failure point

---

## 📋 Kas Reikia Padaryti Dabar

### 1. **Patikrinti FCM Priority** ⚠️ PIRMENYBĖ
Eik į Supabase Edge Function arba FCM sending kodą:

```typescript
// Supabase Edge Function
const message = {
  token: fcmToken,
  data: { command: 'open_gate' },
  android: {
    priority: 'high',  // ⚠️ BŪTINA Android 12+
  },
};
```

### 2. **Monitor Logs**
Kai service "miršta", žiūrėk log'us:
```bash
flutter run --release
# Arba
adb logcat | grep -E "FCM|Service|Foreground"
```

Ieškoti šių error'ų:
- `ForegroundServiceStartNotAllowedException`
- `ForegroundServiceDidNotStartInTimeException`

### 3. **Testai**
a) **Test su working service:**
   - Service running → FCM push → turėtų tik trigger check

b) **Test su dead service:**
   - Kill service (force stop app) → FCM push
   - Žiūrėk ar paleidžia ar meta exception

c) **Test su Android 12+ device**
   - Svarbiausias testas!

---

## 🔄 Kada Pereiti Prie WorkManager?

### Jei matai šiuos logs/errors:
1. ❌ `ForegroundServiceStartNotAllowedException` (dažnai)
2. ❌ `ForegroundServiceDidNotStartInTimeException`
3. ❌ FCM delivery vėluoja (>30s)
4. ❌ Service neprisikelia po crash

### Tada:
➡️ Implement WorkManager solution (3-4 val. darbo)

---

## 💡 Papildomi Patarimai

### FCM Token Registration
Užtikrink kad:
```dart
// main.dart
messaging.onTokenRefresh.listen((newToken) {
  _registerFCMToken(newToken);  // ✅ Jau turi
});
```

### Notification Channel Importance
```dart
channelImportance: NotificationChannelImportance.HIGH,  // Ne DEFAULT!
```

### App Standby Buckets
Android deda app'us į "buckets" (active, working_set, frequent, rare, restricted).
- Jei app restricted → FCM vėluoja
- User turi eiti Settings → Battery → Unrestricted

### Battery Optimization
```dart
await Permission.ignoreBatteryOptimizations.request();  // ✅ Jau turi
```

---

## 📊 Dabartinio Sprendimo Prognozė

| Scenario | Veiks? | Pastabos |
|----------|--------|----------|
| Service running + FCM push | ✅ 100% | Tik trigger check |
| Service crashed + FCM high priority + Android 11 | ✅ 95% | Turėtų paleisti |
| Service crashed + FCM high priority + Android 12 | ⚠️ 60-80% | Depends on timing |
| Service crashed + FCM normal priority | ❌ 10% | Android blocks |
| Service crashed + FCM delayed (>30s) | ❌ 5% | No exemption |

---

## 🎯 Išvada

**Dabartinis sprendimas:**
- ✅ Geras Android 11 ir žemiau
- ⚠️ Risky Android 12+
- ✅ Veiks jei FCM high-priority ir greitas delivery

**Rekomendacija:**
1. **DABAR:** Pridėtas error handling ir priority check (✅ padaryta)
2. **PO TESTŲ:** Jei matai problemas → implement WorkManager
3. **LONG-TERM:** WorkManager yra "industry standard" šiai problemai

ChatGPT patarimai **100% teisingi** - WorkManager yra patikimesnis, bet dabartinis sprendimas gali veikti jei FCM high-priority ir greitas.
