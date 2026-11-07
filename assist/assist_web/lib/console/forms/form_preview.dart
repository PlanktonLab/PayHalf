import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/console_kit.dart';
import '../../shared/tp_colors.dart';
import '../web_utils.dart';
import 'form_store.dart';

/// 民眾在台北通看到的樣子：一次一題、可放大字體、可朗讀，可以實際試填。
class PhonePreview extends StatefulWidget {
  const PhonePreview({super.key, required this.store, required this.form, this.follow});
  final FormStore store;
  final FForm form;

  /// 編輯器選到第幾題，預覽就跳到那一題
  final int? follow;
  @override
  State<PhonePreview> createState() => _PhonePreviewState();
}

class _PhonePreviewState extends State<PhonePreview> {
  int i = 0;
  double scale = 1.2;
  bool done = false;
  String? error;
  final Map<String, Object?> ans = {};
  final Map<String, TextEditingController> _ctl = {};

  FForm get f => widget.form;

  @override
  void didUpdateWidget(PhonePreview old) {
    super.didUpdateWidget(old);
    final t = widget.follow;
    if (t != null && t >= 0 && t != old.follow) {
      i = t;
      done = false;
      error = null;
    }
  }

  TextEditingController ctl(FField x) =>
      _ctl.putIfAbsent(x.id, () => TextEditingController(text: ans[x.id] as String? ?? ''));

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() => setState(() {
    i = 0;
    done = false;
    error = null;
    ans.clear();
    for (final c in _ctl.values) {
      c.clear();
    }
  });

  Object? value(FField x) {
    if (const {'text', 'textarea', 'number', 'phone', 'idno', 'address', 'date'}.contains(x.type)) {
      return ctl(x).text.trim();
    }
    return ans[x.id];
  }

  String? validate(FField x, Object? v) {
    final empty = v == null || v == '' || v == false || (v is List && v.isEmpty);
    if (empty) return x.required ? '這題要填喔，請回答後再按「下一題」' : null;
    final s = v is String ? v : '';
    if (x.type == 'idno' && !RegExp(r'^[A-Z][12489]\d{8}$').hasMatch(s.toUpperCase())) {
      return '身分證字號格式不對，應該是 1 個英文字母加 9 個數字';
    }
    if (x.type == 'phone' && !RegExp(r'^(09\d{2}-?\d{3}-?\d{3}|0\d{1,2}-?\d{6,8})$').hasMatch(s.replaceAll(' ', ''))) {
      return '電話號碼格式不對，請再檢查一次';
    }
    if (x.type == 'date' && !RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(s)) return '請用「年-月-日」的格式，例如 1948-03-15';
    return null;
  }

  void next() {
    final x = f.fields[i];
    final v = value(x);
    final e = validate(x, v);
    if (e != null) return setState(() => error = e);
    ans[x.id] = v;
    setState(() {
      error = null;
      i++;
    });
  }

  void submit() {
    final row = <String, dynamic>{'_t': DateTime.now().millisecondsSinceEpoch, '_by': '本人（試填）'};
    for (final x in f.fields) {
      final v = ans[x.id];
      row[x.id] = v is List ? v.join('、') : (x.type == 'consent' ? (v == true ? '已同意' : '') : v);
    }
    widget.store.addLive(f, row);
    setState(() => done = true);
  }

  String summary(FField x) {
    final v = ans[x.id];
    if (v is List) return v.isEmpty ? '（沒有填）' : v.join('、');
    if (x.type == 'consent') return v == true ? '已同意' : '（沒有勾選）';
    if (x.type == 'idno' && v is String && v.length > 6) return '${v.substring(0, 3)}●●●●${v.substring(v.length - 3)}';
    return (v == null || v == '') ? '（沒有填）' : '$v';
  }

