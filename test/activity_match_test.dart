import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/bean/account.dart';
import 'package:town_pass/bean/activity.dart';
import 'package:town_pass/service/activity_match.dart';

void main() {
  final accountData =
      jsonDecode(
            File('assets/mock_data/account.json').readAsStringSync(),
          )['data']
          as Map<String, dynamic>;
  final account = Account.fromJson(accountData);
  final now = DateTime(2026, 11, 7, 12);
  ActivityItem item(ActivityAudience? audience) => ActivityItem(
    audience: audience,
    title: '',
    content: '',
    imageUrl: '',
    webUrl: null,
    startDateTime: DateTime(2026, 11, 1),
    endDateTime: DateTime(2026, 11, 30, 17),
  );

  test('location alone never establishes subsidy eligibility', () {
    final subsidy = item(ActivityAudience.taipei);
    expect(matchActivity(subsidy, account, now)?.label, '與你相關');
    final otherCity = Account.fromJson({
      ...accountData,
      'residentAddress': '新北市中和區',
    });
    expect(matchActivity(subsidy, otherCity, now), isNull);
    final nearby = Account.fromJson({
      ...accountData,
      'residentAddress': '台北市萬華區',
    });
    expect(
      matchActivity(item(ActivityAudience.wanhua), nearby, now)?.label,
      '與你相關',
    );
    expect(matchActivity(item(ActivityAudience.daan), nearby, now), isNull);
  });

  test(
    'no badge outside the announcement window, without account or audience',
    () {
      final card = item(ActivityAudience.personalLibraryCard);
      expect(matchActivity(card, account, now)?.label, '可申請');
      expect(matchActivity(card, null, now), isNull);
      expect(matchActivity(card, account, DateTime(2026, 10, 31)), isNull);
      expect(matchActivity(card, account, DateTime(2026, 11, 30, 18)), isNull);
      expect(matchActivity(item(null), account, now), isNull);
    },
  );

  test(
    'age-based relevance starts on the birthday and ignores malformed dates',
    () {
      final renewal = item(ActivityAudience.olderDriver);
      Account born(String date) =>
          Account.fromJson({...accountData, 'birthday': date});
      expect(matchActivity(renewal, born('1956/11/08'), now), isNull);
      expect(matchActivity(renewal, born('1956/11/07'), now)?.label, '與你相關');
      expect(matchActivity(renewal, born('1956/02/31'), now), isNull);
    },
  );
}
