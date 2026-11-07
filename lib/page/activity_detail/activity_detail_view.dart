import 'package:town_pass/page/activity_list/activity_tag.dart';
import 'package:town_pass/page/assist/assist_form/assist_form_view.dart';
import 'package:town_pass/util/tp_cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/activity.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_bottom_sheet.dart';
import 'package:town_pass/util/tp_button.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_duration.dart';
import 'package:town_pass/util/tp_line.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_text.dart';

class ActivityDetailView extends StatelessWidget {
  const ActivityDetailView({super.key});

  ActivityItem get activity => Get.arguments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.white,
      appBar: const TPAppBar(title: '活動訊息'),
      body: Column(
        children: [
          TPCachedNetworkImage(imageUrl: activity.imageUrl, width: double.infinity, height: 128, fit: BoxFit.contain),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TPText(
              activity.title,
              style: TPTextStyles.h3SemiBold,
              color: TPColors.primary500,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    child: _ActivityDurationWidget(
                      duration: TPDuration(
                        start: activity.startDateTime,
                        end: activity.endDateTime,
                      ),
                    ),
                  ),
                  ActivityTag(activity, explain: true),
                  const TPLine.horizontal(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TPText(
                        activity.content,
                        style: TPTextStyles.h3Regular,
                        color: TPColors.grayscale800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: switch (activity.webUrl) {
        _ when activity.formId != null => TPBottomSheet(
            child: Column(
              children: [
                TPButton.primary(
                  text: '立即報名',
                  onPressed: () => AssistFormView.open(activity.formId!),
                ),
                const SizedBox(height: 12),
                TPButton.secondary(
                  text: '需要別人協助填寫',
                  onPressed: () => AssistFormView.open(activity.formId!, askHelp: true),
                ),
              ],
            ),
          ),
        null => null,
        String() => TPBottomSheet(
            child: Column(
              children: [
                TPButton.primary(
                  text: '網址連結',
                  onPressed: () async => await TPRoute.openUri(
                    uri: activity.webUrl ?? '',
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _ActivityDurationWidget extends StatelessWidget {
  final TPDuration duration;

  const _ActivityDurationWidget({
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Assets.svg.iconCalender.svg(width: 24, height: 24),
        const SizedBox(width: 16),
        TPText(
          duration.format(),
          style: TPTextStyles.h3Regular,
          color: TPColors.grayscale800,
        ),
      ],
    );
  }
}
