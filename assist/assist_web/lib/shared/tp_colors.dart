import 'package:flutter/material.dart';

/// 沿用台北通 TownPass 的色票（lib/util/tp_colors.dart），再補上少數狀態色。
abstract final class TPColors {
  static const white = Color(0xFFFFFFFF);

  static const primary50 = Color(0xFFEDF8FA);
  static const primary100 = Color(0xFFDBF1F5);
  static const primary200 = Color(0xFFB4E2EA);
  static const primary300 = Color(0xFF93D4DF);
  static const primary400 = Color(0xFF71C5D5);
  static const primary500 = Color(0xFF5AB4C5);
  static const primary600 = Color(0xFF468D9B);
  static const primary700 = Color(0xFF356C77);
  static const primary800 = Color(0xFF22474E);
  static const primary900 = Color(0xFF112629);

  static const secondary50 = Color(0xFFFDF8ED);
  static const secondary100 = Color(0xFFFCF2DF);
  static const secondary200 = Color(0xFFF8E3BC);
  static const secondary500 = Color(0xFFF5BA4B);
  static const secondary600 = Color(0xFFE7A43C);
  static const secondary700 = Color(0xFFAD7B2B);
  static const secondary800 = Color(0xFF74521B);

  static const grayscale50 = Color(0xFFF1F3F4);
  static const grayscale100 = Color(0xFFE3E7E9);
  static const grayscale200 = Color(0xFFCAD1D5);
  static const grayscale300 = Color(0xFFADB8BE);
  static const grayscale400 = Color(0xFF91A0A8);
  static const grayscale500 = Color(0xFF738995);
  static const grayscale600 = Color(0xFF5E6D76);
  static const grayscale700 = Color(0xFF475259);
  static const grayscale800 = Color(0xFF30383D);
  static const grayscale900 = Color(0xFF171B1D);

  static const red50 = Color(0xFFFAEEEE);
  static const red100 = Color(0xFFF5DCDD);
  static const red200 = Color(0xFFEBB6B6);
  static const red500 = Color(0xFFD45251);
  static const red600 = Color(0xFFC2332F);
  static const red700 = Color(0xFF912522);

  // 補充：成功與資訊狀態色（與主色調和）
  static const green50 = Color(0xFFEAF6EF);
  static const green500 = Color(0xFF3E9E6E);
  static const green700 = Color(0xFF2A6E4C);
  static const blue500 = Color(0xFF4B8DBF);

  /// 台北通帳戶頁、帳單頁使用的品牌漸層
  static const brandGradient = LinearGradient(
    colors: [primary500, blue500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
