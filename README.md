# Gate Control Device v1.1.4

**Vartų valdymo sistema su FCM wake-up ir crash recovery.**

## 📱 Funkcionalumas

- ✅ Foreground service klausosi Supabase komandų
- ✅ FCM wake-up mechanizmas (high-priority notifications)
- ✅ Auto phone call į +37069922987
- ✅ SMS siuntimas (transparent activity)
- ✅ Crash recovery & fast shutdown
- ✅ Service lifecycle respektavimas

## 📚 Dokumentacija

### Vartotojui:
- **[SERVICE_LIFECYCLE_PHILOSOPHY.md](SERVICE_LIFECYCLE_PHILOSOPHY.md)** - Kaip sistema veikia, kada servisas "not running" yra normalu

### Programuotojui:
- **[CRASH_RECOVERY_FIX.md](CRASH_RECOVERY_FIX.md)** - Kas buvo crash'as ir kaip išspręstas
- **[TECHNICAL_CRASH_ANALYSIS.md](TECHNICAL_CRASH_ANALYSIS.md)** - Gili technine analizė, diagnostika, native logging

### Legacy:
- [FCM_FGS_ANALYSIS.md](FCM_FGS_ANALYSIS.md) - v1.0 FCM wake-up implementacija
- [FCM_RESTART_FIX.md](FCM_RESTART_FIX.md) - v1.1 ServiceStartActivity fix
- [FCM_TESTING.md](FCM_TESTING.md) - FCM testavimo procedūros

## 🚀 Versijos

### v1.1.4 (Current) - 2026-01-30
- ✅ Fixed `ForegroundServiceDidNotStopInTimeException` crash
- ✅ Fast shutdown (< 3s) su `_isShuttingDown` flag
- ✅ Crash state clearing on app startup
- ✅ No aggressive auto-restart
- ✅ Emergency recovery button (manual)
- ⚠️ Beta status - monitor production

### v1.1.3
- FCM wake-up + polling hybrid
- ServiceStartActivity transparent launch

### v1.0
- Basic foreground service + FCM

## ⚙️ Setup

### 1. Dependencies
```bash
flutter pub get
```

### 2. Firebase Setup
- `firebase_options.dart` - auto-generated
- `google-services.json` - Android

### 3. Supabase
- URL: `https://xyzttzqvbescdpihvyfu.supabase.co`
- Tables: `gate_commands`, `device_tokens`

### 4. Permissions
```xml
CALL_PHONE, SEND_SMS, FOREGROUND_SERVICE, 
FOREGROUND_SERVICE_DATA_SYNC, POST_NOTIFICATIONS,
REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
```

## 🏗️ Build

```bash
# Debug
flutter run

# Release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

## 🐛 Diagnostika

### Jei Crash Kartojasi:

1. **Žiūrėti Service Logs** - app UI "Service Logs" button
2. **Check logcat**:
   ```bash
   adb logcat | grep -E "(SERVICE_|GATE_|FCM_)"
   ```
3. **Skaityk**: [TECHNICAL_CRASH_ANALYSIS.md](TECHNICAL_CRASH_ANALYSIS.md)
4. **Native logging** - jei reikia gilesnės diagnostikos

### Emergency Recovery:

1. App UI → "Recovery" button (raudonas)
2. Arba force stop:
   ```bash
   adb shell am force-stop com.example.gate_control_device
   ```

## 🎯 Architektūra

```
[Supabase gate_commands] ←→ [Foreground Service]
                                     ↓
                              [Phone Call API]
                              [SMS API]
                                     ↑
[FCM (wake-up)] → [ServiceStartActivity] → [Service Start]
```

### Service States:

- **Running** - aktyvus, tikrina komandas kas 60s
- **Stopped** - Android sustabdė (battery) - **NORMALU**
- **Waking** - FCM pažadina per ServiceStartActivity

## 📊 Monitoring

### Normal Behavior Logs:
- `SERVICE_STARTED` - ✅ User paleido
- `SERVICE_STOPPED` - ✅ User sustabdė
- `SERVICE_NOT_RUNNING` - ✅ Android sustabdė (normalu)
- `SERVICE_STOPPED_BY_SYSTEM` - ✅ Battery optimization

### Recovery Logs:
- `CRASH_RECOVERY` - ⚠️ Cleared stuck state
- `FULL_RECOVERY_START` - 🚨 Manual recovery

### Command Logs:
- `GATE_COMMAND` - 📞 Skambučio komanda
- `SMS_COMMAND` - 📱 SMS komanda
- `FCM_RECEIVED` - 🔥 FCM gautas

## ⚠️ Known Limitations

1. **FCM wake-up** - ne 100% garantuotas:
   - OEM battery restrictions
   - Doze mode delays
   - Network issues
   
2. **ServiceStartActivity** - gali būti blokuojama:
   - Android 12+ background restrictions
   - Fallback: notification + user tap

3. **dataSync FGS type** - rizikingas ilgam running:
   - Skirtas sync, ne commands
   - Griežtesni timeout reikalavimai

## 🔄 Future Improvements

1. **Native guard** - `isStopping` Kotlin flag
2. **onTimeout() handler** - explicit stopSelf()
3. **Notification fallback** - primary instead of silent start
4. **FGS type review** - dataSync → phoneCall?
5. **Native logging** - diagnostics

## 📞 Support

- GitHub Issues
- Service Logs ekranas app UI
- [TECHNICAL_CRASH_ANALYSIS.md](TECHNICAL_CRASH_ANALYSIS.md) - troubleshooting

---

**Status**: Beta - Monitor Production  
**Patikimumas**: ~80% silent wake-up, 100% su user tap

