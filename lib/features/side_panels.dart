import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/config_store.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

class SettingsBody extends StatefulWidget {
  const SettingsBody({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  @override
  Widget build(BuildContext context) {
    final AppSettings s = widget.state.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tok.s20, Tok.s8, Tok.s20, Tok.s24),
      children: <Widget>[
        _SectionLabel('登录'),
        _SwitchRow(
          title: '记住登录状态',
          desc: '登录信息保存在本机的独立数据目录里，下次打开免登录。'
              '关掉后退出浏览器时会清掉登录态，下次需要重新登录。',
          value: s.rememberSession,
          onChanged: (bool v) => widget.state.updateSettings((AppSettings x) {
            x.rememberSession = v;
          }),
        ),
        // 手动退出登录：清掉 cookie，换号时用得上
        Padding(
          padding: const EdgeInsets.only(left: Tok.s12, top: Tok.s4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GhostButton(
              label: '退出登录并清空登录态',
              icon: Icons.logout_rounded,
              onPressed: () async {
                await widget.state.clearSession();
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
        const SizedBox(height: Tok.s16),
        _SectionLabel('行为'),
        _SwitchRow(
          title: '进入后台自动读取',
          desc: '页面加载完成后自动抓取推流码，无需手动点击。',
          value: s.autoExtractOnOpen,
          onChanged: (bool v) => widget.state.updateSettings((AppSettings x) {
            x.autoExtractOnOpen = v;
          }),
        ),
        const SizedBox(height: Tok.s16),
        _SectionLabel('启动页面'),
        _SegmentRow(
          options: const <String, String>{
            'studio': '直播后台',
            'live': '快手直播',
          },
          value: s.startPage,
          onChanged: (String v) => widget.state.updateSettings((AppSettings x) {
            x.startPage = v;
          }),
        ),
        const SizedBox(height: Tok.s24),
        _SectionLabel('关于'),
        _InfoRow(label: '版本', value: '1.0.0'),
        _InfoRow(label: '运行方式', value: '系统内置 Edge WebView2'),
        _InfoRow(
          label: '数据目录',
          value: ConfigStore.instance.dataDir.isEmpty
              ? '—'
              : ConfigStore.instance.dataDir,
          small: true,
        ),
        const SizedBox(height: Tok.s20),
        Container(
          padding: const EdgeInsets.all(Tok.s14),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(Tok.r10),
            border: Border.all(color: Tok.hairlineSoft),
          ),
          child: const Text(
            '本工具仅在本地读取你自己账号的推流信息，不经过任何第三方服务器。'
            '请遵守快手平台服务条款。',
            style: TextStyle(fontSize: 11.5, height: 1.7, color: Tok.inkLow),
          ),
        ),
      ],
    );
  }
}

class AccountsBody extends StatefulWidget {
  const AccountsBody({super.key, required this.state});

  final AppState state;

  @override
  State<AccountsBody> createState() => _AccountsBodyState();
}

class _AccountsBodyState extends State<AccountsBody> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('请填写账号备注名');
      return;
    }
    await widget.state.addCurrentAsAccount(
      label: name,
      phone: _phoneCtrl.text.trim(),
    );
    _nameCtrl.clear();
    _phoneCtrl.clear();
    if (mounted) setState(() {});
    _snack('账号已添加');
  }

