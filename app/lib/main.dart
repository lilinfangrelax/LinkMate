import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'settings_service.dart';

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
  List<Map<String, dynamic>> _tabs = [];
  int? _selectedBrowserId; // null means "All"
  int _totalTabCount = 0;
  Timer? _timer;
  bool _showSettings = false;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _refreshData();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final browsers = await _dbHelper.getBrowsersWithTabCounts();
    final totalCount = await _dbHelper.getTotalTabCount();
    
    List<Map<String, dynamic>> tabs;
    if (_selectedBrowserId == null) {
      tabs = await _dbHelper.getAllTabs();
    } else {
      tabs = await _dbHelper.getTabsForBrowser(_selectedBrowserId!);
    }

    if (mounted) {
      setState(() {
        _browsers = browsers;
        _totalTabCount = totalCount;
        _tabs = tabs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkMate'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
            ),
            child: BrowserSidebar(
              browsers: _browsers,
              totalCount: _totalTabCount,
              selectedId: _selectedBrowserId,
              showSettings: _showSettings,
              onSelect: (id) {
                setState(() {
                  _selectedBrowserId = id;
                  _showSettings = false;
                });
                _refreshData();
              },
              onSettingsTap: () {
                setState(() {
                  _showSettings = true;
                  _selectedBrowserId = null;
                });
              },
            ),
          ),
          // Main Content
          Expanded(
            child: _showSettings 
              ? SettingsPage(settingsService: _settingsService)
              : LinksView(
                  tabs: _tabs,
                  dbHelper: _dbHelper,
                  title: _selectedBrowserId == null 
                      ? 'All Links' 
                      : _browsers.firstWhere((b) => b['id'] == _selectedBrowserId, orElse: () => {'name': 'Browser'})['name'],
                ),
          ),
        ],
      ),
    );
  }
}

class BrowserSidebar extends StatelessWidget {
  final List<Map<String, dynamic>> browsers;
  final int totalCount;
  final int? selectedId;
  final bool showSettings;
  final Function(int?) onSelect;
  final VoidCallback onSettingsTap;

