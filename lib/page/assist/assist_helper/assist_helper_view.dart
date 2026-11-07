import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_celebration.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart' show AssistTicker, assistMmss;
import 'package:town_pass/service/assist_helper_controller.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 協助者（里長、家人、1999 客服）用手機陪長輩辦事的畫面。
/// 由首頁「掃描」掃到長輩的配對 QR Code 進來（帶入配對碼），或從「設定 › 測試身分」打開。
class AssistHelperView extends StatefulWidget {
  const AssistHelperView({super.key, this.code});
  final String? code;

  static Future<void> open([String? code]) async {
    await Get.to(() => AssistHelperView(code: code), routeName: '/assist_helper');
  }

  @override
  State<AssistHelperView> createState() => _AssistHelperViewState();
}

class _AssistHelperViewState extends State<AssistHelperView> {
  late final AssistHelperController c;
  String? _pastResultId;

  @override
  void initState() {
    super.initState();
    final id = Get.find<AssistService>().helperId.value;
    c = Get.put(AssistHelperController(helperId: id), tag: 'helper');
  }

  @override
  void dispose() {
    Get.delete<AssistHelperController>(tag: 'helper');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = c.focused;
      final Widget body;
      final String title;
      if (c.loading.value) {
        title = '陪辦';
        body = const Center(child: CircularProgressIndicator());
      } else if (c.loginError.value != null) {
        title = '陪辦';
        body = _Message(
          icon: Icons.cloud_off_rounded,
          text: c.loginError.value!,
          action: FilledButton(onPressed: c.login, child: const Text('再試一次')),
        );
      } else if (s == null) {
        title = '新陪辦';
        body = _NewRequest(
          c: c,
          code: widget.code,
          onOpenRecent: (session) {
            _pastResultId = session.isOpen ? null : session.id;
            c.focusedId.value = session.id;
          },
        );
      } else if (s.isPending) {
        title = '等待長輩回應';
        body = _Waiting(c: c, s: s);
      } else if (s.isActive) {
        title = s.serviceTitle;
        body = _Session(c: c, s: s);
      } else {
        title = s.serviceTitle;
        body = _Done(c: c, s: s, animate: s.id != _pastResultId);
      }
      return PopScope(
        // 案件開著時，返回鍵先回到新陪辦／列表，不直接離開
        canPop: s == null || !s.isOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && s != null && !s.isOpen) c.focusedId.value = null;
        },
        child: Scaffold(
          backgroundColor: TPColors.grayscale50,
          appBar: TPAppBar(
            title: title,
            actions: [
              if (s != null && s.isActive)
                TextButton(
                  onPressed: () => _confirmEnd(context, c),
                  child: const Text('結束', style: TextStyle(color: TPColors.red600, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          body: body,
        ),
      );
    });
  }
}

Future<void> _run(Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    Get.closeAllSnackbars();
    Get.snackbar(
      '沒有完成',
      e is AssistApiException ? e.message : '連線失敗，請稍後再試',
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      backgroundColor: TPColors.grayscale800,
      colorText: TPColors.white,
    );
  }
}

Future<void> _confirmEnd(BuildContext context, AssistHelperController c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('結束這次陪辦？'),
      content: const Text('結束後您就無法再引導長輩，長輩手機上的協助畫面也會關閉。已授權的資料不會送出。'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TPColors.red600),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('結束陪辦'),
        ),
      ],
    ),
  );
  if (ok == true) await _run(c.end);
}

// ═════════════════════════════════════════════ 共用

const _cardRadius = 16.0;

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16), this.color = TPColors.white});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(_cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(text, style: const TextStyle(fontSize: 14, color: TPColors.grayscale500, fontWeight: FontWeight.w600)),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: TPColors.grayscale400),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: TPColors.grayscale700)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// 底部固定的主要操作列
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
    decoration: const BoxDecoration(
      color: TPColors.white,
      boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
    ),
    child: Row(children: children),
  );
}

ButtonStyle _primary() => FilledButton.styleFrom(
  backgroundColor: TPColors.primary600,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
);

ButtonStyle _secondary() => OutlinedButton.styleFrom(
  foregroundColor: TPColors.grayscale800,
  minimumSize: const Size.fromHeight(52),
  side: const BorderSide(color: TPColors.grayscale200),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
);

