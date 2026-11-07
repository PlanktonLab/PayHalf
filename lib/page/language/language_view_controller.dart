import 'package:get/get.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_i18n.dart';

class LanguageViewController extends GetxController {
  List<TPLanguage> get languageList => TPLanguage.all;

  /// 與左上角「切換身分」面板的語言選擇同一套：套用並記在帳號上
  void onIndexChange(int index) {
    final code = TPLanguage.all[index].code;
    if (Get.isRegistered<AssistService>()) {
      Get.find<AssistService>().setLanguage(code);
    } else {
      TPLanguage.apply(code);
    }
  }
}
