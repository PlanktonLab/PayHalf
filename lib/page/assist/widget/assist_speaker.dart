import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 朗讀：使用手機系統內建語音，不使用雲端服務（沿用陪辦微服務的做法）。
///
/// 只念說明、用途與風險提醒，不念出身分證字號等個資內容，避免旁人聽到。
abstract final class AssistSpeaker {
  static final FlutterTts _tts = FlutterTts();
  static final RxnString speakingKey = RxnString();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      // iOS 靜音模式下也要念得出來
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
      await _tts.setLanguage('zh-TW');
      await _tts.setSpeechRate(0.45);
      _tts.setCompletionHandler(() => speakingKey.value = null);
      _tts.setCancelHandler(() => speakingKey.value = null);
      _tts.setErrorHandler((_) => speakingKey.value = null);
    } catch (_) {}
  }

  static Future<void> speak(String key, String text) async {
    await _init();
    await _tts.stop();
    speakingKey.value = key;
    try {
      await _tts.speak(text);
    } catch (_) {
      speakingKey.value = null;
    }
  }

  static Future<void> stop() async {
    speakingKey.value = null;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// 「念給我聽」按鈕。離開畫面時自動停止。
class AssistReadButton extends StatefulWidget {
  const AssistReadButton({super.key, required this.id, required this.text, this.onDark = false});

  /// 用來辨識哪一顆按鈕正在念
  final String id;
  final String Function() text;
  final bool onDark;

  @override
  State<AssistReadButton> createState() => _AssistReadButtonState();
}

class _AssistReadButtonState extends State<AssistReadButton> {
  @override
  void dispose() {
    if (AssistSpeaker.speakingKey.value == widget.id) AssistSpeaker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final on = AssistSpeaker.speakingKey.value == widget.id;
      final fg = widget.onDark ? TPColors.white : TPColors.primary700;
      return Semantics(
        button: true,
        label: on ? '停止朗讀' : '念給我聽',
        excludeSemantics: true,
        child: TextButton.icon(
          onPressed: () => on ? AssistSpeaker.stop() : AssistSpeaker.speak(widget.id, widget.text()),
          style: TextButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: widget.onDark ? TPColors.white.withValues(alpha: 0.18) : TPColors.primary50,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          ),
          icon: Icon(on ? Icons.stop_circle_rounded : Icons.volume_up_rounded, size: context.iconSize(22)),
          label: Text(
            on ? '停止' : '念給我聽',
            style: AssistText.callout.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
      );
    });
  }
}
