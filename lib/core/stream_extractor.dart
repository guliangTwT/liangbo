/// 推流码数据结构与提取规则。
///
/// 设计要点：
/// 快手的推流信息在 `studio.kuaishou.com` 后台，推流地址与推流码成对出现。
/// 页面是 Vue SPA，数据在运行时由接口填充，DOM 结构随时可能变。
/// 因此这里采用"多层降级"策略，任何一层命中即可：
///
///   1. 输入框 value（最可靠，官方页面就是给用户复制的输入框）
///   2. 页面文本里正则捞 rtmp:// 与常见 key 形态
///   3. 从 script 标签里的 __INITIAL_STATE__ / JSON 里找
///
/// 提取逻辑放在 JS 里执行（evaluateJavascript），避免把整页 HTML 搬回 Dart
/// 再解析——那是 CPU 与内存的双重浪费。
library;

import 'dart:convert';

/// 一条推流信息。
class StreamInfo {
  const StreamInfo({
    required this.server,
    required this.key,
    required this.capturedAt,
    this.accountHint = '',
  });

  /// 推流地址，如 rtmp://push.example.com/live
  final String server;

  /// 推流密钥
  final String key;

  /// 抓取时刻
  final DateTime capturedAt;

  /// 页面能识别到的账号名（可选）
  final String accountHint;

  /// OBS 里可直接粘贴的完整串流地址。
  ///
  /// 快手的 server 末尾可能已带 `/`，key 也可能带前导 `/`，这里统一规整。
  String get combined {
    final String s = server.trim().replaceAll(RegExp(r'/+$'), '');
    final String k = key.trim().replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) return k;
    if (k.isEmpty) return s;
    return '$s/$k';
  }

  bool get valid => server.trim().isNotEmpty && key.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'server': server,
        'key': key,
        'capturedAt': capturedAt.toIso8601String(),
        'accountHint': accountHint,
      };

  static StreamInfo fromJson(Map<String, dynamic> json) => StreamInfo(
        server: (json['server'] as String?) ?? '',
        key: (json['key'] as String?) ?? '',
        capturedAt:
            DateTime.tryParse((json['capturedAt'] as String?) ?? '') ?? DateTime.now(),
        accountHint: (json['accountHint'] as String?) ?? '',
      );

  StreamInfo copyWith({String? server, String? key, String? accountHint}) => StreamInfo(
        server: server ?? this.server,
        key: key ?? this.key,
        capturedAt: capturedAt,
        accountHint: accountHint ?? this.accountHint,
      );
}

/// 提取器吐出的原始结果（含失败原因，便于 UI 给出准确提示）。
class ExtractResult {
  const ExtractResult({
    this.info,
    this.reason = '',
    this.needLogin = false,
    this.sawLoginPage = false,
  });

  final StreamInfo? info;

  /// 失败原因，已转成面向用户的中文。
  final String reason;

  /// 需要用户先登录。
  final bool needLogin;

  /// 检测到当前停在登录页，UI 可以据此把 WebView 推到前台。
  final bool sawLoginPage;

  bool get ok => info != null && info!.valid;

  static const ExtractResult none = ExtractResult(reason: '尚未抓取');
}

