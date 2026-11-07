import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/activity.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/activity_match.dart';
import 'package:town_pass/util/tp_colors.dart';

class ActivityTag extends StatelessWidget {
  const ActivityTag(this.item, {this.explain = false, super.key});

  final ActivityItem item;
  final bool explain;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final account = Get.find<AccountService>().account;
      final match = matchActivity(item, account, DateTime.now());
      if (match == null) return const SizedBox.shrink();
      final canApply = match.label == '可申請';
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: canApply ? const Color(0xFF186042) : TPColors.primary800,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      canApply ? Icons.check_circle : Icons.star,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        match.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (explain)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(match.reason),
              ),
          ],
        ),
      );
    });
  }
}
