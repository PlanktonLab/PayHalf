import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_scan.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 設定 › 開發測試 › 測試身分：
/// 一支手機可以當「長輩」接受協助，也可以掃別人的 QR Code 當「協助者」。
class AssistIdentityView extends StatelessWidget {
  const AssistIdentityView({super.key});

  /// 設定頁那一列右側的摘要
  static String summary(AssistService s) {
    String name(List<({String id, String name, String note})> list, String id) =>
        list.firstWhereOrNull((a) => a.id == id)?.name ?? id;
    return '${name(AssistService.elderAccounts, s.elderId.value)}／${name(AssistService.helperAccounts, s.helperId.value)}';
  }

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: const TPAppBar(title: '測試身分'),
      body: Obx(() {
        final elder = service.elderId.value;
        final helper = service.helperId.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Title('這支手機是哪位長輩', '接受協助、出示配對 QR Code 時用這個身分。切換後會結束目前的陪辦並重新登入。'),
            for (final a in AssistService.elderAccounts) ...[
              _Option(
                title: a.name,
                subtitle: a.note,
                selected: elder == a.id,
                onTap: () async {
                  await service.useElder(a.id);
                  Get.closeAllSnackbars();
                  Get.snackbar('已切換', '這支手機現在是長輩「${a.name}」', snackPosition: SnackPosition.BOTTOM);
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            const _Title('掃 QR Code 時以誰協助', '在首頁按「掃描」掃長輩的配對 QR Code，會用這個身分開始陪辦。'),
            for (final a in AssistService.helperAccounts) ...[
              _Option(
                title: a.name,
                subtitle: a.note,
                selected: helper == a.id,
                onTap: () => service.useHelper(a.id),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: assistScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('掃描'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openHelperConsole(),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('開始陪辦'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TPColors.primary600,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '小提醒：用兩支手機測試時，兩邊不要選同一位長輩，不然兩支手機都會收到協助請求。',
              style: TextStyle(color: TPColors.grayscale500, fontSize: 13, height: 1.5),
            ),
          ],
        );
      }),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.desc);
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: TPColors.grayscale900, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(color: TPColors.grayscale500, fontSize: 13, height: 1.45)),
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? TPColors.primary50 : TPColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? TPColors.primary500 : TPColors.white, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: selected ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: TPColors.grayscale900, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: TPColors.grayscale500, fontSize: 13)),
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
}
