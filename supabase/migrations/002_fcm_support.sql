-- Gate Control Device v1.1 - Database Migration
-- ================================================
-- Sukuriame naują device_tokens lentelę FCM token'ams
-- Atnaujiname gate_commands lentelę su device_id

-- 1. Sukurti device_tokens lentelę
CREATE TABLE IF NOT EXISTS device_tokens (
  id BIGSERIAL PRIMARY KEY,
  device_id TEXT UNIQUE NOT NULL,
  fcm_token TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Sukurti index greitesniam paieškai
CREATE INDEX IF NOT EXISTS idx_device_tokens_device_id ON device_tokens(device_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_fcm_token ON device_tokens(fcm_token);

-- 3. Enable RLS (Row Level Security)
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- 4. Policies
DROP POLICY IF EXISTS "Service role can manage tokens" ON device_tokens;
CREATE POLICY "Service role can manage tokens"
  ON device_tokens
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can manage their own tokens" ON device_tokens;
CREATE POLICY "Users can manage their own tokens"
  ON device_tokens
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 5. Pridėti device_id stulpelį gate_commands lentelėje (jei neegzistuoja)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gate_commands' 
    AND column_name = 'device_id'
  ) THEN
    ALTER TABLE gate_commands ADD COLUMN device_id TEXT DEFAULT 'default';
  END IF;
  
  -- Pridėti SMS laukus (compatibility su Miltegona_Manager)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gate_commands' 
    AND column_name = 'phone_number'
  ) THEN
    ALTER TABLE gate_commands ADD COLUMN phone_number VARCHAR(20);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gate_commands' 
    AND column_name = 'sms_message'
  ) THEN
    ALTER TABLE gate_commands ADD COLUMN sms_message TEXT;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gate_commands' 
    AND column_name = 'order_code'
  ) THEN
    ALTER TABLE gate_commands ADD COLUMN order_code VARCHAR(5);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gate_commands' 
    AND column_name = 'sms_type'
  ) THEN
    ALTER TABLE gate_commands ADD COLUMN sms_type TEXT;
  END IF;
END $$;

-- 6. Sukurti index device_id
CREATE INDEX IF NOT EXISTS idx_gate_commands_device_id ON gate_commands(device_id);

-- 7. Sukurti funkciją automatiniam updated_at atnaujinimui
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Pridėti trigger device_tokens lentelei
DROP TRIGGER IF EXISTS update_device_tokens_updated_at ON device_tokens;
CREATE TRIGGER update_device_tokens_updated_at
  BEFORE UPDATE ON device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 9. Sukurti view pending commands
CREATE OR REPLACE VIEW pending_commands AS
SELECT 
  id,
  command,
  phone_number,
  order_code,
  sms_type,
  device_id,
  status,
  created_at
FROM gate_commands
WHERE status = 'pending'
ORDER BY created_at ASC;

-- 10. Grant permissions on view
GRANT SELECT ON pending_commands TO authenticated;
GRANT SELECT ON pending_commands TO service_role;

-- Migration complete!
-- ==================
-- Dabar reikia:
-- 1. Deploy Edge Function: supabase functions deploy gate-notify
-- 2. Set FCM secret: supabase secrets set FCM_SERVER_KEY=your_key
-- 3. Test su Android įrenginiu
