import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/assist_helper/assist_helper_view.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 協助者手機：信任我的長輩按了「請他來幫我」。按「去幫他」直接帶到陪辦畫面（長輩已選好）。
class AssistHelpCallSheet extends StatelessWidget {
  const AssistHelpCallSheet({super.key, required this.id});
  final String id;

  static bool _open = false;

  static Future<void> show(String id) async {
    final context = Get.context;
    if (_open || context == null) return;
    _open = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: TPColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => AssistHelpCallSheet(id: id),
      );
    } finally {
      _open = false;
    }
  }

  static void go(String elderId) => AssistHelperView.open(elderId: elderId);

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return AssistTextScaleCap(
      child: Obx(() {
        final r = service.helpForMe.firstWhereOrNull((e) => e.id == id);
        if (r == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
          });
          return const SizedBox(height: 120);
        }
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.secondary100),
                        child: Text(
                          r.elderName.characters.first,
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: TPColors.secondary800),
                        ),
                      ),
                      const Positioned(right: -2, bottom: -2, child: AssistTrustedMark(size: 22)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('${r.elderName}\n請您幫忙', textAlign: TextAlign.center, style: AssistText.largeTitle),
                const SizedBox(height: 8),
                const Text('按「去幫他」，選好要辦的事，他的手機就會收到通知。', textAlign: TextAlign.center, style: AssistText.callout),
                const SizedBox(height: 20),
                AssistButton(
                  '去幫他',
                  icon: Icons.volunteer_activism_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    go(r.elderId);
                  },
                ),
                const SizedBox(height: 10),
                AssistButton('等一下', style: AssistButtonStyle.plain, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        );
      }),
    );
  }
}
