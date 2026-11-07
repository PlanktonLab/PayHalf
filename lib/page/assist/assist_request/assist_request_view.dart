import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_speaker.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 有人想協助您：看清楚是誰、要辦什麼，再由長輩自己決定。
class AssistRequestView extends StatelessWidget {
  const AssistRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final id = Get.arguments as String;

    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: const TPAppBar(title: '協助請求'),
      body: AssistTextScaleCap(
        child: Obx(() {
          final s = service.sessions[id];
          if (s == null) return const Center(child: CircularProgressIndicator());
          return AssistTicker(
            builder: (context, now) {
              // 剛按下同意、正在切換到協辦畫面時，不要閃出「已經接受」的頁面
              if (s.isActive) return const Center(child: CircularProgressIndicator());
              final expired = !s.isPending || (s.expiresAt?.isBefore(now) ?? true);
              if (expired) return _Gone(s: s);
              return _Body(s: s, now: now);
            },
          );
        }),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.s, required this.now});
  final AssistSession s;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final h = s.helper!;
    final left = s.expiresAt!.difference(now);

    return AssistActionLayout(
      content: [
        Center(child: AssistHelperAvatar(helper: h, size: 92)),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(assistHelperDisplayName(h), textAlign: TextAlign.center, style: AssistText.largeTitle),
        ),
        const SizedBox(height: 8),
        Center(child: AssistHelperBadge(helper: h)),
        if (h.org != null) ...[
          const SizedBox(height: 6),
          Text(h.org!, textAlign: TextAlign.center, style: AssistText.callout),
        ],
        const SizedBox(height: 12),
        Center(
          child: AssistReadButton(
            id: 'request-${s.id}',
            text: () =>
                '${assistHelperDisplayName(h)}想陪您辦理${s.serviceTitle}。'
                '${h.verified ? '這是市府認證的身分。' : '對方不是公務人員，請確認您認識他。'}'
                '對方看不到您的身分證、地址、電話，這些資料會直接填進申請表，交給承辦機關。每一項都會先問過您，最後也只有您能按送出。'
                '市府、里長、一九九九都不會要您轉帳、給密碼或簡訊驗證碼。'
                '要接受協助，請按好，請他幫我。不要的話，請按不要。',
          ),
        ),
        const SizedBox(height: 20),
        AssistCard(
          child: Column(
            children: [
              const Text('想陪您辦理', style: AssistText.callout),
              const SizedBox(height: 2),
              Text('「${s.serviceTitle}」', textAlign: TextAlign.center, style: AssistText.title),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!h.verified) ...[
          const AssistNotice(
            icon: Icons.info_rounded,
            color: TPColors.secondary800,
            background: TPColors.secondary100,
            title: '對方不是公務人員',
            text: '請確認您認識他，而且是您自己想辦這件事。',
          ),
          const SizedBox(height: 12),
        ],
        const AssistNotice(
          icon: Icons.visibility_off_rounded,
          color: AssistColors.green700,
          background: AssistColors.green50,
          title: '您的資料由您決定',
          text: '對方看不到您的身分證、地址、電話，這些資料會直接填進申請表，交給承辦機關。每一項都會先問過您，最後也只有您能按「送出」。',
        ),
        const SizedBox(height: 12),
        AssistNotice.fraud(),
        const SizedBox(height: 16),
        Semantics(
          label: '這個請求還有 ${assistSpokenDuration(left)} 會自動取消',
          child: ExcludeSemantics(
            child: Text(
              '${assistMmss(left)} 後這個請求自動取消',
              textAlign: TextAlign.center,
              style: AssistText.callout.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ],
      actions: [
        AssistButton(
          '好，請他幫我',
          icon: Icons.check_rounded,
          onPressed: () async {
            if (await assistRun(() => service.respond(s.id, true))) {
              Get.offNamed(TPRoute.assistSession, arguments: s.id);
            }
          },
        ),
        AssistButton(
          '不要',
          style: AssistButtonStyle.secondary,
          onPressed: () async {
            if (await assistRun(() => service.respond(s.id, false))) Get.back();
          },
        ),
        AssistButton(
          '我不認識這個人',
          style: AssistButtonStyle.destructivePlain,
          semanticsHint: '封鎖並回報這個人',
          onPressed: () async {
            final ok = await assistConfirm(
              title: '封鎖這個人？',
              message: '${h.name} 以後不能再傳協助請求給您，市府也會收到回報。',
              confirmLabel: '封鎖並回報',
            );
            if (ok && await assistRun(() => service.block(s.id))) Get.back();
          },
        ),
      ],
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone({required this.s});
  final AssistSession s;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 40),
      Icon(Icons.timer_off_rounded, size: context.iconSize(56), color: TPColors.grayscale400),
      const SizedBox(height: 16),
      Text(s.isActive ? '您已經接受這次協助' : '這個請求已經失效', textAlign: TextAlign.center, style: AssistText.title),
      const SizedBox(height: 8),
      const Text('如果還需要幫忙，可以請對方重新送出，或撥打 1999。', textAlign: TextAlign.center, style: AssistText.callout),
      const SizedBox(height: 24),
      AssistButton(
        s.isActive ? '前往協助畫面' : '回到首頁',
        onPressed: () => s.isActive ? Get.offNamed(TPRoute.assistSession, arguments: s.id) : Get.back(),
      ),
    ],
  );
}
