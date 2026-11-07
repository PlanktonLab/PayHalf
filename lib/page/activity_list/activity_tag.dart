import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/activity.dart';
import 'package:town_pass/gen/fonts.gen.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/activity_match.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 依帳戶資料顯示「與你相關／可申請」標籤。
///
/// - [explain]：在詳情頁顯示原因。
/// - [overlay]：疊在活動圖片上時，限制字級放大倍率，避免大字時蓋住整張圖。
class ActivityTag extends StatelessWidget {
  const ActivityTag(this.item, {this.explain = false, this.overlay = false, super.key});

  final ActivityItem item;
  final bool explain;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final account = Get.find<AccountService>().account;
      final match = matchActivity(item, account, DateTime.now());
      if (match == null) return const SizedBox.shrink();
      final canApply = match.kind == ActivityMatchKind.canApply;
      final scaler = overlay
          ? MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)
          : MediaQuery.textScalerOf(context);

      final badge = DecoratedBox(
        decoration: BoxDecoration(
          color: canApply ? TPColors.green700 : TPColors.primary800,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(canApply ? Icons.check_circle : Icons.star, size: scaler.scale(16), color: TPColors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  match.label,
                  textScaler: scaler,
                  style: const TextStyle(
                    color: TPColors.white,
                    fontSize: 14,
                    fontFamily: FontFamily.pingFangTC,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      return Semantics(
        // VoiceOver 會念出「與你相關，原因…」
        label: explain ? match.label : trf('{0}。{1}', [match.label, match.reason]),
        excludeSemantics: !explain,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge,
              if (explain)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    match.reason,
                    style: const TextStyle(
                      color: TPColors.grayscale700,
                      fontSize: 16,
                      height: 1.5,
                      fontFamily: FontFamily.pingFangTC,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
