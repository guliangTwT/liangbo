import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/config_store.dart';
import '../core/stream_extractor.dart';

/// 应用运行阶段。
enum Stage {
  /// 还没开始，等待用户操作
  idle,

  /// WebView 正在加载页面
  loading,

  /// 停在登录页，等用户手动登录
  login,

  /// 登录完成，正在进入推流页
  entering,

  /// 正在抓取
  extracting,

  /// 抓取成功
  done,

  /// 出错
  error,
}

/// 全局状态。
///
/// 用 [ChangeNotifier] 而不是引入 Provider/Riverpod：整个应用只有一个状态源，
/// 手写监听是最省内存的方案（少一层 InheritedWidget 重建）。
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final ConfigStore _store = ConfigStore.instance;

  AppConfig get config => _store.config;
  AppSettings get settings => config.settings;

  // ===== 运行时状态 =====
  Stage _stage = Stage.idle;
  Stage get stage => _stage;

  String _statusText = '准备就绪';
  String get statusText => _statusText;

  StreamInfo? _stream;
  StreamInfo? get stream => _stream;

  /// 已抓到的最近一次结果（即使当前正在出错，也保留供复制）
  StreamInfo? _lastGood;
  StreamInfo? get lastGood => _lastGood;

  bool _webviewVisible = true;
  bool get webviewVisible => _webviewVisible;

  /// 浏览器实例是否挂载在组件树上。
  ///
  /// WebView2 一旦创建，就会在进程内拉起一整套 Chromium 组件（实测主进程
  /// 提交内存 +700MB、多出 16 个线程）。这些开销只有"需要和网页交互"时才值得付。
  ///
  /// 所以这里做成按需挂载：登录/抓取时挂上，抓完就卸载（组件销毁会连带
  /// 释放 WebView2 环境）。空闲时应用只剩 Flutter 本身的开销。
  bool _browserMounted = false;
  bool get browserMounted => _browserMounted;

  /// 首次启动被调用过 startFlow，但 WebView 还没就绪。
  /// WebView 创建是异步的，这里记住意图，等 onWebViewCreated 后补执行。
  bool _startPending = false;

  /// 页面就绪后需要自动执行的启动动作。
  void onControllerReady() {
    if (_startPending) {
      _startPending = false;
      startFlow();
    }
  }

  /// 挂载浏览器并进入登录/抓取流程。
  Future<void> openBrowser() async {
    if (_browserMounted) {
      _webviewVisible = true;
      notifyListeners();
      startFlow();
      return;
    }
    _browserMounted = true;
    _webviewVisible = true;
    _set(Stage.loading, '正在准备浏览器…');
    // WebView 创建完成后会回调 onControllerReady
    _startPending = true;
    notifyListeners();
  }

  /// 卸载浏览器，释放 WebView2 占用的资源。
  ///
  /// 登录态默认保留（cookie 已由 userDataFolder 落盘，下次挂载还在）。
  /// 但若用户关了「记住登录状态」，就在卸载后清掉那份数据，
  /// 保证下次打开必须重新登录。
  void closeBrowser() {
    if (!_browserMounted) return;
    _browserMounted = false;
    _webviewVisible = false;
    controller = null;
    _stopPolling();
    // 已抓到结果就保持 done；否则回到 idle
    if (_stage != Stage.done) {
      _stage = Stage.idle;
      _statusText = _lastGood != null ? '已显示上次结果' : '准备就绪';
    }
    notifyListeners();

    if (!settings.rememberSession) {
      // 组件销毁后文件句柄才会释放，稍等再删
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!_browserMounted) _store.deleteWebviewData();
      });
    }
  }

  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  bool _canGoBack = false;
  bool get canGoBack => _canGoBack;

  /// 设置面板是否可见（触发 UI 层的显示动画）
  bool _settingsOpen = false;
  bool get settingsOpen => _settingsOpen;

  /// 账号面板
  bool _accountsOpen = false;
  bool get accountsOpen => _accountsOpen;

  InAppWebViewController? controller;

  Timer? _pollTimer;

  /// 进入后台页面后的几次延时抓取。必须存下来才能取消，
  /// 否则页面切走后这些定时器仍会触发，拿着已经失效的 controller 干活。
  final List<Timer> _extractTimers = <Timer>[];

  DateTime _lastExtractAt = DateTime.fromMillisecondsSinceEpoch(0);

  // 目标页面
  static const String studioUrl = 'https://studio.kuaishou.com/studio/live';
  static const String loginUrl = 'https://passport.kuaishou.com/pc/account/login';
  static const String studioHomeUrl = 'https://studio.kuaishou.com/';

  Future<void> init() async {
    await _store.load();
    _stage = Stage.idle;
    _statusText = '准备就绪';
    notifyListeners();
  }

  // ===== 生命周期控制 =====

  /// 首次进入：打开推流后台页面。若已登录会直接进，否则跳登录页。
  ///
  /// WebView 实例是异步创建的（首帧后才有 controller），所以这里可能被
  /// 提前调用。此时只登记意图，等 onWebViewCreated 回调再来一次。
  Future<void> startFlow({bool forceLogin = false}) async {
    final InAppWebViewController? c = controller;
    if (c == null) {
      _startPending = true;
      _set(Stage.loading, '正在准备浏览器…');
      return;
    }
    _stream = null;
    _set(Stage.loading, '正在打开快手直播后台…');
    _webviewVisible = true;
    notifyListeners();
    try {
      final String url = forceLogin
          ? loginUrl
          : (settings.startPage == 'live' ? 'https://live.kuaishou.com/' : studioUrl);
      await c.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (e) {
      _set(Stage.error, '打开页面失败：$e');
    }
  }

  Future<void> reload() async {
    final InAppWebViewController? c = controller;
    if (c == null) return;
    _set(Stage.loading, '正在刷新…');
    try {
      await c.reload();
    } catch (_) {}
  }

  Future<void> goBack() async {
    final InAppWebViewController? c = controller;
    if (c == null) return;
    if (await c.canGoBack()) {
      await c.goBack();
    }
  }

  Future<void> openSettings(bool open) async {
    _settingsOpen = open;
    if (open) _accountsOpen = false;
    notifyListeners();
  }

  Future<void> openAccounts(bool open) async {
    _accountsOpen = open;
    if (open) _settingsOpen = false;
    notifyListeners();
  }

  void toggleWebview() {
    _webviewVisible = !_webviewVisible;
    notifyListeners();
  }

  void showWebview() {
    if (!_webviewVisible) {
      _webviewVisible = true;
      notifyListeners();
    }
  }

  /// 直接把缓存结果填到界面上，不启动浏览器。
  ///
  /// 这是"冷启动零开销"的关键：上次抓到的推流码通常仍然有效，
  /// 让用户一打开就能复制，不必每次等一个浏览器。
  void showCached(StreamInfo info) {
    if (_stream != null) return;
    _lastGood = info;
    _statusText = '上次读取的结果';
    _stage = Stage.idle;
    notifyListeners();
  }

  /// 当前展示的数据是否为缓存（非本次会话抓取）。
  bool get showingCache => _stream == null && _lastGood != null;

  // ===== WebView 事件 =====

  void onPageStarted(String url) {
    _currentUrl = url;
    _canGoBack = false;
    if (_isLoginUrl(url)) {
      _set(Stage.login, '请在下方窗口登录快手');
    } else if (_stage == Stage.idle) {
      _set(Stage.loading, '正在加载…');
    }
    notifyListeners();
  }

  void onPageFinished(String url) {
    _currentUrl = url;
    _refreshNav();

    if (_isLoginUrl(url)) {
      _set(Stage.login, '请在下方窗口登录快手');
      return;
    }

    // 落地到后台页面：自动抓一次
    if (settings.autoExtractOnOpen) {
      _set(Stage.entering, '正在读取推流信息…');
      // 等 Vue 把数据渲染出来；两次尝试覆盖快慢网络
      _scheduleExtract(delays: const <int>[600, 1800, 3500]);
    } else {
      _set(Stage.idle, '已进入后台，点"读取推流码"开始');
    }
    notifyListeners();
  }

  void onLoadError(String message) {
    _set(Stage.error, '页面加载失败：$message');
  }

  Future<void> _refreshNav() async {
    final InAppWebViewController? c = controller;
    if (c == null) return;
    try {
      _canGoBack = await c.canGoBack();
      notifyListeners();
    } catch (_) {}
  }

  bool _isLoginUrl(String url) {
    final String u = url.toLowerCase();
    return u.contains('passport.kuaishou.com') ||
        u.contains('/pc/account/login') ||
        (u.contains('kuaishou.com') && u.contains('/login'));
  }

  // ===== 抓取 =====

  /// 手动触发抓取。
  ///
  /// 浏览器没挂载时（用户还没登录过），先拉起浏览器再抓，避免点了没反应。
  Future<void> extractNow() async {
    if (!_browserMounted) {
      await openBrowser();
      return;
    }
    await _runExtract(userInitiated: true);
  }

  void _scheduleExtract({required List<int> delays}) {
    _cancelExtractTimers();
    int acc = 0;
    for (final int d in delays) {
      acc += d;
      _extractTimers.add(Timer(Duration(milliseconds: acc), () {
        _runExtract(userInitiated: false);
      }));
    }
  }

  void _cancelExtractTimers() {
    for (final Timer t in _extractTimers) {
      t.cancel();
    }
    _extractTimers.clear();
  }

  Future<void> _runExtract({required bool userInitiated}) async {
    final InAppWebViewController? c = controller;
    if (c == null) return;

    // 防抖：同一页面 800ms 内不重复跑，避免轮询把 CPU 打高
    final DateTime now = DateTime.now();
    if (!userInitiated && now.difference(_lastExtractAt).inMilliseconds < 800) {
      return;
    }
    _lastExtractAt = now;

    if (userInitiated) {
      _set(Stage.extracting, '正在读取推流信息…');
    }

    try {
      final Object? raw = await c.evaluateJavascript(source: kExtractScript);
      final ExtractResult r = parseExtractPayload(raw?.toString() ?? '');

      if (r.ok) {
        _stream = r.info;
        _lastGood = r.info;
        _set(Stage.done, '推流码已获取');
        // 写入账号缓存，供免登录时先展示
        final SavedAccount? act = config.active;
        if (act != null && r.info != null) {
          unawaited(_store.cacheStream(act.id, r.info!.server, r.info!.key));
        }
        _stopPolling();
        // 抓完就没必要继续养着一个 Chromium：延后一点卸载，
        // 让 UI 先把结果动画播完，避免同帧销毁导致掉帧。
        Timer(const Duration(milliseconds: 1100), () {
          if (_stage == Stage.done) closeBrowser();
        });
        return;
      }

      if (r.sawLoginPage) {
        _set(Stage.login, '请在下方窗口登录快手');
        return;
      }

      // 没抓到：如果用户手动触发，给出明确原因；自动触发则保持安静
      if (userInitiated) {
        _set(Stage.error, r.reason.isEmpty ? '未找到推流信息' : r.reason);
      } else {
        _statusText = r.reason.isEmpty ? '等待页面加载推流信息…' : r.reason;
        notifyListeners();
      }
    } catch (e) {
      if (userInitiated) {
        _set(Stage.error, '读取失败：$e');
      }
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelExtractTimers();
  }

  // ===== 账号 =====

  Future<void> addCurrentAsAccount({String label = '', String phone = ''}) async {
    final String name = label.trim().isNotEmpty
        ? label.trim()
        : '账号 ${config.accounts.length + 1}';
    await _store.addAccount(label: name, phone: phone);
    notifyListeners();
  }

  Future<void> removeAccount(String id) async {
    await _store.removeAccount(id);
    notifyListeners();
  }

  Future<void> setActiveAccount(String id) async {
    await _store.setActive(id);
    notifyListeners();
  }

  Future<void> updateSettings(void Function(AppSettings s) mutate) async {
    mutate(settings);
    await _store.save();
    notifyListeners();
  }

  /// 清空本地登录态（删除 WebView 的 userDataFolder）。
  ///
  /// 用于关闭「记住登录状态」时真正登出：WebView2 的 cookie 存在那个目录里，
  /// 删掉目录就等于退出登录。必须在浏览器卸载状态下调用，否则文件被占用。
  Future<void> clearSession() async {
    closeBrowser();
    // 给 WebView 一点时间释放文件句柄
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _store.deleteWebviewData();
    _stage = Stage.idle;
    _statusText = '已退出登录';
    notifyListeners();
  }

  void _set(Stage s, String text) {
    _stage = s;
    _statusText = text;
    if (s == Stage.error || s == Stage.done) {
      _stopPolling();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
