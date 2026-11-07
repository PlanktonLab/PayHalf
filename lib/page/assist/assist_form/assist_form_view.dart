import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_form_inputs.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 靜態 QR Code 表單：長輩用台北通掃了海報上的 QR Code，自己一題一題填。
///
/// 個資題可以一鍵帶入台北通實名資料（按了才帶入）；
/// 任何時候都可以按右上角「找人幫我」：線上客服／旁邊的人／信任的人，
/// 已經填好的答案會帶進陪辦，對方從還沒填的地方接著陪。
class AssistFormView extends StatefulWidget {
  const AssistFormView({super.key, required this.formId, this.askHelp = false});
  final String formId;

  /// 從活動頁按「需要別人協助填寫」進來：表單一載入就直接打開求助選單
  final bool askHelp;

  static Future<void> open(String formId, {bool askHelp = false}) async {
    await Get.to(() => AssistFormView(formId: formId, askHelp: askHelp), routeName: '/assist_form');
  }

  @override
  State<AssistFormView> createState() => _AssistFormViewState();
}

class _AssistFormViewState extends State<AssistFormView> {
  final service = Get.find<AssistService>();
  StaticForm? form;
  String? error;

  /// -1 = 表單說明；0..n-1 = 第幾題；n = 確認送出
  int page = -1;
  final answers = <String, String>{};

  /// 個資題：長輩選擇「自己輸入」而不是帶入
  final typing = <String>{};
  bool busy = false;
  Map<String, dynamic>? done;
  final openedAt = DateTime.now();
  Worker? _watch;
  String? _handledSession;

  List<StaticFormField> get fields => form?.fields ?? const [];

  @override
  void initState() {
    super.initState();
    load();
    // 求助之後，對方發起的陪辦請求一到就直接打開「誰要協助您」畫面；長輩同意後這一頁就功成身退
    _watch = ever(service.sessions, (_) => _onSessions());
  }

