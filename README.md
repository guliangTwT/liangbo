# 凉播

快手直播推流码获取工具（Windows 桌面应用）。

内嵌浏览器登录快手，自动读取直播后台的推流地址与推流密钥，一键复制到 OBS / 直播伴侣。

---

## 功能

- **内嵌浏览器登录**：程序里就是一个完整的浏览器，扫码、验证码、滑块都跟正常上网一样。不逆向接口、不碰风控。
- **自动读取**：登录后自动跳到直播后台并抓取推流信息，三层降级策略（输入框 → 页面文本 → 内嵌 JSON）。
- **免登录**：登录态由 WebView2 的独立数据目录持久化，下次打开直接抓。
- **多账号**：保存多个账号的备注与最近一次推流信息，冷启动即可复制上次结果。
- **一键复制**：推流地址、推流密钥、完整串流地址分别可复制。
- **资源占用低**：浏览器按需挂载、用完即销毁。空闲时只有 Flutter 本身的开销。

## 资源占用实测

在本机（Windows 11 / 16 核）实测：

| 状态 | 物理内存 (WorkingSet) | 提交内存 (Commit) |
|------|---------------------|------------------|
| 空闲（未打开浏览器） | **约 135 MB** | 约 190 MB |
| 浏览器打开（快手登录页） | 约 565 MB | 约 450 MB |

浏览器那部分开销来自快手页面本身（Vue SPA + 大量静态资源），任何内嵌浏览器的方案都绕不过。
关键是**抓完推流码后浏览器会自动销毁**，内存立刻回落到空闲水平。

作为对照：原参考项目 elbp 用 Playwright 常驻一个 Chromium，空闲也要 300MB+ 且从不释放。

### 性能优化记录（都是实测数据，改代码前请先读）

这个项目踩过几个 Flutter Windows 的性能坑，结论记录在这里，避免以后改回去：

1. **不要用渐变着色器画装饰元素。**
   `RadialGradient.createShader()` / `LinearGradient.createShader()` 在 Flutter Windows + ANGLE
   下会为每个 shader 申请大块驱动侧缓冲。背景光斑用三个渐变色块画，进程提交内存从
   **190MB 飙到 1373MB**；换成纯色同心圆叠加后回到 190MB。

2. **不要用多个带渐变的 `DecoratedBox` 叠加。**
   每个都会触发独立离屏图层，同样爆内存。

3. **WebView2 的激进参数适得其反。**
   `--disable-gpu-compositing` / `--single-process` / `--no-zygote` 会让提交内存从 160MB
   涨到 890MB（软件渲染路径申请大块后备缓冲）。

4. **浏览器按需挂载。**
   WebView2 一旦创建就常驻一整套 Chromium 组件（+16 线程、数百 MB）。抓完即销毁是
   最有效的省内存手段。

5. **背景光斑用定时器推进而非每帧插值。**
   28 秒一圈的缓慢漂移，12fps 推进肉眼完全看不出差异，GPU 负载降到 1/5。

6. **`DragToMoveArea` 只包标题栏。**
   包整页会拦截所有鼠标事件，按钮点不动。

## 构建

### 环境要求

- Flutter 3.47+（Dart 3.13+）
- Visual Studio 2022 Build Tools（含 C++ 桌面开发、Windows 10/11 SDK）
- NuGet（`flutter_inappwebview_windows` 构建时需要）

### 步骤

```bash
# 1. 拉依赖
flutter pub get

# 2. 构建
flutter build windows --release

# 3. 产物
build/windows/x64/runner/Release/liangbo.exe
```

**注意：构建路径不能含中文。** Flutter 的 CMake/MSBuild 链路在非 ASCII 路径下
会因为代码页问题报 `Unable to read file: ...app.dill`。如果工程放在中文目录下，
可以建一个英文 junction 再构建：

```bat
mklink /J C:\lbbuild "D:\path\to\lb_app"
cd /d C:\lbbuild
flutter build windows --release
```

### 运行时依赖

- **WebView2 Runtime**：Windows 10/11 通常已预装。若没有，从微软官网安装
  「Evergreen Standalone Installer」。

## 项目结构

```
lib/
├── main.dart                    程序入口、窗口初始化、主题
├── core/
│   ├── app_state.dart           全局状态（单例 ChangeNotifier）
│   ├── config_store.dart        配置读写、账号存储
│   └── stream_extractor.dart    推流码提取（注入页面的 JS + 结果解析）
├── design/
│   ├── tokens.dart              设计令牌：颜色、间距、动效曲线
│   ├── theme.dart               Material 主题
│   ├── glass.dart               背景光斑、玻璃卡片
│   ├── widgets.dart             按钮、状态胶囊等基础组件
│   └── shell.dart               标题栏、复制字段、抽屉面板
└── features/
    ├── home_shell.dart          主界面装配
    ├── stream_panel.dart        推流信息展示 + 浏览器浮层
    └── side_panels.dart         设置与账号面板
```

## 数据存放位置

```
<应用支持目录>\liangbo\
├── config.json          账号与设置
└── webview\             WebView2 数据（含登录 cookie）
```

登录 cookie 由 WebView2 自行持久化并按当前 Windows 用户隔离，不经过本程序的代码，
也不会上传到任何服务器。

## 免责声明

本工具只读取你自己账号在快手后台展示的推流信息，不修改任何服务端数据。
使用前请确认符合快手平台服务条款。
