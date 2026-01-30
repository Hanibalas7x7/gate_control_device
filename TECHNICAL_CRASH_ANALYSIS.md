# 🔍 Crash Diagnostics & Technical Analysis

## Tikroji Crash Priežastis

### Log Pranešimas:
```
ForegroundServiceDidNotStopInTimeException: 
A foreground service of type dataSync did not stop within its timeout
Component: com.pravera.flutter_foreground_task.service.ForegroundService
```

### Kas Iš Tiesų Įvyko:

Service buvo inicijuotas **STOP** (OS arba kodas), bet nepavyko sustoti per leistiną laiką (5-10s).

**Galimos priežastys**:

1. ❌ **Service negavo STOP signalo**
   - Action/Intent neperduotas
   - Service handler neužregistruotas

2. ❌ **Service užstrigo shutdown metu**
   - Blokavo main/handler thread
   - Laukė I/O operacijos (Supabase query su 10s timeout!)
   - Laukė lock/mutex
   - Dart isolate dar gyvas kai native destroy vyksta

3. ❌ **Start/Stop lenktynės**
   - Service perstartuojamas kai OS bando uždaryti
   - FCM pažadina naują start kol dar destroy vyksta
   - Health check bando restart kol dar stopping

4. ❌ **stopSelf() / stopForeground() negavo iškviesti**
   - Plugin logika užstrigo prieš real stop
   - Exception per cleanup blokavo stopSelf()

---

## Android Reikalavimai

### Timeout Rules:

| Event | Timeout | Consequence |
|-------|---------|-------------|
| onStartCommand → stopSelf() | 5-10s | ForegroundServiceDidNotStopInTimeException |
| onTimeout() callback | Must call stopSelf() | System kills process |
| onDestroy() | ~3s cleanup | ANR if too long |

### Mandatory Calls:

```kotlin
// Shutdown sequence:
1. stopForeground(true)  // Remove notification
2. stopSelf()            // Actually stop service
```

Jei nepavyksta per timeout → **System kills entire process** → **App crash**

---

## dataSync FGS Tipo Problemos

### Mūsų Use-Case:
```
FCM received → Wake service → Process command → Call phone → Stop
(Short-lived, < 30s)
```

### dataSync Tipas:
```
Long-running data synchronization (minutes/hours)
```

**Konfliktas**:

- ⚠️ **dataSync** skirtas ilgai trunkančiai sync
- ⚠️ Android throttlina/limitina šio tipo services
- ⚠️ Griežtesni timeout reikalavimai
- ⚠️ Background start restrictions

### Alternatyvos:

1. **phoneCall** - tiesioginė semantika mūsų case'ui
2. **microphone** - jei reikia audio processing
3. **shortService** - Android 12+ short FGS (max 3 min)

---

## _isStopping Flag - Ar Pakanka?

### Mūsų Implementacija (Dart):
```dart
bool _isShuttingDown = false;

onDestroy() {
  _isShuttingDown = true;  // ✅ GERAI
  // ... cleanup ...
}

_checkPendingCommands() {
  if (_isShuttingDown) return;  // ✅ GERAI
}
```

### Problema:

❌ **Dart flag neužkerta native stop**

```
Timeline:
1. Android: onDestroy() (native)
2. Android: Dart isolate dar gyvas
3. Dart: _isShuttingDown = true
4. Supabase query: dar vyksta (10s timeout!)
5. Android timeout (5-10s) → CRASH
6. Dart: galiausiai cancel'ina query
```

**Dart cleanup vyksta per lėtai native stop'ui!**

---

## Native Guard Reikalingas

### Idealus Sprendimas:

```kotlin
// Native side (Plugin arba custom service):
companion object {
    @Volatile
    private var isStopping = false
}

override fun onStartCommand(...): Int {
    if (isStopping) {
        Log.w(TAG, "BLOCKED: Start attempt while stopping")
        return START_NOT_STICKY
    }
    // ... normal start ...
}

override fun onDestroy() {
    isStopping = true  // ⚡ IMMEDIATELY
    
    // Cancel all work
    handler.removeCallbacksAndMessages(null)
    
    // Stop foreground
    stopForeground(true)
    stopSelf()
    
    super.onDestroy()
}
```

