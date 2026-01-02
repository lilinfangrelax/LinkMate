import 'dart:async';
import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LinkMateApp());
}

class LinkMateApp extends StatelessWidget {
  const LinkMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkMate',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BrowsersPage(),
    );
  }
}

class BrowsersPage extends StatefulWidget {
  const BrowsersPage({super.key});

  @override
  State<BrowsersPage> createState() => _BrowsersPageState();
}

class _BrowsersPageState extends State<BrowsersPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _browsers = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refreshBrowsers();
    // Auto-refresh every 2 seconds to see incoming syncs live
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshBrowsers();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBrowsers() async {
    final browsers = await _dbHelper.getBrowsers();
    setState(() {
      _browsers = browsers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshBrowsers(),
          ),
        ],
      ),
      body: _browsers.isEmpty
          ? const Center(child: Text('No browsers synced yet.'))
          : ListView.builder(
              itemCount: _browsers.length,
              itemBuilder: (context, index) {
                final browser = _browsers[index];
                return BrowserCard(
                  browser: browser,
                  dbHelper: _dbHelper,
                );
              },
            ),
    );
  }
}

class BrowserCard extends StatefulWidget {
  final Map<String, dynamic> browser;
  final DatabaseHelper dbHelper;

  const BrowserCard({super.key, required this.browser, required this.dbHelper});

  @override
  State<BrowserCard> createState() => _BrowserCardState();
}

class _BrowserCardState extends State<BrowserCard> {
  List<Map<String, dynamic>> _tabs = [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Pre-load tabs if you want, or load on expand
  }

  Future<void> _loadTabs() async {
    final browserId = widget.browser['id'] as int;
    final tabs = await widget.dbHelper.getTabsForBrowser(browserId);
    if (mounted) {
      setState(() {
        _tabs = tabs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (expanded) {
          setState(() => _expanded = expanded);
          if (expanded) {
            _loadTabs();
          }
        },
        title: Text(widget.browser['name'] ?? 'Unknown Browser'),
        subtitle: Text('Last seen: ${DateTime.fromMillisecondsSinceEpoch(widget.browser['last_seen'])}'),
        leading: Icon(
          widget.browser['type'] == 'chrome'
              ? Icons.web
              : Icons.web_asset,
          color: Colors.blueAccent,
        ),
        children: [
          if (_tabs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No tabs or loading..."),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                return ListTile(
                  leading: tab['favicon_url'] != null && (tab['favicon_url'] as String).isNotEmpty
                      ? const Icon(Icons.circle, size: 12, color: Colors.grey) // Placeholder
                      : const Icon(Icons.public, size: 20),
                  title: Text(
                    tab['title'] ?? 'No Title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    tab['url'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    // Future: Send command to browser to focus this tab
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
