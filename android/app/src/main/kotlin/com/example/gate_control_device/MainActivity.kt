package com.example.gate_control_device

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.gate_control_device/sms"
    private val TAG = "MainActivity"

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        val shouldClose = intent.getBooleanExtra("close_after_start", false)
        
        // Handle auto-start service from ServiceStartActivity
        if (intent.getBooleanExtra("auto_start_service", false)) {
            Log.d(TAG, "🚀 Auto-start service flag detected - notifying Flutter")
            
            // Wait for Flutter engine to be ready
            Handler(Looper.getMainLooper()).postDelayed({
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("autoStartService", null)
                }
                
                // Close activity after starting service
                if (shouldClose) {
                    Handler(Looper.getMainLooper()).postDelayed({
                        Log.d(TAG, "🔚 Closing MainActivity after service start")
                        moveTaskToBack(true) // Move to background instead of finish()
                    }, 2000) // Wait 2 seconds for service to start
                }
            }, 500)
        }
        
        // Handle service start request from ServiceStartActivity
        if (intent.action == "START_SERVICE_FROM_FCM") {
            Log.d(TAG, "🚀 Received START_SERVICE_FROM_FCM intent - triggering Flutter method")
            
            // Notify Flutter to start the service
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("startServiceFromNative", null)
            }
        }
    }

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
                "startServiceActivity" -> {
                    // Start transparent activity that will start the foreground service
                    try {
                        Log.d(TAG, "🚀 Starting ServiceStartActivity from Dart")
                        val intent = Intent(this, ServiceStartActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success("ServiceStartActivity started")
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Failed to start ServiceStartActivity: ${e.message}")
                        result.error("START_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
