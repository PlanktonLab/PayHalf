import 'package:town_pass/page/language/language_view_controller.dart';
import 'package:town_pass/util/tp_i18n.dart';
import 'package:town_pass/util/tp_setting_list.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LanguageView extends GetView<LanguageViewController> {
  const LanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.white,
      appBar: TPAppBar(title: '語言'.tr),
      body: TPSettingList(
        children: [
          TPSettingListTile.selectionList(
            initialIndex: TPLanguage.all.indexOf(TPLanguage.current),
            onIndexChange: (index) => controller.onIndexChange(index),
            selections: [
              for (final l in TPLanguage.all) SettingSelectionListItem(title: l.nativeName),
            ],
          ),
        ],
      ),
    );
  }
}
