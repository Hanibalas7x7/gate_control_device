-- Fix RLS policy for device_tokens
-- Allow anon users to upsert their own device tokens

-- Drop old restrictive policy
DROP POLICY IF EXISTS "Users can manage their own tokens" ON device_tokens;

-- Create new policy allowing anon users to insert/update
CREATE POLICY "Anyone can register device tokens"
  ON device_tokens
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Alternative: If you want more security (only allow inserts)
-- CREATE POLICY "Anyone can insert tokens"
--   ON device_tokens
--   FOR INSERT
--   TO anon, authenticated
--   WITH CHECK (true);

-- CREATE POLICY "Anyone can update their own tokens"
--   ON device_tokens
--   FOR UPDATE
--   TO anon, authenticated
--   USING (true)
--   WITH CHECK (true);
