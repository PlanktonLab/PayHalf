import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/assist/widget/assist_deep_link.dart';
import 'package:town_pass/page/assist/widget/assist_remote_frame.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/service/device_service.dart';
import 'package:town_pass/service/geo_locator_service.dart';
import 'package:town_pass/service/notification_service.dart';
import 'package:town_pass/service/package_service.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/service/subscription_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_i18n.dart';
import 'package:town_pass/util/tp_route.dart';

const _transparentStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
);

/// 上次選的語言（多國語系）
Locale _initialLocale = TPLanguage.zhTW.locale;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(
  //   widgetsBinding: WidgetsFlutterBinding.ensureInitialized(),
  // );

  // 介面沒有做橫向版面：鎖定直式
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initServices();
  _initialLocale = await TPLanguage.initial();

  SystemChrome.setSystemUIOverlayStyle(_transparentStatusBar);

  runApp(const MyApp());
}

Future<void> initServices() async {
  await Get.putAsync<AccountService>(() async => await AccountService().init());
  await Get.putAsync<DeviceService>(() async => await DeviceService().init());
  await Get.putAsync<PackageService>(() async => await PackageService().init());
  await Get.putAsync<SharedPreferencesService>(() async => await SharedPreferencesService().init());
  await Get.putAsync<GeoLocatorService>(() async => await GeoLocatorService().init());
  await Get.putAsync<NotificationService>(() async => await NotificationService().init());

  await Get.putAsync<SubscriptionService>(() => SubscriptionService().init());
  // 陪辦：背景連線，不阻塞啟動
  Get.put<AssistService>(AssistService().init());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Town Pass',
      translations: TPTranslations(),
      locale: _initialLocale,
      fallbackLocale: TPLanguage.zhTW.locale,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TPColors.grayscale50,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: TPColors.white,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: TPColors.primary500),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0.0,
          iconTheme: IconThemeData(size: 56),
          actionsIconTheme: IconThemeData(size: 56),
        ),
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (_) => Semantics(
            excludeSemantics: true,
            child: Assets.svg.iconArrowLeft.svg(width: 24, height: 24),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: TPRoute.main,
      onInit: () {
        NotificationService.requestPermission();
        // 相機掃海報 QR Code → 直接打開表單
        assistListenDeepLinks();
      },
      getPages: TPRoute.page,
      // 讓陪辦提示膠囊知道目前在哪一頁（在協辦畫面本身就不顯示，避免重複）
      routingCallback: (r) {
        if (r != null && Get.isRegistered<AssistService>()) Get.find<AssistService>().route.value = r.current;
      },
      // 陪辦進行中：整個畫面加上光框與「某某 正在陪您操作」提示
      builder: (context, child) => AssistRemoteFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}