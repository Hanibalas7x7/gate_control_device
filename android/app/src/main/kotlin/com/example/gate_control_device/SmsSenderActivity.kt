package com.example.gate_control_device

import android.app.Activity
import android.os.Bundle
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import android.widget.Toast
import androidx.core.content.ContextCompat
import android.Manifest
import android.content.pm.PackageManager

class SmsSenderActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Make activity transparent and non-interactive
        setFinishOnTouchOutside(false)
        
        val phoneNumber = intent.getStringExtra("phone_number")
        val message = intent.getStringExtra("message")
        
        Log.d("SmsSenderActivity", "📱 onCreate - Phone: $phoneNumber, Message length: ${message?.length}")
        
        if (phoneNumber != null && message != null) {
            sendSmsDirectly(phoneNumber, message)
        } else {
            Log.e("SmsSenderActivity", "❌ Missing phone number or message")
            finish()
        }
    }
    
    private fun sendSmsDirectly(phoneNumber: String, message: String) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) 
                != PackageManager.PERMISSION_GRANTED) {
                Log.e("SmsSenderActivity", "❌ SEND_SMS permission not granted")
                Toast.makeText(this, "SMS leidimas nesuteiktas", Toast.LENGTH_SHORT).show()
                finish()
                return
            }
            
            Log.d("SmsSenderActivity", "✅ SEND_SMS permission granted")
            
            // Get default SMS subscription for dual SIM support
            val subscriptionManager = getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val defaultSmsSubscriptionId = SubscriptionManager.getDefaultSmsSubscriptionId()
            
            Log.d("SmsSenderActivity", "📱 Default SMS subscription ID: $defaultSmsSubscriptionId")
            
            // Get SmsManager instance
            val smsManager = if (defaultSmsSubscriptionId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                SmsManager.getSmsManagerForSubscriptionId(defaultSmsSubscriptionId)
            } else {
                SmsManager.getDefault()
            }
            
            // Split message if too long
            val parts = smsManager.divideMessage(message)
            Log.d("SmsSenderActivity", "📱 Message split into ${parts.size} part(s)")
            
            // Send SMS
            if (parts.size == 1) {
                Log.d("SmsSenderActivity", "📤 Sending single SMS to: $phoneNumber")
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            } else {
                Log.d("SmsSenderActivity", "📤 Sending multipart SMS to: $phoneNumber")
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
            }
            
            Log.d("SmsSenderActivity", "✅ SMS sent successfully")
            Toast.makeText(this, "SMS išsiųstas", Toast.LENGTH_SHORT).show()
            
        } catch (e: Exception) {
            Log.e("SmsSenderActivity", "❌ Error sending SMS: ${e.message}", e)
            Toast.makeText(this, "SMS siuntimo klaida: ${e.message}", Toast.LENGTH_SHORT).show()
        } finally {
            // Close activity after a short delay to ensure SMS is sent
            window.decorView.postDelayed({
                finish()
            }, 500)
        }
    }
}
