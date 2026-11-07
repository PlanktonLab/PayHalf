import 'package:flutter/material.dart';

import 'elder/elder_app.dart';
import 'helper/helper_app.dart';
import 'landing/landing_page.dart';
import 'shared/theme.dart';
import 'shared/tp_colors.dart';

void main() => runApp(const AssistDemoApp());

class AssistDemoApp extends StatelessWidget {
  const AssistDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '台北通 陪你辦',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      onGenerateRoute: (settings) {
        final Widget page = switch (settings.name) {
          '/helper' => const HelperApp(),
          '/elder' => const ElderApp(),
          '/demo' => const SplitDemo(),
          _ => const LandingPage(),
        };
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        );
      },
    );
  }
}

/// 一個畫面並排兩個身分：左邊協助者（電腦版），右邊長輩手機。
class SplitDemo extends StatelessWidget {
  const SplitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(child: HelperApp(compact: true)),
          Container(width: 1, color: TPColors.grayscale200),
          const SizedBox(width: 500, child: ElderApp()),
        ],
      ),
    );
  }
}
