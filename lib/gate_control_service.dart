import 'dart:developer' as developer;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String gatePhoneNumber = '+37069922987';

@pragma('vm:entry-point')
void startGateControlService() {
  FlutterForegroundTask.setTaskHandler(GateControlTaskHandler());
}

class GateControlTaskHandler extends TaskHandler {
  RealtimeChannel? _channel;
  final _supabase = Supabase.instance.client;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    developer.log('Gate Control Service Started');
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    try {
      _channel = _supabase.channel('gate_commands');
      
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'gate_commands',
        callback: (payload) {
          developer.log('Received command: ${payload.newRecord}');
          
          final status = payload.newRecord['status'] as String?;
          final command = payload.newRecord['command'] as String?;
          
          if (status == 'pending' && command == 'open_gate') {
            _handleGateCommand(payload.newRecord['id'] as int);
          }
        },
      ).subscribe();
      
      developer.log('Realtime listener setup complete');
    } catch (e) {
      developer.log('Error setting up realtime: $e');
    }
  }

  Future<void> _handleGateCommand(int commandId) async {
    try {
      developer.log('Making call to $gatePhoneNumber');
      
      // Make the phone call
      await FlutterPhoneDirectCaller.callNumber(gatePhoneNumber);
      
      // Update command status
      await _supabase
          .from('gate_commands')
          .update({'status': 'completed'})
          .eq('id', commandId);
      
      developer.log('Command $commandId completed');
      
      // Update notification
      FlutterForegroundTask.updateService(
        notificationTitle: 'Vartų Valdymas',
        notificationText: 'Skambutis atliktas: ${DateTime.now().toString().substring(11, 19)}',
      );
    } catch (e) {
      developer.log('Error handling command: $e');
      
      // Update command status to failed
      await _supabase
          .from('gate_commands')
          .update({'status': 'failed'})
          .eq('id', commandId);
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
