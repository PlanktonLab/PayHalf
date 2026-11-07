import 'dart:async';
import 'package:town_pass/service/subscription_service.dart';

import 'package:town_pass/bean/activity.dart';
import 'package:get/get.dart';

class ActivityBannerWidgetController extends GetxController {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  set isLoading(bool value) {
    _isLoading = value;
    update();
  }

  ActivityList? list;

  @override
  void onInit() {
    super.onInit();

    _isLoading = true;

    Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        timer.cancel();
        list = Get.find<SubscriptionService>().activities;
        isLoading = false;
      },
    );
  }
}
