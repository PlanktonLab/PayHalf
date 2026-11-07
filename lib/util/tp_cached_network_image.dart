import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/util/tp_colors.dart';

class TPCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final Map<String, String>? httpHeaders;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final double borderRadius;

  const TPCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.httpHeaders,
    this.width,
    this.height,
    this.fit,
    this.color = TPColors.white,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('assets/svg/')) {
      return Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TPColors.primary50,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: SvgPicture.asset(imageUrl, fit: BoxFit.contain),
      );
    }
    return _buildContainer();
  }

  Widget _buildContainer() {
    return Container(
      width: width,
      height: height,
      // 設定容器的背景顏色和外框圓角，在圖片載入中或錯誤時可見。
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
      ),
      child: ClipRRect( // 確保圖片內容（包含載入中及錯誤狀態）也依照圓角進行裁切。
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          httpHeaders: httpHeaders,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          placeholder: (context, string) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, string, object) => ColoredBox(
            color: TPColors.grayscale100,
            child: Center(
              child: Assets.svg.logoS.svg(),
            ),
          ),
        ),
      ),
    );
  }
}