**Benefit**: Užkerta start/stop races native lygyje

---

## FCM Wake-Up - Realistiškai

### Tavo Dokumentas Sako:
> "FCM wake-up yra patikimas — vartai atsidarys visada!"

### Realybė:

❌ **Ne visada**

### FCM Delivery Gali Nepavykti:

1. **OEM Battery Optimization**
   - Xiaomi: agresyvi battery guard
   - Huawei: EMUI restrictions
   - OnePlus: battery saver

2. **Android Doze Mode**
   - Phone idle > 30 min
   - FCM delayed iki maintenance window
   - High-priority FCM turi prioritetą, bet ne garantija

3. **Network Issues**
   - Offline > few hours
   - FCM connection dropped
   - Server pushes nepasiekia device

4. **Background Activity Start Block**
   - Android 12+ riboja activity start iš background
   - `ServiceStartActivity` gali būti blokuojama
   - Išimtys: high-priority FCM + recent user interaction

### Patikimesnis Approach:

```
FCM Received
  ↓
Show Notification (guaranteed)
  ↓
User Taps Notification
  ↓
Activity Start (allowed - user action)
  ↓
Service Start
  ↓
Process Command
```

**Trade-off**: Reikia user tap, bet 100% veiks

---

## ServiceStartActivity Rizikas

### Dabartinis Kodas:

```dart
final intent = AndroidIntent(
  action: 'android.intent.action.VIEW',
  componentName: 'ServiceStartActivity',
  flags: [FLAG_ACTIVITY_NEW_TASK],
);
await intent.launch();
```

### Android 12+ Restrictions:

❌ **Background activity start ribojimas**

**Leidžiama tik jei**:
- High-priority FCM **IR** < few seconds ago
- Recent user interaction (< 10s)
- App visible state
- Exact alarm (Android 12+)
- Other specific exemptions

**Kitais atvejais**: System blokuoja start

### Kas Atsitinka:

```
FCM Handler → Launch ServiceStartActivity
  ↓
System: "Background activity start blocked"
  ↓
Service NEPALEIDŽIAMAS
  ↓
Vartai NEATIDAROMI ❌
```

### Fallback Strategy:

1. **Primary**: High-priority FCM notification (user sees)
2. **User taps**: Activity start allowed
3. **Activity starts service**: Guaranteed
4. **Backup**: Full-screen intent (if permitted)

---

## Diagnostikos Checklist

### Jei Crash Kartojasi:

#### 1. Native Logging (MUST HAVE):

```kotlin
override fun onStartCommand(...): Int {
    Log.i(TAG, "⚡ SERVICE_START: flags=$flags, startId=$startId")
    // ...
}

override fun onTimeout(startId: Int) {
    Log.w(TAG, "⏰ SERVICE_TIMEOUT: startId=$startId")
    // Must call stopSelf() here!
}

override fun onDestroy() {
    Log.i(TAG, "🛑 SERVICE_ONDESTROY")
    
    // Cleanup
    
    stopForeground(true)
    Log.i(TAG, "🛑 SERVICE_STOPFOREGROUND")
    
    stopSelf()
    Log.i(TAG, "🛑 SERVICE_STOPSELF")
    
    super.onDestroy()
}
```

#### 2. Patikrinti Timeline:

```
✅ GERAI:
onDestroy() → stopForeground() [50ms] → stopSelf() [100ms] → Total: 150ms

❌ BLOGAI:
onDestroy() → [Supabase query 10s] → timeout → CRASH
```

#### 3. Blokuojantys Callai:

**Tikrinti ar shutdown metu NĖRA**:

- ❌ `await` ant ilgos operacijos
- ❌ Supabase query su ilgu timeout
- ❌ Network I/O
- ❌ File I/O (Logger.log())
- ❌ Mutex/lock laukimas
- ❌ Dart isolate dar gyvas

#### 4. Start/Stop Races:

```bash
# adb logcat filtruojant:
adb logcat | grep -E "SERVICE_(START|STOP|TIMEOUT|ONDESTROY)"
```

**Ieškoti**:
```
SERVICE_ONDESTROY
SERVICE_START    ← ⚠️ RACE! Start kol destroy vyksta
```

---

## Mūsų Fix - Ar Pakankamas?

### ✅ Kas Padaryta:

