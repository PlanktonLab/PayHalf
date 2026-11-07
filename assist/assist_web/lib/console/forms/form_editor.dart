import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../shared/console_kit.dart';
import '../web_utils.dart';
import 'form_preview.dart';
import 'form_store.dart';
import 'forms_home.dart' show statusTone, deleteWarning;
import 'poster_dialog.dart';

/// 單一表單的編輯器：問題／回覆／設定。
class FormEditor extends StatefulWidget {
  const FormEditor({super.key, required this.store, required this.formId, required this.onBack, this.initialTab = 0});
  final FormStore store;
  final String formId;
  final int initialTab;
  final VoidCallback onBack;

  @override
  State<FormEditor> createState() => _FormEditorState();
}

class _FormEditorState extends State<FormEditor> {
  late int tab = widget.initialTab;
  String? sel;
  bool listView = false;
  int? focusOpt;

  FormStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    // 新建的空白表單：直接選好第一題，可以馬上打字
    final f = store.byId(widget.formId);
    if (f != null && f.fields.length == 1 && f.fields.first.label.isEmpty) sel = f.fields.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final f = store.byId(widget.formId);
    if (f == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onBack());
      return const SizedBox();
    }
    if (sel != null && f.fields.every((x) => x.id != sel)) sel = null;
    final n = f.responses;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () => store.undo(f),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () => store.undo(f),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () => store.redo(f),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () => store.redo(f),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 1080;
            final pad = box.maxWidth < 640 ? 16.0 : 32.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 22, pad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(f, wide),
                      const SizedBox(height: 14),
                      CTabs(
                        index: tab,
                        onChanged: (i) => setState(() => tab = i),
                        tabs: [('問題', '${f.fields.length}'), ('回覆', '$n'), ('設定', null)],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (tab) {
                    1 => _ResponsesTab(store: store, f: f, pad: pad),
                    2 => _SettingsTab(store: store, f: f, pad: pad),
                    _ => _questions(f, wide, pad),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────────── 頁首

  Widget _header(FForm f, bool wide) {
    final saved = hm(DateTime.fromMillisecondsSinceEpoch(f.updated));
    final publish = switch (f.status) {
      FStatus.draft => CButton.primary('發布', icon: Icons.send_rounded, onPressed: () => _publishDialog(f)),
      FStatus.open => CButton('已發布', icon: Icons.link_rounded, onPressed: () => _publishDialog(f)),
      FStatus.closed => CButton.primary('重新開放', icon: Icons.send_rounded, onPressed: () => _publishDialog(f)),
    };
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CIconButton(icon: Icons.arrow_back_rounded, tooltip: '回到我的表單', bordered: true, onPressed: widget.onBack),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: ValueKey('title-${f.id}-${store.revision}'),
                      initialValue: f.title,
                      style: CText.pageTitle.copyWith(fontSize: 22),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        hintText: '未命名表單',
                        hintStyle: TextStyle(color: C.ink4, fontSize: 22, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.accent, width: 1.6)),
                        contentPadding: EdgeInsets.only(bottom: 2),
                      ),
                      onChanged: (v) => store.edit(f, () => f.title = v, immediate: false),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CStatus(f.status.label, tone: statusTone(f.status), size: 13),
                        _saveState(f, saved),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CIconButton(
              icon: Icons.undo_rounded,
              tooltip: '復原（⌘Z）',
              onPressed: store.canUndo(f) ? () => store.undo(f) : null,
            ),
            CIconButton(
              icon: Icons.redo_rounded,
              tooltip: '重做（⇧⌘Z）',
              onPressed: store.canRedo(f) ? () => store.redo(f) : null,
            ),
            const SizedBox(width: 8),
            if (!wide || tab != 0) ...[
              CButton('預覽', icon: Icons.visibility_outlined, onPressed: () => _previewDialog(f)),
              const SizedBox(width: 8),
            ],
            if (f.published) ...[
              CButton(
                'QR Code 海報',
                icon: Icons.qr_code_2_rounded,
                onPressed: () => showPosterDialog(context, store, f),
              ),
              const SizedBox(width: 8),
            ],
            publish,
          ],
        ),
      ],
    );
  }

  /// 自動儲存的狀態：儲存中／已儲存／沒存到（可重試）
  Widget _saveState(FForm f, String saved) {
    final err = store.saveErrors[f.id];
    if (err != null && !store.hasPending(f)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 15, color: C.danger),
          const SizedBox(width: 4),
          Text('還沒存到伺服器：$err', style: CText.small.copyWith(color: C.danger)),
          const SizedBox(width: 6),
          CButton('重試', kind: CButtonKind.ghost, onPressed: () => store.retrySave(f)),
        ],
      );
    }
    final busy = store.hasPending(f);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(busy ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 15, color: C.ink4),
        const SizedBox(width: 4),
        Text(busy ? '儲存中…' : '已自動儲存 $saved', style: CText.small),
      ],
    );
  }

  // ───────────────────────────── 問題

  Widget _questions(FForm f, bool wide, double pad) {
    void addField(FField x) {
      final i = f.fields.indexWhere((a) => a.id == sel);
      store.edit(f, () => f.fields.insert(i >= 0 ? i + 1 : f.fields.length, x));
      setState(() => sel = x.id);
    }

    final editor = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 20, wide ? 12 : pad, 12),
          sliver: SliverToBoxAdapter(
            child: CPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CField(
                    key: ValueKey('desc-${f.id}-${store.revision}'),
                    label: '表單說明',
                    initialValue: f.desc,
                    hint: '用一兩句白話告訴民眾這是做什麼的',
                    help: '會顯示在第一題上方。',
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (v) => store.edit(f, () => f.desc = v, immediate: false),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, wide ? 12 : pad, 0),
          sliver: SliverReorderableList(
            itemCount: f.fields.length,
            onReorderItem: (a, b) => store.edit(f, () => f.fields.insert(b, f.fields.removeAt(a))),
            proxyDecorator: (child, _, _) => Material(color: Colors.transparent, elevation: 0, child: child),
            itemBuilder: (context, i) {
              final x = f.fields[i];
              return Padding(
                key: ValueKey(x.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _QCard(
                  store: store,
                  f: f,
                  x: x,
                  index: i,
                  selected: sel == x.id,
                  focusOpt: sel == x.id ? focusOpt : null,
                  onSelect: () => setState(() {
                    sel = x.id;
                    focusOpt = null;
                  }),
                  onFocusOpt: (j) => setState(() => focusOpt = j),
                  onDeleted: (removed, at) {
                    setState(() => sel = f.fields.isEmpty ? null : f.fields[at.clamp(0, f.fields.length - 1)].id);
                    cToast(
                      context,
                      '已刪除這一題',
                      action: '復原',
                      onAction: () {
                        store.edit(f, () => f.fields.insert(at.clamp(0, f.fields.length), removed));
                        setState(() => sel = removed.id);
                      },
                    );
                  },
                  onDuplicated: (c) => setState(() => sel = c.id),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 4, wide ? 12 : pad, 48),
          sliver: SliverToBoxAdapter(
            child: f.fields.isEmpty
                ? CPanel(
                    child: CEmpty(
                      icon: Icons.edit_note_rounded,
                      title: '還沒有題目',
                      body: '新增第一題，或直接加入常用個人資料。',
                      action: _addBar(f, addField, center: true),
                    ),
                  )
                : _addBar(f, addField),
          ),
        ),
      ],
    );

    if (!wide) return editor;
    final warn = warnCount(f);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: editor),
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12, 20, pad, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CPanel(
                  child: PhonePreview(
                    key: ValueKey('pv-${f.id}'),
                    store: store,
                    form: f,
                    follow: sel == null ? null : f.fields.indexWhere((x) => x.id == sel),
                  ),
                ),
                const SizedBox(height: 12),
                CPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CPanelHeader(title: '長輩好懂檢查', icon: Icons.spellcheck_rounded),
                      const SizedBox(height: 10),
                      if (f.fields.isEmpty)
                        const Text('加入題目後會自動檢查。', style: CText.small)
                      else if (warn == 0)
                        const CStatus('所有題目長輩都看得懂', tone: CTone.ok)
                      else ...[
                        CStatus('$warn 題可以寫得更好懂', tone: CTone.warn),
                        const SizedBox(height: 8),
                        for (final x in f.fields.where((x) => readability(x).isNotEmpty))
                          CBarRow(
                            label: '第 ${f.fields.indexOf(x) + 1} 題　${x.label.isEmpty ? '（尚未輸入）' : x.label}',
                            value: '${readability(x).length} 項',
                            fraction: 0,
                            onTap: () => setState(() => sel = x.id),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _addBar(FForm f, void Function(FField) add, {bool center = false}) {
    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CButton.primary(
          '新增題目',
          icon: Icons.add_rounded,
          onPressed: () => add(FField(type: 'radio')),
        ),
        CMenu(
          items: [
            for (final q in quickFields)
              CMenuItem(
                q.$5,
                icon: q.$4,
                onTap: () => add(FField(type: q.$1, label: q.$2, hint: q.$3)),
              ),
          ],
          builder: (context, toggle) => CButton(
            '加入常用個資',
            icon: Icons.person_add_alt_outlined,
            trailingIcon: Icons.expand_more_rounded,
            onPressed: toggle,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────── 對話框

  void _previewDialog(FForm f) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListenableBuilder(
                  listenable: store,
                  builder: (_, _) => PhonePreview(store: store, form: f),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: CButton('關閉', onPressed: () => Navigator.pop(ctx)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 表單的固定網址（就是 QR Code 的內容），向後端問
  Widget _linkBox(BuildContext ctx, FForm f) => FutureBuilder<String>(
    future: store.urlOf(f),
    builder: (context, snap) => Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: C.inset,
        borderRadius: BorderRadius.circular(C.rControl),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: snap.hasError
                ? const Text('暫時拿不到網址，請稍後再試', style: CText.small)
                : SelectableText(snap.data ?? '讀取中…', style: CText.mono.copyWith(color: C.ink2)),
          ),
          CButton(
            '複製連結',
            icon: Icons.copy_rounded,
            onPressed: snap.data == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: snap.data!));
                    cToast(ctx, '已複製連結');
                  },
          ),
        ],
      ),
    ),
  );

  Widget _posterButton(BuildContext ctx, FForm f) => CButton(
    'QR Code 海報',
    icon: Icons.qr_code_2_rounded,
    onPressed: () {
      Navigator.pop(ctx);
      showPosterDialog(context, store, f);
    },
  );

  Future<void> _publishDialog(FForm f) async {
    if (f.status == FStatus.open) {
      return showDialog(
        context: context,
        builder: (ctx) => CDialog(
          title: '表單收件中',
          subtitle: '民眾用台北通掃 QR Code，或打開下面的連結就能填寫。',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _linkBox(ctx, f),
              const SizedBox(height: 8),
              const Text('這個網址固定不變，修改題目後不用重新分享或重印海報。', style: CText.small),
            ],
          ),
          actions: [
            _posterButton(ctx, f),
            CButton(
              '停止收件',
              icon: Icons.lock_outline_rounded,
              kind: CButtonKind.danger,
              onPressed: () {
                store.edit(f, () => f.status = FStatus.closed);
                Navigator.pop(ctx);
                cToast(context, '已停止收件');
              },
            ),
            CButton.primary('完成', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
    }
    if (f.status == FStatus.closed) {
      final ok = await cConfirm(context, title: '重新開放填寫？', body: '民眾又可以填寫這份表單了。', confirm: '重新開放', cancel: '先不要');
      if (ok) {
        store.edit(f, () => f.status = FStatus.open);
        if (mounted) cToast(context, '已重新開放');
      }
      return;
    }
    final issues = [
      if (f.title.trim().isEmpty) '還沒有表單名稱',
      if (f.fields.isEmpty) '還沒有任何題目',
      if (f.fields.any((x) => x.label.trim().isEmpty)) '有題目還沒輸入問題',
      if (f.fields.any((x) => x.hasOptions && x.options.any((o) => o.trim().isEmpty))) '有選項是空白的',
    ];
    final w = warnCount(f);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => CDialog(
        title: '發布這份表單',
        subtitle: '發布後，民眾就能在台北通找到並填寫。',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.displayTitle, style: CText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    '${f.fields.length} 題　·　${f.deadline.isEmpty ? '不設截止日' : '截止 ${f.deadline}'}　·　${f.allowAssist ? '開放陪辦' : '僅限本人填寫'}',
                    style: CText.small,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (issues.isNotEmpty)
              for (final t in issues) ...[
                CNotice(text: t, tone: CTone.danger, icon: Icons.error_outline_rounded),
                const SizedBox(height: 6),
              ]
            else if (w > 0)
              CNotice(text: '有 $w 題可以寫得更好懂。可以先發布，之後再修改。', tone: CTone.warn, icon: Icons.lightbulb_outline_rounded)
            else
              const CStatus('所有題目長輩都看得懂', tone: CTone.ok),
          ],
        ),
        actions: [
          CButton('取消', onPressed: () => Navigator.pop(ctx, false)),
          CButton.primary(
            '發布',
            icon: Icons.send_rounded,
            onPressed: issues.isEmpty ? () => Navigator.pop(ctx, true) : null,
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    store.edit(f, () => f.status = FStatus.open);
    await store.flush(f);
    if (!mounted) return;
    final err = store.saveErrors[f.id];
    if (err != null) {
      cToast(context, '發布沒有成功：$err');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => CDialog(
        title: '發布成功',
        subtitle: '民眾現在可以用台北通填寫「${f.displayTitle}」。印一張 QR Code 海報貼在現場，掃了就能填。',
        body: _linkBox(ctx, f),
        actions: [
          _posterButton(ctx, f),
          CButton(
            '回到我的表單',
            onPressed: () {
              Navigator.pop(ctx);
              widget.onBack();
            },
          ),
          CButton.primary('完成', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 題目卡

class _QCard extends StatelessWidget {
  const _QCard({
    required this.store,
    required this.f,
    required this.x,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onDeleted,
    required this.onDuplicated,
    required this.onFocusOpt,
    this.focusOpt,
  });
  final FormStore store;
  final FForm f;
  final FField x;
  final int index;
  final bool selected;
  final int? focusOpt;
  final VoidCallback onSelect;
  final void Function(FField removed, int at) onDeleted;
  final ValueChanged<FField> onDuplicated;
  final ValueChanged<int> onFocusOpt;

  @override
  Widget build(BuildContext context) {
    final advice = readability(x);
    final grip = ReorderableDragStartListener(
      index: index,
      child: const MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: '按住拖曳，調整順序',
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Icon(Icons.drag_indicator_rounded, size: 20, color: C.ink4),
          ),
        ),
      ),
    );
    final number = SizedBox(
      width: 26,
      child: Text(
        '${index + 1}',
        style: CText.small.copyWith(fontFeatures: CText.tabular, fontWeight: FontWeight.w600),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.rPanel),
        border: Border.all(color: selected ? C.accent : C.border, width: selected ? 1.6 : 1),
        boxShadow: selected ? C.popShadow : C.panelShadow,
      ),
      child: selected ? _editing(context, grip, number, advice) : _collapsed(grip, number, advice),
    );
  }

  Widget _collapsed(Widget grip, Widget number, List<Advice> advice) {
    return Semantics(
      button: true,
      label: '編輯第 ${index + 1} 題：${x.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(C.rPanel),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              grip,
              Padding(padding: const EdgeInsets.only(top: 9), child: number),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: x.label.isEmpty ? '（尚未輸入問題）' : x.label,
                          children: [
                            if (x.required)
                              const TextSpan(
                                text: ' *',
                                style: TextStyle(color: C.dangerInk),
                              ),
                          ],
                        ),
                        style: CText.bodyStrong.copyWith(color: x.label.isEmpty ? C.ink4 : C.ink),
                      ),
                      if (x.hint.isNotEmpty) Text(x.hint, style: CText.small),
                      const SizedBox(height: 10),
                      _mock(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CTag(qTypes[x.type]!.name, icon: qTypes[x.type]!.icon),
                    if (advice.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const CTag('可以更好懂', icon: Icons.lightbulb_outline_rounded, tone: CTone.warn),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 收合時的作答示意（灰色，表示不可填）
  Widget _mock() {
    Widget line(String t, {double w = 260, IconData? trail}) => Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(C.rControl)),
      child: Row(
        children: [
          Expanded(
            child: Text(t, style: CText.small.copyWith(color: C.ink4)),
          ),
          if (trail != null) Icon(trail, size: 16, color: C.ink4),
        ],
      ),
    );
    switch (x.type) {
      case 'radio':
      case 'checkbox':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final o in x.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      x.type == 'radio' ? Icons.radio_button_off_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: C.ink4,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(o, style: CText.secondary)),
                  ],
                ),
              ),
          ],
        );
      case 'select':
        return line('請選擇', trail: Icons.expand_more_rounded);
      case 'textarea':
        return line('詳細說明的回答', w: 420);
      case 'date':
        return line('年 / 月 / 日', w: 200, trail: Icons.calendar_today_outlined);
      case 'file':
        return line('選擇照片或檔案', w: 200, trail: Icons.attach_file_rounded);
      case 'consent':
        return Row(
          children: [
            const Icon(Icons.check_box_outline_blank_rounded, size: 18, color: C.ink4),
            const SizedBox(width: 8),
            Flexible(child: Text(x.label, style: CText.secondary)),
          ],
        );
      case 'idno':
        return line('A12●●●●789', w: 200);
      case 'phone':
        return line('0912-345-678', w: 200);
      case 'address':
        return line('臺北市…', w: 420);
      case 'number':
        return line('數字', w: 140);
      default:
        return line('短答文字');
    }
  }

  Widget _editing(BuildContext context, Widget grip, Widget number, List<Advice> advice) {
    final rev = store.revision;
    void edit(void Function() c, {bool now = true}) => store.edit(f, c, immediate: now);

    final typeMenu = CMenu(
      items: [
        for (final e in qTypes.entries)
          CMenuItem(
            e.value.name,
            icon: e.value.icon,
            selected: e.key == x.type,
            onTap: () => edit(() {
              x.type = e.key;
              if (x.hasOptions && x.options.isEmpty) x.options = ['選項 1'];
            }),
          ),
      ],
      builder: (context, toggle) => SizedBox(
        height: 44,
        child: CButton(
          qTypes[x.type]!.name,
          icon: qTypes[x.type]!.icon,
          trailingIcon: Icons.expand_more_rounded,
          onPressed: toggle,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              grip,
              Padding(padding: const EdgeInsets.only(top: 12), child: number),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        final labelField = CField(
                          key: ValueKey('label-${x.id}-$rev'),
                          initialValue: x.label,
                          hint: '問題（用一句白話寫，例如「你住在哪裡」）',
                          autofocus: x.label.isEmpty,
                          style: CText.bodyStrong.copyWith(fontSize: 16),
                          onChanged: (v) => edit(() => x.label = v, now: false),
                        );
                        if (box.maxWidth < 460) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [labelField, const SizedBox(height: 8), typeMenu],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: labelField),
                            const SizedBox(width: 10),
                            typeMenu,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    CField(
                      key: ValueKey('hint-${x.id}-$rev'),
                      initialValue: x.hint,
                      hint: '說明文字（選填，例如：請填身分證上的名字）',
                      style: CText.secondary,
                      onChanged: (v) => edit(() => x.hint = v, now: false),
                    ),
                    if (x.hasOptions) ...[const SizedBox(height: 14), _options(rev, edit)],
                    const SizedBox(height: 14),
                    if (advice.isEmpty)
                      const CStatus('這題長輩看得懂', tone: CTone.ok, size: 13)
                    else
                      for (final a in advice) ...[
                        CNotice(
                          icon: Icons.lightbulb_outline_rounded,
                          tone: CTone.warn,
                          text: a.msg,
                          action: a.to == null
                              ? null
                              : CButton(
                                  '改成「${a.to}」',
                                  onPressed: () {
                                    edit(() => x.label = x.label.replaceAll(a.from!, a.to!));
                                    cToast(context, '已改好');
                                  },
                                ),
                        ),
                        const SizedBox(height: 6),
                      ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 36),
              CIconButton(
                icon: Icons.arrow_upward_rounded,
                tooltip: '上移',
                onPressed: index == 0 ? null : () => edit(() => f.fields.insert(index - 1, f.fields.removeAt(index))),
              ),
              CIconButton(
                icon: Icons.arrow_downward_rounded,
                tooltip: '下移',
                onPressed: index == f.fields.length - 1
                    ? null
                    : () => edit(() => f.fields.insert(index + 1, f.fields.removeAt(index))),
              ),
              CIconButton(
                icon: Icons.copy_rounded,
                tooltip: '複製這題',
                onPressed: () {
                  final c = x.clone();
                  edit(() => f.fields.insert(index + 1, c));
                  onDuplicated(c);
                  cToast(context, '已複製這一題');
                },
              ),
              CIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: '刪除這題',
                color: C.dangerInk,
                onPressed: () {
                  edit(() => f.fields.removeAt(index));
                  onDeleted(x, index);
                },
              ),
              const Spacer(),
              const Text('必填', style: CText.label),
              const SizedBox(width: 8),
              Semantics(
                label: '必填',
                child: Switch(value: x.required, onChanged: (v) => edit(() => x.required = v)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _options(int rev, void Function(void Function(), {bool now}) edit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var j = 0; j < x.options.length; j++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: x.type == 'select'
                      ? Text('${j + 1}.', style: CText.small)
                      : Icon(
                          x.type == 'radio' ? Icons.radio_button_off_rounded : Icons.check_box_outline_blank_rounded,
                          size: 18,
                          color: C.ink4,
                        ),
                ),
                Expanded(
                  child: CField(
                    key: ValueKey('opt-${x.id}-$j-$rev'),
                    initialValue: x.options[j],
                    autofocus: focusOpt == j,
                    hint: '選項 ${j + 1}',
                    onChanged: (v) => edit(() => x.options[j] = v, now: false),
                    onSubmitted: (_) {
                      edit(() => x.options.insert(j + 1, '選項 ${x.options.length + 1}'));
                      onFocusOpt(j + 1);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                CIconButton(
                  icon: Icons.close_rounded,
                  tooltip: '刪除選項 ${j + 1}',
                  onPressed: x.options.length <= 1 ? null : () => edit(() => x.options.removeAt(j)),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: CButton(
            '新增選項',
            icon: Icons.add_rounded,
            kind: CButtonKind.ghost,
            onPressed: () {
              edit(() => x.options.add('選項 ${x.options.length + 1}'));
              onFocusOpt(x.options.length - 1);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 28, top: 2),
          child: Text('在選項裡按 Enter 可以直接新增下一個。', style: CText.caption),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════ 回覆

class _ResponsesTab extends StatefulWidget {
  const _ResponsesTab({required this.store, required this.f, required this.pad});
  final FormStore store;
  final FForm f;
  final double pad;
  @override
  State<_ResponsesTab> createState() => _ResponsesTabState();
}

enum _RView { summary, single, table }

class _ResponsesTabState extends State<_ResponsesTab> {
  _RView view = _RView.summary;
  bool showSamples = true;

  /// 個別回覆：目前看的是哪一份（用 id 記，新回覆進來時不會跳掉）
  String? currentId;

  /// 個別回覆裡點開查看的遮蔽欄位
  final Set<String> revealed = {};

  FormStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.loadRows(widget.f);
  }

  void csv(FForm f, List<Map<String, dynamic>> rs) {
    String q(Object? s) => '"${(s ?? '').toString().replaceAll('"', '""')}"';
    final lines = [
      ['收件編號', '送出時間', '填寫方式', '陪辦人員', '示意資料', ...f.fields.map((x) => x.label)].map(q).join(','),
      for (final r in rs)
        [
          r.receipt,
          ymdhm(r.at),
          r.by,
          r.helperName ?? '',
          r.isSample ? '是' : '',
          ...f.fields.map((x) => maskAnswer(x, r[x.id])),
        ].map(q).join(','),
    ];
    downloadText('${f.displayTitle}_回覆資料.csv', lines.join('\r\n'));
    cToast(context, '已下載');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final all = store.rows[f.id];
    final err = store.rowsError[f.id];
    final rs = (all ?? const <Map<String, dynamic>>[]).where((r) => showSamples || !r.isSample).toList();
    final hasSamples = all?.any((r) => r.isSample) ?? false;

    final Widget body;
    if (all == null && err != null) {
      body = CPanel(
        child: CEmpty(
          icon: Icons.cloud_off_rounded,
          title: '回覆讀不出來',
          body: err,
          action: CButton('重試', icon: Icons.refresh_rounded, onPressed: () => store.loadRows(f, force: true)),
        ),
      );
    } else if (all == null) {
      body = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (rs.isEmpty) {
      body = CPanel(
        child: CEmpty(
          icon: Icons.inbox_outlined,
          title: '還沒有人填寫',
          body: f.status == FStatus.draft
              ? '表單發布後，民眾的回覆會即時出現在這裡。'
              : hasSamples
              ? '還沒有民眾送出真的回覆。打開「顯示示意資料」可以看範例。'
              : '等待民眾填寫中，有人送出會馬上出現在這裡。',
        ),
      );
    } else {
      body = switch (view) {
        _RView.summary => _summary(f, rs),
        _RView.single => _single(f, rs),
        _RView.table => _table(f, rs),
      };
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(widget.pad, 20, widget.pad, 48),
      children: [
        CStatStrip(
          items: [
            CStat(
              icon: Icons.inbox_outlined,
              label: '全部回覆',
              value: '${f.responses}',
              note: f.realResponses != f.responses ? '民眾送出 ${f.realResponses} 份' : null,
            ),
            CStat(icon: Icons.today_outlined, label: '今天', value: '${f.today}'),
            CStat(
              icon: Icons.handshake_outlined,
              label: '陪辦填寫',
              value: '${f.assisted}',
              note: '本人 ${f.responses - f.assisted}',
            ),
            CStat(icon: Icons.support_agent_rounded, label: '正在等線上幫忙', value: '${store.waitingFor(f)}'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CSegmented<_RView>(
              value: view,
              onChanged: (v) => setState(() => view = v),
              options: const [
                (_RView.summary, '摘要', Icons.bar_chart_rounded),
                (_RView.single, '個別回覆', Icons.article_outlined),
                (_RView.table, '全部回覆', Icons.table_rows_outlined),
              ],
            ),
            if (hasSamples)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('顯示示意資料', style: CText.label),
                  const SizedBox(width: 6),
                  Switch(value: showSamples, onChanged: (v) => setState(() => showSamples = v)),
                ],
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('接受回覆', style: CText.label),
                const SizedBox(width: 6),
                Switch(
                  value: f.status == FStatus.open,
                  onChanged: f.status == FStatus.draft
                      ? null
                      : (v) {
                          store.edit(f, () => f.status = v ? FStatus.open : FStatus.closed);
                          cToast(context, v ? '已開始接受回覆' : '已停止接受回覆');
                        },
                ),
              ],
            ),
            CButton('下載成 Excel 檔', icon: Icons.download_rounded, onPressed: rs.isEmpty ? null : () => csv(f, rs)),
            CIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '重新整理',
              onPressed: store.rowsLoading.contains(f.id) ? null : () => store.loadRows(f, force: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasSamples
              ? '民眾送出後會即時出現在這裡。標著「示意」的是展示用的範例，不是真的民眾資料，可以關掉「顯示示意資料」。身分證字號與電話只顯示一部分。'
              : '民眾送出後會即時出現在這裡。身分證字號與電話只顯示一部分。',
          style: CText.small,
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }

  Widget _summary(FForm f, List<Map<String, dynamic>> rs) {
    final by = <String, int>{};
    for (final r in rs) {
      by[r.by] = (by[r.by] ?? 0) + 1;
    }
    final byMax = by.values.fold(1, (a, b) => a > b ? a : b);
    final panels = <Widget>[
      CPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CPanelHeader(title: '誰填的', subtitle: '${rs.length} 份回覆，${by.length} 種方式'),
            const SizedBox(height: 12),
            for (final e in by.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              CBarRow(
                label: e.key,
                value: '${e.value}',
                fraction: e.value / byMax,
                icon: e.key.startsWith('本人') ? Icons.person_outline_rounded : Icons.handshake_outlined,
              ),
          ],
        ),
      ),
      for (final x in f.fields) _fieldSummary(x, rs),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final two = box.maxWidth > 820;
        final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final p in panels) SizedBox(width: w, child: p)],
        );
      },
    );
  }

  Widget _fieldSummary(FField x, List<Map<String, dynamic>> rs) {
    final vals = rs.map((r) => r[x.id]).where((v) => v != null && v.toString().isNotEmpty).toList();
    Widget body;
    if (x.hasOptions) {
      final c = {for (final o in x.options) o: 0};
      for (final v in vals) {
        for (final p in v.toString().split('、')) {
          if (c.containsKey(p)) c[p] = c[p]! + 1;
        }
      }
      final m = c.values.fold(1, (a, b) => a > b ? a : b);
      body = Column(
        children: [
          for (final e in c.entries)
            CBarRow(
              label: e.key,
              value: '${e.value}（${(e.value / (vals.isEmpty ? 1 : vals.length) * 100).round()}%）',
              fraction: e.value / m,
            ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final v in vals.take(4))
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(C.rControl)),
              child: Text(maskAnswer(x, v), overflow: TextOverflow.ellipsis, style: CText.secondary),
            ),
          if (vals.length > 4) Text('還有 ${vals.length - 4} 筆，請到「全部回覆」查看', style: CText.small),
        ],
      );
    }
    return CPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CPanelHeader(
            title: x.label.isEmpty ? '（未命名題目）' : x.label,
            subtitle: '${vals.length} 個回覆',
            icon: qTypes[x.type]?.icon,
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  // ───────────────────────────── 個別回覆

  Widget _single(FForm f, List<Map<String, dynamic>> rs) {
    var i = rs.indexWhere((r) => r.rowId == currentId);
    if (i < 0) i = 0;
    final r = rs[i];
    void go(int n) => setState(() {
      currentId = rs[n].rowId;
      revealed.clear();
    });

    Widget meta(String k, Widget v) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(k, style: CText.caption)),
          Expanded(child: v),
        ],
      ),
    );

    final how = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CTag(
          r.viaAssist ? '陪辦' : '本人填寫',
          icon: r.viaAssist ? Icons.handshake_outlined : Icons.person_outline_rounded,
          tone: r.viaAssist ? CTone.accent : CTone.neutral,
        ),
        Text(r.viaAssist ? '${r.by}${r.helperName == null ? '' : '（${r.helperName}）'}' : r.by, style: CText.secondary),
      ],
    );

    return CPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: C.canvas,
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(
              children: [
                CIconButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: '較新的一份',
                  onPressed: i > 0 ? () => go(i - 1) : null,
                ),
                Text('第 ${i + 1} 份，共 ${rs.length} 份', style: CText.bodyStrong.copyWith(fontFeatures: CText.tabular)),
                CIconButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: '較舊的一份',
                  onPressed: i < rs.length - 1 ? () => go(i + 1) : null,
                ),
                const Spacer(),
                if (r.isSample) const CTag('示意', tone: CTone.warn),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                meta('收件編號', SelectableText(r.receipt.isEmpty ? '—' : r.receipt, style: CText.mono)),
                meta('送出時間', Text(ymdhm(r.at), style: CText.secondary.copyWith(fontFeatures: CText.tabular))),
                meta('填寫方式', how),
              ],
            ),
          ),
          const Divider(),
          for (var k = 0; k < f.fields.length; k++) ...[
            if (k > 0) const Divider(indent: 20, endIndent: 20),
            _answer(f.fields[k], k, r),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _answer(FField x, int k, Map<String, dynamic> r) {
    final raw = r[x.id]?.toString() ?? '';
    final key = '${r.rowId}:${x.id}';
    final masked = isMasked(x) && raw.isNotEmpty;
    final show = !masked || revealed.contains(key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${k + 1}. ${x.label.isEmpty ? '（未命名題目）' : x.label}', style: CText.small),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: raw.isEmpty
                    ? Text('（沒有填）', style: CText.secondary.copyWith(color: C.ink4))
                    : SelectableText(show ? raw : maskAnswer(x, raw), style: CText.body),
              ),
              if (masked) ...[
                const SizedBox(width: 8),
                CButton(
                  show ? '遮起來' : '查看完整',
                  icon: show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  kind: CButtonKind.ghost,
                  onPressed: () => setState(() => show ? revealed.remove(key) : revealed.add(key)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── 全部回覆（表格）

  Widget _table(FForm f, List<Map<String, dynamic>> rs) {
    const w = 170.0;
    Widget cell(String t, {bool head = false}) => SizedBox(
      width: w,
      child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: head ? CText.caption : CText.secondary),
    );
    return CPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: C.canvas,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    cell('送出時間', head: true),
                    cell('收件編號', head: true),
                    cell('誰填的', head: true),
                    for (final x in f.fields) cell(x.label, head: true),
                  ],
                ),
              ),
              for (final r in rs) ...[
                Container(height: 1, width: w * (f.fields.length + 3) + 40, color: C.divider),
                InkWell(
                  onTap: () => setState(() {
                    currentId = r.rowId;
                    revealed.clear();
                    view = _RView.single;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        cell(ymdhm(r.at)),
                        cell(r.receipt),
                        SizedBox(
                          width: w,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(r.by, maxLines: 2, overflow: TextOverflow.ellipsis, style: CText.secondary),
                              ),
                              if (r.isSample) ...[
                                const SizedBox(width: 6),
                                const CTag('示意', tone: CTone.warn, size: 11),
                              ],
                            ],
                          ),
                        ),
                        for (final x in f.fields) cell(maskAnswer(x, r[x.id])),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 設定

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.store, required this.f, required this.pad});
  final FormStore store;
  final FForm f;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final rev = store.revision;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 20, pad, 48),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CPanelHeader(title: '一般', subtitle: '這些資訊會顯示給民眾看'),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          CField(
                            key: ValueKey('dept-$rev'),
                            width: 320,
                            label: '哪個單位辦的',
                            initialValue: f.dept,
                            onChanged: (v) => store.edit(f, () => f.dept = v, immediate: false),
                          ),
                          CField(
                            key: ValueKey('dl-$rev'),
                            width: 220,
                            label: '截止日期',
                            optional: true,
                            initialValue: f.deadline,
                            hint: '不設截止日',
                            readOnly: true,
                            prefixIcon: Icons.calendar_today_outlined,
                            suffix: f.deadline.isEmpty
                                ? null
                                : CIconButton(
                                    icon: Icons.close_rounded,
                                    tooltip: '清除截止日期',
                                    size: 32,
                                    onPressed: () => store.edit(f, () => f.deadline = ''),
                                  ),
                            onTap: () async {
                              final now = DateTime.now();
                              final d = await showDatePicker(
                                context: context,
                                firstDate: now.subtract(const Duration(days: 1)),
                                lastDate: DateTime(now.year + 3),
                                initialDate: DateTime.tryParse(f.deadline) ?? now.add(const Duration(days: 30)),
                                helpText: '選擇截止日期',
                              );
                              if (d != null) {
                                store.edit(f, () => f.deadline = '${d.year}-${two(d.month)}-${two(d.day)}');
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CPanel(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CPanelHeader(title: '填寫方式', subtitle: '決定誰可以填、怎麼填'),
                      const SizedBox(height: 4),
                      CSwitchRow(
                        title: '開放「陪辦」',
                        desc: '家人、里長、看護或 1999 客服可以陪長輩一起辦。長輩的個資由長輩在自己的台北通上逐項同意，協助者看不到內容；最後由長輩本人按送出。',
                        value: f.allowAssist,
                        onChanged: (v) => store.edit(f, () => f.allowAssist = v),
                      ),
                      const Divider(),
                      CSwitchRow(
                        title: '每人只能填一次',
                        desc: '同一位民眾送出後，就不能再填第二次。',
                        value: f.once,
                        onChanged: (v) => store.edit(f, () => f.once = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CPanelHeader(title: '送出之後', subtitle: '民眾按下「確認送出」後會看到這段話'),
                      const SizedBox(height: 16),
                      CField(
                        key: ValueKey('done-$rev'),
                        label: '確認訊息',
                        initialValue: f.doneMsg,
                        maxLines: 3,
                        minLines: 2,
                        onChanged: (v) => store.edit(f, () => f.doneMsg = v, immediate: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CPanel(
                  child: Row(
                    children: [
                      const Expanded(
                        child: CPanelHeader(title: '刪除表單', subtitle: '刪除後，表單和所有回覆都無法復原。'),
                      ),
                      CButton(
                        '刪除這份表單',
                        icon: Icons.delete_outline_rounded,
                        kind: CButtonKind.danger,
                        onPressed: () async {
                          final ok = await cConfirm(
                            context,
                            title: '刪除這份表單？',
                            body: deleteWarning(f),
                            confirm: '刪除表單',
                            danger: true,
                          );
                          if (!ok) return;
                          try {
                            await store.delete(f);
                          } catch (e) {
                            if (context.mounted) {
                              cToast(context, '刪除失敗：${e is ApiException ? e.message : '連線中斷，請稍後再試'}');
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
