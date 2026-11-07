import 'package:town_pass/page/setting/assist_identity_view.dart';
import 'package:town_pass/page/setting/assist_server_view.dart';
import 'package:town_pass/page/setting/setting_view_controller.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_setting_list.dart';
import 'package:town_pass/util/extension/datetime.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_bottom_sheet.dart';
import 'package:town_pass/util/tp_button.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/util/tp_i18n.dart';

class SettingView extends GetView<SettingViewController> {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      init: Get.put<SettingViewController>(SettingViewController()),
      builder: (controller) {
        return Scaffold(
          appBar: TPAppBar(title: '設定'.tr),
          body: TPSettingList(
            children: [
              TPSettingListTile.header(title: '個人資料'.tr),
              TPSettingListTile.navigate(
                title: '基本資料'.tr,
                onTap: () => Get.toNamed(TPRoute.basicInfo),
              ),
              TPSettingListTile.line(),
              TPSettingListTile.navigate(
                title: '語言'.tr,
                onTap: () => Get.toNamed(TPRoute.language),
              ),
              TPSettingListTile.header(title: '偏好設定'.tr),
              TPSettingListTile.navigate(
                title: 'APP起始頁面'.tr,
                onTap: () => Get.toNamed(TPRoute.settingStartPage),
              ),
              TPSettingListTile.header(title: '通知'.tr),
              TPSettingListTile.switchButton(title: '訊息通知提醒'.tr),
              TPSettingListTile.header(title: '發票設定'.tr),
              TPSettingListTile.navigate(
                title: '手機載具'.tr,
                onTap: () => Get.toNamed(TPRoute.invoiceReceipt),
              ),
              TPSettingListTile.header(title: '安全性'.tr),
              TPSettingListTile.navigate(title: '歷程與授權管理'.tr),
              TPSettingListTile.line(),
              TPSettingListTile.switchButton(title: '快速登入'.tr),
              TPSettingListTile.line(),
              TPSettingListTile.navigate(
                title: '停用帳號'.tr,
                onTap: () => Get.toNamed(TPRoute.suspendAccount),
              ),
              TPSettingListTile.header(title: '開發測試'.tr),
              TPSettingListTile.navigate(
                title: '測試身分'.tr,
                content: AssistIdentityView.summary(Get.find<AssistService>()),
                onTap: () async {
                  await Get.to(() => const AssistIdentityView());
                  controller.update();
                },
              ),
              TPSettingListTile.line(),
              TPSettingListTile.navigate(
                title: '陪辦伺服器'.tr,
                content: AssistServerView.labelFor(Get.find<AssistService>().server.value),
                onTap: () async {
                  await Get.to(() => const AssistServerView());
                  controller.update();
                },
              ),
            ],
          ),
          bottomNavigationBar: TPBottomSheet(
            child: Column(
              children: [
                TPText(
                  trf('最後登入時間：{0}', [controller.lastLoginDateTime.format('yyyy/MM/dd HH:mm:ss')]),
                  style: TPTextStyles.bodyRegular,
                  color: TPColors.primary500,
                ),
                const SizedBox(height: 10),
                TPButton.primary(text: '登出'.tr),
              ],
            ),
          ),
        );
      },
    );
  }
}
