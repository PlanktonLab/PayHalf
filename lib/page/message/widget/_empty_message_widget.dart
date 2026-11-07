part of 'package:town_pass/page/message/message_view.dart';

class _EmptyMessageWidget extends StatelessWidget {
  const _EmptyMessageWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        SizedBox(
          width: 160,
          height: 160,
          child: Center(child: Assets.svg.bookingL.svg()),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: TPText(
            '目前無訊息'.tr,
            style: TPTextStyles.h2SemiBold,
            color: TPColors.primary500,
          ),
        ),
        TPText(
          '請試試其他關鍵字或篩選分類'.tr,
          style: TPTextStyles.bodySemiBold,
          color: TPColors.grayscale400,
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}
