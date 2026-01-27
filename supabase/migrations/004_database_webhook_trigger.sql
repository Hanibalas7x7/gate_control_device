-- Database Webhook Trigger for gate_commands
-- Automatiškai kviečia Edge Function kai atsiranda naujas pending įrašas

-- 1. Sukurti funkciją, kuri kviečia Edge Function
CREATE OR REPLACE FUNCTION notify_gate_command()
RETURNS TRIGGER AS $$
DECLARE
  request_id bigint;
BEGIN
  -- Kviesti Edge Function tik jei status = 'pending'
  IF NEW.status = 'pending' THEN
    -- Kviečiame Edge Function per pg_net extension
    SELECT net.http_post(
      url := 'https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5enR0enF2YmVzY2RwaGh2eWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTQ5OTMsImV4cCI6MjA2OTEzMDk5M30.OpIs65YShePgpV2KG4Uqjpkj3RDNv12Rj9eLudveWQY'
      ),
      body := jsonb_build_object(
        'command', NEW.command,
        'deviceId', NEW.device_id,
        'commandId', NEW.id
      )
    ) INTO request_id;
    
    RAISE LOG 'Sent FCM notification for command ID: %, request_id: %', NEW.id, request_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Sukurti trigger
DROP TRIGGER IF EXISTS gate_command_webhook ON gate_commands;
CREATE TRIGGER gate_command_webhook
  AFTER INSERT ON gate_commands
  FOR EACH ROW
  EXECUTE FUNCTION notify_gate_command();

-- 3. Enable pg_net extension (jei dar neįjungta)
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- PASTABA: Reikia pakeisti service_role key į tikrą!
-- Gauti: Supabase Dashboard → Settings → API → service_role key