  void _snack(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<SavedAccount> list = widget.state.config.accounts;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(Tok.s20, Tok.s8, Tok.s20, Tok.s16),
          child: Column(
            children: <Widget>[
              _FlatField(
                controller: _nameCtrl,
                hint: '备注名，如「主号」',
                icon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: Tok.s8),
              _FlatField(
                controller: _phoneCtrl,
                hint: '手机号（可留空）',
                icon: Icons.phone_iphone_rounded,
              ),
              const SizedBox(height: Tok.s12),
              BrandButton(
                label: '添加当前账号',
                icon: Icons.add_rounded,
                expand: true,
                height: 40,
                onPressed: _add,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    '还没有保存的账号\n添加后会记住它的推流信息',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.8, color: Tok.inkFaint),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Tok.s16, vertical: Tok.s12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Tok.s8),
                  itemBuilder: (BuildContext context, int i) {
                    final SavedAccount a = list[i];
                    final bool active = a.id == widget.state.config.activeAccountId;
                    return _AccountTile(
                      account: a,
                      active: active,
                      onUse: () async {
                        await widget.state.setActiveAccount(a.id);
                        if (mounted) setState(() {});
                      },
                      onDelete: () async {
                        await widget.state.removeAccount(a.id);
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatefulWidget {
  const _AccountTile({
    required this.account,
    required this.active,
    required this.onUse,
    required this.onDelete,
  });

  final SavedAccount account;
  final bool active;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final SavedAccount a = widget.account;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Tok.fast,
        curve: Tok.outQuint,
        padding: const EdgeInsets.all(Tok.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tok.r12),
          color: widget.active
              ? Tok.brand.withValues(alpha: 0.10)
              : (_hover ? const Color(0x0DFFFFFF) : const Color(0x06FFFFFF)),
          border: Border.all(
            color: widget.active
                ? Tok.brand.withValues(alpha: 0.34)
                : (_hover ? const Color(0x24FFFFFF) : Tok.hairlineSoft),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Tok.r8),
                    color: widget.active ? Tok.brand : const Color(0x14FFFFFF),
                  ),
                  child: Text(
                    // 备注名可能为空字符串（历史数据/手改配置），
                    // characters.first 在空串上会抛异常，这里兜底成「?」
                    a.label.isEmpty ? '?' : a.label.characters.first,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.active ? Colors.white : Tok.inkMid,
                    ),
                  ),
                ),
                const SizedBox(width: Tok.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        a.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Tok.ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.maskedPhone,
                        style: const TextStyle(fontSize: 11, color: Tok.inkFaint),
                      ),
                    ],
                  ),
                ),
                if (widget.active)
                  const StatusPill(text: '当前', color: Tok.brand)
                else
                  AnimatedOpacity(
                    duration: Tok.fast,
                    opacity: _hover ? 1 : 0,
                    child: GhostButton(label: '使用', onPressed: widget.onUse),
                  ),
              ],
            ),
            if (a.hasCache) ...<Widget>[
              const SizedBox(height: Tok.s10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Tok.s10, vertical: Tok.s8),
                decoration: BoxDecoration(
                  color: const Color(0x59000000),
                  borderRadius: BorderRadius.circular(Tok.r8),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.history_rounded, size: 12, color: Tok.inkFaint),
                    const SizedBox(width: Tok.s6),
                    Expanded(
                      child: Text(
                        a.lastServer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Tok.inkLow,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 操作按钮常驻占位、用透明度控制可见。
            // 之前是 if (_hover) 直接增删组件，导致悬停时卡片高度突变、
            // 整个列表往下跳，观感很差。
            Padding(
              padding: const EdgeInsets.only(top: Tok.s8),
              child: AnimatedOpacity(
                duration: Tok.fast,
                opacity: _hover ? 1 : 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    GhostButton(
                      label: '删除',
                      icon: Icons.delete_outline_rounded,
                      onPressed: _hover ? widget.onDelete : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatField extends StatelessWidget {
  const _FlatField({required this.controller, required this.hint, required this.icon});

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 12.5, color: Tok.ink, height: 1.4),
      cursorColor: Tok.brand,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: Tok.inkFaint),
        prefixIcon: Icon(icon, size: 15, color: Tok.inkFaint),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Tok.s12, vertical: Tok.s12),
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.r8),
          borderSide: const BorderSide(color: Tok.hairlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.r8),
          borderSide: const BorderSide(color: Tok.hairlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.r8),
          borderSide: BorderSide(color: Tok.brand.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tok.s10, top: Tok.s12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Tok.inkFaint,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatefulWidget {
  const _SwitchRow({
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Tok.fast,
          padding: const EdgeInsets.all(Tok.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tok.r10),
            color: _hover ? const Color(0x0AFFFFFF) : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tok.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: Tok.s4),
                    Text(
                      widget.desc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Tok.inkLow,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Tok.s12),
              _Toggle(value: widget.value),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Tok.normal,
      curve: Tok.outQuint,
      width: 38,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tok.pill),
        color: value ? Tok.brand : const Color(0x1FFFFFFF),
        boxShadow: value
            ? <BoxShadow>[
                BoxShadow(color: Tok.brand.withValues(alpha: 0.35), blurRadius: 10),
              ]
            : null,
      ),
      child: AnimatedAlign(
        duration: Tok.normal,
        curve: Tok.outBack,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tok.s4),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(Tok.r10),
        border: Border.all(color: Tok.hairlineSoft),
      ),
      child: Row(
        children: options.entries.map((MapEntry<String, String> e) {
          final bool sel = e.key == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: Tok.fast,
                curve: Tok.outQuint,
                padding: const EdgeInsets.symmetric(vertical: Tok.s8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Tok.r8),
                  color: sel ? Tok.brand.withValues(alpha: 0.16) : Colors.transparent,
                  border: Border.all(
                    color: sel ? Tok.brand.withValues(alpha: 0.4) : Colors.transparent,
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    color: sel ? Tok.brandBright : Tok.inkLow,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.small = false});

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tok.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Tok.inkFaint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: small ? 10 : 11.5,
                color: Tok.inkMid,
                height: 1.5,
                fontFamily: small ? 'Consolas' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
