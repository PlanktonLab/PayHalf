import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/assist/assist_help_others/assist_help_others_view.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 首頁最上方的持續性徽章。
///
/// 刻意不用彈出視窗：長輩可能誤觸關閉。徽章沒有關閉鈕，
/// 會一直留在首頁並倒數，直到長輩回應或請求逾時才消失。
class AssistHomeBadge extends StatelessWidget {
  const AssistHomeBadge({super.key, this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 0)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return AssistTextScaleCap(
      child: Obx(() {
        // 讀取 sessions 讓 Obx 追蹤變化
        service.sessions.length;
        final active = service.active;
        return AssistTicker(
          builder: (context, now) {
            final incoming = service.incoming;
            final Widget child;
            if (active != null) {
              child = _ActiveBadge(key: ValueKey('active-${active.id}'), s: active, padding: padding);
            } else if (incoming != null) {
              child = _IncomingBadge(key: ValueKey('incoming-${incoming.id}'), s: incoming, now: now, padding: padding);
            } else {
              child = const SizedBox(width: double.infinity, key: ValueKey('none'));
            }
            return AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => SizeTransition(
                sizeFactor: a,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: a, child: c),
              ),
              child: child,
            );
          },
        );
      }),
    );
  }
}

class _IncomingBadge extends StatelessWidget {
  const _IncomingBadge({super.key, required this.s, required this.now, required this.padding});
  final AssistSession s;
  final DateTime now;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final h = s.helper!;
    final left = s.expiresAt!.difference(now);
    final total = s.expiresAt!.difference(s.createdAt).inSeconds.clamp(1, 1 << 30);
    final progress = (left.inSeconds / total).clamp(0.0, 1.0);
    final urgent = left.inSeconds <= 30;
    // 無障礙大字時，把「查看並回應」放在最上面，不用往下捲才找得到
    final big = context.largeText;
    final respond = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56, minWidth: double.infinity),
      child: TextButton(
        onPressed: () => Get.toNamed(TPRoute.assistRequest, arguments: s.id),
        style: TextButton.styleFrom(
          backgroundColor: TPColors.white,
          foregroundColor: TPColors.primary700,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('查看並回應', style: AssistText.button),
      ),
    );

    return Padding(
      padding: padding,
      child: Semantics(
        container: true,
        label:
            '協助請求。${assistHelperDisplayName(h)} 想陪您辦理${s.serviceTitle}。'
            '${s.helperTrusted ? '這是您信任的人。' : ''}${h.verified ? '市府認證身分。' : '對方不是公務人員。'}剩下 ${assistSpokenDuration(left)}。',
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AssistColors.brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // 用 Text.rich 讓圖示跟文字一起換行，最大字級時不會溢出
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: TPColors.white,
                                size: context.iconSize(22),
                              ),
                            ),
                          ),
                          const TextSpan(text: '有人想協助您'),
                        ],
                      ),
                      style: AssistText.headline.copyWith(color: TPColors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgent ? TPColors.secondary500 : TPColors.white,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '剩 ${assistMmss(left)}',
                        textScaler: context.cappedScaler,
                        style: AssistText.headline.copyWith(
                          color: urgent ? TPColors.grayscale900 : TPColors.primary800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (big) ...[const SizedBox(height: 14), respond],
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Row(
                  children: [
                    Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.white),
                      padding: const EdgeInsets.all(3),
                      child: AssistHelperAvatar(helper: h, size: 52),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(assistHelperDisplayName(h), style: AssistText.title.copyWith(color: TPColors.white)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (s.helperTrusted)
                                const AssistPill(
                                  '您信任的人',
                                  color: AssistColors.green700,
                                  background: AssistColors.green50,
                                  icon: Icons.favorite_rounded,
                                ),
                              AssistHelperBadge(helper: h),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: Text('想陪您辦理「${s.serviceTitle}」', style: AssistText.body.copyWith(color: TPColors.white)),
              ),
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: TPColors.white.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(urgent ? TPColors.secondary500 : TPColors.white),
                  ),
                ),
              ),
              if (!big) ...[const SizedBox(height: 16), respond],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({super.key, required this.s, required this.padding});
  final AssistSession s;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final h = s.helper!;
    final needsYou = s.pendingAuthField != null || s.isReviewing;
    final big = context.largeText;
    final goBack = AssistButton(
      needsYou ? '前往確認' : '回到協助畫面',
      icon: Icons.arrow_forward_rounded,
      onPressed: () => Get.toNamed(TPRoute.assistSession, arguments: s.id),
    );
    return Padding(
      padding: padding,
      child: AssistCard(
        border: Border.all(color: needsYou ? TPColors.secondary500 : TPColors.primary300, width: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AssistHelperAvatar(helper: h, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${assistHelperDisplayName(h)} 正在陪您辦理「${s.serviceTitle}」', style: AssistText.headline),
                ),
              ],
            ),
            // 無障礙大字時按鈕放在標題下方，不用往下捲
            if (big) ...[const SizedBox(height: 14), goBack],
            if (needsYou) ...[
              const SizedBox(height: 12),
              AssistNotice(
                icon: Icons.touch_app_rounded,
                color: TPColors.secondary800,
                background: TPColors.secondary100,
                text: s.isReviewing ? '請您確認資料並送出' : '有一項資料等您確認：「${s.pendingAuthField!.label}」',
              ),
            ],
            if (!big) ...[const SizedBox(height: 14), goBack],
          ],
        ),
      ),
    );
  }
}

/// 首頁的陪辦入口：「請人陪我辦」與「幫別人辦」。每個人都可以被協助，也可以協助別人。
class AssistEntryCard extends StatelessWidget {
  const AssistEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AssistTextScaleCap(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _EntryTile(
              // 與服務頁「陪辦」使用同一個台北通風格圖示
              leading: Assets.svg.iconAccompany.svg(width: context.iconSize(52), height: context.iconSize(52)),
              title: '不會用嗎？請人陪我辦',
              subtitle: '讓里長、家人或 1999 客服，陪您用手機一起辦。',
              onTap: () => Get.toNamed(TPRoute.assistPairing),
            ),
            const SizedBox(height: 10),
            _EntryTile(
              // 同樣的圓形台北通風格，改用暖色區分「幫別人」
              leading: Container(
                width: context.iconSize(52),
                height: context.iconSize(52),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.secondary500),
                child: Icon(Icons.volunteer_activism_rounded, color: TPColors.white, size: context.iconSize(28)),
              ),
              title: '我也能幫別人辦',
              subtitle: '幫爸媽、長輩或鄰居代辦，對方的個資您看不到。',
              onTap: () => Get.to(() => const AssistHelpOthersView(), routeName: '/assist_help_others'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title。$subtitle',
      child: Material(
        color: TPColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AssistText.headline),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AssistText.callout),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: TPColors.grayscale400, size: context.iconSize(28)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
