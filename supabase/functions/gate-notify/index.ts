// Gate Notify Edge Function v1.1
// FCM V1 API implementation with Service Account authentication

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts"

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

    // Get Firebase Service Account credentials
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!
    const serviceAccount = JSON.parse(serviceAccountJson)
    
    // Generate OAuth2 access token using JWT
    const jwt = await create(
      { alg: "RS256", typ: "JWT" },
      {
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: getNumericDate(0),
        exp: getNumericDate(60 * 60), // 1 hour
      },
      await crypto.subtle.importKey(
        "pkcs8",
        new TextEncoder().encode(serviceAccount.private_key),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
      )
    )
    
    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })
    
    const { access_token } = await tokenResponse.json()
    
    if (!access_token) {
      console.error('❌ Failed to get access token')
      return new Response(
        JSON.stringify({ error: 'Failed to authenticate with Firebase' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log('✅ Got OAuth2 access token')
    
    // Send FCM V1 API notification
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    
    const fcmPayload = {
      message: {
        token: tokenData.fcm_token,
        data: {
          commandId: commandData.id.toString(),
          command,
          phoneNumber: phoneNumber || '',
          message: message || '',
        },
        android: {
          priority: 'high',
        },
      },
    }

    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${access_token}`,
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
