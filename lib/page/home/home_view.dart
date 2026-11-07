import 'package:flutter/material.dart';
import 'package:town_pass/page/assist/widget/assist_home_section.dart';
import 'package:town_pass/page/assist/widget/assist_persona_switcher.dart';
import 'package:town_pass/page/assist/widget/assist_scan.dart';
import 'package:town_pass/page/home/widget/activity_info/activity_info_widget.dart';
import 'package:town_pass/page/home/widget/city_news/city_news_widget.dart';
import 'package:town_pass/page/home/widget/news/news_banner_widget.dart';
import 'package:town_pass/page/home/widget/subscription/subscription_widget.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:get/get.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        showLogo: true,
        title: '首頁'.tr,
        // Demo：左上角直接切換「這支手機是誰」，帳戶頁從切換面板進
        leading: const AssistPersonaButton(),
        leadingWidth: AssistPersonaButton.width,
        backgroundColor: TPColors.white,
      ),
      floatingActionButton: const AssistScanButton(),
      body: const CustomScrollView(
        slivers: [
          // 陪辦：有人想協助時，首頁最上方出現持續性徽章
          SliverToBoxAdapter(child: AssistHomeBadge()),
          _SliverGap(20),
          SliverToBoxAdapter(child: NewsBannerWidget()),
          _SliverGap(20),
          SliverToBoxAdapter(child: ActivityInfoWidget()),
          _SliverGap(8),
          SliverToBoxAdapter(child: CityNewsWidget()),
          _SliverGap(12),
          // 協助者身分：信任我的長輩請我幫忙時才出現
          SliverToBoxAdapter(child: AssistHelpCallCard()),
          SliverToBoxAdapter(child: AssistEntryCard()),
          _SliverGap(16),
          SliverToBoxAdapter(child: SubscriptionWidget()),
          // 留空間給右下角的「掃描」按鈕，最下面的內容才不會被擋住
          _SliverGap(96),
        ],
      ),
    );
  }
}

class _SliverGap extends StatelessWidget {
  const _SliverGap(this.height);

  final double height;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: SizedBox(height: height));
  }
}