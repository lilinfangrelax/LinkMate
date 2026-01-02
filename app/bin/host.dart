import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:app/database_helper.dart';

void main() async {
  // Native Messaging Host for LinkMate
  // Protocol:
  // 1. Length (4 bytes, unsigned integer, little-endian)
  // 2. JSON Message (UTF-8 encoded string)

  // Initialize logging
  final logFile = File('host.log');
  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    logFile.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
    stderr.writeln(message); // Still write to stderr for manual testing
  }

  log('LinkMate Native Host Started');

  try {
    await for (final message in _readMessages()) {
      _handleMessage(message, log);
    }
  } catch (e, stackTrace) {
    log('Error in main loop: $e');
    log(stackTrace.toString());
  }
}

/// Stream of parsed JSON messages from stdin
Stream<Map<String, dynamic>> _readMessages() async* {
  final stdinStream = stdin;

  // We need to read raw bytes.
  // Note: Dart's stdin is buffered and processed effectively as a stream of byte lists.
  // Since we require exact byte counts for the header, we might need a buffer.
  
  // A simple buffer to hold incoming data
  List<int> buffer = [];
  
  await for (final chunk in stdinStream) {
    buffer.addAll(chunk);

    while (true) {
      // Check if we have enough bytes for the header (4 bytes)
      if (buffer.length < 4) {
        break; // Wait for more data
      }

      // Read length (Little Endian)
      final lengthData = Uint8List.fromList(buffer.sublist(0, 4));
      final length = lengthData.buffer.asByteData().getUint32(0, Endian.little);

      // Check if we have the full message
      if (buffer.length < 4 + length) {
        break; // Wait for more data
      }

      // Extract message bytes
      final messageBytes = buffer.sublist(4, 4 + length);
      
      // Remove processed bytes from buffer
      // Optimization: In a high-throughput scenario, using a circular buffer or similar structure is better.
      // For now, sublist is sufficient for functionality.
      buffer = buffer.sublist(4 + length);

      try {
        final jsonString = utf8.decode(messageBytes);
        final jsonMap = jsonDecode(jsonString);
        yield jsonMap;
      } catch (e) {
        stderr.writeln("Failed to parse message: $e");
      }
    }
  }
}

void _handleMessage(Map<String, dynamic> message, void Function(String) log) async {
  final type = message['type'];
  log("Received Message Type: $type");
  
  if (type == 'TABS_SYNC') {
      try {
        final browser = message['browser'] as String;
        final accountId = message['accountId'] as String?;
        final profileName = message['profileName'] as String?;
        final tabs = (message['data']?['tabs'] as List?) ?? [];
        final groups = (message['data']?['groups'] as List?) ?? [];
        
        log("Syncing ${tabs.length} tabs from $browser ($profileName)...");
        
        await DatabaseHelper().syncTabs(browser, accountId, tabs, groups, profileName: profileName);
        
        log("Sync complete.");
      } catch (e) {
        log("Database Sync Error: $e");
      }
  }
}