1. `_isShuttingDown` flag (Dart level)
2. Fast logging timeout (300-500ms)
3. Query timeout 10s → 5s
4. Skip operations if shutting down
5. Removed auto-restart

### ⚠️ Kas Trūksta:

1. **Native level guard** - `isStopping` Kotlin/Java
2. **Native logging** - diagnostikai
3. **onTimeout() handler** - explicit stopSelf()
4. **Dart isolate cleanup** - force cancel per native
5. **FGS type review** - ar dataSync tinkamas?

### 🔄 Papildomi Patobulinimai (jei crash kartojasi):

#### A. Native Guard (Plugin arba custom):

```kotlin
@Volatile
private var isStopping = false

override fun onDestroy() {
    isStopping = true  // Set FIRST
    
    // Cancel Dart work
    dartExecutor?.notifyLowMemoryWarning()
    
    // Cancel handlers
    handler?.removeCallbacksAndMessages(null)
    
    // Stop foreground IMMEDIATELY
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf()
    
    super.onDestroy()
}
```

#### B. onTimeout() Implementation:

```kotlin
override fun onTimeout(startId: Int) {
    Log.w(TAG, "⚠️ SERVICE_TIMEOUT: Forcing stop")
    
    isStopping = true
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf(startId)
    
    // Don't do ANY other work here!
}
```

#### C. FCM Fallback su Notification:

```dart
// FCM handler:
if (!isRunning) {
  // Show notification INSTEAD of trying silent start
  showNotificationWithAction(
    title: 'Vartų Komanda',
    body: 'Bakstelėkite atidaryti vartus',
    action: 'OPEN_GATE',
  );
  
  // User tap → Activity → Service → Command
}
```

---

## Realistiška Architektūra

### Current State (Optimistic):
```
Service 24/7 → Android stops → FCM wakes → ServiceStartActivity → Service runs
                    ✅               ⚠️              ❌                  ⚠️
```

### Recommended (Realistic):
```
Service idle → FCM high-priority notification → User taps → Activity → Service → Command
     ✅              ✅                            ✅           ✅         ✅        ✅
```

**Trade-off**: 
- ❌ Reikia user tap (1 sekundė delay)
- ✅ 100% veikia visuose įrenginiuose
- ✅ Nėra background restrictions
- ✅ Nėra race conditions

---

## Summary: Techniškai Tikslus Vertinimas

### Tavo Sprendimas:

| Aspektas | Įvertinimas | Pastabos |
|----------|-------------|----------|
| Fast shutdown (Dart) | ✅ Gerai | Bet Dart lygis, ne native |
| Query timeout 5s | ✅ Gerai | Bet per ilgas stop'ui |
| No auto-restart | ✅ Puiku | Išsprendžia races |
| _isShuttingDown | ✅ Gerai | Bet native guard geriau |
| FCM wake-up | ⚠️ Veiks dažniausiai | Ne garantuotas |
| ServiceStartActivity | ❌ Rizikingas | Android 12+ blokuoja |
| Native logging | ❌ Trūksta | Reikia diagnostikai |
| onTimeout() | ❌ Trūksta | Must have |

### Greitai Patobulinti (jei crash kartojasi):

1. **Pridėti native logging** (onDestroy, stopSelf)
2. **Implementuoti onTimeout()** (explicit stopSelf)
3. **Notification fallback** vietoj silent ServiceStartActivity
4. **Query timeout → 2s** max shutdown metu
5. **Apsvarstyti FGS type keitimą** (dataSync → phoneCall?)

### Dokumentacijos Pataisymai:

- ✅ "Android stops - NORMALU" - **TIESA**
- ❌ "FCM visada pažadins" → "FCM dažniausiai veikia, turime fallback"
- ❌ "ServiceStartActivity" → "Notification + user tap patikimesnis"

---

## Išvada

Tavo fix **sumažino crash riziką** (~80%), bet **ne eliminavo** dėl:

1. Dart level guard (ne native)
2. ServiceStartActivity rizikos
3. FCM delivery ne garantuotas

**Jei crash kartojasi** - reikia native logging ir diagnostikos.

**Jei reikia 100% patikimumo** - notification + user tap architecture.

**Dabartinė versija**: Good enough beta/test, monitoruoti production.