  const BrowserSidebar({
    super.key, 
    required this.browsers, 
    required this.totalCount, 
    required this.selectedId, 
    required this.showSettings,
    required this.onSelect,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          dense: true,
          selected: selectedId == null,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.all_inclusive, size: 20, color: Colors.blueAccent),
          title: const Text('全部', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text('$totalCount', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          onTap: () => onSelect(null),
        ),
        const Divider(height: 1),
        ...browsers.map((browser) {
          final isSelected = selectedId == browser['id'];
          return ListTile(
            dense: true,
            selected: isSelected,
            leading: BrowserIcon(
              browser: browser,
            ),
            title: Text(
              browser['name'] ?? 'Unknown Browser',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '${browser['tab_count']}',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () => onSelect(browser['id']),
          );
        }),
        const Spacer(),
        const Divider(height: 1),
        ListTile(
          dense: true,
          selected: showSettings,
          leading: const Icon(Icons.settings, size: 20),
          title: const Text('设置'),
          onTap: onSettingsTap,
        ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  final SettingsService settingsService;
  const SettingsPage({super.key, required this.settingsService});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _chromeIdController = TextEditingController();
  final TextEditingController _edgeIdController = TextEditingController();
  final TextEditingController _firefoxIdController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final chromeId = await widget.settingsService.getChromeId();
    final edgeId = await widget.settingsService.getEdgeId();
    final firefoxId = await widget.settingsService.getFirefoxId();
    setState(() {
      _chromeIdController.text = chromeId;
      _edgeIdController.text = edgeId;
      _firefoxIdController.text = firefoxId;
      _loading = false;
    });
  }

  Future<void> _handleRegister() async {
    setState(() => _saving = true);
    
    // Save current IDs first
    await widget.settingsService.setChromeId(_chromeIdController.text);
    await widget.settingsService.setEdgeId(_edgeIdController.text);
    await widget.settingsService.setFirefoxId(_firefoxIdController.text);
    
    final success = await widget.settingsService.registerHost();
    
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '注册成功！' : '注册失败，请检查日志'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '应用设置',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '配置浏览器扩展 ID 以允许应用与浏览器通讯。',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _handleRegister,
                  icon: _saving 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 20),
                  label: const Text('保存并应用'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 24, endIndent: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBrowserSection(
                    title: 'Google Chrome',
                    icon: 'assets/chrome_888896.png',
                    controller: _chromeIdController,
                    hint: '例如: iakdbplajafmdpacnkbojcndfkaagodl',
                  ),
                  const SizedBox(height: 16),
                  _buildBrowserSection(
                    title: 'Microsoft Edge',
                    icon: 'assets/edge_888899.png',
                    controller: _edgeIdController,
                    hint: '例如: kbffpkbiighjnfefjgkjhnnhofajldbe',
                  ),
                  const SizedBox(height: 16),
                  _buildBrowserSection(
                    title: 'Mozilla Firefox',
                    icon: 'assets/firefox_888902.png',
                    controller: _firefoxIdController,
                    hint: '例如: linkmate@linkmate.com',
                  ),
   
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserSection({
    required String title, 
    required String icon, 
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(icon, width: 24, height: 24, errorBuilder: (c, e, s) => const Icon(Icons.browser_updated, size: 24)),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '扩展 ID / 标识符',
              hintText: hint,
              helperText: '在编辑完成后，点击下方的“应用设置”生效',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class BrowserIcon extends StatelessWidget {
  final Map<String, dynamic> browser;
  final double size;

  const BrowserIcon({
    super.key, 
    required this.browser, 
    this.size = 20
  });

  String _getAssetPath(String type) {
    final t = type.toLowerCase();
    if (t.contains('chrome')) {
      return 'assets/chrome_888896.png';
    } else if (t.contains('edge')) {
      return 'assets/edge_888899.png';
    } else if (t.contains('firefox')) {
      return 'assets/firefox_888902.png';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final type = browser['type'] as String? ?? '';
    final assetPath = _getAssetPath(type);

    if (assetPath.isEmpty) {
      return Icon(Icons.web, size: size, color: Colors.blueAccent);
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => Icon(Icons.web, size: size, color: Colors.blueAccent),
    );
  }
}

class LinksView extends StatelessWidget {
  final List<Map<String, dynamic>> tabs;
  final DatabaseHelper dbHelper;
  final String title;

  const LinksView({
    super.key, 
    required this.tabs, 
    required this.dbHelper,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No links found in $title', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: FaviconWidget(
                    tab: tab,
                    dbHelper: dbHelper,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tab['title'] ?? 'No Title',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tab['browser_name'] != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 0.5),
                          ),
                          child: Text(
                            tab['browser_name'],
                            style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    tab['url'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    // Action
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FaviconWidget extends StatefulWidget {
  final Map<String, dynamic> tab;
  final DatabaseHelper dbHelper;

  const FaviconWidget({super.key, required this.tab, required this.dbHelper});

  @override
  State<FaviconWidget> createState() => _FaviconWidgetState();
}

class _FaviconWidgetState extends State<FaviconWidget> {
  Uint8List? _iconData;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _iconData = widget.tab['favicon_data'] as Uint8List?;
    if (_iconData == null) {
      _loadIcon();
    }
  }

  @override
  void didUpdateWidget(FaviconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab['id'] != oldWidget.tab['id'] || widget.tab['favicon_url'] != oldWidget.tab['favicon_url']) {
        _iconData = widget.tab['favicon_data'] as Uint8List?;
        if (_iconData == null) {
          _loadIcon();
        }
    }
  }

  Future<void> _loadIcon() async {
    final url = widget.tab['favicon_url'] as String?;
    if (url == null || url.isEmpty) return;

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      Uint8List? data;
      if (url.startsWith('data:image/')) {
        // Handle Base64
        final String base64Str = url.split(',').last;
        data = base64Decode(base64Str);
      } else if (url.startsWith('http')) {
        // Handle URL
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          data = response.bodyBytes;
        }
      }

      if (data != null && mounted) {
        setState(() {
          _iconData = data;
          _loading = false;
        });
        // Save to database
        await widget.dbHelper.updateTabFavicon(widget.tab['id'], data);
      } else {
         if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading favicon: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_iconData != null) {
      return Image.memory(
        _iconData!,
        width: 20,
        height: 20,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.public, size: 20),
      );
    }

    if (_loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return const Icon(Icons.public, size: 20);
  }
}

