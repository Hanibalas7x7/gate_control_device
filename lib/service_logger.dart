import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ServiceLogger {
  static const String _logFileName = 'service_logs.txt';
  static const int _maxLogLines = 500; // Keep last 500 events

  static Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_logFileName');
  }

  static Future<void> log(String event, {String? details}) async {
    try {
      final file = await _getLogFile();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final logEntry = '[$timestamp] $event${details != null ? ': $details' : ''}\n';
      
      print('📝 Writing log to: ${file.path}');
      print('📝 Log entry: $logEntry');
      
      // Append to file
      await file.writeAsString(logEntry, mode: FileMode.append);
      
      // Verify write
      final exists = await file.exists();
      final size = await file.length();
      print('📝 File exists: $exists, size: $size bytes');
      
      // Trim if too large
      await _trimLogsIfNeeded(file);
      
      print('📝 Logged: $event');
    } catch (e) {
      print('❌ Failed to log event: $e');
    }
  }

  // SYNC version for critical logs that must complete before service dies
  static void logSync(String event, {String? details}) {
    try {
      // Get documents directory path synchronously
      // On Android: /data/user/0/package_name/app_flutter
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final logEntry = '[$timestamp] $event${details != null ? ': $details' : ''}\n';
      
      print('📝 SYNC Attempting log: $event');
      
      // Try to write synchronously - use runSync pattern
      getApplicationDocumentsDirectory().then((directory) {
        final file = File('${directory.path}/$_logFileName');
        print('📝 SYNC Writing to: ${file.path}');
        
        // SYNCHRONOUS write - blocks until done
        file.writeAsStringSync(logEntry, mode: FileMode.append, flush: true);
        print('📝 SYNC Logged successfully: $event');
      }).catchError((e) {
        print('❌ SYNC Failed to log: $e');
      });
      
      // Also force a blocking delay to let it complete
      sleep(Duration(milliseconds: 50));
    } catch (e) {
      print('❌ SYNC Failed to log event: $e');
    }
  }

  static Future<void> _trimLogsIfNeeded(File file) async {
    try {
      final lines = await file.readAsLines();
      if (lines.length > _maxLogLines) {
        // Keep only last _maxLogLines
        final trimmedLines = lines.sublist(lines.length - _maxLogLines);
        await file.writeAsString(trimmedLines.join('\n') + '\n');
      }
    } catch (e) {
      print('❌ Failed to trim logs: $e');
    }
  }

  static Future<List<LogEntry>> getLogs() async {
    try {
      final file = await _getLogFile();
      print('📖 Reading logs from: ${file.path}');
      
      if (!await file.exists()) {
        print('📖 Log file does not exist yet');
        return [];
      }
      
      final lines = await file.readAsLines();
      print('📖 Found ${lines.length} lines in log file');
      
      return lines.reversed
          .where((line) => line.isNotEmpty)
          .map((line) => LogEntry.fromString(line))
          .toList();
    } catch (e) {
      print('❌ Failed to read logs: $e');
      return [];
    }
  }

  static Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.delete();
      }
      await log('LOGS_CLEARED', details: 'User cleared log history');
    } catch (e) {
      print('❌ Failed to clear logs: $e');
    }
  }

  // Predefined log events
  static Future<void> logAppStart() => log('APP_STARTED');
  static Future<void> logServiceStart() => log('SERVICE_STARTED');
  static Future<void> logServiceStop() => log('SERVICE_STOPPED', details: 'User stopped');
  static Future<void> logServiceCrash() => log('SERVICE_CRASHED', details: 'Detected dead service');
  static Future<void> logServiceRestart() => log('SERVICE_RESTARTED', details: 'Auto-restart after crash');
  static Future<void> logFCMReceived(String command) => log('FCM_RECEIVED', details: 'Command: $command');
  static Future<void> logFCMRestartAttempt() => log('FCM_RESTART_ATTEMPT', details: 'Service was dead');
  static Future<void> logFCMRestartSuccess() => log('FCM_RESTART_SUCCESS', details: 'Service revived');
  static Future<void> logFCMRestartFailed(String error) => log('FCM_RESTART_FAILED', details: error);
  static Future<void> logBootReceived() => log('BOOT_COMPLETED', details: 'Device restarted');
  static Future<void> logGateCommand(int commandId) => log('GATE_COMMAND', details: 'ID: $commandId');
  static Future<void> logSmsCommand(int commandId, String phone) => 
      log('SMS_COMMAND', details: 'ID: $commandId, Phone: $phone');
}

