# ⚡ Service Lifecycle Philosophy

## Svarbiausias Principas

**Leisti Android'ui sustabdyti servisą - tai NORMALU, NE CRASH!**

FCM pažadins servisą kai reikia atidaryti vartus.

---

## Architektūra

### Traditional Approach (BLOGAI) ❌

```
Service Running 24/7
   ↓
Android tries to stop (battery)
   ↓
App resists: auto-restart
   ↓
Android force kills → CRASH
   ↓
App can't restart (stuck state)
```

**Rezultatas**: Crash, battery drain, conflicts su Android

---

### New Approach (GERAI) ✅

```
Service Running
   ↓
Android stops (battery optimization) - NORMALU
   ↓
Service stops cleanly (< 3s) - NĖRA CRASH
   ↓
FCM message received (vartai atidaryti)
   ↓
ServiceStartActivity wakes service
   ↓
Service processes command
   ↓
(Optional) Android stops again - NORMALU
```

**Rezultatas**: Nėra crashes, geresnis battery, Android lifecycle respected

---

## Kada Servisas Veikia

### ✅ Running When Needed:
- User manually started service
- FCM message received → ServiceStartActivity → service starts
- Service processing command
- Within 24-48h after start (depends on Android settings)

### ✅ Stopped (NORMALU):
- Android battery optimization kicks in
- Phone idle for long time
- Android decides to save RAM
- User manually stopped

**Tai NE CRASH** - tai Android lifecycle!

---

## FCM Wake-Up Mechanizmas

### How It Works:

1. **Vartai reikia atidaryti**:
   - Miltegona Manager sends FCM
   - OR Supabase Edge Function sends FCM

2. **FCM received**:
   - `_firebaseMessagingBackgroundHandler` runs
   - Checks if service running

3. **If service NOT running**:
   - Launches `ServiceStartActivity`
   - Activity starts service
   - Activity closes automatically

4. **Service processes command**:
   - Skambina į +37069922987
   - Marks command as completed

5. **(Optional) Service stops later**:
   - Android stops after few hours
   - **Tai NORMALU** - FCM pažadins vėl

---

## Battery Optimization

### Why Android Stops Services:

- **Battery Saver Mode** - system aggressively stops background services
- **Doze Mode** - phone idle, all background limited
- **Memory Pressure** - RAM needed for other apps
- **Long Running** - service running > 24h without user interaction

### Why This Is GOOD:

- ✅ **Better battery life** - servisas ne 24/7
- ✅ **Less resource usage** - RAM released when not needed
- ✅ **Respects user settings** - battery optimization works
- ✅ **No conflicts** - Android happy = no crashes

---

## Kai Naudoti Emergency Recovery

### ✅ USE Recovery When:

1. **Service won't start at all**:
   - Press "Paleisti servisą" → nothing happens
   - Error messages in logs
   - UI shows "running" but notification not visible

2. **UI desync**:
   - UI says "running" but service actually stopped
   - Press "Sustabdyti" → nothing happens

3. **After real crash**:
   - App force closed
   - System killed app (not just service)

### ❌ DON'T USE When:

1. **Service normally stopped**:
   - Notification gone after few hours
   - UI shows "not running" correctly
   - **Just press "Paleisti servisą"** - ne recovery

2. **Android stopped for battery**:
   - Phone was idle long time
   - Battery saver active
   - **Tai NORMALU** - ne crash

3. **After FCM wake-up**:
   - Service ran, processed command, stopped
   - **Tai NORMALU** - FCM pažadins vėl

---

## Logging Strategy

### What Logs Mean:

| Log Message | Meaning | Normal? |
|------------|---------|---------|
| `SERVICE_STARTED` | Service started by user/FCM | ✅ Normal |
| `SERVICE_STOP_REQUESTED` | User pressed stop | ✅ Normal |
| `SERVICE_STOPPED` | Service stopped cleanly | ✅ Normal |
| `SERVICE_NOT_RUNNING` | App opened, service not running | ✅ Normal (FCM pažadins) |
| `SERVICE_STOPPED_BY_SYSTEM` | Android stopped service | ✅ Normal (battery) |
| `CRASH_RECOVERY` | Cleared stuck state on app start | ⚠️ Recovery action |
| `FULL_RECOVERY_START` | Manual recovery initiated | 🚨 Emergency only |

**Dauguma "not running" logs yra NORMALU** - ne crash!

---

## User Experience

### Normal Day:

```
Morning:
  - User opens app
  - Presses "Paleisti servisą"
  - Service starts ✅

Midday:
  - FCM received (vartai)
  - Service wakes up ✅
  - Gate opens ✅
  - (Service may stop after)

Evening:
  - FCM received (vartai)
  - Service wakes up ✅
  - Gate opens ✅

Night:
  - Android stops service (battery)
  - Tai NORMALU ✅
```

**User nematys jokių problemų** - vartai atidaromi visada!

---

## Summary

### Key Points:

1. ✅ **Service ne 24/7** - tai ne būtina
2. ✅ **FCM pažadina** kai reikia
3. ✅ **Android lifecycle respected** - nėra conflicts
4. ✅ **No crashes** - clean shutdown
5. ✅ **Better battery** - service stops when not needed
6. ✅ **Emergency recovery** - manual only, kai tikrai reikia

### Philosophy:

> **Geriau leisti Android'ui sustabdyti servisą švelniai,  
> nei kovoti su sistema ir gauti crash.**

**FCM wake-up yra patikimas** - vartai atsidarys visada!

---

**Versija**: v1.1.4 - Crash Recovery & Lifecycle Respect  
**Data**: 2026-01-30  
**Status**: Production Ready ✅
