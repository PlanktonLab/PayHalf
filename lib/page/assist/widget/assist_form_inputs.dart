import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 表單題目共用的大字作答元件：陪辦畫面與「自己填」的靜態 QR 表單都用這裡。

/// 一個選項（單選圓點／多選方框），整列都可以點
class AssistOptionRow extends StatelessWidget {
  const AssistOptionRow({super.key, required this.label, required this.selected, required this.onTap, this.multi = false});
  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = multi
        ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
        : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: !multi,
      child: Material(
        color: selected ? TPColors.primary50 : TPColors.grayscale50,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? TPColors.primary500 : TPColors.grayscale200, width: 2),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: selected ? TPColors.primary500 : TPColors.grayscale400, size: context.iconSize(28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AssistText.body.copyWith(fontSize: 20, fontWeight: selected ? FontWeight.w600 : null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 多選題：可以勾好幾個，勾好再按「選好了」
class AssistMultiChoice extends StatefulWidget {
  const AssistMultiChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onConfirm,
    this.labels,
    this.confirmLabel = '選好了',
    this.onChanged,
  });
  final ValueChanged<String>? onChanged;
  final List<String> options;
  final List<String>? labels;

  /// 目前的值：用「、」串起來
  final String? value;
  final String confirmLabel;
  final Future<void> Function(String value)? onConfirm;

  @override
  State<AssistMultiChoice> createState() => _AssistMultiChoiceState();
}

class _AssistMultiChoiceState extends State<AssistMultiChoice> {
  late Set<String> picked = _parse(widget.value);

  static Set<String> _parse(String? v) => (v ?? '').split('、').where((e) => e.isNotEmpty).toSet();

  @override
  void didUpdateWidget(covariant AssistMultiChoice old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) picked = _parse(widget.value);
  }

  String get joined => widget.options.where(picked.contains).join('、');

  @override
  Widget build(BuildContext context) {
    final saved = _parse(widget.value);
    final changed = picked.length != saved.length || !picked.containsAll(saved);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('可以選好幾個', style: AssistText.footnote),
        for (var i = 0; i < widget.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AssistOptionRow(
              multi: true,
              label: widget.labels?[i] ?? widget.options[i],
              selected: picked.contains(widget.options[i]),
              onTap: () => setState(() {
                final o = widget.options[i];
                picked.contains(o) ? picked.remove(o) : picked.add(o);
                widget.onChanged?.call(joined);
              }),
            ),
          ),
        if (widget.onConfirm != null && (changed || saved.isEmpty)) ...[
          const SizedBox(height: 12),
          AssistButton(
            widget.confirmLabel,
            icon: Icons.check_rounded,
            onPressed: picked.isEmpty ? null : () => widget.onConfirm!(joined),
          ),
        ],
      ],
    );
  }
}

/// 文字題：大字輸入框＋「填好了」。日期題改用日曆選，數字題跳數字鍵盤。
class AssistTextAnswer extends StatefulWidget {
  const AssistTextAnswer({
    super.key,
    required this.label,
    required this.inputType,
    required this.initial,
    required this.onSubmit,
    this.hint = '',
    this.done = false,
    this.submitLabel = '填好了',
    this.onChanged,
  });
  final String label;
  final String inputType;
  final String hint;
  final String initial;
  final bool done;
  final String submitLabel;

  /// 為 null 時不顯示「填好了」按鈕（自己填的表單用「下一題」統一處理）
  final Future<void> Function(String value)? onSubmit;
  final ValueChanged<String>? onChanged;

  @override
  State<AssistTextAnswer> createState() => _AssistTextAnswerState();
}

class _AssistTextAnswerState extends State<AssistTextAnswer> {
  late final TextEditingController c = TextEditingController(text: widget.initial);
  late String saved = widget.initial;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final init = DateTime.tryParse(c.text) ?? DateTime(now.year - 70, 1, 1);
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 2),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: widget.label,
    );
    if (d == null) return;
    setState(() {
      c.text = '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
    });
    widget.onChanged?.call(c.text);
  }

  String get pretty {
    final d = DateTime.tryParse(c.text);
    return d == null ? '點這裡選日期' : '${d.year} 年 ${d.month} 月 ${d.day} 日';
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.inputType;
    final Widget input;
    if (type == 'date') {
      input = Material(
        color: TPColors.grayscale50,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: pickDate,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TPColors.grayscale200, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: TPColors.primary500, size: context.iconSize(26)),
                const SizedBox(width: 12),
                Expanded(child: Text(pretty, style: AssistText.body.copyWith(fontSize: 20))),
              ],
            ),
          ),
        ),
      );
    } else {
      input = TextField(
        controller: c,
        onChanged: (v) {
          setState(() {});
          widget.onChanged?.call(v);
        },
        minLines: type == 'textarea' ? 3 : 1,
        maxLines: type == 'textarea' ? 6 : 1,
        maxLength: type == 'textarea' ? 500 : 100,
        keyboardType: switch (type) {
          'number' => TextInputType.number,
          'phone' => TextInputType.phone,
          'textarea' => TextInputType.multiline,
          'address' => TextInputType.streetAddress,
          _ => TextInputType.text,
        },
        inputFormatters: type == 'number' ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: AssistText.body.copyWith(fontSize: 21, color: TPColors.grayscale900),
        decoration: InputDecoration(
          hintText: widget.hint.isEmpty ? '請在這裡輸入' : widget.hint,
          hintStyle: AssistText.body.copyWith(color: TPColors.grayscale400),
          counterText: '',
          filled: true,
          fillColor: TPColors.grayscale50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: TPColors.grayscale200, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: TPColors.primary500, width: 2),
          ),
        ),
      );
    }
    final dirty = c.text.trim() != saved.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        if (widget.onSubmit != null) ...[
          const SizedBox(height: 10),
          if (widget.done && !dirty)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AssistColors.green500, size: context.iconSize(22)),
                const SizedBox(width: 6),
                const Text('已經填好了，要改可以直接修改', style: AssistText.callout),
              ],
            )
          else
            AssistButton(
              widget.submitLabel,
              icon: Icons.check_rounded,
              onPressed: c.text.trim().isEmpty
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      await widget.onSubmit!(c.text.trim());
                      if (mounted) setState(() => saved = c.text.trim());
                    },
            ),
        ],
      ],
    );
  }
}
