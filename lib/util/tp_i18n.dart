import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/util/i18n/tp_translations_data.dart';

/// 多國語系：以繁體中文原文當 key（`'中文'.tr`），找不到翻譯就顯示中文，
/// 所以新加的字串不會壞掉，只是還沒翻。翻譯表在 i18n/tp_translations_data.dart。
///
/// 語言是「使用者的設定」：正式版在註冊台北通帳號時選，demo 則在左上角「切換身分」面板切換；
/// 選好的語言會存在後端使用者資料（換手機登入也一樣），本機也記一份，開 App 時先套用。
class TPLanguage {
  const TPLanguage(this.code, this.nativeName, this.locale);
  final String code;
  final String nativeName;
  final Locale locale;

  static const zhTW = TPLanguage('zh-TW', '繁體中文', Locale('zh', 'TW'));

  static const all = <TPLanguage>[
    zhTW,
    TPLanguage('en', 'English', Locale('en', 'US')),
    TPLanguage('vi', 'Tiếng Việt', Locale('vi', 'VN')),
    TPLanguage('id', 'Bahasa Indonesia', Locale('id', 'ID')),
    TPLanguage('th', 'ภาษาไทย', Locale('th', 'TH')),
    TPLanguage('ja', '日本語', Locale('ja', 'JP')),
    TPLanguage('ko', '한국어', Locale('ko', 'KR')),
  ];

  static TPLanguage of(String? code) => all.firstWhere((l) => l.code == code, orElse: () => zhTW);

  static TPLanguage get current {
    final l = Get.locale;
    return all.firstWhere((e) => e.locale.languageCode == l?.languageCode, orElse: () => zhTW);
  }

  static const _prefKey = 'tp_language';

  /// 開 App 時讀本機記住的語言
  static Future<Locale> initial() async {
    try {
      final p = await SharedPreferences.getInstance();
      return of(p.getString(_prefKey)).locale;
    } catch (_) {
      return zhTW.locale;
    }
  }

  /// 套用語言（整個 App 立刻重畫）並記在本機
  static Future<void> apply(String? code) async {
    final lang = of(code);
    if (Get.locale?.languageCode != lang.locale.languageCode) {
      await Get.updateLocale(lang.locale);
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, lang.code);
    } catch (_) {}
  }
}

class TPTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => tpTranslations;
}

/// 有變數的字串：`trf('還有 {0} 分鐘', [n])`
String trf(String key, List<Object?> args) {
  var s = key.tr;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return s;
}
