import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:town_pass/page/assist/widget/assist_home_section.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 「請人陪我辦」：產生一次性配對碼，給協助者掃描或輸入。
class AssistPairingView extends StatefulWidget {
  const AssistPairingView({super.key});
  @override
  State<AssistPairingView> createState() => _AssistPairingViewState();
}

class _AssistPairingViewState extends State<AssistPairingView> {
  final service = Get.find<AssistService>();

  @override
  void initState() {
    super.initState();
    if (service.pairing.value == null || service.pairing.value!.expiresAt.isBefore(DateTime.now())) {
      assistRun(service.createPairingCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: const TPAppBar(title: '請人陪我辦'),
      body: AssistTextScaleCap(
        child: Obx(() {
          if (!service.linked.value) return _Offline(onRetry: service.retryNow);
          final p = service.pairing.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              // 對方送出請求後，徽章會直接出現在這裡
              const AssistHomeBadge(padding: EdgeInsets.only(top: 16)),
              const SizedBox(height: 16),
              Semantics(header: true, child: const Text('請把這個畫面給幫忙的人看', style: AssistText.largeTitle)),
              const SizedBox(height: 6),
              const Text('對方用台北通掃描，或輸入下面的號碼，就能陪您一起辦。', style: AssistText.callout),
              const SizedBox(height: 18),
              AssistCard(
                padding: const EdgeInsets.all(22),
                child: p == null
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : AssistTicker(
                        builder: (context, now) {
                          final left = p.expiresAt.difference(now);
                          final expired = left.isNegative;
                          return Column(
                            children: [
                              Semantics(
                                label: '配對 QR Code',
                                image: true,
                                child: Opacity(
                                  opacity: expired ? 0.12 : 1,
                                  child: QrImageView(
                                    data: p.qrPayload,
                                    size: 200,
                                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: TPColors.primary800),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.circle,
                                      color: TPColors.primary800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                label: expired ? '配對碼已失效' : '配對碼 ${p.code.split('').join(' ')}',
                                child: ExcludeSemantics(
                                  child: FittedBox(
                                    child: Text(
                                      expired ? '— — —  — — —' : '${p.code.substring(0, 3)} ${p.code.substring(3)}',
                                      textScaler: context.cappedScaler,
                                      style: AssistText.largeTitle.copyWith(
                                        fontSize: 46,
                                        letterSpacing: 6,
                                        color: TPColors.primary800,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expired ? '這組號碼已失效，請換一組' : '還有 ${assistMmss(left)}，只能用一次',
                                textAlign: TextAlign.center,
                                style: AssistText.callout.copyWith(
                                  color: expired ? TPColors.red600 : TPColors.grayscale600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              AssistButton(
                                '換一組號碼',
                                style: expired ? AssistButtonStyle.primary : AssistButtonStyle.secondary,
                                icon: Icons.refresh_rounded,
                                onPressed: () => assistRun(service.createPairingCode),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 22),
              Semantics(header: true, child: const Text('誰可以幫您？', style: AssistText.title)),
              const SizedBox(height: 10),
              const AssistCard(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  children: [
                    _Who(icon: Icons.holiday_village_rounded, title: '里長或里幹事', desc: '畫面會顯示「市府認證」'),
                    Divider(height: 1),
                    _Who(icon: Icons.support_agent_rounded, title: '1999 市民熱線客服', desc: '畫面會顯示「市府認證」'),
                    Divider(height: 1),
                    _Who(icon: Icons.family_restroom_rounded, title: '家人或朋友', desc: '請確認是您認識的人'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AssistNotice.fraud(),
              const SizedBox(height: 8),
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
    );
  }
}

class _Who extends StatelessWidget {
  const _Who({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title;
  final String desc;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: MergeSemantics(
      child: Row(
        children: [
          Icon(icon, color: TPColors.primary500, size: context.iconSize(28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AssistText.headline),
                Text(desc, style: AssistText.callout),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 40),
      Icon(Icons.cloud_off_rounded, size: context.iconSize(56), color: TPColors.grayscale400),
      const SizedBox(height: 16),
      const Text('暫時連不上陪你辦服務', textAlign: TextAlign.center, style: AssistText.title),
      const SizedBox(height: 8),
      const Text('請確認網路，稍後再試。也可以直接撥打 1999 請客服協助。', textAlign: TextAlign.center, style: AssistText.callout),
      const SizedBox(height: 24),
      AssistButton('再試一次', onPressed: onRetry),
    ],
  );
}
