import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_state.dart';
import 'core/config_store.dart';
import 'design/theme.dart';
import 'features/home_shell.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 收紧图片缓存：本应用没有任何网络图片，默认的 100MB/1000 张缓存纯属浪费。
  PaintingBinding.instance.imageCache
    ..maximumSize = 16
    ..maximumSizeBytes = 8 << 20;

  // 配置要在首帧前加载完：窗口尺寸、账号缓存都依赖它。
  await ConfigStore.instance.init();
  await AppState.instance.init();

  // 无边框窗口：自己画标题栏，才能做出完整的深色玻璃观感。
  await windowManager.ensureInitialized();

  final cfg = AppState.instance.settings;
  final Size size = _sanitizeSize(cfg.windowWidth, cfg.windowHeight);

  const WindowOptions options = WindowOptions(
    size: Size(1120, 736),
    minimumSize: Size(760, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: '凉播',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setSize(size);
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  // 退出前保存窗口尺寸，下次打开还原
  windowManager.addListener(_WindowPersist());

  runApp(const LiangBoApp());
}

Size _sanitizeSize(double w, double h) {
  // 防止配置文件被改坏后窗口大得离谱
  final double cw = w.clamp(760.0, 4000.0);
  final double ch = h.clamp(560.0, 3000.0);
  return Size(cw, ch);
}

/// 窗口尺寸持久化。
///
/// 拖动过程中只改内存值，真正落盘放在关闭时——避免拖拽时反复写文件。
class _WindowPersist with WindowListener {
  @override
  void onWindowResized() async {
    final Size s = await windowManager.getSize();
    if (s.width < 200 || s.height < 200) return;
    final AppState st = AppState.instance;
    st.settings.windowWidth = s.width;
    st.settings.windowHeight = s.height;
  }

  @override
  void onWindowClose() async {
    await ConfigStore.instance.save();
  }
}

class LiangBoApp extends StatelessWidget {
  const LiangBoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '凉播',
      debugShowCheckedModeBanner: false,
      theme: LbTheme.build(),
      scrollBehavior: const _AppScrollBehavior(),
      builder: (BuildContext context, Widget? child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: MediaQuery(
            // 系统超大字体容易把紧凑的侧栏撑破，收窄到可用范围
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const HomeShell(),
    );
  }
}

/// 桌面端允许鼠标拖拽滚动内容区。
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
