import 'package:intl/intl.dart';
import 'package:town_pass/bean/account.dart';
import 'package:town_pass/bean/activity.dart';

typedef ActivityMatch = ({String label, String reason});

ActivityMatch? matchActivity(
  ActivityItem item,
  Account? account,
  DateTime now,
) {
  if (account == null ||
      account.memberType != 'personal' ||
      now.isBefore(item.startDateTime) ||
      (item.endDateTime?.isBefore(now) ?? false))
    return null;

  final audience = item.audience;
  if (audience == null) return null;
  if (audience == ActivityAudience.personalLibraryCard) {
    return (label: '可申請', reason: '北市圖受理個人申辦。首次辦證可線上申請，已有借閱證請查閱換補發方式。');
  }
  if (audience == ActivityAudience.olderDriver) {
    final birth = DateFormat('yyyy/MM/dd')
        .tryParseStrict(account.birthday.replaceAll('-', '/'));
    if (birth == null ||
        DateTime(birth.year + 70, birth.month, birth.day).isAfter(now))
      return null;
    return (label: '與你相關', reason: '你的帳戶年齡已滿 70 歲；如持有駕照，可查看高齡換照資訊。');
  }
  final address = account.residentAddress.trim().replaceAll('台', '臺');
  final district = switch (audience) {
    ActivityAudience.daan => '大安區',
    ActivityAudience.zhongzheng => '中正區',
    ActivityAudience.wanhua => '萬華區',
    _ => '',
  };
  if (!address.startsWith('臺北市$district')) return null;
  return (
    label: '與你相關',
    reason: district.isEmpty
        ? '你的帳戶地址位於臺北市，這則市政資訊適用於本市。若為補助，仍須核對公告資格。'
        : '活動位於$district，與你的帳戶地址在同一行政區。',
  );
}
