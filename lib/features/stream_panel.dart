import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart' show DragToMoveArea;

import '../core/app_state.dart';
import '../core/config_store.dart';
import '../core/stream_extractor.dart';
import '../design/shell.dart' show CopyField;
import '../design/tokens.dart';
import '../design/widgets.dart';

/// 推流信息展示区。
///
/// 三块内容：状态行、推流地址、推流码。
/// 数据为空时显示占位而不是空白，避免布局跳动。
class StreamPanel extends StatelessWidget {
  const StreamPanel({
    super.key,
    required this.state,
    required this.onCopyToast,
  });

  final AppState state;
  final ValueChanged<String> onCopyToast;

  @override
  Widget build(BuildContext context) {
    final StreamInfo? info = state.stream ?? state.lastGood;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusRow(state: state),
        const SizedBox(height: Tok.s16),
        CopyField(
          label: '推流地址 · SERVER',
          value: info?.server ?? '',
          hint: '等待读取…',
          emphasize: false,
          icon: Icons.dns_outlined,
          onCopied: onCopyToast,
        ),
        const SizedBox(height: Tok.s10),
        CopyField(
          label: '推流密钥 · STREAM KEY',
          value: info?.key ?? '',
          hint: '等待读取…',
          emphasize: true,
          icon: Icons.key_rounded,
          onCopied: onCopyToast,
        ),
        if (info != null) ...<Widget>[
          const SizedBox(height: Tok.s10),
          // 完整串流地址：有些软件只接受一条完整 URL
          CopyField(
            label: '完整串流地址 · 一键填入',
            value: info.combined,
            hint: '',
            icon: Icons.link_rounded,
            onCopied: onCopyToast,
          ),
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final (Color color, bool pulse) = switch (state.stage) {
      Stage.done => (Tok.ok, false),
      Stage.error => (Tok.danger, false),
      Stage.login => (Tok.warn, false),
      Stage.idle => (Tok.inkLow, false),
      _ => (Tok.brand, true),
    };

    return Row(
      children: <Widget>[
        AnimatedSwitcher(
          duration: Tok.normal,
          transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1)
                  .animate(CurvedAnimation(parent: a, curve: Tok.outQuint)),
              child: child,
            ),
          ),
          child: StatusPill(
            key: ValueKey<String>('${state.stage}-${state.statusText}'),
            text: state.statusText,
            color: color,
            pulse: pulse,
          ),
        ),
        const Spacer(),
        // 只在本次会话真正抓取过时显示时间；缓存数据的时间在右侧状态卡里看
        if (state.stream != null)
          Text(
            _timeAgo(state.stream!.capturedAt),
            style: const TextStyle(fontSize: 11, color: Tok.inkFaint),
          ),
      ],
    );
  }

  String _timeAgo(DateTime t) {
    final Duration d = DateTime.now().difference(t);
    if (d.inSeconds < 10) return '刚刚';
    if (d.inMinutes < 1) return '${d.inSeconds} 秒前';
    if (d.inHours < 1) return '${d.inMinutes} 分钟前';
    return '${d.inHours} 小时前';
  }
}

/// 内嵌浏览器浮层。
///
/// 为什么做成浮层而不是嵌在页面里：
/// - 快手登录页和后台是完整桌面网站，塞进 400px 高的区域里根本没法操作
/// - WebView2 是独立窗口子层，无法在其上叠加 Flutter 内容，浮层能让层级关系清晰
/// - 只在需要时挂载，用完即销毁，空闲时这部分资源归零
class BrowserLayer extends StatelessWidget {
  const BrowserLayer({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  final AppState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!state.browserMounted) return const SizedBox.shrink();
    return Positioned.fill(
      child: _BrowserShell(state: state, onRefresh: onRefresh),
    );
  }
}

class _BrowserShell extends StatelessWidget {
  const _BrowserShell({required this.state, required this.onRefresh});

  final AppState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppState s = state;