  @override
  void dispose() {
    _watch?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final f = await service.openForm(widget.formId);
      if (!mounted) return;
      setState(() => form = f);
      if (widget.askHelp) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? help() : null);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onSessions() {
    final f = form;
    if (f == null || !mounted) return;
    final mine = service.sessions.values
        .where((s) => s.serviceId == f.serviceId && s.createdAt.isAfter(openedAt.subtract(const Duration(seconds: 5))))
        .toList();
    for (final s in mine) {
      if (s.isPending && _handledSession != s.id && !service.isHelping(s.id)) {
        _handledSession = s.id;
        service.formTicket.value = null;
        // 關掉求助視窗，直接請長輩確認是誰要來幫忙
        Navigator.of(context).popUntil((r) => r.settings.name == '/assist_form' || r.isFirst);
        Get.toNamed(TPRoute.assistRequest, arguments: s.id);
      }
      if (s.isActive) {
        final route = ModalRoute.of(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route != null && route.isActive && mounted) Navigator.of(context).removeRoute(route);
        });
        return;
      }
    }
  }

  bool answered(StaticFormField f) => (answers[f.id] ?? '').trim().isNotEmpty;

  bool canNext(StaticFormField f) => !f.required || f.type == 'file' || answered(f);

  void go(int p) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => page = p);
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      final r = await service.submitForm(widget.formId, answers);
      if (mounted) setState(() => done = r);
    } catch (e) {
      await assistRun(() => Future.error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void help() {
    final f = form;
    if (f == null) return;
    final q = page >= 0 && page < fields.length ? fields[page].label : null;
    _HelpSheet.show(context, form: f, answers: Map.of(answers), question: q);
  }

  @override
  Widget build(BuildContext context) {
    final f = form;
    Widget body;
    if (error != null) {
      body = _Message(
        icon: Icons.error_outline_rounded,
        title: '打不開這份表單'.tr,
        text: error!,
        action: AssistButton('再試一次'.tr, onPressed: load),
      );
    } else if (f == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (done != null) {
      body = _Done(form: f, result: done!);
    } else if (f.submitted != null) {
      body = _Message(
        icon: Icons.task_alt_rounded,
        title: '你已經填過這份表單了'.tr,
        text: trf('收件編號 {0}\n有問題可以打 1999 市民熱線。', [f.submitted!['receiptNo']]),
        action: AssistButton('回到首頁'.tr, onPressed: () => Get.until((r) => r.isFirst)),
      );
    } else if (f.status != 'open') {
      body = _Message(
        icon: Icons.event_busy_rounded,
        title: '這份表單已經停止收件了'.tr,
        text: trf('「{0}」目前沒有在收件。有問題可以打 1999 市民熱線。', [f.title]),
        action: AssistButton('回到首頁'.tr, onPressed: () => Get.until((r) => r.isFirst)),
      );
    } else if (page < 0) {
      body = _Intro(form: f, onStart: () => go(0));
    } else if (page >= fields.length) {
      body = _Review(
        form: f,
        answers: answers,
        busy: busy,
        onEdit: go,
        onSubmit: submit,
      );
    } else {
      body = _Question(
        key: ValueKey(fields[page].id),
        form: f,
        index: page,
        answers: answers,
        typing: typing,
        onChanged: () => setState(() {}),
        onPrev: () => go(page - 1),
        onNext: canNext(fields[page]) ? () => go(page + 1) : null,
      );
    }

    final showHelp = f != null && done == null && f.submitted == null && f.status == 'open' && f.allowAssist;
    return AssistTextScaleCap(
      child: Scaffold(
        backgroundColor: TPColors.grayscale50,
        appBar: TPAppBar(title: '填寫表單'.tr),
        body: Column(
          children: [
            if (showHelp) _HelpBar(form: f, page: page, total: fields.length, onHelp: help),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 上方：進度＋找人幫我

class _HelpBar extends StatelessWidget {
  const _HelpBar({required this.form, required this.page, required this.total, required this.onHelp});
  final StaticForm form;
  final int page;
  final int total;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final progress = page < 0 ? 0.0 : (page / total).clamp(0.0, 1.0);
    final label = page < 0
        ? form.dept
        : page >= total
        ? '最後一步：確認送出'.tr
        : trf('第 {0} 題，共 {1} 題', [page + 1, total]);
    return Container(
      color: TPColors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: AssistText.callout.copyWith(color: TPColors.grayscale700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Obx(() {
                final waiting = service.formTicket.value?['status'] == 'waiting';
                return Semantics(
                  button: true,
                  label: waiting ? '已經通知客服，點兩下查看'.tr : '不會填？找人幫我'.tr,
                  excludeSemantics: true,
                  child: Material(
                    color: waiting ? TPColors.secondary100 : TPColors.primary50,
                    shape: StadiumBorder(side: BorderSide(color: waiting ? TPColors.secondary500 : TPColors.primary300)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onHelp,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              waiting ? Icons.support_agent_rounded : Icons.front_hand_rounded,
                              size: context.iconSize(20),
                              color: waiting ? TPColors.secondary800 : TPColors.primary700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              waiting ? '客服馬上來'.tr : '找人幫我'.tr,
                              style: AssistText.callout.copyWith(
                                fontWeight: FontWeight.w700,
                                color: waiting ? TPColors.secondary800 : TPColors.primary700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          if (page >= 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: TPColors.grayscale100,
                color: TPColors.primary500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 表單說明

class _Intro extends StatelessWidget {
  const _Intro({required this.form, required this.onStart});
  final StaticForm form;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final n = form.fields.length;
    final d = DateTime.tryParse(form.deadline);
    final hasProfile = form.fields.any((f) => f.profile != null);
    return AssistActionLayout(
      content: [Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(form.title, style: AssistText.largeTitle),
          const SizedBox(height: 6),
          Text(form.dept, style: AssistText.callout.copyWith(color: TPColors.primary700)),
          if (form.desc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(form.desc, style: AssistText.body),
          ],
          const SizedBox(height: 20),
          AssistCard(
            child: Column(
              children: [
                _Fact(Icons.format_list_numbered_rounded, trf('一共 {0} 題，大約 {1} 分鐘', [n, assistFormMinutes(form.fields)])),
                if (d != null) _Fact(Icons.event_rounded, trf('{0} 月 {1} 日前填好', [d.month, d.day])),
                if (hasProfile) _Fact(Icons.badge_rounded, trf('{0}可以從台北通帳號帶入，你按了才會帶入', [_profileNames(form.fields)])),
                _Fact(Icons.front_hand_rounded, '不會填的時候，按右上角「找人幫我」'.tr),
              ],
            ),
          ),
        ],
      )],
      actions: [AssistButton('開始填寫'.tr, icon: Icons.edit_rounded, onPressed: onStart)],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: TPColors.primary500, size: context.iconSize(24)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AssistText.body.copyWith(fontSize: 18))),
      ],
    ),
  );
}

// ═════════════════════════════════════════════ 一題一頁

class _Question extends StatelessWidget {
  const _Question({
    super.key,
    required this.form,
    required this.index,
    required this.answers,
    required this.typing,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
  });
  final StaticForm form;
  final int index;
  final Map<String, String> answers;
  final Set<String> typing;
  final VoidCallback onChanged;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final f = form.fields[index];
    final v = answers[f.id] ?? '';
    void set(String x) {
      if (x.trim().isEmpty) {
        answers.remove(f.id);
      } else {
        answers[f.id] = x;
      }
      onChanged();
    }

    final prefill = form.prefill[f.id];
    Widget input;
    if (f.profile != null && prefill != null && !typing.contains(f.id)) {
      input = _ProfileAnswer(
        f: f,
        value: v,
        prefill: prefill,
        onFill: () => set(prefill),
        onEdit: (x) => set(x),
        onType: () {
          typing.add(f.id);
          set('');
        },
      );
    } else if (f.type == 'radio' || f.type == 'select') {
      input = Column(
        children: [
          for (final o in f.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AssistOptionRow(label: o, selected: v == o, onTap: () => set(o)),
            ),
        ],
      );
    } else if (f.type == 'checkbox') {
      input = AssistMultiChoice(options: f.options, value: v, onConfirm: null, onChanged: set);
    } else if (f.type == 'consent') {
      input = AssistOptionRow(multi: true, label: '我同意'.tr, selected: v.isNotEmpty, onTap: () => set(v.isEmpty ? '我同意'.tr : ''));
    } else if (f.type == 'file') {
      input = AssistNotice(
        icon: Icons.photo_camera_back_rounded,
        color: TPColors.primary800,
        background: TPColors.primary50,
        text: '照片可以之後再補，先按「下一題」就好。'.tr,
      );
    } else {
      input = AssistTextAnswer(
        label: f.label,
        inputType: f.type == 'idno' ? 'text' : f.type,
        // 提示已經寫在題目下面，輸入框裡就不重複
        hint: '',
        initial: v,
        onSubmit: null,
        onChanged: set,
      );
    }

    final last = index == form.fields.length - 1;
    final empty = v.trim().isEmpty;
    return AssistActionLayout(
      content: [Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(f.label, style: AssistText.title.copyWith(fontSize: 26)),
          if (f.hint.isNotEmpty && !(f.profile != null && prefill != null && !typing.contains(f.id))) ...[
            const SizedBox(height: 6),
            Text(f.hint, style: AssistText.callout),
          ],
          if (!f.required) ...[
            const SizedBox(height: 4),
            Text('這題可以不填'.tr, style: AssistText.footnote),
          ],
          const SizedBox(height: 18),
          input,
        ],
      )],
      actions: [
        AssistButton(
          last ? '看一下，準備送出'.tr : (!f.required && empty ? '跳過這題'.tr : '下一題'.tr),
          icon: Icons.arrow_forward_rounded,
          onPressed: onNext,
        ),
        AssistButton(index == 0 ? '回到說明'.tr : '上一題'.tr, style: AssistButtonStyle.plain, onPressed: onPrev),
      ],
    );
  }
}

/// 個資題：按「填入我的○○」才從台北通帳號帶入；也可以自己輸入
class _ProfileAnswer extends StatelessWidget {
  const _ProfileAnswer({
    required this.f,
    required this.value,
    required this.prefill,
    required this.onFill,
    required this.onEdit,
    required this.onType,
  });
  final StaticFormField f;
  final String value;
  final String prefill;
  final VoidCallback onFill;
  final ValueChanged<String> onEdit;
  final VoidCallback onType;

  String get bare => profileKindName(f.profile, f.raw['label'] as String? ?? '');

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssistButton(
            trf('填入我的{0}', [bare]),
            icon: Icons.badge_rounded,
            style: AssistButtonStyle.secondary,
            onPressed: () {
              HapticFeedback.selectionClick();
              onFill();
            },
          ),
          const SizedBox(height: 8),
          Text('會用你台北通帳號裡的資料，按了才會帶入。'.tr, style: AssistText.footnote),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onType, child: Text('我自己輸入'.tr, style: AssistText.callout.copyWith(color: TPColors.primary600))),
          ),
        ],
      );
    }
    return AssistCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AssistColors.green500, size: context.iconSize(22)),
              const SizedBox(width: 6),
              Text('已經帶入'.tr, style: AssistText.callout),
            ],
          ),
          const SizedBox(height: 6),
          AssistRevealValue(fieldKey: f.profile!, label: bare, value: value, style: AssistText.headline),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  final v = await assistEditValue(label: bare, initial: value);
                  if (v != null && v.trim().isNotEmpty) onEdit(v.trim());
                },
                child: Text('修改'.tr, style: AssistText.callout.copyWith(color: TPColors.primary600, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => onEdit(''),
                child: Text('不要帶入'.tr, style: AssistText.callout.copyWith(color: TPColors.red600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 確認送出

class _Review extends StatelessWidget {
  const _Review({required this.form, required this.answers, required this.busy, required this.onEdit, required this.onSubmit});
  final StaticForm form;
  final Map<String, String> answers;
  final bool busy;
  final ValueChanged<int> onEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final fs = form.fields;
    final missing = [for (var i = 0; i < fs.length; i++) if (fs[i].required && fs[i].type != 'file' && (answers[fs[i].id] ?? '').isEmpty) i];
    return AssistActionLayout(
      content: [Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text('看一下對不對'.tr, style: AssistText.largeTitle),
          const SizedBox(height: 6),
          Text('要改哪一題，點那一題就可以回去改。'.tr, style: AssistText.callout),
          const SizedBox(height: 16),
          AssistCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < fs.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  InkWell(
                    onTap: () => onEdit(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fs[i].label, style: AssistText.callout),
                                if ((answers[fs[i].id] ?? '').isEmpty)
                                  Text(
                                    fs[i].type == 'file' ? '之後再補'.tr : (fs[i].required ? '還沒回答'.tr : '沒有填'.tr),
                                    style: AssistText.headline.copyWith(
                                      color: missing.contains(i) ? TPColors.red600 : TPColors.grayscale400,
                                    ),
                                  )
                                else if (fs[i].profile != null)
                                  AssistRevealValue(
                                    fieldKey: fs[i].profile!,
                                    label: fs[i].label,
                                    value: answers[fs[i].id],
                                    style: AssistText.headline,
                                  )
                                else
                                  Text(answers[fs[i].id]!, style: AssistText.headline),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: TPColors.grayscale400),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(trf('送出後由「{0}」受理。', [form.dept]), style: AssistText.footnote),
        ],
      )],
      actions: [
        if (missing.isNotEmpty)
          AssistButton(trf('還有 {0} 題沒回答', [missing.length]), style: AssistButtonStyle.secondary, onPressed: () => onEdit(missing.first))
        else
          AssistButton('確認送出'.tr, icon: Icons.lock_rounded, style: AssistButtonStyle.success, onPressed: busy ? null : onSubmit),
        AssistButton('上一題'.tr, style: AssistButtonStyle.plain, onPressed: () => onEdit(fs.length - 1)),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.form, required this.result});
  final StaticForm form;
  final Map<String, dynamic> result;
  @override
  Widget build(BuildContext context) => _Message(
    icon: Icons.check_circle_rounded,
    iconColor: AssistColors.green500,
    title: '送出了！'.tr,
    text: trf('{0}\n\n收件編號 {1}', [(result['doneMsg'] as String?)?.isNotEmpty == true ? result['doneMsg'] : form.doneMsg, result['receiptNo']]),
    action: AssistButton('回到首頁'.tr, onPressed: () => Get.until((r) => r.isFirst)),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, required this.action, this.iconColor});
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String text;
  final AssistButton action;
  @override
  Widget build(BuildContext context) => AssistActionLayout(
    content: [Column(
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: context.iconSize(72), color: iconColor ?? TPColors.primary500),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: AssistText.largeTitle),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: AssistText.body),
      ],
    )],
    actions: [action],
  );
}

