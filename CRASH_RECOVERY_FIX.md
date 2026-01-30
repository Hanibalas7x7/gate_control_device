# 🚨 Crash Recovery & Timeout Protection Fix

## Problema

```
android.app.RemoteServiceException$ForegroundServiceDidNotStopInTimeException: 
A foreground service of type dataSync did not stop within its timeout
```

**Priežastis**: Foreground servisas nepersijungė per Android leistiną laiką (5-10 sek.), sistema užmušė visą procesą.

Po crash'o **aplikacija nebegalėjo pasileisti** kol neišvalai crash būsenos.

---

## Sprendimas

### ✅ 1. Fast Shutdown Handling

**`gate_control_service.dart`**:
- ✅ Pridėtas `_isShuttingDown` flag
- ✅ Cancel visi pending operations per 2 sekundes
- ✅ Supabase queries sumažinti nuo 10s → 5s timeout
- ✅ Stop logging su 300-500ms timeout
- ✅ Shutdown check visuose metoduose:
  - `onDestroy()` - clean shutdown per 2s
  - `onRepeatEvent()` - skip if shutting down
  - `onReceiveData()` - ignore data if shutting down
  - `_checkPendingCommands()` - skip if shutting down

### ✅ 2. Crash State Clearing

**`service_recovery_helper.dart`** (NAUJAS):
- ✅ `clearCrashState()` - išvalo stuck service state
- ✅ `needsRecovery()` - patikrina ar reikia recovery
- ✅ `performFullRecovery()` - pilnas recovery process

**`main.dart`**:
- ✅ Crash state clearing app startup metu
- ✅ Emergency Recovery mygtukas UI
- ✅ Auto-recovery po crash detection

### ✅ 3. AndroidManifest.xml

~~Pridėtas `stopWithTaskRemovalAllowed="true"`~~ (Pašalinta - nesuderinama su žemesnėmis API)

**Crash fix'as veikia be manifest pakeitimų** - pagrindinė logika yra kode (`_isShuttingDown` flag ir fast shutdown).

---

## Architektūra

### Android Lifecycle Philosophy

**Svarbu**: Leisti Android'ui sustabdyti servisą be crash - tai normalus behavior!

```
Service Running
   ↓
Android stops service (battery optimization)
   ↓
Service stops cleanly (< 3s)
   ↓
FCM message received
   ↓
ServiceStartActivity wakes up service
   ↓
Service Running again
```

**Nėra crash** - tai normalus Android lifecycle!

### Shutdown Flow

```
1. User/System requests stop
   ↓
2. Set _isShuttingDown = true (IMMEDIATELY)
   ↓
3. Cancel all pending operations
   ↓
4. Fast log write (300-500ms timeout)
   ↓
5. Cleanup Supabase client
   ↓
6. Service stops cleanly (< 3 seconds)
```

### Crash Recovery Flow

```
1. App starts
   ↓
2. ServiceRecoveryHelper.clearCrashState() (clean any stuck state)
   ↓
3. Check if service running
   ↓
4. If NOT running:
   - Log: SERVICE_NOT_RUNNING
   - Update UI
   - FCM will wake up when needed
   ↓
5. User can manually start OR wait for FCM
```

**Ne auto-restart** - tai Android'o sprendimas!

---

## Naujos funkcijos

### 🚨 Emergency Recovery Button (Manual Only)

UI'je pridėtas **Recovery** mygtukas:
- Atlieka pilną serviso recovery **tik rankiniu būdu**
- Išvalo stuck state
- Leidžia paleisti servisą iš naujo

**Naudoti tik jei servisas tikrai užstrigęs, NE kai Android normaliai sustabdė!**

### 📊 Health Monitoring (No Auto-Restart)

Service health check:
- Monitorina serviso būseną kas 30 sekundžių
- **Tik atnaujina UI** - nebe auto-restart
- Logina: `SERVICE_STOPPED_BY_SYSTEM`
- FCM pažadins kai reikia

Visi events logginami:
- `CRASH_RECOVERY` - crash state cleared
- `FULL_RECOVERY_START` - recovery pradėtas (manual)
- `FULL_RECOVERY_COMPLETE` - recovery baigtas (manual)
- `SERVICE_NOT_RUNNING` - servisas sustojo (normal)
- `SERVICE_STOPPED_BY_SYSTEM` - Android sustabdė (normal)

---

## Testavimas

### Testuoti Normal Stop (Tai NORMALU - Ne Crash):

