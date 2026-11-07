String two(int n) => n.toString().padLeft(2, '0');

String hm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
String hms(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
String ymdhm(DateTime t) => '${t.year}/${two(t.month)}/${two(t.day)} ${hm(t)}';

String mmss(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 60)}:${two(s % 60)}';
}

/// 長輩畫面預設遮蔽，避免旁人（包含協助者）從旁偷看。
String maskValue(String key, String? value) {
  if (value == null || value.isEmpty) return '';
  switch (key) {
    case 'idNo':
      return value.length < 4 ? value : '${value.substring(0, 2)}*****${value.substring(value.length - 3)}';
    case 'phone':
      final digits = value.replaceAll('-', '');
      return digits.length < 7 ? value : '${digits.substring(0, 4)}-***-${digits.substring(digits.length - 3)}';
    case 'residentAddress':
      return value.length < 6 ? value : '${value.substring(0, 6)}＊＊＊＊';
    case 'birthday':
      return value.length < 4 ? value : '${value.substring(0, 4)}-**-**';
    default:
      return value;
  }
}
