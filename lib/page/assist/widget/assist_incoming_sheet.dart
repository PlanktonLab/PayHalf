import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 有人想協助長輩時，從底部彈出的提示。
///
/// 長輩把它關掉也沒關係：首頁上方的徽章會一直留著，隨時可以回應。
/// 請求失效（逾時、對方取消、已在別處回應）時會自己收起來。
class AssistIncomingSheet extends StatefulWidget {
  const AssistIncomingSheet({super.key, required this.id});
  final String id;

  static bool _open = false;

  static Future<void> show(String id) async {
    final context = Get.context;
    if (_open || context == null) return;
    // 已經在看這個請求，或正在陪辦中（一次只能接受一個），就不彈
    if (Get.currentRoute == TPRoute.assistRequest || Get.currentRoute == TPRoute.assistSession) return;
    _open = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: TPColors.white,
        barrierColor: TPColors.grayscale900.withValues(alpha: 0.45),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => AssistIncomingSheet(id: id),
      );
    } finally {
      _open = false;
    }
  }

  @override
  State<AssistIncomingSheet> createState() => _AssistIncomingSheetState();
}

class _AssistIncomingSheetState extends State<AssistIncomingSheet> with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  bool closing = false;

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void close() {
    if (closing || !mounted) return;
    closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return AssistTextScaleCap(
      child: Obx(() {
        final s = service.sessions[widget.id];
        return AssistTicker(
          builder: (context, now) {
            final alive = s != null && !service.isHelping(s.id) && s.isPending && (s.expiresAt?.isAfter(now) ?? false) && s.helper != null;
            if (!alive) {
              WidgetsBinding.instance.addPostFrameCallback((_) => close());
              return const SizedBox(height: 120);
            }
            return _content(context, s, now);
          },
        );
      }),
    );
  }

  Widget _content(BuildContext context, AssistSession s, DateTime now) {
    final h = s.helper!;
    final left = s.expiresAt!.difference(now);
    final reduce = context.reduceMotion;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
            const SizedBox(height: 18),
            // 頭像外圈一圈圈往外擴散，表示「有人在找您」
            Center(
              child: SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!reduce)
                      for (final offset in const [0.0, 0.5])
                        AnimatedBuilder(
                          animation: pulse,
                          builder: (context, _) {
                            final t = (pulse.value + offset) % 1.0;
                            return Container(
                              width: 84 + 48 * t,
                              height: 84 + 48 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: TPColors.primary300.withValues(alpha: 0.35 * (1 - t)),
                              ),
                            );
                          },
                        ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.white),
                      child: AssistHelperAvatar(helper: h, size: 80),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text('${assistHelperDisplayName(h)}\n想協助您', textAlign: TextAlign.center, style: AssistText.largeTitle),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (s.helperTrusted)
                  const AssistPill(
                    '您信任的人',
                    color: AssistColors.green700,
                    background: AssistColors.green50,
                    icon: Icons.favorite_rounded,
                  ),
                AssistHelperBadge(helper: h),
              ],
            ),
            const SizedBox(height: 16),
            AssistCard(
              color: TPColors.primary50,
              child: Column(
                children: [
                  Text('想陪您辦理', style: AssistText.callout.copyWith(color: TPColors.primary700)),
                  const SizedBox(height: 2),
                  Text('「${s.serviceTitle}」', textAlign: TextAlign.center, style: AssistText.title),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${assistMmss(left)} 後自動取消・先關掉也可以，首頁上方會一直留著',
              textAlign: TextAlign.center,
              style: AssistText.footnote.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 16),
            AssistButton(
              '查看並回應',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                closing = true;
                Navigator.of(context).pop();
                Get.toNamed(TPRoute.assistRequest, arguments: s.id);
              },
            ),
            const SizedBox(height: 10),
            AssistButton('等一下再說', style: AssistButtonStyle.plain, onPressed: close),
          ],
        ),
      ),
    );
  }
}
