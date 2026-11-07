import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../shared/console_kit.dart';
import 'form_store.dart';
import 'poster_dialog.dart';

/// 「我的表單」：範本、篩選與表單清單。
class FormsHome extends StatefulWidget {
  const FormsHome({super.key, required this.store, required this.onOpen, required this.onHelp});
  final FormStore store;
  final void Function(String formId, int tab) onOpen;
  final VoidCallback onHelp;

  @override
  State<FormsHome> createState() => _FormsHomeState();
}

class _FormsHomeState extends State<FormsHome> {
  FStatus? filter;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (store.state != LoadState.ready) return _status(store);
    final all = store.forms;
    final list =
        all
            .where((f) => filter == null || f.status == filter)
            .where((f) => q.isEmpty || '${f.title}${f.dept}'.toLowerCase().contains(q.toLowerCase()))
            .toList()
          ..sort((a, b) => b.updated.compareTo(a.updated));
    int cnt(FStatus? s) => s == null ? all.length : all.where((f) => f.status == s).length;
    final responses = all.fold<int>(0, (n, f) => n + f.responses);
    final today = all.fold<int>(0, (n, f) => n + f.today);
    final assisted = all.fold<int>(0, (n, f) => n + f.assisted);
    final waiting = all.fold<int>(0, (n, f) => n + store.waitingFor(f));

