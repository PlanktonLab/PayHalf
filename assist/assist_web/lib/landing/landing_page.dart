import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/tp_colors.dart';
import '../shared/widgets.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget entry(IconData icon, String title, String desc, String route, {bool primary = false}) => SizedBox(
      width: 300,
      child: TPCard(
        onTap: () => route.startsWith('/admin')
            ? launchUrl(Uri.parse('${Uri.base.origin}$route'), webOnlyWindowName: '_self')
            : Navigator.of(context).pushNamed(route),
        color: primary ? TPColors.primary50 : TPColors.white,
        border: primary ? Border.all(color: TPColors.primary300, width: 2) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: TPColors.brandGradient, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: TPColors.white, size: 28),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(color: TPColors.grayscale600, height: 1.6)),
            const SizedBox(height: 14),
            Text(
              '開啟 →',
              style: TextStyle(color: TPColors.primary600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TPColors.primary50, TPColors.grayscale50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      TownPassLogo(size: 30),
                      SizedBox(width: 12),
                      Text('台北通　陪你辦', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '不是代填，是陪填。協助者帶著走每一步，所有資料的授權與送出，只發生在長輩本人已實名登入的手機上。',
                    style: TextStyle(fontSize: 17, color: TPColors.grayscale700, height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      entry(Icons.view_column_rounded, '並排示範', '一個畫面同時看協助者工作台與長輩手機，適合評審展示。', '/demo', primary: true),
                      entry(Icons.desktop_windows_rounded, '協助者工作台', '里長、家人或 1999 客服使用的電腦版介面。', '/helper'),
                      entry(Icons.phone_iphone_rounded, '長輩的手機', '模擬已登入台北通的長輩手機。可在另一台裝置開啟。', '/elder'),
                      entry(Icons.dynamic_form_rounded, '承辦人表單後台', '各局處建立民眾要填的表單，並決定是否開放陪你辦。', '/admin/'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '雙裝置示範：在電腦開「協助者工作台」，在手機瀏覽器開同一個網址的「長輩的手機」。',
                    style: TextStyle(color: TPColors.grayscale500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
