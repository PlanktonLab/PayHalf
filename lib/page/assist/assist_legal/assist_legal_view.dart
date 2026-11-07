import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// 我的權利與法規說明：任何時候都能查閱。
class AssistLegalView extends StatelessWidget {
  const AssistLegalView({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: const TPAppBar(title: '我的權利與法規'),
      body: AssistTextScaleCap(
        child: Obx(() {
          final legal = service.legal.value;
          if (legal == null) return const Center(child: CircularProgressIndicator());
          final sections = (legal['sections'] as List).cast<Map>();
          final hotlines = (legal['hotlines'] as List).cast<Map>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              for (final sec in sections) ...[
                AssistCard(
                  color: sec['highlight'] == true ? TPColors.red50 : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          sec['title'] as String,
                          style: AssistText.headline.copyWith(color: sec['highlight'] == true ? TPColors.red700 : null),
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final line in (sec['body'] as List).cast<String>())
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ExcludeSemantics(child: Text('・', style: AssistText.body)),
                              Expanded(child: Text(line, style: AssistText.body)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Semantics(header: true, child: const Text('有問題請打電話', style: AssistText.title)),
              const SizedBox(height: 10),
              AssistCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < hotlines.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                      ListTile(
                        minVerticalPadding: 14,
                        leading: Icon(Icons.phone_rounded, color: TPColors.primary500, size: context.iconSize(28)),
                        title: Text(hotlines[i]['label'] as String, style: AssistText.body),
                        subtitle: Text(
                          hotlines[i]['number'] as String,
                          style: AssistText.headline.copyWith(color: TPColors.primary700),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, size: context.iconSize(26)),
                        onTap: () => launchUrlString('tel://${(hotlines[i]['number'] as String).replaceAll('-', '')}'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('最後更新：${legal['updatedAt']}。條文為摘要，以全國法規資料庫為準。', style: AssistText.footnote),
            ],
          );
        }),
      ),
    );
  }
}
