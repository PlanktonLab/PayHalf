import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_home_section.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/home/widget/activity_info/activity_info_widget.dart';
import 'package:town_pass/page/home/widget/city_news/city_news_widget.dart';
import 'package:town_pass/page/home/widget/news/news_banner_widget.dart';
import 'package:town_pass/page/home/widget/subscription/subscription_widget.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        showLogo: true,
        title: '首頁',
        leading: IconButton(
          icon: Semantics(
            label: '帳戶',
            child: Assets.svg.iconPerson.svg(),
          ),
          onPressed: () => Get.toNamed(TPRoute.account),
        ),
        backgroundColor: TPColors.white,
      ),
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
          SliverToBoxAdapter(child: AssistEntryCard()),
          _SliverGap(16),
          SliverToBoxAdapter(child: SubscriptionWidget()),
          _SliverGap(32),
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