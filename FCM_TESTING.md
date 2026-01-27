# FCM Testing Guide

## Kaip patikrinti ar FCM veikia

### 1. Gauti FCM Token iš app

**App UI metodas:**
1. Atidaryk Gate Control app
2. Paspausk mygtuką "Kopijuoti FCM Token"
3. Token nukopijuotas į clipboard

**Logs metodas:**
```bash
flutter run
# Paieškokite loge:
# 🔑 FCM Token: xxxxxx...
```

### 2. Patikrinti ar token užregistruotas Supabase

```sql
-- Supabase SQL Editor
SELECT * FROM device_tokens WHERE device_id = 'default';
```

Turėtumėte matyti:
- `device_id`: default
- `fcm_token`: jūsų token
- `updated_at`: recent timestamp

### 3. Siųsti test FCM pranešimą

**PowerShell (Windows):**
```powershell
.\test_fcm.ps1 "YOUR_FCM_TOKEN_HERE"
```

**Su komanda:**
```powershell
.\test_fcm.ps1 "YOUR_FCM_TOKEN_HERE" -Command "open_gate"
```

**cURL (Cross-platform):**
```bash
curl -X POST https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5enR0enF2YmVzY2RwaWh2eWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTQ5OTMsImV4cCI6MjA2OTEzMDk5M30.OpIs65YShePgpV2KG4Uqjpkj3RDNv12Rj9eLudveWQY" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "default",
    "command": "test",
    "commandId": 12345
  }'
```

### 4. Ką tikėtis

**Jei FCM veikia:**
- ✅ App status bar: notification icon
- ✅ App foreground: Green snackbar "🔔 FCM gautas: test"
- ✅ Console logs: "🔥 Background message received" arba "🔔 Foreground FCM message"
- ✅ Edge Function response: `{ "success": true, "messageId": "..." }`

**Jei neveikia:**
- ❌ Nėra notification
- ❌ Edge Function error: "No FCM token found" arba "Failed to send"
- ❌ Check device_tokens table - ar token yra?

### 5. Debugging steps

**Jei FCM negaunamas:**

1. **Patikrinti FCM permission:**
   ```
   App UI → "Patikrinti leidimus" mygtukas
   ```

2. **Patikrinti token Supabase:**
   ```sql
   SELECT fcm_token, updated_at FROM device_tokens WHERE device_id = 'default';
   ```

3. **Patikrinti Edge Function logs:**
   ```bash
   # Supabase Dashboard → Functions → gate-notify → Logs
   ```

4. **Regeneruoti FCM token:**
   - Uninstall app
   - Reinstall app
   - Naujas token bus sugeneruotas

5. **Patikrinti Firebase Console:**
   - Firebase Console → Project settings → Cloud Messaging
   - Ar service account JSON teisingas?

### 6. Test su Miltegona_Manager

**Per UI:**
1. Miltegona_Manager → Paspausk "VARTAI" mygtuką
2. Turėtų:
   - Įrašyti į gate_commands
   - Trigger iškviesti Edge Function
   - Edge Function siųsti FCM
   - App gauti FCM
   - Service check pending commands
   - Paskambinti į +37069922987

**Per SQL:**
```sql
-- Rankiniu būdu insert command
INSERT INTO gate_commands (command, status, device_id)
VALUES ('open_gate', 'pending', 'default');

-- Patikrinti ar status pasikeitė į completed
SELECT * FROM gate_commands 
WHERE device_id = 'default' 
ORDER BY created_at DESC 
LIMIT 5;
```

### 7. Diagnostics checklist

- [ ] FCM token matomas App UI
- [ ] FCM token užregistruotas device_tokens table
- [ ] Edge Function veikia (test_fcm.ps1 returns success)
- [ ] App gauna FCM foreground (snackbar message)
- [ ] App gauna FCM background (log message)
- [ ] Service tikrina pending commands
- [ ] Phone call veikia (actual call initiated)
- [ ] Status updated to completed

### Common Issues

**"No FCM token found":**
- App neužregistravo token
- Restart app ir palauk 5 sekundes
- Check device_tokens table

**"Failed to send notification":**
- Firebase credentials issue
- Check Edge Function logs
- Verify service account JSON in Edge Function

**FCM gautas bet nepaskambina:**
- Service neveikia - check "Paleisti servisą"
- Permission issues - check phone permission
- Command not pending - check gate_commands table

**FCM negaunamas po force stop:**
- Android limitation - turi atidaryti app rankiniu būdu
- Po atidarimo service auto-start per 2s

