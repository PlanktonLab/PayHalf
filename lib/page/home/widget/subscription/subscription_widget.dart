import 'package:town_pass/service/subscription_service.dart';
import 'package:town_pass/page/activity_list/activity_tag.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/subscription.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/gen/fonts.gen.dart';
import 'package:town_pass/page/home/widget/subscription/subscription_item_widget.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_line.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_text.dart';

class SubscriptionWidget extends StatelessWidget {
  const SubscriptionWidget({super.key});

  List<SubscriptionItem> get subscriptionList =>
      Get.find<SubscriptionService>().itemList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                TPText(
                  '訂閱'.tr,
                  style: TextStyle(
                    color: TPColors.grayscale800,
                    fontSize: 20,
                    fontFamily: FontFamily.pingFangTC,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await TPRoute.openUri(uri: SubscriptionService.settingsUrl);
                  },
                  child: Row(
                    children: [
                      Assets.svg.iconSettings.svg(
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          TPColors.grayscale600,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TPText(
                        '設定'.tr,
                        style: TPTextStyles.h3Regular,
                        color: TPColors.grayscale600,
                      ),
                    ],
                  ),
                ),
                const TPLine.vertical(
                  margin: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  color: TPColors.grayscale200,
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await TPRoute.openUri(
                      uri: 'https://taipei-pass-service.vercel.app/subscription/item-list',
                    );
                  },
                  child: Row(
                    children: [
                      TPText(
                        '更多'.tr,
                        style: TPTextStyles.h3Regular,
                        color: TPColors.grayscale600,
                      ),
                      const SizedBox(width: 8),
                      Assets.svg.iconArrowRight.svg(
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          TPColors.grayscale600,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final service = Get.find<SubscriptionService>();
          if (!service.relatedEnabled) return const SizedBox.shrink();
          final items = service.relatedActivities;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TPText('與我相關'.tr, style: TPTextStyles.h3SemiBold),
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('目前沒有符合你帳戶資料的活動。'.tr),
                  ),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: ActivityTag(item),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Get.toNamed(TPRoute.activityDetail, arguments: item),
                  ),
              ],
            ),
          );
        }),
        Obx(
          () => switch (subscriptionList.isEmpty) {
            true when Get.find<SubscriptionService>().relatedEnabled =>
              const SizedBox.shrink(),
            true => Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              color: TPColors.primary50,
              child: Row(
                children: [
                  Assets.svg.illustrationsBookingS.svg(width: 54, height: 46),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TPText(
                        '活動、服務、福利 一鍵讓你知'.tr,
                        style: TextStyle(
                          color: TPColors.grayscale800,
                          fontSize: 16,
                          fontFamily: FontFamily.pingFangTC,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TPText(
                        '訂閱設定'.tr,
                        style: const TextStyle(
                          color: TPColors.primary500,
                          fontSize: 16,
                          fontFamily: FontFamily.pingFangTC,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.underline,
                          decorationColor: TPColors.primary500,
                        ),
                        onTap: () async {
                          await TPRoute.openUri(uri: SubscriptionService.settingsUrl);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            false => ColoredBox(
              color: TPColors.white,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 12.0,
                ),
                itemCount: subscriptionList.length,
                separatorBuilder: (_, __) => const TPLine.horizontal(
                  margin: EdgeInsets.symmetric(vertical: 12.0),
                ),
                itemBuilder: (_, index) =>
                    SubscriptionItemWidget(item: subscriptionList[index]),
              ),
            ),
          },
        ),
      ],
    );
  }
}
