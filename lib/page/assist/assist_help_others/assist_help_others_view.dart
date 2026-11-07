import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/assist_helper/assist_helper_view.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 「我也能幫別人辦」：登記要幫誰代辦什麼。
///
/// 目前是示範用表單，資料只留在這支手機。送出後引導到真正的陪辦流程
/// （請對方出示配對 QR Code，或對方已把您加為信任的人就能直接請求）。
class AssistHelpOthersView extends StatefulWidget {
  const AssistHelpOthersView({super.key});

  @override
  State<AssistHelpOthersView> createState() => _AssistHelpOthersViewState();
}

class _AssistHelpOthersViewState extends State<AssistHelpOthersView> {
  static const _relations = ['爸媽', '祖父母', '其他親戚', '鄰居朋友', '其他'];
  static const _services = ['敬老卡申請', '里民活動報名', '其他（寫在備註）'];
  static const _where = ['在我旁邊', '不在旁邊，用手機遠端'];

  final name = TextEditingController();
  final note = TextEditingController();
  String? relation;
  String? service;
  String where = _where.first;
  bool promise = false;
  bool sent = false;

  @override
  void dispose() {
    name.dispose();
    note.dispose();
    super.dispose();
  }

  bool get ready => name.text.trim().isNotEmpty && relation != null && service != null && promise;

  void submit() {
    if (!ready) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return AssistTextScaleCap(
      child: Scaffold(
        backgroundColor: TPColors.grayscale50,
        appBar: const TPAppBar(title: '幫別人辦'),
        body: AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
          child: sent ? _done(context) : _form(context),
        ),
      ),
    );
  }

  // ───────────────────────── 表單

  Widget _form(BuildContext context) {
    return AssistActionLayout(
      key: const ValueKey('form'),
      content: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TPColors.secondary100, TPColors.secondary50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.volunteer_activism_rounded, color: TPColors.secondary700, size: context.iconSize(32)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('每個人都能互相幫忙', style: AssistText.headline),
                    SizedBox(height: 4),
                    Text('今天您幫別人，改天也可以請別人幫您。先告訴我們您要幫誰、辦什麼。', style: AssistText.callout),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _Label('您要幫誰？'),
        TextField(
          controller: name,
          style: AssistText.headline,
          textInputAction: TextInputAction.next,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '對方的名字，例如：王大明',
            hintStyle: AssistText.headline.copyWith(color: TPColors.grayscale400, fontWeight: FontWeight.w400),
            counterText: '',
            filled: true,
            fillColor: TPColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: TPColors.primary500, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Chips(options: _relations, value: relation, onChanged: (v) => setState(() => relation = v)),
        const SizedBox(height: 22),
        const _Label('要幫忙辦什麼？'),
        for (final sv in _services) ...[
          _Option(label: sv, selected: service == sv, onTap: () => setState(() => service = sv)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        const _Label('對方現在在哪裡？'),
        _Chips(options: _where, value: where, onChanged: (v) => setState(() => where = v ?? where)),
        const SizedBox(height: 22),
        const _Label('想說的話（可不填）'),
        TextField(
          controller: note,
          style: AssistText.body,
          minLines: 2,
          maxLines: 4,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: '例如：媽媽下週要去區公所，我先陪她在手機上填好',
            hintStyle: AssistText.body.copyWith(color: TPColors.grayscale400),
            filled: true,
            fillColor: TPColors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: TPColors.white,
          borderRadius: BorderRadius.circular(16),
          child: CheckboxListTile(
            value: promise,
            onChanged: (v) => setState(() => promise = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: TPColors.primary500,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            title: const Text('我了解：我看不到對方的身分證、地址、電話。每一項資料都要對方自己同意，最後也只有對方能按送出。', style: AssistText.callout),
          ),
        ),
        const SizedBox(height: 10),
        const Text('這是示範表單，資料只存在這支手機。', style: AssistText.footnote),
      ],
      actions: [
        AssistButton('送出', icon: Icons.send_rounded, onPressed: ready ? submit : null),
      ],
    );
  }

  // ───────────────────────── 送出後

  Widget _done(BuildContext context) {
    final who = name.text.trim();
    final remote = where != _where.first;
    return AssistActionLayout(
      key: const ValueKey('done'),
      content: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AssistColors.green50),
            child: Icon(Icons.check_rounded, size: context.iconSize(56), color: AssistColors.green700),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          liveRegion: true,
          child: const Text('已記下來了', textAlign: TextAlign.center, style: AssistText.largeTitle),
        ),
        const SizedBox(height: 6),
        Text('您要幫$relation「$who」辦理「$service」', textAlign: TextAlign.center, style: AssistText.body),
        const SizedBox(height: 22),
        AssistCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('接下來這樣做', style: AssistText.headline),
              const SizedBox(height: 12),
              _StepRow(
                n: 1,
                text: remote
                    ? '請 $who 打開台北通首頁的「請人陪我辦」，把畫面上的 6 位數號碼念給您聽。'
                    : '請 $who 打開台北通首頁的「請人陪我辦」，畫面會出現 QR Code。',
              ),
              _StepRow(n: 2, text: remote ? '按下面「開始陪辦」，輸入號碼。' : '按首頁右下角「掃描」掃這個 QR Code，或按下面「開始陪辦」輸入號碼。'),
              _StepRow(n: 3, text: '$who 手機上按「好，請他幫我」，就可以一步一步陪他辦。', last: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const AssistNotice(
          icon: Icons.favorite_rounded,
          color: AssistColors.green700,
          background: AssistColors.green50,
          text: '辦完後，對方可以把您加為「信任的人」，下次就不用配對碼，直接從「開始陪辦」選對方就好。',
        ),
      ],
      actions: [
        AssistButton(
          '開始陪辦',
          icon: Icons.arrow_forward_rounded,
          onPressed: () async {
            Get.back();
            await AssistHelperView.open();
          },
        ),
        AssistButton('回到首頁', style: AssistButtonStyle.secondary, onPressed: Get.back),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(header: true, child: Text(text, style: AssistText.title.copyWith(fontSize: 22))),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in options)
        Semantics(
          button: true,
          selected: value == o,
          child: Material(
            color: value == o ? TPColors.primary50 : TPColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
              side: BorderSide(color: value == o ? TPColors.primary500 : TPColors.grayscale200, width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(o);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Text(
                  o,
                  style: AssistText.callout.copyWith(
                    color: value == o ? TPColors.primary700 : TPColors.grayscale700,
                    fontWeight: value == o ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: Material(
      color: selected ? TPColors.primary50 : TPColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? TPColors.primary500 : TPColors.white, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? TPColors.primary500 : TPColors.grayscale400,
                size: context.iconSize(26),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AssistText.body.copyWith(fontWeight: selected ? FontWeight.w600 : null))),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.text, this.last = false});
  final int n;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.primary500),
          child: Text('$n', style: AssistText.callout.copyWith(color: TPColors.white, fontWeight: FontWeight.w700, height: 1.1)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AssistText.body)),
      ],
    ),
  );
}
