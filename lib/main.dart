import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gate_control_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      channelImportance: NotificationChannelImportance.MIN, // Minimali svarba - rodo tik statusbar'e
      priority: NotificationPriority.MIN, // Minimali pirmenybė
      visibility: NotificationVisibility.VISIBILITY_SECRET, // Slapta - nerodo lock screen'e
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gate Control Device',
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

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _setupTaskDataCallback();
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
    
    // Log permission statuses
    print('📱 Phone permission: $phoneStatus');
    print('💬 SMS permission: $smsStatus');
    print('📤 SMS send permission: $smsSendStatus');
    print('🔔 Notification permission: $notificationStatus');
    
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
                        const Text(' Servisas veikia fone'),
                        const Text(' Automatiškai paleidžiamas įjungus telefoną'),
                        const Text(' Skambina į +37069922987'),
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