/// 注入到页面的 JS。
///
/// 返回 JSON 字符串，由 Dart 侧 `jsonDecode`。
/// 注意：这个脚本会在每次轮询时执行，必须足够轻量（不做整页 innerHTML 序列化，
/// 只在需要时才取 body.innerText 的截断片段）。
const String kExtractScript = r'''
(function () {
  try {
    var out = { ok: false, server: '', key: '', account: '', reason: '', login: false };

    var href = location.href || '';
    // 登录页判定：快手登录页在 passport / login 路径下
    if (/passport\.kuaishou\.com|\/login|\/signin/i.test(href)) {
      out.login = true;
      out.reason = '需要登录';
      return JSON.stringify(out);
    }

    // ---------- 1. 从输入框取值 ----------
    // 官方页面的推流地址/推流码就是只读 input，最可靠。
    var serverRe = /(^|\.)push|rtmp|server|addr|url/i;
    var keyRe = /key|stream|secret|token/i;

    var inputs = document.querySelectorAll('input, textarea');
    var serverCandidates = [];
    var keyCandidates = [];

    for (var i = 0; i < inputs.length; i++) {
      var el = inputs[i];
      var v = (el.value || '').trim();
      if (!v || v.length < 4) continue;

      var name = ((el.name || '') + ' ' + (el.id || '') + ' ' +
                  (el.getAttribute('placeholder') || '') + ' ' +
                  (el.className || '')).toLowerCase();

      if (/^r?tmp/i.test(v) || /^rtmps?:\/\//i.test(v)) {
        serverCandidates.push({ v: v, w: 100 });
      } else if (/^(srt|http|https):\/\//i.test(v) && /push|live|stream/i.test(v)) {
        serverCandidates.push({ v: v, w: 80 });
      } else if (serverRe.test(name) && !keyRe.test(name)) {
        serverCandidates.push({ v: v, w: 40 });
      }

      if (keyRe.test(name) && !/^r?tmps?:\/\//i.test(v)) {
        // 推流码通常是一长串，且不含空格
        if (v.length >= 6 && !/\s/.test(v)) keyCandidates.push({ v: v, w: 60 });
      }
    }

    function pick(list) {
      if (!list.length) return '';
      list.sort(function (a, b) { return b.w - a.w; });
      return list[0].v;
    }

    out.server = pick(serverCandidates);
    out.key = pick(keyCandidates);

    // 输入框里若直接是完整推流串（server/key 已拼好），拆开
    if (out.server && !out.key) {
      var m = out.server.match(/^(r?tmps?:\/\/[^\/\s]+(?:\/[^\/\s]*)?)\/([^\s\/]{6,})$/);
      if (m) { out.server = m[1]; out.key = m[2]; }
    }

    // ---------- 2. 兜底：从可见文本里捞 ----------
    if (!out.server) {
      var txt = (document.body ? document.body.innerText : '') || '';
      // 限制扫描长度，避免长页面拖慢
      if (txt.length > 60000) txt = txt.slice(0, 60000);
      var rm = txt.match(/r?tmps?:\/\/[^\s"'<>]{6,}/i);
      if (rm) {
        out.server = rm[0];
        // 同一行里冒号后面跟的长串，大概率是 key
        var lineStart = txt.lastIndexOf('\n', rm.index);
        var lineEnd = txt.indexOf('\n', rm.index);
        var line = txt.slice(lineStart + 1, lineEnd === -1 ? txt.length : lineEnd);
        var km = line.replace(rm[0], '').match(/[A-Za-z0-9_\-\.]{12,}/);
        if (km) out.key = km[0];
      }
    }

    // ---------- 3. 兜底：从页面内嵌 JSON 里找 ----------
    if (!out.server || !out.key) {
      var scripts = document.querySelectorAll('script:not([src])');
      for (var s = 0; s < scripts.length && s < 40; s++) {
        var t = scripts[s].textContent || '';
        if (t.length < 40 || t.length > 400000) continue;
        if (t.indexOf('pushUrl') === -1 && t.indexOf('rtmp') === -1 &&
            t.indexOf('streamKey') === -1) continue;

        if (!out.key) {
          var km2 = t.match(/"(?:pushKey|streamKey|stream_key|key)"\s*:\s*"([^"]{6,200})"/i);
          if (km2) out.key = km2[1];
        }
        if (!out.server) {
          var sm = t.match(/"(?:pushUrl|push_url|server|rtmpUrl)"\s*:\s*"((?:r?tmps?:\/\/)[^"]{4,300})"/i);
          if (sm) out.server = sm[1];
        }
        // live.pushUrl 是数组：[{url, key}, ...]
        if (!out.server || !out.key) {
          var am = t.match(/"pushUrl"\s*:\s*\[\s*\{[^}]*"url"\s*:\s*"([^"]+)"[^}]*"key"\s*:\s*"([^"]+)"/i);
          if (am) {
            if (!out.server) out.server = am[1];
            if (!out.key) out.key = am[2];
          }
        }
        if (out.server && out.key) break;
      }
    }

    // ---------- 账号名 ----------
    try {
      var nameEl = document.querySelector('[class*="user-name"], [class*="userName"], [class*="nickname"], [class*="nick-name"]');
      if (nameEl) out.account = (nameEl.textContent || '').trim().slice(0, 40);
    } catch (e) {}

    if (!out.server && !out.key) {
      out.reason = '当前页面没有找到推流信息';
    } else if (!out.server) {
      out.reason = '只找到了推流码，缺少推流地址';
    } else if (!out.key) {
      out.reason = '只找到了推流地址，缺少推流码';
    } else {
      out.ok = true;
      out.reason = '';
    }

    return JSON.stringify(out);
  } catch (e) {
    return JSON.stringify({ ok: false, server: '', key: '', account: '', login: false, reason: '页面解析异常: ' + (e && e.message ? e.message : String(e)) });
  }
})()
''';

/// 把 JS 返回值解析成 [ExtractResult]。
ExtractResult parseExtractPayload(String raw) {
  String s = raw.trim();
  if (s.isEmpty || s == 'null' || s == 'undefined') {
    return const ExtractResult(reason: '页面尚未响应');
  }

  // evaluateJavascript 有时会把字符串再包一层引号并转义，剥掉。
  if (s.startsWith('"') && s.endsWith('"') && s.length > 2) {
    try {
      final Object? inner = jsonDecode(s);
      if (inner is String) s = inner;
    } catch (_) {
      s = s.substring(1, s.length - 1);
    }
  }

  Map<String, dynamic>? map;
  try {
    final Object? decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) map = decoded;
  } catch (_) {
    return const ExtractResult(reason: '页面返回格式异常');
  }
  if (map == null) return const ExtractResult(reason: '页面返回格式异常');

  final bool sawLogin = map['login'] == true;
  if (sawLogin) {
    return const ExtractResult(
      reason: '需要在下方完成登录',
      needLogin: true,
      sawLoginPage: true,
    );
  }

  final String server = ((map['server'] as String?) ?? '').trim();
  final String key = ((map['key'] as String?) ?? '').trim();
  final String account = ((map['account'] as String?) ?? '').trim();
  final bool ok = map['ok'] == true;

  if (ok && server.isNotEmpty && key.isNotEmpty) {
    return ExtractResult(
      info: StreamInfo(
        server: server,
        key: key,
        capturedAt: DateTime.now(),
        accountHint: account,
      ),
      reason: '',
    );
  }

  return ExtractResult(
    reason: ((map['reason'] as String?) ?? '未找到推流信息').trim(),
    needLogin: false,
  );
}