class LogEntry {
  final DateTime timestamp;
  final String event;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.event,
    this.details,
  });

  factory LogEntry.fromString(String line) {
    // Parse format: [2026-01-29 15:30:45] EVENT: details
    try {
      final match = RegExp(r'\[(.*?)\] (.*?)(?:: (.*))?$').firstMatch(line);
      if (match == null) {
        return LogEntry(
          timestamp: DateTime.now(),
          event: 'PARSE_ERROR',
          details: 'No regex match: $line',
        );
      }

      final timestampStr = match.group(1);
      if (timestampStr == null || timestampStr.isEmpty) {
        return LogEntry(
          timestamp: DateTime.now(),
          event: 'PARSE_ERROR',
          details: 'Empty timestamp: $line',
        );
      }

      DateTime parsedTimestamp;
      try {
        parsedTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestampStr);
      } catch (e) {
        return LogEntry(
          timestamp: DateTime.now(),
          event: 'PARSE_ERROR',
          details: 'Invalid timestamp "$timestampStr": $line',
        );
      }

      return LogEntry(
        timestamp: parsedTimestamp,
        event: match.group(2) ?? 'UNKNOWN_EVENT',
        details: match.group(3),
      );
    } catch (e) {
      return LogEntry(
        timestamp: DateTime.now(),
        event: 'PARSE_ERROR',
        details: 'Exception: $e | Line: $line',
      );
    }
  }

  String get displayTime => DateFormat('HH:mm:ss').format(timestamp);
  String get displayDate => DateFormat('yyyy-MM-dd').format(timestamp);
  
  String get emoji {
    switch (event) {
      case 'APP_STARTED': return '🚀';
      case 'APP_OPENED_AFTER_KILL': return '☠️';
      case 'SERVICE_STARTED': return '✅';
      case 'SERVICE_STOP_REQUESTED': return '🛑';
      case 'SERVICE_STOPPED': return '🛑';
      case 'SERVICE_CRASHED': return '💥';
      case 'SERVICE_RESTARTED': return '🔄';
      case 'FCM_RECEIVED': return '🔔';
      case 'FCM_RESTART_ATTEMPT': return '⚠️';
      case 'FCM_RESTART_SUCCESS': return '✅';
      case 'FCM_RESTART_FAILED': return '❌';
      case 'BOOT_COMPLETED': return '🔋';
      case 'GATE_COMMAND': return '🚪';
      case 'SMS_COMMAND': return '📱';
      case 'LOGS_CLEARED': return '🗑️';
      case 'PARSE_ERROR': return '⚠️';
      default: return '📝';
    }
  }

  String get eventName {
    switch (event) {
      case 'APP_STARTED': return 'App Paleidimas';
      case 'SERVICE_STARTED': return 'Servisas Paleistas';
      case 'SERVICE_STOPPED': return 'Servisas Sustabdytas';
      case 'SERVICE_CRASHED': return 'Servisas Krito';
      case 'SERVICE_RESTARTED': return 'Servisas Perkrautas';
      case 'FCM_RECEIVED': return 'FCM Pranešimas';
      case 'FCM_RESTART_ATTEMPT': return 'FCM Restart Bandymas';
      case 'FCM_RESTART_SUCCESS': return 'FCM Restart Sėkmė';
      case 'FCM_RESTART_FAILED': return 'FCM Restart Klaida';
      case 'BOOT_COMPLETED': return 'Device Restart';
      case 'GATE_COMMAND': return 'Vartų Komanda';
      case 'SMS_COMMAND': return 'SMS Komanda';
      case 'LOGS_CLEARED': return 'Logs Išvalyti';
      default: return event;
    }
  }
}
