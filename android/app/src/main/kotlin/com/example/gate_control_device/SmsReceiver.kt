package com.example.gate_control_device

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.app.Activity
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import android.os.Build
import androidx.core.content.ContextCompat

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SmsReceiver", "📱 ==========================================")
        Log.d("SmsReceiver", "📱 Broadcast received!")
        Log.d("SmsReceiver", "📱 Action: ${intent.action}")
        
        // Check SMS permission
        val smsPermission = ContextCompat.checkSelfPermission(context, android.Manifest.permission.SEND_SMS)
        Log.d("SmsReceiver", "📱 SMS Permission: ${if (smsPermission == PackageManager.PERMISSION_GRANTED) "GRANTED" else "DENIED"}")
        
        // Log all extras
        val extras = intent.extras
        if (extras != null) {
            Log.d("SmsReceiver", "📱 Extras count: ${extras.size()}")
            for (key in extras.keySet()) {
                Log.d("SmsReceiver", "📱 Extra: $key = ${extras.get(key)}")
            }
        }
        
        if (intent.action == "com.example.gate_control_device.SEND_SMS") {
            var phoneNumber = intent.getStringExtra("phone_number")
            var message = intent.getStringExtra("message")
            
            Log.d("SmsReceiver", "📱 Phone: $phoneNumber")
            Log.d("SmsReceiver", "📱 Message length: ${message?.length}")
            
            if (phoneNumber != null && message != null) {
                try {
                    // Get default SMS subscription ID for dual SIM phones
                    var smsManager: SmsManager
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                        try {
                            // Get the default SMS subscription ID (what user configured in settings)
                            val defaultSubId = SubscriptionManager.getDefaultSmsSubscriptionId()
                            Log.d("SmsReceiver", "📱 Default SMS subscription ID: $defaultSubId")
                            
                            if (defaultSubId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    smsManager = context.getSystemService(SmsManager::class.java).createForSubscriptionId(defaultSubId)
                                } else {
                                    @Suppress("DEPRECATION")
                                    smsManager = SmsManager.getSmsManagerForSubscriptionId(defaultSubId)
                                }
                                Log.d("SmsReceiver", "📱 Using default SMS subscription")
                            } else {
                                Log.d("SmsReceiver", "📱 No default SMS subscription, trying active subscriptions")
                                val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                                val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList
                                
                                if (activeSubscriptions != null && activeSubscriptions.isNotEmpty()) {
                                    val subId = activeSubscriptions[0].subscriptionId
                                    Log.d("SmsReceiver", "📱 Using first active subscription: $subId")
                                    Log.d("SmsReceiver", "📱 Carrier: ${activeSubscriptions[0].carrierName}")
                                    
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                        smsManager = context.getSystemService(SmsManager::class.java).createForSubscriptionId(subId)
                                    } else {
                                        @Suppress("DEPRECATION")
                                        smsManager = SmsManager.getSmsManagerForSubscriptionId(subId)
                                    }
                                } else {
                                    Log.d("SmsReceiver", "📱 No active subscriptions, using default SmsManager")
                                    smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                        context.getSystemService(SmsManager::class.java)
                                    } else {
                                        @Suppress("DEPRECATION")
                                        SmsManager.getDefault()
                                    }
                                }
                            }
                        } catch (e: SecurityException) {
                            Log.e("SmsReceiver", "📱 SecurityException: ${e.message}")
                            smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                context.getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        smsManager = SmsManager.getDefault()
                    }
                    
                    // Log the actual subscription ID being used
                    try {
                        Log.d("SmsReceiver", "📱 SmsManager subscriptionId: ${smsManager.subscriptionId}")
                    } catch (e: Exception) {
                        Log.d("SmsReceiver", "📱 Could not get subscriptionId from SmsManager")
                    }
                    
                    Log.d("SmsReceiver", "📱 Calling sendTextMessage to: $phoneNumber")
                    
                    // Create PendingIntents for delivery confirmation
                    val sentIntent = Intent("SMS_SENT_$phoneNumber")
                    val sentPI = PendingIntent.getBroadcast(
                        context, 
                        phoneNumber.hashCode(), 
                        sentIntent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                    
                    // Register a one-time receiver for this specific SMS
                    val sentReceiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context?, i: Intent?) {
                            when (resultCode) {
                                Activity.RESULT_OK -> {
                                    Log.d("SmsReceiver", "✅✅✅ SMS SENT TO CARRIER SUCCESSFULLY!")
                                }
                                SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                                    Log.e("SmsReceiver", "❌ CARRIER REJECTED: GENERIC FAILURE")
                                }
                                SmsManager.RESULT_ERROR_NO_SERVICE -> {
                                    Log.e("SmsReceiver", "❌ CARRIER REJECTED: NO SERVICE (check signal)")
                                }
                                SmsManager.RESULT_ERROR_NULL_PDU -> {
                                    Log.e("SmsReceiver", "❌ CARRIER REJECTED: NULL PDU")
                                }
                                SmsManager.RESULT_ERROR_RADIO_OFF -> {
                                    Log.e("SmsReceiver", "❌ CARRIER REJECTED: RADIO OFF (airplane mode?)")
                                }
                                else -> {
                                    Log.e("SmsReceiver", "❌ CARRIER REJECTED: UNKNOWN ERROR $resultCode")
                                }
                            }
                            try {
                                ctx?.unregisterReceiver(this)
                            } catch (e: Exception) {
                                // Already unregistered
                            }
                        }
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        context.registerReceiver(sentReceiver, IntentFilter("SMS_SENT_$phoneNumber"), Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        context.registerReceiver(sentReceiver, IntentFilter("SMS_SENT_$phoneNumber"))
                    }
                    
                    if (message.length > 160) {
                        val parts = smsManager.divideMessage(message)
                        Log.d("SmsReceiver", "📱 Sending multipart SMS (${parts.size} parts)")
                        val sentIntents = ArrayList<PendingIntent>()
                        for (i in 0 until parts.size) {
                            sentIntents.add(sentPI)
                        }
                        smsManager.sendMultipartTextMessage(phoneNumber, null, parts, sentIntents, null)
                    } else {
                        Log.d("SmsReceiver", "📱 Sending single SMS...")
                        smsManager.sendTextMessage(phoneNumber, null, message, sentPI, null)
                    }
                    Log.d("SmsReceiver", "✅ sendTextMessage() completed without exception")
                } catch (e: SecurityException) {
                    Log.e("SmsReceiver", "❌ SecurityException: ${e.message}")
                    e.printStackTrace()
                } catch (e: Exception) {
                    Log.e("SmsReceiver", "❌ Exception: ${e.message}")
                    e.printStackTrace()
                }
            } else {
                Log.e("SmsReceiver", "❌ Phone number or message is null")
            }
        }
        Log.d("SmsReceiver", "📱 ==========================================")
    }
}
