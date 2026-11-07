import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_dialog.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_web_view.dart';

/// 開啟掃描。掃到長輩的配對 QR Code 時，直接以選定的協助者打開陪辦工作台並帶入配對碼。
Future<void> assistScan() async {
  final raw = await Get.toNamed(TPRoute.qrCodeScan) as String?;
  if (raw == null || raw.trim().isEmpty) return;
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

/// 以選定的協助者在 App 內打開陪辦工作台（有配對碼就先填好）
Future<void> openHelperConsole([String? code]) => Get.toNamed(
  TPRoute.webView,
  arguments: WebViewArgument(url: Get.find<AssistService>().helperConsoleUrl(code), forceTitle: '陪辦工作台'),
) ?? Future.value();

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
