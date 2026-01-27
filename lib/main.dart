import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'gate_control_service.dart';

// FCM background handler - ensures service stays alive
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔥 FCM Wake-up: ${message.data}');
  // Service will handle commands via polling
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      eventAction: ForegroundTaskEventAction.repeat(15000),
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
    _autoStartServiceIfNeeded();
  }
  
  Future<void> _autoStartServiceIfNeeded() async {
    // Auto-start service when app opens (helps after crash or restart)
    await Future.delayed(Duration(seconds: 2));
    
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      print('⚠️ Service not running - auto-starting after crash/restart...');
      await _startService();
    } else {
      print('✅ Service already running');
    }
    
    // Start periodic health check
    _startHealthCheck();
  }
  
  void _startHealthCheck() {
    // Check service health every 30 seconds
    Future.delayed(Duration(seconds: 30), () async {
      if (!mounted) return;
      
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning && _serviceRunning) {
        print('⚠️⚠️ Service crashed! Attempting restart...');
        setState(() {
          _serviceRunning = false;
        });
        
        // Try to restart
        await Future.delayed(Duration(seconds: 2));
        await _startService();
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
    }
  }
  
  Future<void> _registerFCMToken(String token) async {
    try {
      await Supabase.instance.client
          .from('device_tokens')
          .upsert({
            'device_id': 'default',
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'device_id');
      
      setState(() {
        _fcmRegistered = true;
      });
      
      print('✅ FCM token registered in Supabase');
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
