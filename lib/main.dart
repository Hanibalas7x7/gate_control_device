import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'firebase_options.dart';
import 'gate_control_service.dart';
import 'service_logger.dart';
import 'service_logs_screen.dart';
import 'service_recovery_helper.dart';

// FCM background handler - ensures service stays alive and restarts if needed
// ⚠️ Android 12+ restrictions: FGS start from background only allowed if:
//    - High-priority FCM received within last few seconds
//    - User interaction occurred recently
//    - Other specific exemptions (exact alarm, etc.)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // CRITICAL: Log immediately to see if handler runs AT ALL
  print('🔥🔥🔥 ========================================');
  print('🔥🔥🔥 FCM BACKGROUND HANDLER TRIGGERED!!!');
  print('🔥🔥🔥 Time: ${DateTime.now()}');
  print('🔥🔥🔥 Data: ${message.data}');
  print('🔥🔥🔥 ========================================');
  
  // Log FCM receipt
  try {
    await ServiceLogger.logFCMReceived(message.data['command'] ?? 'unknown');
    print('🔥 Logged FCM receipt');
  } catch (e) {
    print('❌ Failed to log FCM: $e');
  }
  
  // Check if service is running
  try {
    final isRunning = await FlutterForegroundTask.isRunningService;
    print('🔥 Service running: $isRunning');
    
    if (isRunning) {
      // Send data to service to trigger immediate check
      FlutterForegroundTask.sendDataToTask({'action': 'check_now', 'source': 'fcm'});
      print('🔥 Sent immediate check trigger to service');
    } else {
      // ⚠️ SERVICE NOT RUNNING - Start via transparent activity
      print('⚠️ Service NOT running - FCM received, starting ServiceStartActivity...');
      await ServiceLogger.log('SERVICE_NOT_RUNNING_FCM', details: 'FCM received but service dead - starting ServiceStartActivity');
      
      // Start transparent activity using AndroidIntent (bypasses method channel issues)
      try {
        print('🔄 Starting ServiceStartActivity via AndroidIntent...');
        
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          package: 'com.example.gate_control_device',
          componentName: 'com.example.gate_control_device.ServiceStartActivity',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        
        await intent.launch();
        
        print('✅ ServiceStartActivity launched via Intent');
        await ServiceLogger.log('FCM_RESTART_SUCCESS', details: 'ServiceStartActivity started via AndroidIntent');
        
        // Wait for service to start
        await Future.delayed(Duration(milliseconds: 1500));
        
        final isNowRunning = await FlutterForegroundTask.isRunningService;
        
        if (isNowRunning) {
          print('✅✅✅ Service confirmed running!');
          // Trigger immediate check
          FlutterForegroundTask.sendDataToTask({'action': 'check_now', 'source': 'fcm'});
          print('🔥 Sent immediate check trigger after restart');
        } else {
          print('⚠️ Service not yet running - check logs');
        }
      } catch (e) {
        print('❌ Failed to start ServiceStartActivity: $e');
        await ServiceLogger.log('FCM_RESTART_FAILED', details: 'ServiceStartActivity error: $e');
      }
    }
  } catch (e) {
    print('❌ Error in FCM handler: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CRITICAL: Clear any crash state before checking service
  // This allows app to restart after Android crashes foreground service
  print('🚑 ========================================');
  print('🚑 APP STARTING - CHECKING FOR CRASH STATE');
  print('🚑 ========================================');
  
  await ServiceRecoveryHelper.clearCrashState();
  
  // Check if service was running (indicates crash/kill if not)
  final wasServiceRunning = await FlutterForegroundTask.isRunningService;
  
  // Log app start with context
  if (wasServiceRunning) {
    await ServiceLogger.log('APP_OPENED', details: 'Service still running');
    print('✅ Service was running');
  } else {
    await ServiceLogger.log('APP_OPENED', details: 'Service not running (stopped by Android/user)');
    print('ℹ️ Service not running - normal, FCM will wake up when needed');
  }
  
  print('🚑 ========================================');
  
  // Global error handler for crash recovery
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌❌❌ FLUTTER ERROR: ${details.exception}');
    print('📍 Stack: ${details.stack}');
    // Continue running despite errors
  };
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Setup FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://xyzttzqvbescdpihvyfu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5enR0enF2YmVzY2RwaWh2eWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTQ5OTMsImV4cCI6MjA2OTEzMDk5M30.OpIs65YShePgpV2KG4Uqjpkj3RDNv12Rj9eLudveWQY',
  );
  
  // Initialize foreground task
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'gate_control_service',
      channelName: 'Vartų Valdymo Servisas',
      channelDescription: 'Klausomasi vartų atidarymo komandų',
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(60000), // 60s - FCM handles instant, this is backup
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  
  // Setup service restart on task removed (app swiped away)
  FlutterForegroundTask.setOnLockScreenVisibility(true);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gate Control v1.1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GateControlHomePage(),
    );
  }
}

