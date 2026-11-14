import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liangbo/core/config_store.dart';
import 'package:liangbo/core/stream_extractor.dart';

/// 推流码解析的单元测试。
///
/// 这一层最容易因为快手页面改版而失效，且有明确的输入输出，
/// 是最值得写测试的地方。
void main() {
  group('parseExtractPayload', () {
    test('完整数据应解析成功', () {
      final String payload = jsonEncode(<String, dynamic>{
        'ok': true,
        'server': 'rtmp://push.example.com/live',
        'key': 'ks_abc123def456',
        'account': '测试主播',
        'login': false,
        'reason': '',
      });
      final ExtractResult r = parseExtractPayload(payload);

      expect(r.ok, isTrue);
      expect(r.info!.server, 'rtmp://push.example.com/live');
      expect(r.info!.key, 'ks_abc123def456');
      expect(r.info!.accountHint, '测试主播');
    });

    test('登录页应标记 needLogin', () {
      final String payload = jsonEncode(<String, dynamic>{
        'ok': false,
        'login': true,
        'reason': '需要登录',
      });
      final ExtractResult r = parseExtractPayload(payload);

      expect(r.ok, isFalse);
      expect(r.needLogin, isTrue);
      expect(r.sawLoginPage, isTrue);
    });

    test('只有 server 没有 key 时不算成功', () {
      final String payload = jsonEncode(<String, dynamic>{
        'ok': false,
        'server': 'rtmp://push.example.com/live',
        'key': '',
        'reason': '只找到了推流地址，缺少推流码',
      });
      final ExtractResult r = parseExtractPayload(payload);

      expect(r.ok, isFalse);
      expect(r.reason, contains('缺少推流码'));
    });

    test('evaluateJavascript 多包一层引号也应能解析', () {
      final String inner = jsonEncode(<String, dynamic>{
        'ok': true,
        'server': 'rtmp://a.b/c',
        'key': 'k123456789',
        'login': false,
      });
      // 模拟某些平台把返回值再 JSON 编码一次
      final String wrapped = jsonEncode(inner);
      final ExtractResult r = parseExtractPayload(wrapped);

      expect(r.ok, isTrue);
      expect(r.info!.server, 'rtmp://a.b/c');
    });

    test('空串/异常输入不应抛异常', () {
      expect(parseExtractPayload('').ok, isFalse);
      expect(parseExtractPayload('null').ok, isFalse);
      expect(parseExtractPayload('not json').ok, isFalse);
      expect(parseExtractPayload('{}').ok, isFalse);
    });
  });

  group('StreamInfo.combined', () {
    test('拼接时处理多余斜杠', () {
      StreamInfo a = StreamInfo(
        server: 'rtmp://push.example.com/live/',
        key: '/ks_abc',
        capturedAt: _t,
      );
      expect(a.combined, 'rtmp://push.example.com/live/ks_abc');

      StreamInfo b = StreamInfo(
        server: 'rtmp://push.example.com/live',
        key: 'ks_abc',
        capturedAt: _t,
      );
      expect(b.combined, 'rtmp://push.example.com/live/ks_abc');    });

    test('server 为空时只返回 key', () {
      StreamInfo a = StreamInfo(server: '', key: 'ks_abc', capturedAt: _t);
      expect(a.combined, 'ks_abc');
    });

    test('valid 要求两者都非空', () {
      expect(StreamInfo(server: 'a', key: 'b', capturedAt: _t).valid, isTrue);
      expect(StreamInfo(server: 'a', key: '', capturedAt: _t).valid, isFalse);
      expect(StreamInfo(server: '', key: 'b', capturedAt: _t).valid, isFalse);
    });
  });

  group('StreamInfo JSON 往返', () {
    test('序列化后能还原', () {
      final DateTime t = DateTime(2026, 11, 15, 10, 30);
      final StreamInfo a = StreamInfo(
        server: 'rtmp://x.y/z',
        key: 'key123',
        capturedAt: t,
        accountHint: '主号',
      );
      final StreamInfo b = StreamInfo.fromJson(a.toJson());

      expect(b.server, a.server);
      expect(b.key, a.key);
      expect(b.accountHint, a.accountHint);
      expect(b.capturedAt, t);
    });
  });

  group('AppConfig JSON 往返', () {
    test('账号与设置能完整还原', () {
      final AppConfig cfg = AppConfig(
        accounts: <SavedAccount>[
          SavedAccount(
            id: 'a1',
            label: '主号',
            phone: '13800138000',
            lastServer: 'rtmp://x.y/z',
            lastKey: 'k1',
            lastSyncAt: DateTime(2026, 11, 15),
          ),
        ],
        activeAccountId: 'a1',
      );
      cfg.settings.rememberSession = false;
      cfg.settings.startPage = 'live';

      final AppConfig back = AppConfig.fromJson(
        jsonDecode(jsonEncode(cfg.toJson())) as Map<String, dynamic>,
      );

      expect(back.accounts.length, 1);
      expect(back.accounts.first.label, '主号');
      expect(back.accounts.first.lastServer, 'rtmp://x.y/z');
      expect(back.activeAccountId, 'a1');
      expect(back.settings.rememberSession, isFalse);
      expect(back.settings.startPage, 'live');
    });

    test('空对象应得到默认配置而不是抛异常', () {
      final AppConfig cfg = AppConfig.fromJson(<String, dynamic>{});
      expect(cfg.accounts, isEmpty);
      expect(cfg.settings.rememberSession, isTrue);
    });

    test('active 在列表为空时返回 null', () {
      final AppConfig cfg = AppConfig.fromJson(<String, dynamic>{});
      expect(cfg.active, isNull);
    });
  });

  group('SavedAccount.maskedPhone', () {
    test('正常手机号脱敏', () {
      final SavedAccount a = SavedAccount(id: '1', label: 'x', phone: '13800138000');
      expect(a.maskedPhone, '138****8000');
    });

    test('空手机号显示未绑定', () {
      final SavedAccount a = SavedAccount(id: '1', label: 'x');
      expect(a.maskedPhone, '未绑定');
    });

    test('过短手机号原样返回', () {
      final SavedAccount a = SavedAccount(id: '1', label: 'x', phone: '123');
      expect(a.maskedPhone, '123');
    });
  });
}

final DateTime _t = DateTime.utc(2026, 1, 1);