// ═════════════════════════════════════════════ 找人幫我

class _HelpSheet extends StatefulWidget {
  const _HelpSheet({required this.form, required this.answers, this.question});
  final StaticForm form;
  final Map<String, String> answers;
  final String? question;

  static Future<void> show(BuildContext context, {required StaticForm form, required Map<String, String> answers, String? question}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: TPColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => AssistTextScaleCap(child: _HelpSheet(form: form, answers: answers, question: question)),
      );

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

enum _Mode { choose, online, nearby, trusted }

class _HelpSheetState extends State<_HelpSheet> {
  final service = Get.find<AssistService>();
  late _Mode mode = service.formTicket.value?['status'] == 'waiting' ? _Mode.online : _Mode.choose;
  bool busy = false;
  String? trustedName;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> ask(_Mode m, {String? helperId, String? name}) async {
    setState(() => busy = true);
    final ok = await assistRun(
      () => service.formHelp(
        widget.form.id,
        m.name,
        widget.answers,
        question: widget.question,
        helperId: helperId,
      ),
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) {
        mode = m;
        trustedName = name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.answers.length;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: TPColors.grayscale200, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            ...switch (mode) {
              _Mode.choose => _choose(n),
              _Mode.online => _online(),
              _Mode.nearby => _nearby(),
              _Mode.trusted => _trusted(),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _choose(int n) {
    final trusted = service.trusted.toList();
    return [
      Text('要找誰幫你？'.tr, style: AssistText.largeTitle),
      const SizedBox(height: 6),
      Text(
        n > 0 ? trf('你已經填好的 {0} 題會保留，對方會從還沒填的地方陪你。', [n]) : '對方會連上你的手機，一步一步陪你填。'.tr,
        style: AssistText.callout,
      ),
      const SizedBox(height: 18),
      for (final t in trusted) ...[
        _Option(
          icon: Icons.favorite_rounded,
          iconColor: TPColors.red500,
          title: trf('請 {0} 幫我', [t.helper.name]),
          text: trf('{0}，你信任的人。他的手機會跳通知', [t.helper.title]),
          onTap: busy ? null : () => ask(_Mode.trusted, helperId: t.helper.id, name: t.helper.name),
        ),
        const SizedBox(height: 10),
      ],
      _Option(
        icon: Icons.support_agent_rounded,
        title: '請線上客服幫我'.tr,
        text: '1999 市民熱線客服人員，通常 1 分鐘內接起'.tr,
        onTap: busy ? null : () => ask(_Mode.online),
      ),
      const SizedBox(height: 10),
      _Option(
        icon: Icons.qr_code_2_rounded,
        title: '請旁邊的人幫我'.tr,
        text: '家人、里長或志工，用他的台北通掃一下就能陪你填'.tr,
        onTap: busy ? null : () => ask(_Mode.nearby),
      ),
      const SizedBox(height: 14),
      AssistNotice(
        icon: Icons.lock_rounded,
        color: TPColors.primary800,
        background: TPColors.primary50,
        text: '幫你的人看不到你的身分證字號、電話這些資料，送出鍵也只有你能按。'.tr,
      ),
    ];
  }

  List<Widget> _online() => [
    Obx(() {
      final t = service.formTicket.value;
      final status = t?['status'] as String?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          if (status == 'waiting') ...[
            const Center(child: SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 4))),
            const SizedBox(height: 18),
            Text('已經通知客服了'.tr, textAlign: TextAlign.center, style: AssistText.largeTitle),
            const SizedBox(height: 8),
            Text('客服接起來時，手機會跳出是誰要幫你，你按「同意」就開始。\n可以先關掉這個視窗繼續填。'.tr, textAlign: TextAlign.center, style: AssistText.callout),
          ] else
            Text(
              status == 'expired' ? '客服現在比較忙，請再試一次，或請旁邊的人幫忙。'.tr : '求助已經結束了。'.tr,
              textAlign: TextAlign.center,
              style: AssistText.headline,
            ),
          const SizedBox(height: 20),
          if (status == 'waiting') ...[
            AssistButton('好，我先繼續填'.tr, onPressed: () => Navigator.of(context).pop()),
            AssistButton(
              '不用了，取消求助'.tr,
              style: AssistButtonStyle.destructivePlain,
              onPressed: () async {
                await assistRun(service.cancelFormTicket);
                if (mounted) setState(() => mode = _Mode.choose);
              },
            ),
          ] else
            AssistButton('換別的方式'.tr, onPressed: () => setState(() => mode = _Mode.choose)),
        ],
      );
    }),
  ];

