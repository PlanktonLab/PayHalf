import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/home/widget/subscription/subscription_widget.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/service/subscription_service.dart';

void main() {
  testWidgets('related subscription updates home and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final account = Get.put(await AccountService().init()).account!;
    Get.put(await SharedPreferencesService().init());
    final service = Get.put(await SubscriptionService().init());
    addTearDown(Get.reset);
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SubscriptionWidget()),
        ),
      ),
    );
    expect(find.text('與我相關'), findsNothing);
    await service.setRelated(true);
    await tester.pumpAndSettle();
    expect(service.relatedEnabled, isTrue);
    expect((await SubscriptionService().init()).relatedEnabled, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('與我相關'), findsOneWidget);
    expect(find.text('北市圖｜申辦個人借閱證'), findsOneWidget);
    expect(find.textContaining('Show Up'), findsNothing);
    expect(Get.find<AccountService>().account?.id, account.id);
    await service.setRelated(false);
    await tester.pumpAndSettle();
    expect(find.text('與我相關'), findsNothing);
  });
}
