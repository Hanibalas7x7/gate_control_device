package com.example.gate_control_device

import android.content.Context
import android.content.Intent
import android.util.Log

object SmsHelper {
    fun sendSmsBroadcast(context: Context, phoneNumber: String, message: String) {
        try {
            Log.d("SmsHelper", "📱 Sending broadcast for SMS")
            Log.d("SmsHelper", "📱 Phone: $phoneNumber")
            
            val intent = Intent("com.example.gate_control_device.SEND_SMS")
            intent.putExtra("phone_number", phoneNumber)
            intent.putExtra("message", message)
            intent.setPackage(context.packageName)
            
            context.sendBroadcast(intent)
            Log.d("SmsHelper", "✅ Broadcast sent")
        } catch (e: Exception) {
            Log.e("SmsHelper", "❌ Error sending broadcast: ${e.message}")
        }
    }
}
