import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_state.dart';
import '../core/config_store.dart';
import '../core/stream_extractor.dart';
import '../design/glass.dart';
import '../design/shell.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'side_panels.dart';
import 'stream_panel.dart';
/// 主界面。
///
/// 窗口拉宽到 900 以上时切换成两栏，窄的时候单栏堆叠。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WindowListener {
  final AppState _s = AppState.instance;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onState);
    windowManager.addListener(this);
    // 不在启动时自动拉起 WebView：那会立刻吃掉几百 MB 内存。
    // 有缓存就直接展示缓存，没有则停在待命状态，等用户点"打开浏览器"。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasCache = _s.config.active?.hasCache ?? false;
      if (hasCache) {
        final a = _s.config.active!;
        _s.showCached(StreamInfo(
          server: a.lastServer,
          key: a.lastKey,
          capturedAt: a.lastSyncAt ?? DateTime.now(),
          accountHint: a.label,
        ));
      }
    });
  }

  @override
  void dispose() {
    _s.removeListener(_onState);
    windowManager.removeListener(this);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  void _toast(String text) {
    final ScaffoldMessengerState? m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, size: 15, color: Tok.ok),
            const SizedBox(width: Tok.s8),
            Text(text),
          ],
        ),
        duration: const Duration(milliseconds: 1600),
        width: 240,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 880;

    return Scaffold(
      backgroundColor: Tok.canvas,
      body: Stack(
        children: <Widget>[
          if (const String.fromEnvironment('NO_HALO') != '1')
            const Positioned.fill(child: HaloBackdrop()),
          Column(
            children: <Widget>[
              // 只让标题栏可拖动。注意不要把这个包到整页：
              // DragToMoveArea 会拦截其覆盖范围内的鼠标事件，导致按钮点不动。
              DragToMoveArea(
                child: TitleBar(
                  onMinimize: () => windowManager.minimize(),
                  onMaximize: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                  onClose: () => windowManager.close(),
                ),
              ),
              ThinProgress(active: _s.stage == Stage.loading ||
                  _s.stage == Stage.extracting ||
                  _s.stage == Stage.entering),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Tok.s24, Tok.s8, Tok.s24, Tok.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FadeSlideIn(child: _header()),
                      const SizedBox(height: Tok.s20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 5, child: FadeSlideIn(delay: const Duration(milliseconds: 60), child: _mainCard())),
                            const SizedBox(width: Tok.s16),
                            SizedBox(width: 268, child: FadeSlideIn(delay: const Duration(milliseconds: 120), child: _sideColumn())),
                          ],
                        )
                      else ...<Widget>[
                        FadeSlideIn(delay: const Duration(milliseconds: 60), child: _mainCard()),
                        const SizedBox(height: Tok.s16),
                        FadeSlideIn(delay: const Duration(milliseconds: 120), child: _sideColumn()),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          BrowserLayer(state: _s, onRefresh: _s.reload),
          Positioned.fill(
            child: SidePanel(
              open: _s.settingsOpen,
              onClose: () => _s.openSettings(false),
              title: '设置',
              width: 360,
              child: SettingsBody(state: _s),
            ),
          ),
          Positioned.fill(
            child: SidePanel(
              open: _s.accountsOpen,
              onClose: () => _s.openAccounts(false),
              title: '账号',
              width: 360,
              child: AccountsBody(state: _s),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 区块 =====

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '推流码',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.6,
                  color: Tok.ink,
                ),
              ),
              const SizedBox(height: Tok.s6),
              Text(
                '登录快手后台后自动读取，一键复制到 OBS 或直播伴侣',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Tok.inkLow,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        IconTap(
          icon: Icons.people_outline_rounded,
          onTap: () => _s.openAccounts(true),
          tooltip: '账号',
          color: Tok.inkMid,
        ),
        const SizedBox(width: Tok.s4),
        IconTap(
          icon: Icons.settings_outlined,
          onTap: () => _s.openSettings(true),
          tooltip: '设置',
          color: Tok.inkMid,
        ),
      ],
    );
  }

  Widget _mainCard() {
    return GlassCard(
      blur: 0,
      padding: const EdgeInsets.all(Tok.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StreamPanel(state: _s, onCopyToast: _toast),
          const SizedBox(height: Tok.s18),
          Row(
            children: <Widget>[
              BrandButton(
                label: _s.stage == Stage.extracting ? '读取中' : '读取推流码',
                icon: Icons.download_rounded,
                busy: _s.stage == Stage.extracting,
                onPressed: _s.stage == Stage.extracting ? null : _s.extractNow,
                height: 42,
              ),
              const SizedBox(width: Tok.s10),
              GhostButton(
                label: _s.browserMounted ? '打开中…' : '打开浏览器',
                icon: _s.browserMounted
                    ? Icons.open_in_browser_rounded
                    : Icons.login_rounded,
                dense: false,
                onPressed: _s.browserMounted ? null : _s.openBrowser,
              ),
              const Spacer(),
              if (_s.stream != null)
                GhostButton(
                  label: '复制全部',
                  icon: Icons.copy_all_rounded,
                  accent: true,
                  dense: false,
                  onPressed: () async {
                    final info = _s.stream!;
                    await Clipboard.setData(ClipboardData(
                      text: '服务器：${info.server}\n推流码：${info.key}',
                    ));
                    _toast('已复制服务器与推流码');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sideColumn() {
    return Column(
      children: <Widget>[
        GlassCard(
          blur: 0,
          padding: const EdgeInsets.all(Tok.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.tips_and_updates_outlined,
                      size: 14, color: Tok.warn),
                  const SizedBox(width: Tok.s6),
                  const Text(
                    '怎么用',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Tok.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tok.s12),
              _step('01', '点「打开浏览器」，在窗口里登录快手'),
              _step('02', '登录后会自动跳到直播后台并读取'),
              _step('03', '复制推流地址和密钥填进 OBS'),
            ],
          ),
        ),
        const SizedBox(height: Tok.s12),
        GlassCard(
          blur: 0,
          padding: const EdgeInsets.all(Tok.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.shield_outlined, size: 14, color: Tok.ok),
                  const SizedBox(width: Tok.s6),
                  const Text(
                    '隐私',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Tok.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tok.s10),
              const Text(
                '所有操作都在本机完成。登录信息保存在本机的独立数据目录里，'
                '不会上传到任何服务器。',
                style: TextStyle(fontSize: 11.5, height: 1.7, color: Tok.inkLow),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tok.s12),
        _readyCard(),
      ],
    );
  }

  /// 就绪状态卡：把「当前用哪个账号、上次什么时候读的」摆出来。
  ///
  /// 主面板在抓取成功后只有两张字段卡，下方留白较多；
  /// 这张卡既补齐视觉重量，也让用户随时知道数据新鲜度。
  Widget _readyCard() {
    final SavedAccount? act = _s.config.active;
    final StreamInfo? info = _s.stream ?? _s.lastGood;
    final bool hasData = info != null;

    return GlassCard(
      blur: 0,
      padding: const EdgeInsets.all(Tok.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                hasData ? Icons.check_circle_outline_rounded : Icons.hourglass_empty_rounded,
                size: 14,
                color: hasData ? Tok.ok : Tok.inkLow,
              ),
              const SizedBox(width: Tok.s6),
              const Text(
                '状态',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Tok.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tok.s12),
          _kv('当前账号', act?.label ?? '未添加'),
          const SizedBox(height: Tok.s8),
          _kv('账号数量', '${_s.config.accounts.length}'),
          const SizedBox(height: Tok.s8),
          _kv(
            '最近读取',
            hasData ? _fmtTime(info.capturedAt) : '还没有',
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 62,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11, color: Tok.inkFaint, height: 1.5),
          ),
        ),
        Expanded(
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Tok.inkMid, height: 1.5),
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime t) {
    final Duration d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tok.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tok.r6),
              color: const Color(0x14FFFFFF),
              border: Border.all(color: Tok.hairlineSoft),
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Tok.inkLow,
                fontFamily: 'Consolas',
              ),
            ),
          ),
          const SizedBox(width: Tok.s10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.6, color: Tok.inkMid),
            ),
          ),
        ],
      ),
    );
  }
}

