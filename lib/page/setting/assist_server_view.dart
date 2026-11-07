import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 設定 › 陪辦伺服器：在本機後端與雲端（payhalf.plankton.tw）之間切換，方便測試。
class AssistServerView extends StatefulWidget {
  const AssistServerView({super.key});

  /// 設定頁那一列右側要顯示的簡短名稱
  static String labelFor(String base) {
    if (base == AssistService.cloudBase) return '雲端'.tr;
    if (base == AssistService.localBase) return '本機'.tr;
    return Uri.tryParse(base)?.authority ?? base;
  }

  @override
  State<AssistServerView> createState() => _AssistServerViewState();
}

class _AssistServerViewState extends State<AssistServerView> {
  final service = Get.find<AssistService>();
  late final TextEditingController custom;
  bool busy = false;
  String? message;
  bool messageIsError = false;
  // 測試失敗時記下目標，讓使用者可以「仍要切換」（例如 DNS 還沒生效但想先選好）
  String? failedBase;

  @override
  void initState() {
    super.initState();
    final cur = service.server.value;
    final isPreset = cur == AssistService.cloudBase || cur == AssistService.localBase;
    custom = TextEditingController(text: isPreset ? '' : cur);
  }

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  Future<void> _use(String base, {bool force = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      failedBase = null;
    });
    // 先測試再切換，避免切到連不上的位址後整個陪辦功能卡住
    final problem = force ? null : await AssistService.probe(base);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        busy = false;
        message = trf('沒有切換：{0}', [problem]);
        messageIsError = true;
        failedBase = base;
      });
      return;
    }
    try {
      await service.useServer(base);
      if (!mounted) return;
      setState(() {
        message = trf('已切換到 {0}', [AssistService.normalizeBase(base)]);
        messageIsError = false;
      });
    } on FormatException catch (e) {
      setState(() {
        message = e.message;
        messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: TPAppBar(title: '陪辦伺服器'.tr),
      body: Obx(() {
        final cur = service.server.value;
        final linked = service.linked.value;
        final connected = service.connected.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(base: cur, linked: linked, connected: connected),
            const SizedBox(height: 20),
            _SectionTitle('切換到'.tr),
            _Option(
              title: '雲端'.tr,
              subtitle: AssistService.cloudBase,
              selected: cur == AssistService.cloudBase,
              enabled: !busy,
              onTap: () => _use(AssistService.cloudBase),
            ),
            const SizedBox(height: 8),
            _Option(
              title: '本機'.tr,
              subtitle: trf('{0}（電腦上執行的後端）', [AssistService.localBase]),
              selected: cur == AssistService.localBase,
              enabled: !busy,
              onTap: () => _use(AssistService.localBase),
            ),
            const SizedBox(height: 20),
            _SectionTitle('自訂位址'.tr),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: custom,
                    enabled: !busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: '例：http://192.168.1.10:3000'.tr,
                      hintStyle: TextStyle(color: TPColors.grayscale400),
                      helperText: '實機連電腦時，填電腦的區網 IP'.tr,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) => v.trim().isEmpty ? null : _use(v),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: busy ? null : () => custom.text.trim().isEmpty ? null : _use(custom.text),
                    style: FilledButton.styleFrom(backgroundColor: TPColors.primary600, minimumSize: const Size.fromHeight(44)),
                    child: Text('使用這個位址'.tr),
                  ),
                ],
              ),
            ),
            if (busy || message != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (busy)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(
                      messageIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: messageIsError ? TPColors.red500 : TPColors.primary600,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      busy ? '測試連線中…'.tr : message!,
                      style: TextStyle(color: messageIsError ? TPColors.red500 : TPColors.grayscale700),
                    ),
                  ),
                ],
              ),
              if (!busy && failedBase != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _use(failedBase!, force: true),
                    child: Text('仍要切換'.tr),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              '切換後會結束目前的陪辦、清掉配對碼，並用同一個台北通帳號重新登入新的伺服器。選擇會記住，下次開啟 App 仍沿用。'.tr,
              style: TextStyle(color: TPColors.grayscale500, fontSize: 13, height: 1.5),
            ),
          ],
        );
      }),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.base, required this.linked, required this.connected});
  final String base;
  final bool linked;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final (label, color) = connected
        ? ('已連線'.tr, TPColors.green500)
        : linked
        ? ('已登入，即時連線中…'.tr, TPColors.orange500)
        : ('連線中…'.tr, TPColors.grayscale400);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目前使用'.tr, style: TextStyle(color: TPColors.grayscale500, fontSize: 13)),
          const SizedBox(height: 4),
          Text(base, style: const TextStyle(color: TPColors.grayscale900, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: TPColors.grayscale700, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: const TextStyle(color: TPColors.grayscale500, fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
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
          onTap: enabled && !selected ? onTap : null,
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
