package com.example.gate_control_device

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Transparent activity that automatically starts the foreground service
 * and immediately closes itself. This bypasses Android 12+ FGS restrictions
 * because activities can be started from FCM and can start FGS.
 */
class ServiceStartActivity : Activity() {
    
    companion object {
        private const val TAG = "ServiceStartActivity"
        private const val CHANNEL = "com.example.gate_control_device/service_control"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "🚀 ServiceStartActivity created - starting service automatically")
        
        try {
            // Send broadcast to all Flutter engines to start service
            val serviceIntent = Intent("START_FOREGROUND_SERVICE_ACTION")
            sendBroadcast(serviceIntent)
            Log.d(TAG, "✅ Sent broadcast to start service")
            
            // Also try to bring MainActivity to foreground which will auto-start service
            val mainIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("auto_start_service", true)
                putExtra("close_after_start", true) // ✅ Close MainActivity after starting service
            }
            
            if (mainIntent != null) {
                startActivity(mainIntent)
                Log.d(TAG, "✅ Started MainActivity - service will auto-start and app will close")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start service: ${e.message}", e)
        }
        
        // Close this activity after a short delay
        Handler(Looper.getMainLooper()).postDelayed({
            Log.d(TAG, "🔚 Closing ServiceStartActivity")
            finish()
        }, 1000)
    }
}
