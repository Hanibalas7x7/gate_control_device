import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔥 Background message received: ${message.data}');
  
  // Handle command
  await _handleCommand(message.data);
}

Future<void> _handleCommand(Map<String, dynamic> data) async {
  final command = data['command'] as String?;
  final commandId = data['commandId'] as String?;
  
  if (command == null || commandId == null) {
    print('❌ Invalid command data');
    return;
  }
  
  print('📋 Handling command: $command (ID: $commandId)');
  
  try {
    if (command == 'open_gate') {
      await _makePhoneCall(commandId);
    } else if (command == 'send_sms') {
      final phoneNumber = data['phoneNumber'] as String?;
      final message = data['message'] as String?;
      await _sendSms(commandId, phoneNumber, message);
    }
  } catch (e) {
    print('❌ Error handling command: $e');
  }
}

Future<void> _makePhoneCall(String commandId) async {
  print('📞 Making call to gate...');
  // Implementation similar to old version
}

Future<void> _sendSms(String commandId, String? phoneNumber, String? message) async {
  print('📱 Sending SMS...');
  // Implementation similar to old version
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://xyzttzqvbescdpihvyfu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5enR0enF2YmVzY2RwaWh2eWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTQ5OTMsImV4cCI6MjA2OTEzMDk5M30.OpIs65YShePgpV2KG4Uqjpkj3RDNv12Rj9eLudveWQY',
  );
  
  // Setup background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
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
  String? _fcmToken;
  bool _isRegistered = false;
  int _pendingSmsCount = 0;

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _checkPendingSms();
    _setupForegroundHandler();
  }

  Future<void> _setupFCM() async {
    // Request permission
    final messaging = FirebaseMessaging.instance;
    
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
      
      // Save token to Supabase
      if (token != null) {
        await _registerDevice(token);
      }
      
      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _registerDevice(newToken);
      });
    } else {
      print('❌ FCM permission denied');
    }
  }

  Future<void> _registerDevice(String fcmToken) async {
    try {
      // Get device ID from SharedPreferences or create new
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
      }
      
      print('📱 Registering device: $deviceId');
      
      // Upsert device token to Supabase
      await Supabase.instance.client
          .from('device_tokens')
          .upsert({
            'device_id': deviceId,
            'fcm_token': fcmToken,
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      setState(() {
        _isRegistered = true;
      });
      
      print('✅ Device registered successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Įrenginys užregistruotas!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error registering device: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Klaida registruojant įrenginį: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupForegroundHandler() {
    // Handle messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔥 Foreground message received: ${message.data}');
      _handleCommand(message.data);
    });
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔥 App opened from notification: ${message.data}');
    });
  }

  Future<void> _checkPendingSms() async {
    try {
      // Check for pending SMS commands
      final response = await Supabase.instance.client
          .from('gate_commands')
          .select()
          .eq('command', 'send_sms')
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      
      final List<dynamic> pendingCommands = response as List<dynamic>;
      
      setState(() {
        _pendingSmsCount = pendingCommands.length;
      });
      
      print('📱 Found ${pendingCommands.length} pending SMS');
      
      // Send all pending SMS
      if (pendingCommands.isNotEmpty) {
        await _sendPendingSms(pendingCommands);
      }
    } catch (e) {
      print('❌ Error checking pending SMS: $e');
    }
  }

  Future<void> _sendPendingSms(List<dynamic> commands) async {
    print('📤 Sending ${commands.length} pending SMS...');
    
    for (final command in commands) {
      try {
        final commandId = command['id'].toString();
        final phoneNumber = command['phone_number'] as String?;
        final orderCode = command['order_code'] as String?;
        final smsType = command['sms_type'] as String?;
        
        if (phoneNumber == null || orderCode == null) {
          print('❌ Invalid SMS command data');
          continue;
        }
        
        // Fetch order details
        final orderResponse = await Supabase.instance.client
            .from('images')
            .select('smeliavimas, gruntavimas, spalva_ir_pavirsuis, completion_date')
            .eq('unique_code', orderCode)
            .single();
        
        // Build SMS message
        String smsMessage;
        if (smsType == 'ready_for_pickup') {
          final smeliavimas = orderResponse['smeliavimas'] == true ? 'TAIP' : 'NE';
          final gruntavimas = orderResponse['gruntavimas'] == true ? 'TAIP' : 'NE';
          final spalva = orderResponse['spalva_ir_pavirsuis'] ?? 'nenurodyta';
          
          smsMessage = 'Miltegona: užsakymo kodas $orderCode.\n'
              'Procesai: smėliavimas – $smeliavimas; gruntavimas – $gruntavimas; dažymas – "$spalva".\n'
              'Užsakymas pabaigtas ir ruošiamas atsiėmimui.';
        } else {
          final smeliavimas = orderResponse['smeliavimas'] == true ? 'TAIP' : 'NE';
          final gruntavimas = orderResponse['gruntavimas'] == true ? 'TAIP' : 'NE';
          final spalva = orderResponse['spalva_ir_pavirsuis'] ?? 'nenurodyta';
          final terminasRaw = orderResponse['completion_date'];
          
          String? terminas;
          if (terminasRaw != null) {
            try {
              final date = DateTime.parse(terminasRaw);
              terminas = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            } catch (e) {
              terminas = null;
            }
          }
          
          smsMessage = 'Miltegona: užsakymo kodas $orderCode.\n'
              'Procesai: smėliavimas – $smeliavimas; gruntavimas – $gruntavimas; dažymas – "$spalva".'
              '${terminas != null ? '\nTerminas: $terminas.' : ''}\n'
              'Sekimas: https://miltegona.lt/sekimas/?code=$orderCode';
        }
        
        print('📱 Sending SMS to $phoneNumber');
        
        // Send SMS via platform channel
        const platform = MethodChannel('com.example.gate_control_device/sms');
        await platform.invokeMethod('sendSmsBroadcast', {
          'phoneNumber': phoneNumber,
          'message': smsMessage,
        });
        
        // Mark as completed
        await Supabase.instance.client
            .from('gate_commands')
            .update({'status': 'completed'})
            .eq('id', command['id']);
        
        print('✅ SMS sent successfully');
        
        setState(() {
          _pendingSmsCount--;
        });
        
      } catch (e) {
        print('❌ Error sending SMS: $e');
        
        // Mark as failed
        try {
          await Supabase.instance.client
              .from('gate_commands')
              .update({'status': 'failed'})
              .eq('id', command['id']);
        } catch (updateError) {
          print('❌ Error updating status: $updateError');
        }
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visi laukiantys SMS išsiųsti!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    final phoneStatus = await Permission.phone.request();
    final smsStatus = await Permission.sms.request();
    final notificationStatus = await Permission.notification.request();
    
    print('📱 Phone: $phoneStatus, SMS: $smsStatus, Notification: $notificationStatus');
    
    if (!phoneStatus.isGranted || !smsStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reikalingi leidimai skambinti ir siųsti SMS!'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Vartų Valdymas v1.1'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRegistered ? Icons.check_circle : Icons.error,
                size: 80,
                color: _isRegistered ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                _isRegistered ? 'FCM aktyvuotas ✓' : 'Laukiama registracijos...',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _isRegistered ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRegistered 
                  ? 'Įrenginys pasiruošęs priimti komandas' 
                  : 'Registruojamas FCM token...',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_pendingSmsCount > 0) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Laukia $_pendingSmsCount SMS',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Patikrinti leidimus',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _checkPendingSms,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Siųsti laukiančius SMS',
                    style: TextStyle(fontSize: 18),
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
                        'v1.1 Informacija',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('✓ FCM push notifikacijos'),
                      const Text('✓ Nereikia foreground service'),
                      const Text('✓ Auto SMS retry po crash'),
                      const Text('✓ Mažiau baterijos vartojimo'),
                      if (_fcmToken != null) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'FCM Token:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _fcmToken!,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
