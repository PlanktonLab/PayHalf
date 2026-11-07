import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 歷程與授權管理：誰協助過我、我同意了什麼、送出了哪些申請。
class AssistRecordsView extends StatefulWidget {
  const AssistRecordsView({super.key});
  @override
  State<AssistRecordsView> createState() => _AssistRecordsViewState();
}

class _AssistRecordsViewState extends State<AssistRecordsView> {
  final service = Get.find<AssistService>();

  @override
  void initState() {
    super.initState();
    service.refreshRecords().catchError((_) {});
  }

  IconData _icon(String type) => switch (type) {
    'field.authorized' => Icons.lock_open_rounded,
    'field.denied' || 'field.revoked' => Icons.lock_rounded,
    'application.submitted' => Icons.send_rounded,
    'lookup.identity' => Icons.person_search_rounded,
    'helper.blocked' || 'helper.auto_blocked' => Icons.block_rounded,
    'request.accepted' => Icons.handshake_rounded,
    'trust.added' => Icons.favorite_rounded,
    'trust.removed' => Icons.heart_broken_rounded,
    _ => Icons.circle_outlined,
  };

  Color _color(String type) => switch (type) {
    'lookup.identity' || 'helper.blocked' || 'helper.auto_blocked' => TPColors.red500,
    'field.authorized' || 'application.submitted' => AssistColors.green500,
    _ => TPColors.primary500,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: const TPAppBar(title: '歷程與授權管理'),
      body: AssistTextScaleCap(
        child: RefreshIndicator(
          onRefresh: () async {
            await service.refreshRecords();
            await service.refreshTrusted();
          },
          child: Obx(() {
            final ok = service.auditStatus.value?['ok'] == true;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                AssistNotice(
                  icon: ok ? Icons.verified_user_rounded : Icons.sync_rounded,
                  color: ok ? AssistColors.green700 : TPColors.grayscale600,
                  background: ok ? AssistColors.green50 : TPColors.white,
                  text: ok ? '紀錄完整，沒有被修改過' : '正在檢查紀錄…',
                ),
                const SizedBox(height: 22),
                Semantics(header: true, child: const Text('信任的人', style: AssistText.title)),
                const SizedBox(height: 4),
                const Text('這些人不用配對碼就能請求陪您辦，您一樣要按同意才會開始。', style: AssistText.callout),
                const SizedBox(height: 10),
                if (service.trusted.isEmpty)
                  const AssistCard(child: Text('還沒有信任的人。辦完一次之後，可以把陪您的家人加進來。', style: AssistText.callout))
                else
                  AssistCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < service.trusted.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                AssistHelperAvatar(helper: service.trusted[i].helper, size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MergeSemantics(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(assistHelperDisplayName(service.trusted[i].helper), style: AssistText.headline),
                                        Text('${assistYmdhm(service.trusted[i].since)} 加入', style: AssistText.footnote),
                                      ],
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final t = service.trusted[i].helper;
                                    final ok = await assistConfirm(
                                      title: '移除 ${t.name}？',
                                      message: '移除後，${t.name} 要陪您辦事時，需要您再出示配對碼。',
                                      confirmLabel: '移除',
                                    );
                                    if (ok) await assistRun(() => service.removeTrusted(t.id));
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: TPColors.red600,
                                    minimumSize: const Size(64, 48),
                                    textStyle: AssistText.body,
                                  ),
                                  child: const Text('移除'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                Semantics(header: true, child: const Text('陪辦送出的申請', style: AssistText.title)),
                const SizedBox(height: 10),
                if (service.applications.isEmpty)
                  const AssistCard(child: Text('還沒有送出的申請', style: AssistText.callout))
                else
                  for (final a in service.applications) ...[
                    AssistCard(
                      child: MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['serviceTitle'] as String, style: AssistText.headline),
                            Text('案件編號 ${a['caseNo']}', style: AssistText.body.copyWith(color: TPColors.primary700)),
                            Text(
                              '${assistYmdhm(DateTime.fromMillisecondsSinceEpoch((a['submittedAt'] as num).toInt()))}　由 ${a['helper']} 陪同',
                              style: AssistText.footnote,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 18),
                Semantics(header: true, child: const Text('誰找過我、我同意了什麼', style: AssistText.title)),
                const SizedBox(height: 10),
                AssistCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Column(
                    children: [
                      if (service.audit.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('目前沒有紀錄', style: AssistText.callout),
                        ),
                      for (var i = 0; i < service.audit.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        MergeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                    _icon(service.audit[i]['type'] as String),
                                    color: _color(service.audit[i]['type'] as String),
                                    size: context.iconSize(24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(service.audit[i]['summary'] as String, style: AssistText.body),
                                      Text(
                                        assistYmdhm(
                                          DateTime.fromMillisecondsSinceEpoch((service.audit[i]['ts'] as num).toInt()),
                                        ),
                                        style: AssistText.footnote,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AssistButton(
                  '我的權利與法規說明',
                  style: AssistButtonStyle.plain,
                  icon: Icons.gavel_rounded,
                  onPressed: () => Get.toNamed(TPRoute.assistLegal),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
