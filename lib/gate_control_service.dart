import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String gatePhoneNumber = '+37069922987';

@pragma('vm:entry-point')
void startGateControlService() {
  FlutterForegroundTask.setTaskHandler(GateControlTaskHandler());
}

class GateControlTaskHandler extends TaskHandler {
  RealtimeChannel? _channel;
  SupabaseClient? _supabase;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    developer.log('🚀 ========================================');
    developer.log('🚀 Gate Control Service Started');
    developer.log('🚀 ========================================');
    
    // Initialize Supabase in the isolate
    try {
      developer.log('🔧 Initializing Supabase in foreground task isolate...');
      await Supabase.initialize(
        url: 'https://xyzttzqvbescdpihvyfu.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5enR0enF2YmVzY2RwaWh2eWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTQ5OTMsImV4cCI6MjA2OTEzMDk5M30.OpIs65YShePgpV2KG4Uqjpkj3RDNv12Rj9eLudveWQY',
      );
      _supabase = Supabase.instance.client;
      developer.log('✅ Supabase initialized and client ready');
    } catch (e) {
      developer.log('❌ Error initializing Supabase: $e');
      return;
    }
    
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    if (_supabase == null) {
      developer.log('❌ Cannot setup listener: Supabase client is null');
      return;
    }
    
    try {
      developer.log('🔧 Setting up realtime channel...');
      _channel = _supabase!.channel('gate_commands');
      
      developer.log('🔧 Configuring postgres changes listener...');
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'gate_commands',
        callback: (payload) {
          developer.log('🔔 ========================================');
          developer.log('🔔 REALTIME EVENT RECEIVED!');
          developer.log('🔔 Payload: ${payload.newRecord}');
          developer.log('🔔 ========================================');
          
          final status = payload.newRecord['status'] as String?;
          final command = payload.newRecord['command'] as String?;
          final id = payload.newRecord['id'];
          
          developer.log('📋 Status: $status');
          developer.log('📋 Command: $command');
          developer.log('📋 ID: $id');
          
          if (status == 'pending' && command == 'open_gate') {
            developer.log('✅ Conditions met! Handling gate command...');
            _handleGateCommand(id as int);
          } else if (status == 'pending' && command == 'send_sms') {
            developer.log('✅ SMS command received! Handling SMS...');
            _handleSmsCommand(id as int, payload.newRecord);
          } else {
            developer.log('⚠️ Conditions NOT met - ignoring command');
            developer.log('   status == "pending"? ${status == 'pending'}');
            developer.log('   command type: $command');
          }
        },
      );
      
      developer.log('🔧 Subscribing to channel...');
      _channel!.subscribe((status, error) {
        developer.log('📡 Channel subscription status: $status');
        if (error != null) {
          developer.log('❌ Subscription error: $error');
        }
        if (status == RealtimeSubscribeStatus.subscribed) {
          developer.log('✅ Successfully subscribed to gate_commands channel!');
        } else if (status == RealtimeSubscribeStatus.closed) {
          developer.log('❌ Channel closed!');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          developer.log('❌ Channel error!');
        }
      });
      
