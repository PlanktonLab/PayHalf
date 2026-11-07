import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/assist_helper/assist_helper_view.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_dialog.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_web_view.dart';

/// 開啟掃描。掃到長輩的配對 QR Code 時，直接以選定的協助者打開陪辦工作台並帶入配對碼。
Future<void> assistScan() async {
  final raw = await Get.toNamed(TPRoute.qrCodeScan) as String?;
  if (raw == null || raw.trim().isEmpty) return;
  final trustCode = AssistService.trustCodeFrom(raw);
  if (trustCode != null) {
    await assistAcceptTrustInvite(trustCode);
    return;
  }
  final code = AssistService.pairingCodeFrom(raw);
  if (code != null) {
    await openHelperConsole(code);
    return;
  }
  final uri = Uri.tryParse(raw.trim());
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.hasAuthority) {
    await Get.toNamed(TPRoute.webView, arguments: WebViewArgument(url: uri.toString()));
    return;
  }
  await TPDialog.showInfo(
    title: '掃描結果',
    content: Text(raw, style: const TextStyle(fontSize: 16, color: TPColors.grayscale700)),
  );
}

/// 以選定的協助者打開手機版陪辦畫面（有配對碼就先填好）
Future<void> openHelperConsole([String? code]) => AssistHelperView.open(code: code);

/// 首頁右下角的懸浮「掃描」按鈕
class AssistScanButton extends StatelessWidget {
  const AssistScanButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'assist-scan',
      onPressed: assistScan,
      backgroundColor: TPColors.primary500,
      foregroundColor: TPColors.white,
      elevation: 3,
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: const Text('掃描', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      tooltip: '掃 QR Code（掃長輩的配對碼可以協助對方）',
    );
  }
}

/// 協助者：掃了（或輸入）長輩的加好友邀請碼，送給長輩確認
Future<void> assistAcceptTrustInvite(String code) async {
  final service = Get.find<AssistService>();
  final me = AssistService.helperAccounts.firstWhereOrNull((a) => a.id == service.helperId.value)?.name ?? '';
  try {
    final r = await service.acceptTrustInvite(code);
    Get.closeAllSnackbars();
    Get.snackbar(
      r == null ? '您已經是對方信任的人' : '已送出，等 ${r.elderName} 按「加入」',
      r == null ? '不用再加一次。' : '長輩手機會問他要不要加您（$me）。',
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      backgroundColor: TPColors.grayscale800,
      colorText: TPColors.white,
    );
  } catch (e) {
    Get.closeAllSnackbars();
    Get.snackbar(
      '沒有加成功',
      e is AssistApiException ? e.message : '連不上陪辦伺服器',
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      backgroundColor: TPColors.grayscale800,
      colorText: TPColors.white,
    );
  }
}

/// 協助者：手動輸入長輩給的 6 位數邀請碼
Future<void> assistEnterTrustCode() async {
  final code = await Get.dialog<String>(const _TrustCodeDialog());
  if (code != null && RegExp(r'^\d{6}$').hasMatch(code)) await assistAcceptTrustInvite(code);
}

/// 輸入框的 controller 由對話框自己管理：關閉動畫跑完才釋放
class _TrustCodeDialog extends StatefulWidget {
  const _TrustCodeDialog();
  @override
  State<_TrustCodeDialog> createState() => _TrustCodeDialogState();
}

class _TrustCodeDialogState extends State<_TrustCodeDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('輸入長輩給的邀請碼'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(fontSize: 28, letterSpacing: 6),
        decoration: const InputDecoration(hintText: '6 位數字', counterText: ''),
        onSubmitted: (v) => Get.back(result: v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        FilledButton(onPressed: () => Get.back(result: controller.text.trim()), child: const Text('加好友')),
      ],
    );
  }
}
