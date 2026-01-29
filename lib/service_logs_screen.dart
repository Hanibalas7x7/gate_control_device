import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'service_logger.dart';

class ServiceLogsScreen extends StatefulWidget {
  const ServiceLogsScreen({super.key});

  @override
  State<ServiceLogsScreen> createState() => _ServiceLogsScreenState();
}

class _ServiceLogsScreenState extends State<ServiceLogsScreen> {
  List<LogEntry> _logs = [];
  bool _loading = true;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await ServiceLogger.getLogs();
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  List<LogEntry> get _filteredLogs {
    if (_filter == 'ALL') return _logs;
    return _logs.where((log) {
      switch (_filter) {
        case 'CRASHES': return log.event.contains('CRASH') || log.event.contains('RESTART');
        case 'FCM': return log.event.contains('FCM');
        case 'COMMANDS': return log.event.contains('COMMAND');
        default: return true;
      }
    }).toList();
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Išvalyti Logs?'),
        content: const Text('Ar tikrai norite ištrinti visus log įrašus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Atšaukti'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Išvalyti', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ServiceLogger.clearLogs();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logs išvalyti'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    final logsText = _logs.map((log) {
      return '[${log.displayDate} ${log.displayTime}] ${log.event}${log.details != null ? ': ${log.details}' : ''}';
    }).join('\n');

    await Clipboard.setData(ClipboardData(text: logsText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Logs nukopijuoti į clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ALL', child: Text('🔍 Visi')),
              const PopupMenuItem(value: 'CRASHES', child: Text('💥 Crashes')),
              const PopupMenuItem(value: 'FCM', child: Text('🔔 FCM')),
              const PopupMenuItem(value: 'COMMANDS', child: Text('📋 Komandos')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _logs.isEmpty ? null : _exportLogs,
            tooltip: 'Kopijuoti logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _logs.isEmpty ? null : _clearLogs,
            tooltip: 'Išvalyti logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Atnaujinti',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Nėra logs',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rodoma ${_filteredLogs.length} iš ${_logs.length} įrašų',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          if (_filter != 'ALL')
                            Chip(
                              label: Text(_filter),
                              onDeleted: () => setState(() => _filter = 'ALL'),
                              backgroundColor: Colors.blue.shade100,
                              deleteIconColor: Colors.blue.shade700,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredLogs.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          final isError = log.event.contains('CRASH') || 
                                         log.event.contains('FAILED') || 
                                         log.event.contains('ERROR');
                          final isSuccess = log.event.contains('SUCCESS') || 
                                           log.event.contains('STARTED');

                          return ListTile(
                            leading: Text(
                              log.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    log.eventName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isError ? Colors.red : 
                                             isSuccess ? Colors.green : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  log.displayTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (log.details != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      log.details!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    log.displayDate,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            tileColor: isError ? Colors.red.shade50 : 
                                       isSuccess ? Colors.green.shade50 : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
