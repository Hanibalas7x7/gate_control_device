# Gate Notify Edge Function

Šis Supabase Edge Function priima gate komandas ir siunčia FCM (Firebase Cloud Messaging) notifikacijas į Android įrenginius.

## Setup

1. Deploy function:
```bash
supabase functions deploy gate-notify
```

2. Nustatyti environment variables:
```bash
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key_here
```

3. Sukurti `device_tokens` lentelę:
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

-- Policy to allow service role to manage tokens
CREATE POLICY "Service role can manage tokens"
  ON device_tokens
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy to allow authenticated users to insert/update their own tokens
CREATE POLICY "Users can manage their own tokens"
  ON device_tokens
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
```

4. Atnaujinti `gate_commands` lentelę (jei reikia):
```sql
ALTER TABLE gate_commands ADD COLUMN IF NOT EXISTS device_id TEXT DEFAULT 'default';
```

## Usage

### Atidaryti vartus:
```bash
curl -X POST https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "command": "open_gate",
    "deviceId": "device_1"
  }'
```

### Siųsti SMS:
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

## Kaip veikia

1. Edge Function priima komandą
2. Įrašo komandą į `gate_commands` lentelę su `status: 'pending'`
3. Gauna FCM token iš `device_tokens` lentelės
4. Siunčia FCM notifikaciją į Android įrenginį
5. Android įrenginys gauna notifikaciją ir atlieka veiksmą
6. Atnaujina komandos statusą į `completed` arba `failed`