1. **Leisti Android sustabdyti**:
   - Laukti kelias valandas
   - Android sustabdys dėl battery optimization
   - **Tai NORMALU** ✅

2. **Tikrinti FCM wake-up**:
   ```bash
   # Siųsti test FCM per Miltegona Manager
   # Arba per Supabase console
   ```
   - Servisas turėtų pakilti
   - Atidaryti vartus

3. **UI state**:
   - Atidaryti app
   - Turėtų rodyti "Service not running"
   - **Tai NORMALU** ✅

### Testuoti Real Crash (Tikras crash):

1. **Force kill app**:
   ```bash
   adb shell am force-stop com.example.gate_control_device
   ```

2. **Atidaryti app**:
   - Crash state cleared automatically
   - UI rodo "Service not running"
   - **Nenaudoti Emergency Recovery** - tiesiog paleisti servisą

3. **Tikrinti logs**:
   - `CRASH_RECOVERY` - cleared stuck state
   - `SERVICE_NOT_RUNNING` - status logged

### Testuoti Fast Shutdown:

1. Paspauskite **"Sustabdyti servisą"**
2. Patikrinkite logs - turėtų sustoti per < 3 sekundes
3. Neturėtų būti timeout errors

---

## Patobulinimai

### Before ❌
- Servisas galėjo "užsikabinti" stabdymo metu
- Android timeout → process kill → **CRASH**
- Po crash nebegalima pasileisti
- Query timeout 10 sekundžių
- Aggressive auto-restart konfliktuoja su Android

### After ✅
- **Fast shutdown** (< 3 sekundės) - **NO CRASH**
- **Crash state clearing** app startup
- **Emergency recovery** button (manual only)
- **Query timeout** 5 sekundės
- **NO auto-restart** - leidžiama Android'ui sustabdyti
- **FCM wake-up** veikia properly
- **Proper cleanup** visų operacijų

---

## Monitoringas

**Service Logs** ekrane matysite:
- ✅ `SERVICE_STOP_REQUESTED` - user pressed stop (normal)
- ✅ `SERVICE_STOPPED` - servisas sustojo cleanly (normal)
- ✅ `SERVICE_NOT_RUNNING` - servisas neveikia (normal - FCM pažadins)
- ✅ `SERVICE_STOPPED_BY_SYSTEM` - Android sustabdė (normal - battery)
- ⚠️ `CRASH_RECOVERY` - crash state cleared (app startup)
- 🚨 `FULL_RECOVERY_START/COMPLETE` - manual recovery (emergency only)

**Svarbu**: Dauguma "not running" yra **NORMALU** - ne crash!

---

## Svarbu

### Kai servisas sustoja:
1. **Nepanikoj** - tai gali būti normalus stop
2. **Pažiūrėti logs** - Service Logs ekrane
3. **Jei neina paleisti** - naudoti Emergency Recovery
4. **Po recovery** - laukti 2 sekundes prieš paleidžiant

### Android 12+ Restrictions:
- FGS turi sustoti **greitai** arba system kill
- Negalima ilgų operacijų shutdown metu
- **Always check `_isShuttingDown` flag**

---

## Greitas Fix Checklist

✅ `_isShuttingDown` flag visiems handler'iams  
✅ Query timeout ≤ 5 sekundės  
✅ Stop logging ≤ 500ms timeout  
✅ Crash state clearing app startup  
✅ Emergency recovery button (manual only)  
✅ Health monitoring (no auto-restart)  
✅ **Leisti Android'ui sustabdyti servisą - tai NORMALU**  
✅ **FCM pažadins servisą kai reikia**  

---

## Rezultatas

**Problema išspręsta**:
- ✅ Servisas sustoja greitai (< 3s) - **NĖRA CRASH**
- ✅ Nėra timeout crashes - Android gali švelniai sustabdyti
- ✅ Gali pasileisti po crash (crash state clearing)
- ✅ Manual recovery mechanizmas (emergency only)
- ✅ **FCM wake-up veikia** - servisas pabudinamas kai reikia
- ✅ **Android lifecycle respected** - battery optimization veikia

**Filosofija**: 
- Servisas **ne running 24/7** - tai ne būtina
- **FCM pažadina** kai reikia vartų atidaryti
- **Android lifecycle respektavimas** - geriau battery life

**Versija**: v1.1.4 - Crash Recovery & Lifecycle Respect  
**Data**: 2026-01-30
