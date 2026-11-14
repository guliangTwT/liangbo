/// 本地持久化。
///
/// 设计约束（来自"资源占用极低"）：
/// - 不做常驻数据库，配置就一个小 JSON，读写都是几十 KB 级别
/// - 不引入 shared_preferences（Windows 下它也是 JSON + 文件，多一层封装没必要）
///
/// 登录态不在这里存：WebView2 的 userDataFolder 会自行持久化 cookie，
/// 由系统按当前 Windows 用户隔离。这样既不用我们写加密，也不会明文落盘。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 是否输出诊断日志。
///
/// 排查配置写入问题时改成 true 重新构建，会在 %APPDATA% 下留一个
/// Liangbo-diag.log。平时关闭，避免用户目录里多出垃圾文件。
const bool kVerboseLog = false;

/// 保存的账号。
class SavedAccount {
  SavedAccount({
    required this.id,
    required this.label,
    this.phone = '',
    this.lastServer = '',
    this.lastKey = '',
    this.lastSyncAt,
  });

  final String id;
  String label;
  String phone;

  /// 最近一次成功抓取的推流信息，用于免登录时先展示缓存。
  String lastServer;
  String lastKey;
  DateTime? lastSyncAt;

  bool get hasCache => lastServer.isNotEmpty && lastKey.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'phone': phone,
        'lastServer': lastServer,
        'lastKey': lastKey,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  static SavedAccount fromJson(Map<String, dynamic> j) => SavedAccount(
        id: (j['id'] as String?) ?? '',
        label: (j['label'] as String?) ?? '未命名',
        phone: (j['phone'] as String?) ?? '',
        lastServer: (j['lastServer'] as String?) ?? '',
        lastKey: (j['lastKey'] as String?) ?? '',
        lastSyncAt: DateTime.tryParse((j['lastSyncAt'] as String?) ?? ''),
      );

  /// 手机号脱敏展示
  String get maskedPhone {
    if (phone.length < 7) return phone.isEmpty ? '未绑定' : phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }
}

/// 应用设置。
class AppSettings {
  AppSettings({
    this.rememberSession = true,
    this.autoExtractOnOpen = true,
    this.startPage = 'studio',
    this.closeToTray = false,
    this.windowWidth = 1120,
    this.windowHeight = 736,
  });

  /// 记住登录态（依赖 WebView2 userDataFolder），下次打开免登录。
  bool rememberSession;

  /// 进入推流页面后自动抓取。
  bool autoExtractOnOpen;

  /// 启动后打开哪个页面：studio / live
  String startPage;

  bool closeToTray;

  double windowWidth;
  double windowHeight;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rememberSession': rememberSession,
        'autoExtractOnOpen': autoExtractOnOpen,
        'startPage': startPage,
        'closeToTray': closeToTray,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        rememberSession: (j['rememberSession'] as bool?) ?? true,
        autoExtractOnOpen: (j['autoExtractOnOpen'] as bool?) ?? true,
        startPage: (j['startPage'] as String?) ?? 'studio',
        closeToTray: (j['closeToTray'] as bool?) ?? false,
        windowWidth: (j['windowWidth'] as num?)?.toDouble() ?? 1120,
        windowHeight: (j['windowHeight'] as num?)?.toDouble() ?? 736,
      );
}

/// 整体配置。
class AppConfig {
  AppConfig({
    List<SavedAccount>? accounts,
    AppSettings? settings,
    this.activeAccountId = '',
  })  : accounts = accounts ?? <SavedAccount>[],
        settings = settings ?? AppSettings();

  final List<SavedAccount> accounts;
  AppSettings settings;
  String activeAccountId;

