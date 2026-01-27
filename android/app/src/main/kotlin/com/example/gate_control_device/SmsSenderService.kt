package com.example.gate_control_device

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.telephony.SmsManager
import android.util.Log

class SmsSenderService : Service() {
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("SmsSenderService", "📱 Service started")
        
        val phoneNumber = intent?.getStringExtra("phone_number")
        val message = intent?.getStringExtra("message")
        
        Log.d("SmsSenderService", "📱 Phone: $phoneNumber")
        Log.d("SmsSenderService", "📱 Message length: ${message?.length}")
        
        if (phoneNumber != null && message != null) {
            try {
                val smsManager = SmsManager.getDefault()
                
                if (message.length > 160) {
                    val parts = smsManager.divideMessage(message)
                    Log.d("SmsSenderService", "📱 Sending multipart SMS (${parts.size} parts)")
                    smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                } else {
                    Log.d("SmsSenderService", "📱 Sending single SMS")
                    smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                }
                
                Log.d("SmsSenderService", "✅ SMS sent successfully")
            } catch (e: Exception) {
                Log.e("SmsSenderService", "❌ Error sending SMS: ${e.message}")
            }
        } else {
            Log.e("SmsSenderService", "❌ Phone or message is null")
        }
        
        // Stop service after sending
        stopSelf()
        
        return START_NOT_STICKY
    }
}
