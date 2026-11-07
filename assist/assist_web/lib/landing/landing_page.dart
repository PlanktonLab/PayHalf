import 'package:flutter/material.dart';

import '../shared/console_kit.dart';
import '../shared/widgets.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget entry(IconData icon, String title, String desc, String route, {String? kbd}) => CPanel(
      onTap: () => Navigator.of(context).pushNamed(route),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CIconTile(icon, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CText.bodyStrong),
                const SizedBox(height: 2),
                Text(desc, style: CText.small),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: C.ink4),
        ],
      ),
    );

    return Theme(
      data: buildConsoleTheme(),
      child: Scaffold(
        backgroundColor: C.canvas,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      TownPassLogo(size: 26),
                      SizedBox(width: 10),
                      Text('台北通　陪辦', style: CText.title),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('不是代填，是陪填', style: CText.pageTitle),
                  const SizedBox(height: 8),
                  const Text('協助者帶著走每一步，所有資料的授權與送出，只發生在長輩本人已實名登入的手機上。', style: CText.secondary),
                  const SizedBox(height: 24),
                  entry(Icons.view_column_outlined, '並排示範', '同一個畫面看承辦工作台與長輩手機，適合評審展示。', '/demo'),
                  const SizedBox(height: 10),
                  entry(Icons.space_dashboard_outlined, '承辦工作台', '里長、家人或 1999 客服陪長輩辦；承辦人建立民眾表單。', '/console'),
                  const SizedBox(height: 10),
                  entry(Icons.phone_iphone_rounded, '長輩的手機', '模擬已登入台北通的長輩手機，可在另一台裝置開啟。', '/elder'),
                  const SizedBox(height: 20),
                  const Text('雙裝置示範：電腦開「承辦工作台」，手機瀏覽器開同一個網址的「長輩的手機」。', style: CText.small),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
