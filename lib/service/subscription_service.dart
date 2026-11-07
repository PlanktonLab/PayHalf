import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:town_pass/bean/activity.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/activity_match.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/subscription.dart';

class SubscriptionService extends GetxService {
  static const settingsUrl = 'https://taipei-pass-service.vercel.app/subscription';
  static const relatedTitle = '訂閱與我相關';

  final RxList<SubscriptionItem> itemList = RxList();

  final _relatedByAccount = <String, bool>{}.obs;
  late final ActivityList activities;

  String? get _accountId => Get.find<AccountService>().account?.id;
  String _key(String id) => 'subscriptions.related.$id';

  bool get relatedEnabled {
    final id = _accountId;
    if (id == null || id.isEmpty) return false;
    return _relatedByAccount[id] ??
        Get.find<SharedPreferencesService>().instance.getBool(_key(id)) ??
        false;
  }

  Future<void> setRelated(bool enabled) async {
    final id = _accountId;
    if (id == null || id.isEmpty) return;
    _relatedByAccount[id] = enabled;
    await Get.find<SharedPreferencesService>().instance.setBool(
      _key(id),
      enabled,
    );
  }

  List<ActivityItem> get relatedActivities {
    final account = Get.find<AccountService>().account;
    final now = DateTime.now();
    return activities.data
        .where((item) => matchActivity(item, account, now) != null)
        .toList();
  }

  Future<SubscriptionService> init() async {
    final json = await rootBundle.loadString(Assets.mockData.activity);
    activities = ActivityList.fromJson(jsonDecode(json));
    return this;
  }

  /// 新增訂閱項目，預設產生兩筆測試用的模擬資料
  void addSubscription({required String title}) {
    final now = DateTime.now();
    itemList.addAll([
      SubscriptionItem(title: title, content: '$title內容 ' * 20, datetime: now),
      SubscriptionItem(title: title, content: '$title內容2 ' * 20, datetime: now),
    ]);
  }

  void removeSubscription({required String title}) {
    itemList.removeWhere((item) => item.title == title);
  }
}
