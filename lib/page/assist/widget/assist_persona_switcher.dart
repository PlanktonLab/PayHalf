import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/assist_form/assist_form_view.dart';
import 'package:town_pass/page/assist/assist_helper/assist_helper_view.dart';
import 'package:town_pass/page/assist/widget/assist_scan.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/page/setting/assist_server_view.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_i18n.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 首頁左上角：這支手機現在是誰。整個 App 都是 demo，所以切換身分放在最顯眼的地方，
/// 點開是一個面板：切長輩、切協助者、一鍵讓信任的人發出請求、切伺服器。
class AssistPersonaButton extends StatelessWidget {
  const AssistPersonaButton({super.key});

  static const double width = 132;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
      child: Obx(() {
        final name = service.elderName;
        final online = service.connected.value;
        return Semantics(
          button: true,
          label: trf('目前身分 {0}，切換身分', [name]),
          child: Material(
            color: TPColors.primary50,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => AssistPersonaSheet.show(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Avatar(name: name, size: 30, online: online),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: TPColors.primary800, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded, size: 18, color: TPColors.primary700),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size, this.online});
  final String name;
  final double size;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AssistColors.brandGradient),
          child: Text(
            name.characters.first,
            style: TextStyle(color: TPColors.white, fontSize: size * 0.5, fontWeight: FontWeight.w700),
          ),
        ),
        if (online != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online! ? TPColors.green500 : TPColors.grayscale400,
                border: Border.all(color: TPColors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// 切換身分面板。
class AssistPersonaSheet extends StatefulWidget {
  const AssistPersonaSheet({super.key});

  static Future<void> show() {
    return showModalBottomSheet<void>(
      context: Get.context!,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TPColors.grayscale50,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const AssistPersonaSheet(),
    );
  }

  @override
  State<AssistPersonaSheet> createState() => _AssistPersonaSheetState();
}

class _AssistPersonaSheetState extends State<AssistPersonaSheet> {
  final service = Get.find<AssistService>();
  List<({String id, String title})> services = const [];
  List<({String id, String title, String agency})> forms = const [];
  String? serviceId;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await service.listServices();
      final fs = await service.listForms();
      if (!mounted) return;
      setState(() {
        forms = fs;
        services = list;
        serviceId ??= list.firstOrNull?.id;
      });
      await service.refreshTrusted();
    } catch (_) {}
  }

  Future<void> _send(String helperId, String helperName) async {
    if (sending || serviceId == null) return;
    setState(() => sending = true);
    try {
      await service.demoTrustedRequest(helperId, serviceId!);
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.closeAllSnackbars();
      Get.snackbar(
        trf('{0} 已送出請求', [helperName]),
        '一兩秒後這支手機會跳出「有人想協助您」'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        backgroundColor: TPColors.grayscale800,
        colorText: TPColors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      Get.closeAllSnackbars();
      Get.snackbar(
        '沒有送出'.tr,
        e is AssistApiException ? e.message : '連不上陪辦伺服器'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        backgroundColor: TPColors.grayscale800,
        colorText: TPColors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Obx(() {
        final elder = service.elderId.value;
        final helper = service.helperId.value;
        final trusted = service.trusted;
        final base = service.server.value;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: TPColors.grayscale300, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('切換身分'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Get.toNamed(TPRoute.account);
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text('帳戶頁'.tr),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _Section('這支手機是'.tr),
            for (final a in AssistService.elderAccounts)
              _Row(
                name: a.name,
                note: a.note,
                selected: elder == a.id,
                onTap: () => service.useElder(a.id),
              ),
            const SizedBox(height: 18),
            // 語言是使用者帳號的設定（正式版在註冊時選），存在後端，換手機登入也一樣
            _Section('介面語言 · Language'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in TPLanguage.all)
                  ChoiceChip(
                    label: Text(l.nativeName),
                    selected: TPLanguage.current.code == l.code,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: TPLanguage.current.code == l.code ? TPColors.white : TPColors.grayscale800,
                    ),
                    selectedColor: TPColors.primary500,
                    backgroundColor: TPColors.white,
                    onSelected: (_) async {
                      await service.setLanguage(l.code);
                      if (mounted) setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Section('一鍵發出協助請求'.tr),
            _DemoCard(
              elderName: service.elderName,
              trusted: [for (final t in trusted) (id: t.helper.id, name: t.helper.name, title: t.helper.title)],
              services: services,
              serviceId: serviceId,
              sending: sending,
              onService: (id) => setState(() => serviceId = id),
              onSend: _send,
            ),
            const SizedBox(height: 18),
            _Section('幫別人辦時，我是'.tr),
            for (final a in AssistService.helperAccounts)
              _Row(
                name: a.name,
                note: a.note,
                selected: helper == a.id,
                onTap: () => service.useHelper(a.id),
              ),
            if (service.helperTrusting.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AssistHelperView.open(elderId: service.helperTrusting.first.elderId);
                  },
                  icon: const Icon(Icons.volunteer_activism_rounded),
                  label: Text(trf('幫 {0} 辦事（信任您，不用配對碼）', [service.helperTrusting.map((e) => e.displayName).join('、')])),
                  style: FilledButton.styleFrom(
                    backgroundColor: AssistColors.green700,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      assistScan();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text('掃 QR Code'.tr),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openHelperConsole();
                    },
                    icon: const Icon(Icons.volunteer_activism_rounded),
                    label: Text('陪辦工作台'.tr),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ),
              ],
            ),
            if (forms.isNotEmpty) ...[
              const SizedBox(height: 18),
              _Section('海報上的表單（假裝掃了 QR Code）'.tr),
              Container(
                decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    for (final f in forms)
                      ListTile(
                        leading: const Icon(Icons.qr_code_2_rounded, color: TPColors.primary600),
                        title: Text(f.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        subtitle: Text(f.agency, style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).pop();
                          AssistFormView.open(f.id);
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            _Section('伺服器'.tr),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  for (final (label, value) in [('雲端'.tr, AssistService.cloudBase), ('本機'.tr, AssistService.localBase)])
                    Expanded(
                      child: _Seg(
                        label: label,
                        selected: base == value,
                        onTap: () => service.useServer(value),
                      ),
                    ),
                  Expanded(
                    child: _Seg(
                      label: '其他…'.tr,
                      selected: base != AssistService.cloudBase && base != AssistService.localBase,
                      onTap: () {
                        Navigator.of(context).pop();
                        Get.to(() => const AssistServerView());
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trf('目前：{0}{1}', [base, service.connected.value ? '（已連線）' : '（連線中…）']),
              style: const TextStyle(fontSize: 12, color: TPColors.grayscale500),
            ),
          ],
        );
      }),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: const TextStyle(color: TPColors.grayscale600, fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.name, required this.note, required this.selected, required this.onTap});
  final String name;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? TPColors.primary50 : TPColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? TPColors.primary500 : TPColors.white, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: selected ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _Avatar(name: name, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TPColors.grayscale900)),
                      Text(note, style: const TextStyle(fontSize: 13, color: TPColors.grayscale500)),
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

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.elderName,
    required this.trusted,
    required this.services,
    required this.serviceId,
    required this.sending,
    required this.onService,
    required this.onSend,
  });
  final String elderName;
  final List<({String id, String name, String title})> trusted;
  final List<({String id, String title})> services;
  final String? serviceId;
  final bool sending;
  final ValueChanged<String> onService;
  final void Function(String helperId, String helperName) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TPColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AssistColors.green50, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trusted.isEmpty)
            Text(
              trf('{0} 還沒有信任的人。到「請人陪我辦」按「加信任的人」，讓家人掃 QR Code。', [elderName]),
              style: const TextStyle(fontSize: 14, color: TPColors.grayscale600, height: 1.5),
            )
          else ...[
            Text(
              trf('{0} 信任的人可以不用配對碼直接發請求，這支手機會馬上跳出通知。', [elderName]),
              style: const TextStyle(fontSize: 13, color: TPColors.grayscale600, height: 1.5),
            ),
            const SizedBox(height: 10),
            if (services.length > 1)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final s in services)
                    ChoiceChip(
                      label: Text(s.title),
                      selected: s.id == serviceId,
                      onSelected: (_) => onService(s.id),
                      selectedColor: TPColors.primary100,
                      labelStyle: TextStyle(color: s.id == serviceId ? TPColors.primary800 : TPColors.grayscale700),
                      side: BorderSide(color: s.id == serviceId ? TPColors.primary500 : TPColors.grayscale200),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            for (final t in trusted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  onPressed: sending || serviceId == null ? null : () => onSend(t.id, t.name),
                  icon: sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TPColors.white))
                      : const Icon(Icons.notifications_active_rounded),
                  label: Text(trf('讓 {0}（{1}）發出請求', [t.name, t.title])),
                  style: FilledButton.styleFrom(
                    backgroundColor: AssistColors.green700,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TPColors.primary600 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selected ? null : onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? TPColors.white : TPColors.grayscale700,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