  List<Widget> _nearby() {
    final p = service.pairing.value;
    if (p == null) return [const Center(child: CircularProgressIndicator())];
    final left = p.expiresAt.difference(DateTime.now());
    final expired = left.isNegative;
    return [
      Text('請旁邊的人掃這個'.tr, textAlign: TextAlign.center, style: AssistText.largeTitle),
      const SizedBox(height: 6),
      Text('他打開台北通，按右下角「掃描」，掃完你的手機就會問你要不要讓他幫忙。'.tr, textAlign: TextAlign.center, style: AssistText.callout),
      const SizedBox(height: 16),
      Center(
        child: Opacity(
          opacity: expired ? 0.12 : 1,
          child: QrImageView(
            data: p.qrPayload,
            size: 220,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: TPColors.primary800),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: TPColors.primary800),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        expired ? '號碼已經失效'.tr : trf('或念號碼給他：{0} {1}', [p.code.substring(0, 3), p.code.substring(3)]),
        textAlign: TextAlign.center,
        style: AssistText.title,
      ),
      Text(
        expired ? '' : trf('{0}:{1} 後失效', [left.inMinutes, '${left.inSeconds % 60}'.padLeft(2, '0')]),
        textAlign: TextAlign.center,
        style: AssistText.footnote,
      ),
      const SizedBox(height: 16),
      if (expired)
        AssistButton('重新產生'.tr, onPressed: busy ? null : () => ask(_Mode.nearby))
      else
        AssistButton('換別的方式'.tr, style: AssistButtonStyle.plain, onPressed: () => setState(() => mode = _Mode.choose)),
    ];
  }

