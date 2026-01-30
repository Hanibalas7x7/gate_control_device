import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'service_logger.dart';

/// Helper class for recovering from service crashes and stuck states
class ServiceRecoveryHelper {
  /// Clear any stuck service state and prepare for fresh start
  /// Call this in main() before checking service status
  static Future<bool> clearCrashState() async {
    try {
      print('🔧 ServiceRecoveryHelper: Clearing crash state...');
      
      // Try to stop any stuck service instances with timeout
      try {
        await FlutterForegroundTask.stopService().timeout(Duration(seconds: 2));
      } catch (timeoutError) {
        print('⚠️ Service stop timeout during crash recovery');
      }
      
      print('✅ Crash state cleared successfully');
      await ServiceLogger.log('CRASH_RECOVERY', details: 'Cleared stuck service state');
      
      // Wait for system to process
      await Future.delayed(Duration(milliseconds: 500));
      
      return true;
    } catch (e) {
      print('⚠️ Error during crash recovery: $e');
      await ServiceLogger.log('CRASH_RECOVERY_ERROR', details: 'Error: $e');
      return false;
    }
  }
  
  /// Check if service crashed and needs recovery
  static Future<bool> needsRecovery() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      
      if (!isRunning) {
        print('⚠️ Service not running - may need recovery');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking service status: $e');
      return true; // Assume needs recovery on error
    }
  }
  
  /// Perform full recovery - stop stuck service and prepare for restart
  static Future<void> performFullRecovery() async {
    print('🚨 ========================================');
    print('🚨 PERFORMING FULL SERVICE RECOVERY');
    print('🚨 ========================================');
    
    await ServiceLogger.log('FULL_RECOVERY_START', details: 'Initiating full service recovery');
    
    // Step 1: Force stop any running service
    try {
      print('🛑 Step 1: Force stopping service...');
      try {
        await FlutterForegroundTask.stopService().timeout(Duration(seconds: 3));
      } catch (timeoutError) {
        print('⚠️ Force stop timeout');
      }
      await Future.delayed(Duration(seconds: 1));
    } catch (e) {
      print('⚠️ Force stop error: $e');
    }
    
    // Step 2: Clear crash state
    await clearCrashState();
    
    // Step 3: Wait for system cleanup
    print('⏳ Step 2: Waiting for system cleanup...');
    await Future.delayed(Duration(seconds: 2));
    
    print('✅ Full recovery complete - ready for restart');
    await ServiceLogger.log('FULL_RECOVERY_COMPLETE', details: 'Service ready for restart');
    
    print('🚨 ========================================');
  }
}
