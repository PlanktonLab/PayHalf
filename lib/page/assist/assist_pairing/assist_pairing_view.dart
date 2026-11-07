import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_home_section.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 「請人陪我辦」：產生一次性配對碼，給協助者掃描或輸入。
class AssistPairingView extends StatefulWidget {
  const AssistPairingView({super.key});
  @override
  State<AssistPairingView> createState() => _AssistPairingViewState();
}

class _AssistPairingViewState extends State<AssistPairingView> {
  final service = Get.find<AssistService>();
  bool failed = false;

  @override
  void initState() {
    super.initState();
    if (service.pairing.value == null || service.pairing.value!.expiresAt.isBefore(DateTime.now())) {
      _create();
    }
  }

  Future<void> _create() async {
    setState(() => failed = false);
    final ok = await assistRun(service.createPairingCode);
    if (mounted && !ok) setState(() => failed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: TPAppBar(title: '請人陪我辦'.tr),
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
              Semantics(header: true, child: Text('請把這個畫面給幫忙的人看'.tr, style: AssistText.largeTitle)),
              const SizedBox(height: 6),
              Text('對方用台北通掃描，或輸入下面的號碼，就能陪您一起辦。'.tr, style: AssistText.callout),
              const SizedBox(height: 18),
              AssistCard(
                padding: const EdgeInsets.all(22),
                child: p == null
                    ? failed
                        ? Column(
                            children: [
                              Text('暫時拿不到號碼，請再試一次。'.tr, style: AssistText.body, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              AssistButton('再試一次'.tr, icon: Icons.refresh_rounded, onPressed: _create),
                            ],
                          )
                        : const Padding(
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
                                label: '配對 QR Code'.tr,
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
                                label: expired ? '配對碼已失效'.tr : trf('配對碼 {0}', [p.code.split('').join(' ')]),
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
                                expired ? '這組號碼已失效，請換一組'.tr : trf('還有 {0}，只能用一次', [assistMmss(left)]),
                                textAlign: TextAlign.center,
                                style: AssistText.callout.copyWith(
                                  color: expired ? TPColors.red600 : TPColors.grayscale600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              AssistButton(
                                '換一組號碼'.tr,
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
              const _TrustedPeople(),
              const SizedBox(height: 22),
              Semantics(header: true, child: Text('誰可以幫您？'.tr, style: AssistText.title)),
              const SizedBox(height: 10),
              AssistCard(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  children: [
                    _Who(icon: Icons.holiday_village_rounded, title: '里長或里幹事'.tr, desc: '畫面會顯示「市府認證」'.tr),
                    Divider(height: 1),
                    _Who(icon: Icons.support_agent_rounded, title: '1999 市民熱線客服'.tr, desc: '畫面會顯示「市府認證」'.tr),
                    Divider(height: 1),
                    _Who(icon: Icons.family_restroom_rounded, title: '家人或朋友'.tr, desc: '請確認是您認識的人'.tr),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AssistNotice.fraud(),
              const SizedBox(height: 8),
              AssistButton(
                '我的權利與法規說明'.tr,
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

/// 信任的人：點一下「請他來幫我」，對方手機就跳通知；也在這裡加人、移除。
class _TrustedPeople extends StatefulWidget {
  const _TrustedPeople();
  @override
  State<_TrustedPeople> createState() => _TrustedPeopleState();
}

class _TrustedPeopleState extends State<_TrustedPeople> {
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Obx(() {
      final list = service.trusted.toList();
      final waiting = {for (final r in service.myHelpRequests) r.helper.id: r};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text('找信任的人'.tr, style: AssistText.title))),
              if (list.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => editing = !editing),
                  child: Text(editing ? '完成'.tr : '編輯'.tr, style: AssistText.callout.copyWith(color: TPColors.primary700)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            list.isEmpty ? '把常幫您的家人加進來，下次不用掃 QR Code。'.tr : '按一下，對方手機會收到通知來幫您。'.tr,
            style: AssistText.callout,
          ),
          const SizedBox(height: 10),
          for (final t in list) ...[
            _TrustedRow(
              t: t,
              waiting: waiting[t.helper.id],
              editing: editing,
            ),
            const SizedBox(height: 10),
          ],
          AssistButton(
            '加信任的人'.tr,
            style: AssistButtonStyle.secondary,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _AddTrustedSheet.show(),
          ),
        ],
      );
    });
  }
}

class _TrustedRow extends StatelessWidget {
  const _TrustedRow({required this.t, required this.waiting, required this.editing});
  final TrustedHelper t;
  final HelpRequest? waiting;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final h = t.helper;
    final Widget action;
    if (editing) {
      action = TextButton(
        style: TextButton.styleFrom(foregroundColor: TPColors.red600, minimumSize: const Size(64, 48)),
        onPressed: () async {
          final ok = await assistConfirm(
            title: trf('移除 {0}？', [h.name]),
            message: '之後他要找您，就要重新掃 QR Code。'.tr,
            confirmLabel: '移除'.tr,
          );
          if (ok) await assistRun(() => service.removeTrusted(h.id));
        },
        child: Text('移除'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      );
    } else if (waiting != null) {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('已通知，等他回應'.tr, style: TextStyle(fontSize: 15, color: TPColors.secondary800, fontWeight: FontWeight.w600)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(56, 40), foregroundColor: TPColors.grayscale600),
            onPressed: () => assistRun(() => service.cancelHelp(waiting!.id)),
            child: Text('取消'.tr, style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    } else {
      action = const Icon(Icons.chevron_right_rounded, color: TPColors.primary600, size: 30);
    }
    final canCall = !editing && waiting == null;
    return Semantics(
      button: canCall,
      label: canCall ? trf('請 {0} 來幫我', [h.name]) : null,
      child: Material(
        color: TPColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: canCall
              ? () async {
                  HapticFeedback.selectionClick();
                  if (await assistRun(() => service.requestHelp(h.id))) {
                    Get.closeAllSnackbars();
                    Get.snackbar(
                      trf('已通知 {0}', [h.name]),
                      '他的手機會跳出通知，等他來幫您。'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(12),
                      backgroundColor: TPColors.grayscale800,
                      colorText: TPColors.white,
                    );
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                AssistHelperAvatar(helper: h, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    excluding: canCall,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AssistHelperName(h, trusted: true, style: AssistText.headline),
                        if (canCall)
                          Text('請他來幫我'.tr, style: AssistText.callout.copyWith(color: TPColors.primary700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 加信任的人（加好友）：出示一組 QR Code／6 位數，家人用台北通掃，長輩再按一次「加入」。
class _AddTrustedSheet extends StatefulWidget {
  const _AddTrustedSheet();

  static Future<void> show() => showModalBottomSheet<void>(
    context: Get.context!,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TPColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _AddTrustedSheet(),
  );

  @override
  State<_AddTrustedSheet> createState() => _AddTrustedSheetState();
}

class _AddTrustedSheetState extends State<_AddTrustedSheet> {
  final service = Get.find<AssistService>();
  ({String code, String qrPayload, DateTime expiresAt})? invite;
  bool failed = false;
  late final Worker _watch;

  @override
  void initState() {
    super.initState();
    _create();
    // 有人掃了：收起這個畫面，讓「要加他嗎？」的確認畫面出來
    _watch = ever(service.trustRequests, (list) {
      if (list.any((r) => r.isPending) && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => failed = false);
    try {
      final v = await service.createTrustInvite();
      if (mounted) setState(() => invite = v);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = invite;
    return AssistTextScaleCap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: TPColors.grayscale200, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Text('加信任的人'.tr, textAlign: TextAlign.center, style: AssistText.title),
              const SizedBox(height: 4),
              Text('請家人用台北通掃這個 QR Code，\n或輸入下面的號碼。'.tr, textAlign: TextAlign.center, style: AssistText.callout),
              const SizedBox(height: 16),
              if (failed)
                AssistButton('暫時拿不到號碼，再試一次'.tr, style: AssistButtonStyle.secondary, onPressed: _create)
              else if (inv == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else
                AssistTicker(
                  builder: (context, now) {
                    final left = inv.expiresAt.difference(now);
                    final expired = left.isNegative;
                    return Column(
                      children: [
                        Opacity(
                          opacity: expired ? 0.15 : 1,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TPColors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: TPColors.red100, width: 2),
                            ),
                            child: QrImageView(
                              data: inv.qrPayload,
                              size: 190,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: TPColors.red700),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.circle,
                                color: TPColors.red700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          label: expired ? '號碼已失效'.tr : trf('號碼 {0}', [inv.code.split('').join(' ')]),
                          excludeSemantics: true,
                          child: Text(
                            expired ? '------' : '${inv.code.substring(0, 3)} ${inv.code.substring(3)}',
                            style: AssistText.largeTitle.copyWith(
                              fontSize: 40,
                              letterSpacing: 6,
                              color: TPColors.red700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Text(
                          expired ? '號碼已失效'.tr : trf('{0} 後失效', [assistMmss(left)]),
                          style: AssistText.callout.copyWith(color: expired ? TPColors.red600 : null),
                        ),
                        if (expired) ...[
                          const SizedBox(height: 10),
                          AssistButton('換一組'.tr, icon: Icons.refresh_rounded, onPressed: _create),
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              AssistNotice(
                icon: Icons.shield_rounded,
                color: TPColors.red700,
                background: TPColors.red50,
                text: '只給您信得過的家人。對方掃了之後，您還要再按一次「加入」才算數。'.tr,
              ),
            ],
          ),
        ),
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
      Text('暫時連不上陪辦服務'.tr, textAlign: TextAlign.center, style: AssistText.title),
      const SizedBox(height: 8),
      Text('請確認網路，稍後再試。也可以直接撥打 1999 請客服協助。'.tr, textAlign: TextAlign.center, style: AssistText.callout),
      const SizedBox(height: 24),
      AssistButton('再試一次'.tr, onPressed: onRetry),
    ],
  );
}