  List<Widget> _trusted() => [
    const SizedBox(height: 8),
    Icon(Icons.favorite_rounded, color: TPColors.red500, size: context.iconSize(56)),
    const SizedBox(height: 12),
    Text(trf('已經通知 {0}', [trustedName ?? '']), textAlign: TextAlign.center, style: AssistText.largeTitle),
    const SizedBox(height: 8),
    Text('他的手機會跳通知。他按「去幫他」之後，你的手機會問你要不要讓他幫忙。'.tr, textAlign: TextAlign.center, style: AssistText.callout),
    const SizedBox(height: 20),
    AssistButton('好，我先繼續填'.tr, onPressed: () => Navigator.of(context).pop()),
    AssistButton('換別的方式'.tr, style: AssistButtonStyle.plain, onPressed: () => setState(() => mode = _Mode.choose)),
  ];
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.text, required this.onTap, this.iconColor});
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: TPColors.grayscale50,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: TPColors.white, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor ?? TPColors.primary600, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AssistText.headline),
                    const SizedBox(height: 2),
                    Text(text, style: AssistText.callout.copyWith(fontSize: 15)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: TPColors.grayscale400),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 預估要填幾分鐘：個資題按一下就帶入（約 15 秒）、選擇題約 20 秒、要打字的約 30 秒
int assistFormMinutes(List<StaticFormField> fields) {
  var sec = 0;
  for (final f in fields) {
    sec += f.profile != null || f.type == 'consent'
        ? 15
        : const {'radio', 'select', 'checkbox'}.contains(f.type)
        ? 20
        : 30;
  }
  return (sec / 60).ceil().clamp(1, 30);
}

/// 可以帶入的個資題名稱，例如「姓名、身分證字號」
String _profileNames(List<StaticFormField> fields) {
  final names = [
    for (final f in fields)
      if (f.profile != null) profileKindName(f.profile, f.raw['label'] as String? ?? ''),
  ];
  return names.length <= 3 ? names.join('、'.tr) : trf('{0}這些', [names.take(2).join('、'.tr)]);
}
