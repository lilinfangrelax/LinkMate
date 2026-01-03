import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyChromeId = 'chrome_extension_id';
  static const String keyEdgeId = 'edge_extension_id';
  static const String keyFirefoxId = 'firefox_extension_id';

  // Default IDs from the existing manifest
  static const String defaultChromeId = 'iakdbplajafmdpacnkbojcndfkaagodl';
  static const String defaultEdgeId = 'kbffpkbiighjnfefjgkjhnnhofajldbe';
  static const String defaultFirefoxId = 'linkmate@linkmate.com';

  Future<String> getChromeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyChromeId) ?? defaultChromeId;
  }

  Future<void> setChromeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyChromeId, id);
  }

  Future<String> getEdgeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyEdgeId) ?? defaultEdgeId;
  }

  Future<void> setEdgeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyEdgeId, id);
  }

  Future<String> getFirefoxId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyFirefoxId) ?? defaultFirefoxId;
  }

  Future<void> setFirefoxId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFirefoxId, id);
  }

  Future<bool> registerHost() async {
    try {
      final chromeId = await getChromeId();
      final edgeId = await getEdgeId();
      final firefoxId = await getFirefoxId();
      
      // Improved heuristic to find project root (directory containing host_manifest)
      // Search up to 10 levels to handle deep build directories
      Directory current = Directory.current;
      String? rootPath;
      
      for (int i = 0; i < 10; i++) {
        if (await Directory(p.join(current.path, 'host_manifest')).exists()) {
          rootPath = current.path;
          break;
        }
        if (current.path == current.parent.path) break; 
        current = current.parent;
      }
      
      // Fallback: If rootPath still null, try using Platform.resolvedExecutable
      if (rootPath == null) {
        current = File(Platform.resolvedExecutable).parent;
        for (int i = 0; i < 10; i++) {
          if (await Directory(p.join(current.path, 'host_manifest')).exists()) {
            rootPath = current.path;
            break;
          }
          if (current.path == current.parent.path) break;
          current = current.parent;
        }
      }
      
      if (rootPath == null) {
        throw Exception("Could not find project root (host_manifest directory)");
      }

      // 1. Determine host executable path (host.exe)
      String exePath = '';
      
      // Possible locations for host.exe:
      // A. root/app/host.exe (Source/Standard structure)
      // B. root/host.exe (Alternate structure)
      // C. current_dir/host.exe (Local debug)
      // D. executable_dir/host.exe (Packaged distribution)
      
      final pathsToTry = [
        p.join(rootPath, 'app', 'host.exe'),
        p.join(rootPath, 'host.exe'),
        p.join(Directory.current.path, 'host.exe'),
        p.join(File(Platform.resolvedExecutable).parent.path, 'host.exe'),
      ];

      for (final path in pathsToTry) {
        if (await File(path).exists()) {
          exePath = path;
          break;
        }
      }

      if (exePath.isEmpty) {
        throw Exception("Could not find host.exe in any of these locations:\n${pathsToTry.join('\n')}");
      }

      final chromeManifestPath = p.join(rootPath, 'host_manifest', 'com.linkmate.host_chrome.json');
      final edgeManifestPath = p.join(rootPath, 'host_manifest', 'com.linkmate.host_edge.json');
      final firefoxManifestPath = p.join(rootPath, 'host_manifest', 'com.linkmate.host_firefox.json');
      
      debugPrint('Registering host with path: $exePath');
      
      // Update Manifests
      await _updateBrowserManifest(chromeManifestPath, exePath, chromeId);
      await _updateBrowserManifest(edgeManifestPath, exePath, edgeId);
      await _updateFirefoxManifest(firefoxManifestPath, exePath, firefoxId);

      // Register in Registry
      if (Platform.isWindows) {
        await _registerWindowsRegistry(chromeId: chromeManifestPath, edgeId: edgeManifestPath, firefoxId: firefoxManifestPath);
      }

      return true;
    } catch (e) {
      debugPrint('Error registering host: $e');
      return false;
    }
  }

  Future<void> _updateBrowserManifest(String path, String exePath, String extensionId) async {
    final file = File(path);
    final content = {
      "name": "com.linkmate.host",
      "description": "LinkMate Native Messaging Host",
      "path": exePath,
      "type": "stdio",
      "allowed_origins": [
        "chrome-extension://$extensionId/"
      ]
    };
    await file.writeAsString(const JsonEncoder.withIndent('    ').convert(content));
  }

  Future<void> _updateFirefoxManifest(String path, String exePath, String firefoxId) async {
    final file = File(path);
    final content = {
        "name": "com.linkmate.host",
        "description": "LinkMate Native Messaging Host",
        "path": exePath,
        "type": "stdio",
        "allowed_extensions": [ firefoxId ]
    };
    await file.writeAsString(JsonEncoder.withIndent('    ').convert(content));
  }

  Future<void> _registerWindowsRegistry({
    required String chromeId,
    required String edgeId,
    required String firefoxId,
  }) async {
    // Chrome
    await Process.run('reg', [
      'add', 'HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.linkmate.host',
      '/ve', '/t', 'REG_SZ', '/d', chromeId, '/f'
    ]);
    
    // Edge
    await Process.run('reg', [
      'add', 'HKCU\\Software\\Microsoft\\Edge\\NativeMessagingHosts\\com.linkmate.host',
      '/ve', '/t', 'REG_SZ', '/d', edgeId, '/f'
    ]);

    // Firefox
    await Process.run('reg', [
      'add', 'HKCU\\Software\\Mozilla\\NativeMessagingHosts\\com.linkmate.host',
      '/ve', '/t', 'REG_SZ', '/d', firefoxId, '/f'
    ]);
  }
}