      developer.log('✅ Realtime listener setup complete');
    } catch (e) {
      developer.log('❌ Error setting up realtime: $e');
    }
  }

  Future<void> _handleGateCommand(int commandId) async {
    developer.log('📞 ========================================');
    developer.log('📞 HANDLING GATE COMMAND');
    developer.log('📞 Command ID: $commandId');
    developer.log('📞 ========================================');
    
    if (_supabase == null) {
      developer.log('❌ Cannot handle command: Supabase client is null');
      return;
    }
    
    try {
      developer.log('📞 Making call to $gatePhoneNumber');
      
      // Make the phone call using Android Intent with FLAG_ACTIVITY_NEW_TASK
      if (Platform.isAndroid) {
        developer.log('📞 Creating Android Intent for phone call');
        
        final AndroidIntent intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$gatePhoneNumber',
          flags: <int>[
            0x10000000, // FLAG_ACTIVITY_NEW_TASK
            0x00400000, // FLAG_ACTIVITY_BROUGHT_TO_FRONT
          ],
        );
        
        developer.log('📞 Launching intent...');
        await intent.launch();
        developer.log('✅ Call initiated successfully');
      } else {
        throw Exception('Platform not supported - only Android is supported');
      }
      
      // Update command status
      developer.log('📝 Updating command status to completed...');
      await _supabase!
          .from('gate_commands')
          .update({'status': 'completed'})
          .eq('id', commandId);
      
      developer.log('✅ Command $commandId completed');
      
      // Update notification
      FlutterForegroundTask.updateService(
        notificationTitle: 'Vartų Valdymas',
        notificationText: 'Skambutis atliktas: ${DateTime.now().toString().substring(11, 19)}',
      );
    } catch (e) {
      developer.log('❌ Error handling command: $e');
      
      // Update command status to failed
      try {
        await _supabase!
            .from('gate_commands')
            .update({'status': 'failed'})
            .eq('id', commandId);
        developer.log('📝 Command marked as failed');
      } catch (updateError) {
        developer.log('❌ Error updating status to failed: $updateError');
      }
    }
  }

  Future<void> _handleSmsCommand(int commandId, Map<String, dynamic> commandData) async {
    developer.log('📱 ========================================');
    developer.log('📱 HANDLING SMS COMMAND');
    developer.log('📱 Command ID: $commandId');
    developer.log('📱 ========================================');
    
    if (_supabase == null) {
      developer.log('❌ Cannot handle SMS: Supabase client is null');
      return;
    }
    
    try {
      final phoneNumber = commandData['phone_number'] as String?;
      final orderCode = commandData['order_code'] as String?;
      final smsType = commandData['sms_type'] as String?;
      
      developer.log('📱 Phone: $phoneNumber');
      developer.log('📱 Order Code: $orderCode');
      developer.log('📱 SMS Type: $smsType');
      
      if (phoneNumber == null || orderCode == null) {
        throw Exception('Missing phone number or order code');
      }
      
      // Fetch order details from images table
      developer.log('📱 Fetching order details from Supabase...');
      final orderResponse = await _supabase!
          .from('images')
          .select('smeliavimas, gruntavimas, spalva_ir_pavirsuis, completion_date')
          .eq('unique_code', orderCode)
          .single();
      
      developer.log('📱 Order data: $orderResponse');
      
      // Build SMS message based on type
      final String smsMessage;
      
      if (smsType == 'ready_for_pickup') {
        // SMS when order is ready for pickup (moved to Matavimui)
        final smeliavimas = orderResponse['smeliavimas'] == true ? 'TAIP' : 'NE';
        final gruntavimas = orderResponse['gruntavimas'] == true ? 'TAIP' : 'NE';
        final spalva = orderResponse['spalva_ir_pavirsuis'] ?? 'nenurodyta';
        
        smsMessage = 'Miltegona: užsakymo kodas $orderCode.\n'
            'Procesai: smėliavimas – $smeliavimas; gruntavimas – $gruntavimas; dažymas – "$spalva".\n'
            'Užsakymas pabaigtas ir ruošiamas atsiėmimui.';
      } else {
        // Default SMS (order created) - include terminas if set
        final smeliavimas = orderResponse['smeliavimas'] == true ? 'TAIP' : 'NE';
        final gruntavimas = orderResponse['gruntavimas'] == true ? 'TAIP' : 'NE';
        final spalva = orderResponse['spalva_ir_pavirsuis'] ?? 'nenurodyta';
        final terminasRaw = orderResponse['completion_date'];
        
        // Format terminas to show only date (YYYY-MM-DD), or null if not set
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
            'Sekimas: miltegona.lt/sekimas';
      }
      
      developer.log('📱 SMS Message:\n$smsMessage');
      
      // Launch transparent Activity that will send SMS automatically
      if (Platform.isAndroid) {
        developer.log('📱 ==========================================');
        developer.log('📱 SENDING SMS VIA TRANSPARENT ACTIVITY');
        developer.log('📱 Phone: $phoneNumber');
        developer.log('📱 Message length: ${smsMessage.length}');
        
        try {
          // Launch SmsSenderActivity - it will send SMS and close automatically
          final AndroidIntent intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            package: 'com.example.gate_control_device',
            componentName: 'com.example.gate_control_device.SmsSenderActivity',
            arguments: <String, dynamic>{
              'phone_number': phoneNumber,
              'message': smsMessage,
            },
            flags: <int>[
              0x10000000, // FLAG_ACTIVITY_NEW_TASK
            ],
          );
          
          developer.log('📱 Launching SMS sender activity...');
          await intent.launch();
          developer.log('📱 SMS sender activity launched');
          developer.log('📱 ==========================================');
          
          // Update command status to completed
          await _supabase!
              .from('gate_commands')
              .update({'status': 'completed'})
              .eq('id', commandId);
          developer.log('✅ Command marked as completed');
          
        } catch (e) {
          developer.log('❌ Error launching SMS intent: $e');
          developer.log('📱 ==========================================');
          throw e;
        }
      } else {
        throw Exception('Platform not supported - only Android is supported');
      }
    } catch (e) {
      developer.log('❌ Error handling SMS command: $e');
      
      // Update command status to failed
      try {
        await _supabase!
            .from('gate_commands')
            .update({'status': 'failed'})
            .eq('id', commandId);
        developer.log('📝 SMS command marked as failed');
      } catch (updateError) {
        developer.log('❌ Error updating status to failed: $updateError');
      }
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Periodic check - keep service alive
    FlutterForegroundTask.updateService(
      notificationTitle: 'Vartų Valdymas',
      notificationText: 'Klausomasi komandų... (${DateTime.now().toString().substring(11, 19)})',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    developer.log('Gate Control Service Stopped');
    await _channel?.unsubscribe();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // Open app when notification is tapped
    FlutterForegroundTask.launchApp('/');
  }
}
