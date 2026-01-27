// Gate Notify Edge Function
// Šis Edge Function priima užklausas ir siunčia FCM notifikaciją į Android įrenginį

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GateCommand {
  command: 'open_gate' | 'send_sms'
  phoneNumber?: string
  message?: string
  deviceId?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { command, phoneNumber, message, deviceId } = await req.json() as GateCommand

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Insert command into database
    const { data: commandData, error: dbError } = await supabase
      .from('gate_commands')
      .insert({
        command,
        phone_number: phoneNumber,
        message,
        device_id: deviceId || 'default',
        status: 'pending',
        created_at: new Date().toISOString(),
      })
      .select()
      .single()

    if (dbError) {
      console.error('Database error:', dbError)
      return new Response(
        JSON.stringify({ error: 'Failed to insert command', details: dbError.message }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('✅ Command inserted:', commandData)

    // Get FCM token from device_tokens table
    const { data: tokenData, error: tokenError } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('device_id', deviceId || 'default')
      .single()

    if (tokenError || !tokenData?.fcm_token) {
      console.error('❌ FCM token not found:', tokenError)
      return new Response(
        JSON.stringify({ 
          warning: 'Command inserted but FCM token not found',
          commandId: commandData.id 
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Send FCM notification
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')!
    
    const fcmPayload = {
      to: tokenData.fcm_token,
      priority: 'high',
      data: {
        commandId: commandData.id.toString(),
        command,
        phoneNumber: phoneNumber || '',
        message: message || '',
      },
    }

    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${fcmServerKey}`,
      },
      body: JSON.stringify(fcmPayload),
    })

    const fcmResult = await fcmResponse.json()
    
    if (!fcmResponse.ok) {
      console.error('❌ FCM send failed:', fcmResult)
      return new Response(
        JSON.stringify({ 
          error: 'FCM notification failed',
          commandId: commandData.id,
          details: fcmResult 
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('✅ FCM notification sent:', fcmResult)

    return new Response(
      JSON.stringify({ 
        success: true,
        commandId: commandData.id,
        fcmResult 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