    void create(String k) {
      final f = store.create(k);
      widget.onOpen(f.id, 0);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      children: [
        CPageHeader(
          title: '表單',
          subtitle: '建立民眾在台北通上填寫的表單，並決定是否開放陪辦。',
          actions: [
            SizedBox(
              width: 240,
              child: CField(
                hint: '搜尋表單',
                prefixIcon: Icons.search_rounded,
                onChanged: (v) => setState(() => q = v.trim()),
              ),
            ),
            CButton.primary('新表單', icon: Icons.add_rounded, onPressed: () => create('blank')),
          ],
        ),
        const SizedBox(height: 24),
        CStatStrip(
          items: [
            CStat(icon: Icons.description_outlined, label: '全部表單', value: '${all.length}'),
            CStat(icon: Icons.inbox_outlined, label: '收件中', value: '${cnt(FStatus.open)}'),
            CStat(
              icon: Icons.groups_outlined,
              label: '累計回覆',
              value: '$responses',
              note: today > 0 ? '今天 +$today' : null,
            ),
            CStat(
              icon: Icons.handshake_outlined,
              label: '陪辦填寫',
              value: '$assisted',
              note: waiting > 0 ? '$waiting 位在等幫忙' : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!store.hideTip) ...[
          CNotice(
            icon: Icons.lightbulb_outline_rounded,
            title: '第一次使用？',
            text: '從下面的範本開始，改一改文字就能發布，不需要懂程式。系統會檢查題目是否好懂，幫你寫給長輩看得懂的版本。',
            action: Wrap(
              spacing: 8,
              children: [
                CButton('看使用說明', onPressed: widget.onHelp),
                CButton('不再顯示', kind: CButtonKind.ghost, onPressed: store.dismissTip),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        CPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CPanelHeader(title: '從範本開始', subtitle: '挑一個最接近的範本，之後都可以修改'),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final cols = box.maxWidth > 900 ? 4 : (box.maxWidth > 520 ? 2 : 1);
                  final w = (box.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final e in templates.entries)
                        SizedBox(
                          width: w,
                          child: _TemplateTile(t: e.value, onTap: () => create(e.key)),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CPanel(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: CPanelHeader(
                  title: '我的表單',
                  subtitle: '${list.length} 份${filter == null ? '' : '「${filter!.label}」'}',
                  trailing: CSegmented<FStatus?>(
                    value: filter,
                    onChanged: (v) => setState(() => filter = v),
                    options: [
                      (null, '全部 ${cnt(null)}', null),
                      (FStatus.open, '收件中 ${cnt(FStatus.open)}', null),
                      (FStatus.draft, '草稿 ${cnt(FStatus.draft)}', null),
                      (FStatus.closed, '已停止 ${cnt(FStatus.closed)}', null),
                    ],
                  ),
                ),
              ),
              const Divider(),
              if (list.isEmpty)
                CEmpty(
                  icon: Icons.description_outlined,
                  title: all.isEmpty ? '還沒有任何表單' : '找不到符合的表單',
                  body: '從上方的範本開始建立吧。',
                )
              else
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth > 760;
                    return Column(
                      children: [
                        if (wide)
                          Container(
                            color: C.canvas,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                            child: const Row(
                              children: [
                                Expanded(flex: 5, child: Text('名稱', style: CText.caption)),
                                Expanded(flex: 2, child: Text('狀態', style: CText.caption)),
                                Expanded(flex: 2, child: Text('題目／回覆', style: CText.caption)),
                                Expanded(flex: 2, child: Text('陪辦', style: CText.caption)),
                                Expanded(flex: 2, child: Text('最後編輯', style: CText.caption)),
                                SizedBox(width: 36),
                              ],
                            ),
                          ),
                        if (wide) const Divider(),
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(),
                          _FormRow(f: list[i], wide: wide, store: store, onOpen: widget.onOpen),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 讀取中、連不到後端、不是承辦人員
Widget _status(FormStore store) {
  final Widget body = switch (store.state) {
    LoadState.notStaff => const CEmpty(
      icon: Icons.lock_outline_rounded,
      title: '表單後台只開放給承辦人員',
      body: '目前登入的身分不能建立或查看表單。請從左下角「切換身分」，改用 1999 客服或里長登入。',
    ),
    LoadState.failed => CEmpty(
      icon: Icons.cloud_off_rounded,
      title: '表單讀不出來',
      body: store.loadError ?? '連不到後端，請稍後再試。',
      action: CButton('重試', icon: Icons.refresh_rounded, onPressed: store.load),
    ),
    _ => const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CircularProgressIndicator()),
    ),
  };
  return ListView(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
    children: [
      const CPageHeader(title: '表單', subtitle: '建立民眾在台北通上填寫的表單，並決定是否開放陪辦。'),
      const SizedBox(height: 24),
      CPanel(child: body),
    ],
  );
}

CTone statusTone(FStatus s) => switch (s) {
  FStatus.open => CTone.ok,
  FStatus.draft => CTone.neutral,
  FStatus.closed => CTone.warn,
};

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.t, required this.onTap});
  final FTemplate t;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '用「${t.name}」範本建立表單',
      excludeSemantics: true,
      child: Material(
        color: C.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: C.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: Icon(t.icon, size: 20, color: C.accentInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, overflow: TextOverflow.ellipsis, style: CText.bodyStrong.copyWith(fontSize: 14)),
                      Text(t.desc, style: CText.small),
                    ],
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

class _FormRow extends StatelessWidget {
  const _FormRow({required this.f, required this.wide, required this.store, required this.onOpen});
  final FForm f;
  final bool wide;
  final FormStore store;
  final void Function(String, int) onOpen;

  @override
  Widget build(BuildContext context) {
    final n = f.responses;
    final updated = ymdhm(DateTime.fromMillisecondsSinceEpoch(f.updated));
    final menu = CMenu(
      items: [
        CMenuItem('開啟編輯', icon: Icons.edit_outlined, onTap: () => onOpen(f.id, 0)),
        CMenuItem('看回覆', icon: Icons.inbox_outlined, onTap: () => onOpen(f.id, 1)),
        if (f.published)
          CMenuItem('QR Code 海報', icon: Icons.qr_code_2_rounded, onTap: () => showPosterDialog(context, store, f)),
        CMenuItem(
          '建立複本',
          icon: Icons.copy_rounded,
          onTap: () {
            store.duplicate(f);
            cToast(context, '已建立複本');
          },
        ),
        const CMenuItem.divider(),
        CMenuItem(
          '刪除',
          icon: Icons.delete_outline_rounded,
          danger: true,
          onTap: () async {
            final ok = await cConfirm(context, title: '刪除這份表單？', body: deleteWarning(f), confirm: '刪除表單', danger: true);
            if (!ok) return;
            try {
              await store.delete(f);
              if (context.mounted) cToast(context, '已刪除表單');
            } catch (e) {
              if (context.mounted) cToast(context, '刪除失敗：${e is ApiException ? e.message : '連線中斷，請稍後再試'}');
            }
          },
        ),
      ],
      builder: (context, toggle) => CIconButton(icon: Icons.more_horiz_rounded, tooltip: '更多動作', onPressed: toggle),
    );

    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(f.displayTitle, overflow: TextOverflow.ellipsis, style: CText.bodyStrong),
        Text(f.dept, overflow: TextOverflow.ellipsis, style: CText.small),
      ],
    );

    return Semantics(
      button: true,
      label: '開啟 ${f.displayTitle}，${f.status.label}',
      child: InkWell(
        onTap: () => onOpen(f.id, 0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 5, child: name),
                    Expanded(flex: 2, child: CStatus(f.status.label, tone: statusTone(f.status))),
                    Expanded(
                      flex: 2,
                      child: Text.rich(
                        TextSpan(
                          text: '${f.fields.length} 題 · $n 份',
                          children: [
                            if (f.today > 0)
                              TextSpan(
                                text: '  今天 +${f.today}',
                                style: CText.small.copyWith(color: C.accentInk),
                              ),
                          ],
                        ),
                        style: CText.secondary.copyWith(fontFeatures: CText.tabular),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: store.waitingFor(f) > 0
                            ? CTag('${store.waitingFor(f)} 位等幫忙', icon: Icons.support_agent_rounded, tone: CTone.warn)
                            : f.allowAssist
                            ? const CTag('開放', icon: Icons.handshake_outlined, tone: CTone.accent)
                            : const Text('僅本人', style: CText.small),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(updated, style: CText.small.copyWith(fontFeatures: CText.tabular)),
                    ),
                    menu,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              CStatus(f.status.label, tone: statusTone(f.status), size: 13),
                              Text('${f.fields.length} 題 · $n 份回覆', style: CText.small),
                              if (f.allowAssist) const CTag('開放陪辦', icon: Icons.handshake_outlined, tone: CTone.accent),
                            ],
                          ),
                        ],
                      ),
                    ),
                    menu,
                  ],
                ),
        ),
      ),
    );
  }
}

/// 刪除前的提醒：真實回覆要講清楚
String deleteWarning(FForm f) {
  final real = f.realResponses;
  final head = '「${f.displayTitle}」';
  if (real > 0) return '$head裡面有 $real 份民眾送出的回覆，會一起刪除，無法復原。${f.published ? '已經印出去的 QR Code 海報也會失效。' : ''}';
  if (f.published) return '$head刪除後無法復原，已經印出去的 QR Code 海報也會失效。';
  return '$head刪除後無法復原。';
}