  SavedAccount? get active {
    for (final SavedAccount a in accounts) {
      if (a.id == activeAccountId) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'accounts': accounts.map((SavedAccount a) => a.toJson()).toList(),
        'settings': settings.toJson(),
        'activeAccountId': activeAccountId,
      };

  static AppConfig fromJson(Map<String, dynamic> j) => AppConfig(
        accounts: ((j['accounts'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(SavedAccount.fromJson)
            .toList(),
        settings: AppSettings.fromJson(
            (j['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
        activeAccountId: (j['activeAccountId'] as String?) ?? '',
      );
}

/// 配置存储。
///
/// 写入策略：先写 .tmp 再原子替换，避免掉电/崩溃时留下半截文件。
class ConfigStore {
  ConfigStore._();
  static final ConfigStore instance = ConfigStore._();

  Directory? _dir;
  File? _file;
  AppConfig? _cache;

  /// 串行化写入。
  ///
  /// 每次 save 都排到上一条之后执行，并 await 到真正写完。
  /// 用 Future 链而不是 bool 标志：bool 标志会把后到的保存直接丢掉。
  Future<void> _writeChain = Future<void>.value();

  Future<void> init() async {
    // 数据目录固定用「AppData\Roaming\Liangbo」这个纯 ASCII 路径。
    //
    // 不用 getApplicationSupportDirectory()：它的末级目录取自 Runner.rc 的
    // ProductName（中文「凉播」），中文路径在 WebView2 的 userDataFolder
    // 和部分文件操作上容易出问题。这里自己拼，保证全链路 ASCII。
    final Directory? roaming = Platform.environment['APPDATA'] != null
        ? Directory(Platform.environment['APPDATA']!)
        : null;
    final Directory base = roaming ?? await getApplicationSupportDirectory();
    _dir = Directory('${base.path}${Platform.pathSeparator}Liangbo');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    _file = File('${_dir!.path}${Platform.pathSeparator}config.json');
    debugPrint('config path: ${_file!.path}');
  }

  /// 数据目录，WebView 的 userDataFolder 也放这里。
  String get dataDir => _dir?.path ?? '';

  String get webviewDir => '$_dir${Platform.pathSeparator}webview';

  AppConfig get config => _cache ??= AppConfig();

  Future<AppConfig> load() async {
    if (_cache != null) return _cache!;
    final File? f = _file;
    if (f == null || !await f.exists()) {
      _cache = AppConfig();
      return _cache!;
    }
    try {
      String raw = await f.readAsString();
      // 去掉 UTF-8 BOM。用户手改配置（记事本另存）时很容易带上 BOM，
      // 而 jsonDecode 不认它，会直接抛异常导致整个配置被当作损坏。
      if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) {
        raw = raw.substring(1);
      }
      if (raw.trim().isEmpty) {
        _cache = AppConfig();
        return _cache!;
      }
      final Object? decoded = jsonDecode(raw);
      _cache = decoded is Map<String, dynamic> ? AppConfig.fromJson(decoded) : AppConfig();
    } catch (e) {
      // 配置损坏时不要卡死启动：备份坏文件后重建
      debugPrint('config parse failed: $e');
      try {
        await f.rename('${f.path}.broken-${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
      _cache = AppConfig();
    }
    return _cache!;
  }

  /// 保存配置。多次调用会按顺序串行执行，且每次调用都等到真正写完才返回。
  Future<void> save() {
    // 用 then 串行化，但要处理前一次失败的情况，否则一次失败会卡死整条链
    final Future<void> next = _writeChain
        .catchError((Object _) {}) // 吞掉上一条的错误，保证链条继续
        .then((_) => _writeNow());
    _writeChain = next;
    return next;
  }

  Future<void> _writeNow() async {
    final File? f = _file;
    _diag('_writeNow start, file=${f?.path}');
    if (f == null) {
      _diag('_writeNow aborted: _file is null (init() not called?)');
      return;
    }
    try {
      final String raw = const JsonEncoder.withIndent('  ').convert(config.toJson());
      final File tmp = File('${f.path}.tmp');
      await tmp.writeAsString(raw, flush: true);
      _diag('tmp written, ${raw.length} chars');
      // Windows 上 rename 到已存在的文件会失败，先删再改名。
      // tmp 与目标同目录，rename 是原子的。
      if (await f.exists()) {
        await f.delete();
      }
      await tmp.rename(f.path);
      _diag('renamed ok, exists=${await f.exists()}');
    } catch (e, st) {
      _diag('save failed: $e\n$st');
    }
  }

  /// 诊断输出。
  ///
  /// 写一个独立日志文件——release 模式下 debugPrint 会被编译掉，
  /// 而配置写入是"用户看不见但必须正确"的路径，出问题必须能查。
  void _diag(String msg) {
    if (!kVerboseLog) return;
    try {
      final String? appdata = Platform.environment['APPDATA'];
      if (appdata == null) return;
      final File log = File('$appdata${Platform.pathSeparator}Liangbo-diag.log');
      log.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $msg\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  // ===== 账号操作 =====

  Future<SavedAccount> addAccount({required String label, String phone = ''}) async {
    final String id = _newId();
    final SavedAccount a = SavedAccount(id: id, label: label, phone: phone);
    config.accounts.add(a);
    if (config.activeAccountId.isEmpty) config.activeAccountId = id;
    await save();
    return a;
  }

  Future<void> removeAccount(String id) async {
    config.accounts.removeWhere((SavedAccount a) => a.id == id);
    if (config.activeAccountId == id) {
      config.activeAccountId =
          config.accounts.isEmpty ? '' : config.accounts.first.id;
    }
    await save();
  }

  Future<void> setActive(String id) async {
    config.activeAccountId = id;
    await save();
  }

  Future<void> cacheStream(String accountId, String server, String key) async {
    for (final SavedAccount a in config.accounts) {
      if (a.id == accountId) {
        a.lastServer = server;
        a.lastKey = key;
        a.lastSyncAt = DateTime.now();
        break;
      }
    }
    await save();
  }

  Future<void> editAccount(String id, {String? label, String? phone}) async {
    for (final SavedAccount a in config.accounts) {
      if (a.id == id) {
        if (label != null && label.trim().isNotEmpty) a.label = label.trim();
        if (phone != null) a.phone = phone.trim();
        break;
      }
    }
    await save();
  }

  /// 删除 WebView 的数据目录，等价于退出登录。
  ///
  /// 调用前必须先卸载 WebView，否则目录被占用删不掉（Windows 文件锁）。
  Future<void> deleteWebviewData() async {
    final Directory d = Directory(webviewDir);
    try {
      if (await d.exists()) {
        await d.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('delete webview data failed: $e');
    }
  }

  String _newId() {
    final int now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(36);
  }
}
