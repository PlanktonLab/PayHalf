import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 下載文字檔（CSV 前面加 BOM，Excel 開啟中文才不會亂碼）。
void downloadText(String filename, String text, {String mime = 'text/csv;charset=utf-8'}) {
  final blob = web.Blob(['﻿$text'.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// 用瀏覽器內建語音朗讀（長輩預覽的「念給我聽」）。
bool speak(String text) {
  try {
    final synth = web.window.speechSynthesis;
    synth.cancel();
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = 'zh-TW'
      ..rate = 0.85;
    synth.speak(u);
    return true;
  } catch (_) {
    return false;
  }
}

void openInNewTab(String path) => web.window.open('${web.window.location.origin}$path', '_blank');