    return Container(
      color: Tok.canvas,
      child: Column(
        children: <Widget>[
          // 浏览器工具条，与主界面同一套视觉语言
          Container(
            decoration: const BoxDecoration(
              color: Tok.canvasLift,
              border: Border(bottom: BorderSide(color: Tok.hairline)),
            ),
            child: Column(
              children: <Widget>[
                DragToMoveArea(
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: Tok.s16),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Tok.r6),
                            color: Tok.brand,
                          ),
                          child: const Icon(Icons.public_rounded,
                              size: 13, color: Colors.white),
                        ),
                        const SizedBox(width: Tok.s10),
                        Text(
                          s.stage == Stage.login ? '登录快手' : '快手直播后台',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Tok.ink,
                          ),
                        ),
                        const Spacer(),
                        GhostButton(
                          label: '返回',
                          icon: Icons.arrow_back_rounded,
                          onPressed: s.canGoBack ? s.goBack : null,
                        ),
                        const SizedBox(width: Tok.s6),
                        GhostButton(
                          label: '刷新',
                          icon: Icons.refresh_rounded,
                          onPressed: onRefresh,
                        ),
                        const SizedBox(width: Tok.s10),
                        BrandButton(
                          label: '完成',
                          icon: Icons.check_rounded,
                          dense: true,
                          height: 30,
                          onPressed: s.closeBrowser,
                        ),
                        const SizedBox(width: Tok.s12),
                      ],
                    ),
                  ),
                ),
                // 地址行 + 状态
                Padding(
                  padding: const EdgeInsets.fromLTRB(Tok.s16, 0, Tok.s16, Tok.s8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          s.currentUrl.isEmpty ? '未打开' : s.currentUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Tok.inkFaint,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ),
                      const SizedBox(width: Tok.s12),
                      StatusPill(
                        text: s.statusText,
                        color: switch (s.stage) {
                          Stage.done => Tok.ok,
                          Stage.error => Tok.danger,
                          Stage.login => Tok.warn,
                          Stage.idle => Tok.inkLow,
                          _ => Tok.brand,
                        },
                        pulse: s.stage == Stage.loading ||
                            s.stage == Stage.extracting ||
                            s.stage == Stage.entering,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // WebView 本体
          const Expanded(child: _WebViewHost()),
        ],
      ),
    );
  }
}

class _WebViewHost extends StatefulWidget {
  const _WebViewHost();

  @override
  State<_WebViewHost> createState() => _WebViewHostState();
}

class _WebViewHostState extends State<_WebViewHost> {
  /// 自定义 WebView 环境。
  ///
  /// 默认环境会拉起一整套 Chromium 服务（后台同步、组件更新、拼写检查…）。
  /// 这里关掉与"渲染一个网页"无关的部分。
  ///
  /// 注意：不要加 --disable-gpu-compositing / --single-process / --no-zygote
  /// 之类的激进参数，实测它们适得其反。
  WebViewEnvironment? _env;
  bool _envReady = false;
  bool _envFailed = false;

  @override
  void initState() {
    super.initState();
    _bootEnv();
  }

  Future<void> _bootEnv() async {
    try {
      final WebViewEnvironment env = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          // 独立数据目录：登录态持久化在这里，也避免和用户 Edge 抢锁
          userDataFolder: ConfigStore.instance.webviewDir,
          additionalBrowserArguments: <String>[
            '--disable-background-networking',
            '--disable-component-update',
            '--disable-default-apps',
            '--disable-spell-checking',
            '--disable-features=Translate,MediaRouter,OptimizationHints,'
                'BackForwardCache,InterestFeedContentSuggestions,'
                'AutofillServerCommunication',
            // 限制 V8 堆上限，防止快手页面脚本把堆撑大
            '--js-flags=--max-old-space-size=192',
            '--renderer-process-limit=1',
          ].join(' '),
        ),
      );
      if (!mounted) {
        await env.dispose();
        return;
      }
      setState(() {
        _env = env;
        _envReady = true;
      });
    } catch (e) {
      debugPrint('WebViewEnvironment create failed: $e');
      if (mounted) setState(() => _envFailed = true);
    }
  }

  @override
  void dispose() {
    _env?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_envReady && !_envFailed) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Tok.brand),
        ),
      );
    }
    return _buildWebView(_env);
  }

  Widget _buildWebView(WebViewEnvironment? env) {
    final AppState s = AppState.instance;

    return InAppWebView(
      webViewEnvironment: env,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        isInspectable: false,
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: false,
        transparentBackground: false,
        isFraudulentWebsiteWarningEnabled: false,
        disableContextMenu: true,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
      ),
      onWebViewCreated: (InAppWebViewController c) {
        s.controller = c;
        // 若之前因 controller 未就绪而挂起了启动流程，这里补上
        s.onControllerReady();
      },
      onLoadStart: (InAppWebViewController c, WebUri? url) {
        s.onPageStarted(url?.toString() ?? '');
      },
      onLoadStop: (InAppWebViewController c, WebUri? url) {
        s.onPageFinished(url?.toString() ?? '');
      },
      onReceivedError:
          (InAppWebViewController c, WebResourceRequest req, WebResourceError err) {
        // 只关心主文档失败，子资源失败不打断流程
        if (req.isForMainFrame ?? false) {
          s.onLoadError(err.description);
        }
      },
      onUpdateVisitedHistory:
          (InAppWebViewController c, WebUri? url, bool? androidIsReload) {
        s.onPageStarted(url?.toString() ?? '');
      },
    );
  }
}
