import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = p.join(Directory.current.path, 'linkmate.db');
    
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Table: browsers
        await db.execute('''
          CREATE TABLE browsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            account_id TEXT,
            name TEXT,
            last_seen INTEGER
          )
        ''');

        // Table: tabs
        await db.execute('''
          CREATE TABLE tabs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            browser_id INTEGER NOT NULL,
            tab_id INTEGER NOT NULL,
            title TEXT,
            url TEXT,
            favicon_url TEXT,
            group_id INTEGER,
            FOREIGN KEY (browser_id) REFERENCES browsers (id) ON DELETE CASCADE
          )
        ''');

        // Table: tab_groups
        await db.execute('''
          CREATE TABLE tab_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            browser_id INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            title TEXT,
            color TEXT,
            FOREIGN KEY (browser_id) REFERENCES browsers (id) ON DELETE CASCADE
          )
        ''');
        
        // Table: tab_clicks (Place holder for future feature)
        await db.execute('''
          CREATE TABLE tab_clicks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tab_id INTEGER,
            click_count INTEGER DEFAULT 0,
            last_access_time INTEGER
          )
        ''');
      },
    );

    // Set busy timeout to 5 seconds to handle concurrent writes
    await db.execute('PRAGMA busy_timeout = 5000');
    
    return db;
  }

  Future<void> syncTabs(String browserType, String? accountId, List<dynamic> tabs, List<dynamic> groups, {String? profileName}) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Find or Create Browser ID
      final browserList = await txn.query(
        'browsers',
        where: 'type = ? AND account_id = ?',
        whereArgs: [browserType, accountId ?? 'default'],
      );

      int browserId;
      if (browserList.isNotEmpty) {
        browserId = browserList.first['id'] as int;
        
        // Update name and timestamp
        final updatedName = profileName ?? browserType;
        await txn.update(
          'browsers',
          {
            'name': updatedName,
            'last_seen': DateTime.now().millisecondsSinceEpoch
          },
          where: 'id = ?',
          whereArgs: [browserId],
        );
      } else {
        browserId = await txn.insert('browsers', {
          'type': browserType,
          'account_id': accountId ?? 'default',
          'name': profileName ?? browserType,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // 2. Clear existing data for this browser (Naive Sync)
      // Note: In a real app, we might want to diff to preserve local stats if linked by specific ID
      await txn.delete('tabs', where: 'browser_id = ?', whereArgs: [browserId]);
      await txn.delete('tab_groups', where: 'browser_id = ?', whereArgs: [browserId]);

      // 3. Insert Groups
      for (final group in groups) {
        await txn.insert('tab_groups', {
          'browser_id': browserId,
          'group_id': group['groupId'],
          'title': group['title'],
          'color': group['color'],
        });
      }

      // 4. Insert Tabs
      final batch = txn.batch();
      for (final tab in tabs) {
        batch.insert('tabs', {
          'browser_id': browserId,
          'tab_id': tab['tabId'],
          'title': tab['title'],
          'url': tab['url'],
          'favicon_url': tab['favIconUrl'],
          'group_id': tab['groupId'],
        });
      }
      await batch.commit(noResult: true);
    });
  }
  Future<List<Map<String, dynamic>>> getBrowsers() async {
    final db = await database;
    return await db.query('browsers', orderBy: 'last_seen DESC');
  }

  Future<List<Map<String, dynamic>>> getTabsForBrowser(int browserId) async {
    final db = await database;
    return await db.query('tabs', where: 'browser_id = ?', whereArgs: [browserId]);
  }
}