class GateControlHomePage extends StatefulWidget {
  const GateControlHomePage({super.key});

  @override
  State<GateControlHomePage> createState() => _GateControlHomePageState();
}

class _GateControlHomePageState extends State<GateControlHomePage> {
  bool _serviceRunning = false;
  String? _fcmToken;
  bool _fcmRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _setupTaskDataCallback();
    _setupFCM();
    _setupNativeCallListener();
    _autoStartServiceIfNeeded();
  }
  
  void _setupNativeCallListener() {
    // Listen for native method calls (from ServiceStartActivity)
    const platform = MethodChannel('com.example.gate_control_device/sms');
    platform.setMethodCallHandler((call) async {
      if (call.method == 'autoStartService') {
        print('🚀🚀🚀 Received autoStartService from native!');
        final isRunning = await FlutterForegroundTask.isRunningService;
        if (!isRunning) {
          print('🔄 Starting service from native trigger...');
          await _startService();
        } else {
          print('✅ Service already running');
        }
      }
    });
  }
  
  Future<void> _autoStartServiceIfNeeded() async {
    // Check service status but DON'T auto-start
    // Android may have stopped it to save battery - FCM will wake it up when needed
    await Future.delayed(Duration(seconds: 1));
    
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      print('ℹ️ Service not running - stopped by Android or user');
      await ServiceLogger.log('SERVICE_NOT_RUNNING', details: 'Service stopped (normal) - FCM will wake up when needed');
      setState(() {
        _serviceRunning = false;
      });
    } else {
      print('✅ Service already running');
      setState(() {
        _serviceRunning = true;
      });
    }
    
    // Start periodic health check (monitoring only, no auto-restart)
    _startHealthCheck();
  }
  
  void _startHealthCheck() {
    // Monitor service health every 30 seconds (no auto-restart)
    Future.delayed(Duration(seconds: 30), () async {
      if (!mounted) return;
      
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning && _serviceRunning) {
        print('ℹ️ Service stopped - Android may have stopped it to save battery');
        await ServiceLogger.log('SERVICE_STOPPED_BY_SYSTEM', details: 'Service stopped (normal) - FCM will wake up when needed');
        setState(() {
          _serviceRunning = false;
        });
        // DON'T auto-restart - let FCM wake it up when needed
      }
      
      // Continue health check
      _startHealthCheck();
    });
  }
  
  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    
    // Request permission
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ FCM permission granted');
      
      // Get FCM token
      final token = await messaging.getToken();
      setState(() {
        _fcmToken = token;
      });
      
      print('🔑 FCM Token: $token');
      
      // Register with Supabase
      if (token != null) {
        await _registerFCMToken(token);
      }
      
      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed');
        _registerFCMToken(newToken);
      });
      
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔔 Foreground FCM message: ${message.data}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔔 FCM gautas: ${message.data['command'] ?? 'test'}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      
      // Listen for notification taps (when app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App opened from notification: ${message.data}');
        
        // Service should auto-start in _autoStartServiceIfNeeded
        // But force check and start if not running
        Future.delayed(Duration(seconds: 1), () async {
          final isRunning = await FlutterForegroundTask.isRunningService;
          if (!isRunning) {
            print('🔄 Starting service after notification tap...');
            await _startService();
          }
        });
      });
      
      // Check if app was opened from terminated state by notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        print('📱 App launched from notification: ${initialMessage.data}');
        // _autoStartServiceIfNeeded will handle service start
      }
    }
  }
  
  Future<void> _registerFCMToken(String token) async {
    try {
      // Register for 'default' device_id
      await Supabase.instance.client
          .from('device_tokens')
          .upsert({
            'device_id': 'default',
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'device_id');
      
      // Register for 'gate_opener_1' device_id (used by Miltegona Manager)
      await Supabase.instance.client
          .from('device_tokens')
          .upsert({
            'device_id': 'gate_opener_1',
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'device_id');
      
      setState(() {
        _fcmRegistered = true;
      });
      
      print('✅ FCM token registered in Supabase (default + gate_opener_1)');
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }
  
  void _setupTaskDataCallback() {
    FlutterForegroundTask.addTaskDataCallback((data) async {
      // Handle data from foreground service
      final dataMap = data as Map<String, dynamic>;
      
      if (dataMap['action'] == 'send_sms') {
        final phoneNumber = dataMap['phoneNumber'] as String;
        final message = dataMap['message'] as String;
        final commandId = dataMap['commandId'] as int;
        
        print('📱 [MAIN] Received SMS request from service');
        print('📱 [MAIN] Phone: $phoneNumber');
        print('📱 [MAIN] Message: $message');
        
        try {
          const platform = MethodChannel('com.example.gate_control_device/sms');
          await platform.invokeMethod('sendSmsBroadcast', {
            'phoneNumber': phoneNumber,
            'message': message,
          });
          print('📱 [MAIN] SMS broadcast sent successfully');
          
          // Update command status to completed
          await Supabase.instance.client
              .from('gate_commands')
              .update({'status': 'completed'})
              .eq('id', commandId);
          print('📱 [MAIN] Command marked as completed');
        } catch (e) {
          print('📱 [MAIN] Error sending SMS: $e');
          
          // Mark command as failed
          await Supabase.instance.client
              .from('gate_commands')
              .update({'status': 'failed'})
              .eq('id', commandId);
        }
      }
    });
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    setState(() {
      _serviceRunning = isRunning;
    });
  }

  Future<void> _requestPermissions() async {
    // Request multiple phone-related permissions
    final phoneStatus = await Permission.phone.request();
    final smsStatus = await Permission.sms.request();
    final smsSendStatus = await Permission.sms.request(); // SEND_SMS
    final notificationStatus = await Permission.notification.request();
    
    // Request battery optimization bypass
    final ignoreBatteryOptimizations = await Permission.ignoreBatteryOptimizations.request();
    
    // Log permission statuses
    print('📱 Phone permission: $phoneStatus');
    print('💬 SMS permission: $smsStatus');
    print('📤 SMS send permission: $smsSendStatus');
    print('🔔 Notification permission: $notificationStatus');
    print('🔋 Battery optimization bypass: $ignoreBatteryOptimizations');
    
    if (!phoneStatus.isGranted || !smsStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SVARBU: Reikalingi leidimai skambinti ir siųsti SMS! Phone: $phoneStatus, SMS: $smsStatus'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Nustatymai',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
    
    if (!notificationStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reikalingas leidimas rodyti pranešimus'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    
    if (!ignoreBatteryOptimizations.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SVARBU: Išjunkite baterijos optimizaciją!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Nustatymai',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startService() async {
    await _requestPermissions();
    
    await ServiceLogger.logServiceStart();
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Vartų Valdymas',
      notificationText: 'Klausomasi komandų...',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'stop', text: 'Sustabdyti'),
      ],
      callback: startGateControlService,
    );
    
    setState(() {
      _serviceRunning = true;
    });
  }

  Future<void> _stopService() async {
    await ServiceLogger.logServiceStop();
    await FlutterForegroundTask.stopService();
    setState(() {
      _serviceRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Vartų Valdymo Sistema'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _serviceRunning ? Icons.check_circle : Icons.error,
                  size: 80,
                  color: _serviceRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _serviceRunning ? 'Servisas veikia ' : 'Servisas sustabdytas',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _serviceRunning ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _serviceRunning 
                    ? 'Klausomasi Supabase komandų...' 
                    : 'Paspauskite mygtuką paleisti servisą',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _serviceRunning ? _stopService : _startService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _serviceRunning ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _serviceRunning ? 'Sustabdyti servisą' : 'Paleisti servisą',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServiceLogsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('Service Logs'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade700, width: 2),
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Emergency recovery button
                          final shouldRecover = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('🚨 Emergency Recovery'),
                              content: const Text(
                                'Ar tikrai norite atlikti pilną serviso atsigavimą?\n\n'
                                'Tai sustabdys ir perkraus servisą.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Atšaukti'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Atgaivinti'),
                                ),
                              ],
                            ),
                          );
                          
                          if (shouldRecover == true && mounted) {
                            setState(() {
                              _serviceRunning = false;
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🚨 Atliekamas atsigavimas...'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            
                            await ServiceRecoveryHelper.performFullRecovery();
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Atsigavimas baigtas! Paleiskite servisą.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.healing, size: 20),
                        label: const Text('Recovery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_fcmToken != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.token, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'FCM Token:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_fcmToken!.substring(0, 30)}...${_fcmToken!.substring(_fcmToken!.length - 20)}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fcmToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Token nukopijuotas!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Kopijuoti'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Share.share(
                              'Gate Control FCM Token:\n\n$_fcmToken\n\nDevice ID: default',
                              subject: 'Gate Control FCM Token',
                            );
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Dalintis'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informacija',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('✓ Servisas veikia fone'),
                        const Text('✓ Automatiškai paleidžiamas įjungus telefoną'),
                        const Text('✓ Skambina į +37069922987'),
                        if (_fcmRegistered) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const Text('✓ FCM Wake-up aktyvuotas', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),                          const SizedBox(height: 4),
                          const Text('Device ID: default', style: TextStyle(fontSize: 12, color: Colors.grey)),                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
