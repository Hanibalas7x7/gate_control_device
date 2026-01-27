package com.example.gate_control_device

import android.content.Intent
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.gate_control_device/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    
                    if (phoneNumber != null && message != null) {
                        try {
                            val smsManager = SmsManager.getDefault()
                            
                            if (message.length > 160) {
                                val parts = smsManager.divideMessage(message)
                                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                            }
                            
                            result.success("SMS sent successfully")
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone number or message is null", null)
                    }
                }
                "sendSmsBroadcast" -> {
                    // Send broadcast to SmsReceiver (works even when app is minimized)
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    
                    if (phoneNumber != null && message != null) {
                        try {
                            // Use helper to send broadcast from any context
                            SmsHelper.sendSmsBroadcast(applicationContext, phoneNumber, message)
                            result.success("Broadcast sent successfully")
                        } catch (e: Exception) {
                            result.error("BROADCAST_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone number or message is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