// ═════════════════════════════════════════════ 新陪辦

class _NewRequest extends StatefulWidget {
  const _NewRequest({required this.c, this.code, required this.onOpenRecent});
  final AssistHelperController c;
  final String? code;
  final ValueChanged<AssistSession> onOpenRecent;
  @override
  State<_NewRequest> createState() => _NewRequestState();
}

class _NewRequestState extends State<_NewRequest> {
  late final TextEditingController code = TextEditingController(text: widget.code ?? '');
  final focus = FocusNode();
  String? serviceId;
  /// 選了「信任我的長輩」就不用配對碼
  String? elderId;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.c.services.isNotEmpty) serviceId = widget.c.services.first['id'] as String;
    if (widget.code == null) {
      final trusted = widget.c.trustedElders;
      if (trusted.length == 1) {
        // 只有一位信任您的長輩：直接選好，按一下就能送出
        elderId = trusted.first['elderId'] as String;
      } else if (trusted.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
      }
    }
  }

  @override
  void dispose() {
    code.dispose();
    focus.dispose();
    super.dispose();
  }

  bool get ready => !busy && serviceId != null && (elderId != null || code.text.length == 6);

  Future<void> send() async {
    if (!ready) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (elderId != null) {
        await widget.c.requestTrusted(serviceId!, elderId!);
      } else {
        await widget.c.requestByCode(serviceId!, code.text);
      }
    } catch (e) {
      setState(() => error = e is AssistApiException ? e.message : '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final me = c.me.value!;
    final recent = c.sorted.take(5).toList();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 18, color: TPColors.grayscale500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '以 ${me['name']}（${me['title']}）身分協助',
                      style: const TextStyle(fontSize: 14, color: TPColors.grayscale600),
                    ),
                  ),
                  Obx(
                    () => Row(
                      children: [
                        _Dot(c.connected.value ? TPColors.green500 : TPColors.grayscale300),
                        const SizedBox(width: 4),
                        Text(
                          c.connected.value ? '已連線' : '連線中',
                          style: const TextStyle(fontSize: 13, color: TPColors.grayscale500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Obx(() {
                final trusted = c.trustedElders.toList();
                if (trusted.isEmpty || widget.code != null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('信任您的長輩・不用配對碼'),
                    for (final e in trusted) ...[
                      _TrustedElderTile(
                        name: e['displayName'] as String,
                        selected: elderId == e['elderId'],
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            error = null;
                            elderId = elderId == e['elderId'] ? null : e['elderId'] as String;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
              }),
              Obx(() => _Label(c.trustedElders.isNotEmpty && widget.code == null ? '或輸入長輩的配對碼' : '長輩的配對碼')),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CodeBoxes(
                      controller: code,
                      focus: focus,
                      error: error != null && elderId == null,
                      onChanged: (_) => setState(() {
                        error = null;
                        elderId = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (elderId == null ? error : null) ??
                          (widget.code != null ? '已從 QR Code 帶入配對碼。' : '請長輩打開台北通「請人陪我辦」，念出 6 位數號碼。'),
                      style: TextStyle(
                        fontSize: 14,
                        color: error != null && elderId == null ? TPColors.red600 : TPColors.grayscale500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Label('要陪長輩辦什麼'),
              for (final sv in c.services) ...[
                _ServiceTile(
                  title: sv['title'] as String,
                  subtitle: '約 ${sv['estMinutes']} 分鐘・${sv['sensitiveFieldCount']} 項個資需長輩授權',
                  selected: serviceId == sv['id'],
                  onTap: () => setState(() => serviceId = sv['id'] as String),
                ),
                const SizedBox(height: 8),
              ],
              if (error != null && elderId != null) ...[
                Text(error!, style: const TextStyle(fontSize: 14, color: TPColors.red600)),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              const _Card(
                color: TPColors.primary50,
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: TPColors.primary700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '您看不到長輩的個資。每一項資料都要長輩自己同意，最後也只有長輩能按送出。',
                        style: TextStyle(fontSize: 14, height: 1.5, color: TPColors.primary800),
                      ),
                    ),
                  ],
                ),
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _Label('最近的案件'),
                _Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _CaseRow(s: recent[i], onTap: () => widget.onOpenRecent(recent[i])),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        _BottomBar(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: _primary(),
                onPressed: ready ? send : null,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TPColors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(elderId != null ? '請長輩確認' : '送出陪辦請求'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 6 格配對碼：實際上是一個透明輸入框疊在格子上，可直接貼上、數字鍵盤輸入
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller, required this.focus, required this.error, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focus;
  final bool error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = ((box.maxWidth - 5 * 8 - 12) / 6).clamp(36.0, 54.0);
        return GestureDetector(
          onTap: focus.requestFocus,
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([controller, focus]),
                builder: (context, _) {
                  final text = controller.text;
                  return Row(
                    children: [
                      for (var i = 0; i < 6; i++) ...[
                        if (i > 0) SizedBox(width: i == 3 ? 20 : 8),
                        Container(
                          width: size,
                          height: size * 1.18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TPColors.grayscale50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              width: focus.hasFocus && i == text.length.clamp(0, 5) ? 2 : 1.2,
                              color: error
                                  ? TPColors.red500
                                  : focus.hasFocus && i == text.length.clamp(0, 5)
                                  ? TPColors.primary500
                                  : TPColors.grayscale200,
                            ),
                          ),
                          child: Text(
                            i < text.length ? text[i] : '',
                            style: TextStyle(
                              fontSize: size * 0.5,
                              fontWeight: FontWeight.w600,
                              color: TPColors.grayscale900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    onChanged: onChanged,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(border: InputBorder.none, counterText: '', labelText: '配對碼，6 位數字'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? TPColors.primary50 : TPColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? TPColors.primary500 : TPColors.white, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TPColors.grayscale900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: TPColors.grayscale500)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? TPColors.primary500 : TPColors.grayscale300,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TrustedElderTile extends StatelessWidget {
  const _TrustedElderTile({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? TPColors.primary50 : TPColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? TPColors.primary500 : TPColors.white, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.secondary100),
                child: Text(
                  name.characters.first,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: TPColors.secondary800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TPColors.grayscale900)),
                    const SizedBox(height: 2),
                    const Text('已把您加為信任的人', style: TextStyle(fontSize: 13, color: TPColors.grayscale500)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? TPColors.primary500 : TPColors.grayscale300,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.s, required this.onTap});
  final AssistSession s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = s.isActive
        ? TPColors.green500
        : s.isPending
        ? TPColors.orange500
        : TPColors.grayscale300;
    final t = s.createdAt;
    return ListTile(
      onTap: onTap,
      title: Text('${s.elderDisplayName}・${s.serviceTitle}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          _Dot(color),
          const SizedBox(width: 6),
          Text(
            '${statusLabel(s)}・${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 13, color: TPColors.grayscale500),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: TPColors.grayscale400),
    );
  }
}

// ═════════════════════════════════════════════ 等待長輩回應

class _Waiting extends StatelessWidget {
  const _Waiting({required this.c, required this.s});
  final AssistHelperController c;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(color: TPColors.primary50, shape: BoxShape.circle),
                    child: const Icon(Icons.phone_iphone_rounded, size: 40, color: TPColors.primary600),
                  ),
                  const SizedBox(height: 20),
                  Text('等 ${s.elderDisplayName} 在手機上同意', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('「${s.serviceTitle}」的陪辦請求已送出', style: const TextStyle(fontSize: 14, color: TPColors.grayscale500)),
                  const SizedBox(height: 20),
                  AssistTicker(
                    builder: (context, now) {
                      final left = (s.expiresAt ?? now).difference(now);
                      return Text(
                        assistMmss(left.isNegative ? Duration.zero : left),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                  const Text('後請求自動失效', style: TextStyle(fontSize: 13, color: TPColors.grayscale500)),
                  const SizedBox(height: 20),
                  const _Card(
                    color: TPColors.grayscale100,
                    child: Text(
                      '長輩手機首頁最上方會出現您的姓名與身分，由長輩自己決定要不要接受。',
                      style: TextStyle(fontSize: 14, height: 1.5, color: TPColors.grayscale700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _BottomBar(
          children: [
            Expanded(
              child: OutlinedButton(style: _secondary(), onPressed: () => _run(c.end), child: const Text('取消請求')),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════ 陪辦進行中

class _Session extends StatelessWidget {
  const _Session({required this.c, required this.s});
  final AssistHelperController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final def = c.serviceDefs[s.serviceId];
    if (def == null) return const Center(child: CircularProgressIndicator());
    final steps = def.steps;
    final step = steps[s.currentStep];
    final last = s.currentStep == steps.length - 1;
    final waiting = s.pendingAuth != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // 對象與狀態
              Row(
                children: [
                  Text('陪 ${s.elderDisplayName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  _Dot(s.isReviewing ? TPColors.orange500 : TPColors.green500),
                  const SizedBox(width: 4),
                  Text(statusLabel(s), style: const TextStyle(fontSize: 13, color: TPColors.grayscale500)),
                  const Spacer(),
                  AssistTicker(
                    builder: (context, now) => Text(
                      '已進行 ${assistMmss(now.difference(s.startedAt ?? now))}',
                      style: const TextStyle(fontSize: 13, color: TPColors.grayscale500, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 步驟進度
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= s.currentStep ? TPColors.primary500 : TPColors.grayscale200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '第 ${s.currentStep + 1} / ${steps.length} 步',
                style: const TextStyle(fontSize: 13, color: TPColors.primary700, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(step.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.phone_iphone_rounded, size: 16, color: TPColors.grayscale500),
                        SizedBox(width: 4),
                        Text('長輩手機上看到', style: TextStyle(fontSize: 13, color: TPColors.grayscale500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('「${step.elderGuide}」', style: const TextStyle(fontSize: 15, height: 1.5)),
                    if (step.helperScript.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.record_voice_over_outlined, size: 16, color: TPColors.primary700),
                          SizedBox(width: 4),
                          Text('建議這樣說', style: TextStyle(fontSize: 13, color: TPColors.primary700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(step.helperScript, style: const TextStyle(fontSize: 15, height: 1.5, color: TPColors.grayscale800)),
                    ],
                  ],
                ),
              ),
              if (step.fields.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _Label('這一步的資料'),
                _Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < step.fields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _FieldRow(c: c, s: s, f: step.fields[i]),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _Card(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: TPColors.primary500,
                  title: const Text('長輩自己換頁', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    s.elderNav ? '完成一步自動到下一步，長輩也能按上一頁／下一頁' : '只有您能換頁，長輩手機會顯示「會帶您到下一步」',
                    style: const TextStyle(fontSize: 13, color: TPColors.grayscale500),
                  ),
                  value: s.elderNav,
                  onChanged: (v) => _run(() => c.setElderNav(v)),
                ),
              ),
              const SizedBox(height: 8),
              _Card(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: TPColors.primary500,
                  title: const Text('長輩自己授權', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    s.elderSelfAuth ? '長輩可以直接點開這一步的資料自己同意，不用等您請求' : '只有您按「請長輩授權」後，長輩才能提供資料',
                    style: const TextStyle(fontSize: 13, color: TPColors.grayscale500),
                  ),
                  value: s.elderSelfAuth,
                  onChanged: (v) => _run(() => c.setElderSelfAuth(v)),
                ),
              ),
              const SizedBox(height: 12),
              _Timeline(s: s),
            ],
          ),
        ),
        _BottomBar(
          children: [
            if (s.currentStep > 0 && !s.isReviewing) ...[
              SizedBox(
                width: 112,
                child: OutlinedButton(
                  style: _secondary().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8))),
                  onPressed: waiting ? null : () => _run(() => c.gotoStep(s.currentStep - 1)),
                  child: const Text('上一步'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton(
                style: _primary(),
                onPressed: waiting || s.isReviewing
                    ? null
                    : () => _run(() => last ? c.requestSubmit() : c.gotoStep(s.currentStep + 1)),
                child: Text(
                  waiting
                      ? '等長輩回應授權…'
                      : s.isReviewing
                      ? '長輩正在確認送出'
                      : last
                      ? '請長輩確認並送出'
                      : '下一步（長輩畫面同步）',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.c, required this.s, required this.f});
  final AssistHelperController c;
  final AssistSession s;
  final FieldDef f;

  @override
  Widget build(BuildContext context) {
    final st = s.field(f.key);
    final focused = s.focusField == f.key;
    final remaining = st.remainingRequests ?? 0;
    final (String label, Color color) = switch (st.status) {
      'authorized' => (st.edited ? '長輩已授權（修改過）' : '長輩已授權', TPColors.green500),
      'filled' => ('長輩選了：${f.optionLabel(st.value)}', TPColors.green500),
      'requested' => ('等待長輩授權', TPColors.orange500),
      'denied' => ('長輩不同意', TPColors.red500),
      _ => (f.sensitive ? '尚未授權' : '請長輩在手機上選擇', TPColors.grayscale300),
    };
    final canAsk = f.sensitive && st.status != 'authorized' && st.status != 'requested' && s.pendingAuth == null && remaining > 0;

    return Container(
      color: focused ? TPColors.primary50 : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(f.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    if (f.sensitive && f.riskLevel == 'high') ...[
                      const SizedBox(width: 6),
                      const _Tag('高敏感', TPColors.red600, TPColors.red50),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Dot(color),
                    const SizedBox(width: 6),
                    Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: TPColors.grayscale600))),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: focused ? '取消標示' : '在長輩畫面上標示這一項',
            onPressed: s.pendingAuth != null ? null : () => _run(() => c.focusField(focused ? null : f.key)),
            icon: Icon(
              focused ? Icons.highlight_alt_rounded : Icons.highlight_alt_outlined,
              color: focused ? TPColors.primary600 : TPColors.grayscale400,
            ),
          ),
          if (f.sensitive)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: TPColors.primary600,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canAsk
                  ? () {
                      HapticFeedback.selectionClick();
                      _run(() => c.requestField(f.key));
                    }
                  : null,
              child: Text(switch (st.status) {
                'authorized' => '已授權',
                'requested' => '詢問中',
                'denied' => remaining > 0 ? '再問一次' : '已達上限',
                _ => '請授權',
              }),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.fg, this.bg);
  final String text;
  final Color fg;
  final Color bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
  );
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.s});
  final AssistSession s;
  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final items = widget.s.timeline.reversed.toList();
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => open = !open),
            leading: const Icon(Icons.history_rounded, color: TPColors.grayscale500),
            title: Text('即時動態（${items.length}）', style: const TextStyle(fontSize: 15)),
            trailing: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  for (final t in items.take(20))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _Dot(switch (t.actor) {
                              'elder' => TPColors.orange500,
                              'helper' => TPColors.primary500,
                              _ => TPColors.grayscale300,
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t.text, style: const TextStyle(fontSize: 13, color: TPColors.grayscale700))),
                          Text(
                            '${t.ts.hour.toString().padLeft(2, '0')}:${t.ts.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12, color: TPColors.grayscale400),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 結果

class _Done extends StatelessWidget {
  const _Done({required this.c, required this.s, required this.animate});
  final AssistHelperController c;
  final AssistSession s;
  final bool animate;
  @override
  Widget build(BuildContext context) {
    final ok = s.status == 'completed';
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ok)
                    AssistCelebration.gratitude(key: ValueKey(s.id), animate: animate)
                  else
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: TPColors.grayscale100, shape: BoxShape.circle),
                      child: const Icon(Icons.info_outline_rounded, size: 44, color: TPColors.grayscale500),
                    ),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      ok ? '謝謝您的陪伴！' : statusLabel(s),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ok ? '${s.elderDisplayName} 已送出「${s.serviceTitle}」。' : '「${s.serviceTitle}」',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: TPColors.grayscale600),
                  ),
                  if (ok && s.caseNo != null) ...[
                    const SizedBox(height: 16),
                    _Card(
                      color: TPColors.primary50,
                      child: Column(
                        children: [
                          const Text('案件編號', style: TextStyle(fontSize: 13, color: TPColors.primary700)),
                          Text(s.caseNo!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: TPColors.primary800)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _BottomBar(
          children: [
            Expanded(
              child: FilledButton(style: _primary(), onPressed: () => c.focusedId.value = null, child: const Text('新陪辦')),
            ),
          ],
        ),
      ],
    );
  }
}
