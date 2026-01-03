import 'dart:io';
import 'dart:typed_data';
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
    return await _initDatabase();
  }

  static bool _ffiInitialized = false;
  static Future<Database>? _initFuture;

  Future<Database> _initDatabase() async {
    if (_initFuture != null) return _initFuture!;
    
    _initFuture = _doInitDatabase();
    return _initFuture!;
  }

  Future<Database> _doInitDatabase() async {
    // Initialize FFI only once
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final dbPath = p.join(Directory.current.path, 'linkmate.db');
    
    final db = await openDatabase(
      dbPath,
      version: 3, // Increment version
      onCreate: (db, version) async {
        // Table: browsers
        await db.execute('''
          CREATE TABLE browsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            account_id TEXT,
            name TEXT,
            last_seen INTEGER,
            icon_data BLOB
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
            favicon_data BLOB,
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          var columns = await db.rawQuery('PRAGMA table_info(tabs)');
          bool columnExists = columns.any((column) => column['name'] == 'favicon_data');
          if (!columnExists) {
            await db.execute('ALTER TABLE tabs ADD COLUMN favicon_data BLOB');
          }
        }
        if (oldVersion < 3) {
          var columns = await db.rawQuery('PRAGMA table_info(browsers)');
          bool columnExists = columns.any((column) => column['name'] == 'icon_data');
          if (!columnExists) {
            await db.execute('ALTER TABLE browsers ADD COLUMN icon_data BLOB');
          }
        }
      },
    );

    // Set busy timeout to 5 seconds to handle concurrent writes
    await db.execute('PRAGMA busy_timeout = 5000');
    
    _database = db;
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

      // 2. Diff Sync to preserve favicon_data
      // Fetch existing tabs to keep favicon_data if URL hasn't changed
      final existingTabs = await txn.query('tabs', where: 'browser_id = ?', columns: ['url', 'favicon_url', 'favicon_data'], whereArgs: [browserId]);
      final faviconMap = {for (var t in existingTabs) t['url'] as String: t['favicon_data'] as Uint8List?};

      // Clear existing data for this browser
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
        final url = tab['url'] as String;
        final favIconUrl = tab['favIconUrl'] as String?;
        
        // Try to preserve existing data if it's the same URL
        var faviconData = faviconMap[url];

        batch.insert('tabs', {
          'browser_id': browserId,
          'tab_id': tab['tabId'],
          'title': tab['title'],
          'url': url,
          'favicon_url': favIconUrl,
          'favicon_data': faviconData,
          'group_id': tab['groupId'],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> updateTabFavicon(int id, Uint8List data) async {
    final db = await database;
    await db.update(
      'tabs',
      {'favicon_data': data},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateBrowserIcon(int id, Uint8List data) async {
    final db = await database;
    await db.update(
      'browsers',
      {'icon_data': data},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getBrowsersWithTabCounts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, COUNT(t.id) as tab_count
      FROM browsers b
      LEFT JOIN tabs t ON b.id = t.browser_id
      GROUP BY b.id
      ORDER BY b.last_seen DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getTabsForBrowser(int browserId) async {
    final db = await database;
    return await db.query('tabs', where: 'browser_id = ?', whereArgs: [browserId]);
  }

  Future<List<Map<String, dynamic>>> getAllTabs() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, b.name as browser_name
      FROM tabs t
      JOIN browsers b ON t.browser_id = b.id
    ''');
  }

  Future<int> getTotalTabCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tabs');
    return (result.first['count'] as int?) ?? 0;
  }
}

