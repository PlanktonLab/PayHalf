import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 長輩手機：家人掃了邀請碼，問長輩「要把他加為信任的人嗎？」一定要長輩本人按「加入」。
class AssistTrustRequestSheet extends StatelessWidget {
  const AssistTrustRequestSheet({super.key, required this.id});
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
        isDismissible: false,
        backgroundColor: TPColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => AssistTrustRequestSheet(id: id),
      );
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return AssistTextScaleCap(
      child: Obx(() {
        final r = service.trustRequests.firstWhereOrNull((e) => e.id == id);
        if (r == null) {
          // 回應後名單裡就沒有它了：只在這個面板還在最上層時關一次，避免連帶把底下頁面關掉
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
          });
          return const SizedBox(height: 120);
        }
        final h = r.helper;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: AssistHelperAvatar(helper: h, size: 88)),
                const SizedBox(height: 14),
                Text(
                  '${assistHelperDisplayName(h)}\n想成為您信任的人',
                  textAlign: TextAlign.center,
                  style: AssistText.largeTitle.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Center(child: AssistHelperBadge(helper: h)),
                const SizedBox(height: 14),
                const Text(
                  '加入後，您可以直接請他來幫忙。\n電話裡有人要您加他，就是詐騙。',
                  textAlign: TextAlign.center,
                  style: AssistText.callout,
                ),
                const SizedBox(height: 20),
                AssistButton(
                  '加入',
                  icon: Icons.favorite_rounded,
                  onPressed: () async {
                    if (await assistRun(() => service.respondTrustRequest(r.id, true))) {
                      Get.closeAllSnackbars();
                      Get.snackbar(
                        '已加入 ${h.name}',
                        '在「請人陪我辦」按他，就能請他來幫忙。',
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(12),
                        backgroundColor: TPColors.grayscale800,
                        colorText: TPColors.white,
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                AssistButton(
                  '不要',
                  style: AssistButtonStyle.secondary,
                  onPressed: () async {
                    await assistRun(() => service.respondTrustRequest(r.id, false));
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
