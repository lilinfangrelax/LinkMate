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
      
      // 1. Get current executable path
      // In development, this might be the dart executable or the flutter tester.
      // In production, it's the app.exe.
      // Based on com.linkmate.host.json, path is "d:\\Dev\\Flutter\\LinkMate\\app\\host.exe"
      // We should probably find where the current project is.
      
      // For this specific project, we know the structure.
      // The manifest files are in LinkMate/host_manifest/
      // The host executable is in LinkMate/app/host.exe (per manifest) 
      // OR it might be this very app if it acts as host.
      
      String exePath = Platform.resolvedExecutable;
      // If we are running in debug mode, resolvedExecutable might be dart.exe.
      // Let's assume the user wants to register THIS app as the host if they are running a build,
      // but for now we'll stick to the path in the root if we can find it.
      
      // Let's find the root directory by looking for 'host_manifest'
      Directory current = Directory.current;
      String? rootPath;
      
      // Simple heuristic to find project root
      for (int i = 0; i < 5; i++) {
        if (await Directory(p.join(current.path, 'host_manifest')).exists()) {
          rootPath = current.path;
          break;
        }
        current = current.parent;
      }
      
      if (rootPath == null) {
        throw Exception("Could not find project root (host_manifest directory)");
      }

      final chromeManifestPath = p.join(rootPath, 'host_manifest', 'com.linkmate.host_chrome.json');
      final edgeManifestPath = p.join(rootPath, 'host_manifest', 'com.linkmate.host_edge.json');
      final firefoxManifestPath = p.join(rootPath, 'host_manifest', 'com.linkmate.host_firefox.json');
      
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