  @override
  Widget build(BuildContext context) {
    if (i > f.fields.length) i = f.fields.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            const Expanded(child: Text('民眾看到的畫面', style: CText.panelTitle)),
            CIconButton(icon: Icons.restart_alt_rounded, tooltip: '重新開始試填', onPressed: reset),
          ],
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('可以實際填填看，試填的資料只會出現在「回覆」裡。', style: CText.small),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: CSegmented<double>(
            value: scale,
            onChanged: (v) => setState(() => scale = v),
            options: const [(1.0, '標準字', null), (1.2, '大字', null), (1.5, '特大字', null)],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 340,
          height: 640,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: C.borderStrong, width: 1.5),
            boxShadow: C.popShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: TPColors.white,
              child: Column(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(gradient: TPColors.brandGradient),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: TPColors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.displayTitle,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: TPColors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                      child: _body(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    final n = f.fields.length;
    if (done) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: C.okSoft),
              child: const Icon(Icons.check_rounded, size: 46, color: C.ok),
            ),
            const SizedBox(height: 18),
            Text(
              f.doneMsg.isEmpty ? '已經幫你送出了' : f.doneMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.5),
            ),
            const SizedBox(height: 20),
            CButton('再試一次', icon: Icons.restart_alt_rounded, onPressed: reset),
          ],
        ),
      );
    }
    if (n == 0) {
      return const Center(child: Text('還沒有題目可以預覽', style: CText.secondary));
    }
    if (i >= n) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('請最後確認', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (final x in f.fields)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.label, style: const TextStyle(fontSize: 13, color: C.ink3)),
                  const SizedBox(height: 2),
                  Text(summary(x), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _nav(back: () => setState(() => i--), forward: submit, forwardLabel: '確認送出'),
        ],
      );
    }
    final x = f.fields[i];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      children: [
        if (i == 0 && f.desc.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: Text(f.desc, style: const TextStyle(fontSize: 14, color: C.accentInk, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: (i + 1) / n, minHeight: 5),
        ),
        const SizedBox(height: 8),
        Text('第 ${i + 1} 題，共 $n 題', style: const TextStyle(fontSize: 13, color: C.ink3)),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: x.label.isEmpty ? '（尚未輸入問題）' : x.label,
            children: [
              if (!x.required)
                const TextSpan(
                  text: '（可以不填）',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: C.ink3),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.45),
        ),
        if (x.hint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(x.hint, style: const TextStyle(fontSize: 14, color: C.ink2, height: 1.5)),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final ok = speak(
                '${x.label}。${x.hint}${x.options.isNotEmpty && x.hasOptions ? '。選項有：${x.options.join('、')}' : ''}',
              );
              if (!ok) cToast(context, '這個瀏覽器不支援朗讀');
            },
            style: TextButton.styleFrom(foregroundColor: C.accentInk),
            icon: const Icon(Icons.volume_up_rounded, size: 20),
            label: const Text('念給我聽', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        _input(x),
        if (error != null) ...[
          const SizedBox(height: 10),
          CNotice(text: error!, tone: CTone.danger, icon: Icons.error_outline_rounded),
        ],
        const SizedBox(height: 18),
        _nav(back: i == 0 ? null : () => setState(() => i--), forward: next, forwardLabel: '下一題'),
      ],
    );
  }

  Widget _nav({VoidCallback? back, required VoidCallback forward, required String forwardLabel}) => Row(
    children: [
      Expanded(child: CButton('上一題', large: true, expand: true, onPressed: back)),
      const SizedBox(width: 10),
      Expanded(child: CButton.primary(forwardLabel, large: true, expand: true, onPressed: forward)),
    ],
  );

  Widget _choice({required bool selected, required String label, required bool multi, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? C.accentSoft : C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? C.accent : C.borderStrong, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  multi
                      ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                      : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  color: selected ? C.accentStrong : C.ink4,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16, height: 1.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(FField x) {
    switch (x.type) {
      case 'radio':
      case 'select':
        return Column(
          children: [
            for (final o in x.options)
              _choice(
                selected: ans[x.id] == o,
                label: o,
                multi: false,
                onTap: () => setState(() {
                  ans[x.id] = o;
                  error = null;
                }),
              ),
          ],
        );
      case 'checkbox':
        final sel = (ans[x.id] as List?)?.cast<String>() ?? <String>[];
        return Column(
          children: [
            for (final o in x.options)
              _choice(
                selected: sel.contains(o),
                label: o,
                multi: true,
                onTap: () => setState(() {
                  ans[x.id] = sel.contains(o) ? (sel..remove(o)).toList() : [...sel, o];
                  error = null;
                }),
              ),
          ],
        );
      case 'consent':
        return _choice(
          selected: ans[x.id] == true,
          label: x.label.isEmpty ? '我同意' : x.label,
          multi: true,
          onTap: () => setState(() => ans[x.id] = !(ans[x.id] == true)),
        );
      case 'file':
        final has = ans[x.id] != null;
        return CButton(
          has ? '已選擇：${ans[x.id]}' : '選擇照片或檔案',
          icon: has ? Icons.check_rounded : Icons.photo_camera_outlined,
          large: true,
          expand: true,
          onPressed: () => setState(() => ans[x.id] = has ? null : '照片.jpg'),
        );
      default:
        final (TextInputType kb, String hint, int lines) = switch (x.type) {
          'textarea' => (TextInputType.multiline, '', 4),
          'number' => (TextInputType.number, '', 1),
          'phone' => (TextInputType.phone, '0912-345-678', 1),
          'idno' => (TextInputType.text, 'A123456789', 1),
          'date' => (TextInputType.datetime, '1948-03-15', 1),
          'address' => (TextInputType.streetAddress, '臺北市…', 2),
          _ => (TextInputType.text, '', 1),
        };
        return CField(
          controller: ctl(x),
          hint: hint,
          keyboardType: kb,
          maxLines: lines,
          minLines: lines,
          maxLength: x.type == 'idno' ? 10 : null,
          inputFormatters: x.type == 'number' ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: const TextStyle(fontSize: 18, height: 1.4),
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
          onSubmitted: (_) => next(),
        );
    }
  }
}
