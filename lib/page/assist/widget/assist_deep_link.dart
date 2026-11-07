import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/assist_form/assist_form_view.dart';
import 'package:town_pass/service/assist_service.dart';

/// 用 iPhone 相機（或任何 App）打開海報上的 QR Code 連結時，直接進到表單。
///   https://payhalf.plankton.tw/f/<表單>  ← Universal Link（已安裝台北通就不經過 Safari）
///   townpass://f/<表單>                    ← 網頁上「使用台北通開啟」按鈕
StreamSubscription<Uri>? _sub;
String? _last;
DateTime _lastAt = DateTime(2000);

void assistListenDeepLinks() {
  _sub ??= AppLinks().uriLinkStream.listen(_open, onError: (_) {});
}

Future<void> _open(Uri uri) async {
  final id = AssistService.formIdFrom(uri.toString());
  if (id == null) return;
  // 同一個連結短時間內只處理一次（冷啟動時初始連結可能送兩次）
  final now = DateTime.now();
  if (_last == id && now.difference(_lastAt) < const Duration(seconds: 3)) return;
  _last = id;
  _lastAt = now;
  // 冷啟動：等第一個畫面出來再開
  for (var i = 0; i < 30 && Get.key.currentState == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await AssistFormView.open(id);
}
