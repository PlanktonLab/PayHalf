import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:town_pass/gen/assets.gen.dart';

abstract final class TrendingServiceModel {
  static List<TrendingService> get serviceList {
    return [
      TrendingService(
        title: '找地點',
        icon: Assets.svg.iconLocationSearch.svg(),
        url: 'https://taipei-pass-service.vercel.app/surrounding-service/',
      ),
      TrendingService(
        icon: Assets.svg.iconDashboardReports.svg(),
        title: '市政資訊儀表板',
        url: 'https://dashboard.gov.taipei/',
        forceWebViewTitle: '市政資訊儀表板',
      ),
      TrendingService(
        icon: Assets.svg.iconLocationSearch.svg(),
        title: '施工資訊',
        url: '',
      ),
      TrendingService(
        icon: Assets.svg.iconAccompany.svg(),
        title: '陪辦',
        url: assistServiceUrl,
        forceWebViewTitle: '陪辦',
      ),
      // 在此列表後加入新熱門按鈕
      // add new trending service button here
    ];
  }

  /// 「陪辦」微服務網址(長輩由人協助申請,長輩只需確認)。
  ///
  /// 以建置參數指定:`flutter run --dart-define=ASSIST_SERVICE_URL=https://example.com/assist/`
  /// - debug 版沒指定時,預設連到本機開發伺服器(Android 模擬器以 10.0.2.2 連到本機)。
  /// - release 版沒指定時為空字串,等同尚未開放(和「施工資訊」一樣點了不會開啟)。
  static const String assistServiceUrl = String.fromEnvironment(
    'ASSIST_SERVICE_URL',
    defaultValue: kDebugMode ? 'http://10.0.2.2:5173/assist/' : '',
  );
}

class TrendingService {
  final Widget icon;
  final String title;
  final String url;
  final String? forceWebViewTitle;

  const TrendingService({
    required this.icon,
    required this.title,
    required this.url,
    this.forceWebViewTitle,
  });
}
