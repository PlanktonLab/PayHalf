import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../../shared/console_kit.dart';
import 'form_store.dart';

/// 海報版型：和後端 src/poster/poster.js 的 LAYOUTS 對應（寬／高用來算預覽比例）
const posterLayouts = <String, (String, double, double)>{
  'a4': ('A4 海報', 1240, 1754),
  'stand': ('壓克力立牌', 1050, 1480),
  'postcard': ('明信片', 1480, 1000),
};

/// 「QR Code 海報」：選版型、預覽、開列印頁、下載 SVG、複製表單網址。
Future<void> showPosterDialog(BuildContext context, FormStore store, FForm f) async {
  // 先把還沒存的修改送到後端，海報上的標題才會是最新的
  await store.flush(f);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Theme(
      data: buildConsoleTheme(),
      child: _PosterDialog(store: store, f: f),
    ),
  );
}

class _PosterDialog extends StatefulWidget {
  const _PosterDialog({required this.store, required this.f});
  final FormStore store;
  final FForm f;
  @override
  State<_PosterDialog> createState() => _PosterDialogState();
}

class _PosterDialogState extends State<_PosterDialog> {
  String layout = 'a4';
  late final Future<String> url = widget.store.urlOf(widget.f);

  String get base => widget.store.apiBase;
  String get id => Uri.encodeComponent(widget.f.id);
  String svgUrl({bool download = false}) =>
      '$base/api/forms/$id/poster.svg?layout=$layout${download ? '&download=1' : '&v=${widget.f.updated}'}';

  void _open(String href) => web.window.open(href, '_blank');

  void _download() {
    final a = web.HTMLAnchorElement()
      ..href = svgUrl(download: true)
      ..download = '';
    a.click();
  }

  @override
  Widget build(BuildContext context) {
    final (_, w, h) = posterLayouts[layout]!;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 620;
              final previewW = wide ? 300.0 : box.maxWidth;
              final preview = Container(
                width: previewW,
                height: (previewW * h / w).clamp(160.0, 440.0),
                decoration: BoxDecoration(
                  color: C.inset,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _SvgImage(key: ValueKey(svgUrl()), src: svgUrl(), label: '「${widget.f.displayTitle}」海報預覽'),
              );
              final side = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('版型', style: CText.label),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CSegmented<String>(
                      value: layout,
                      onChanged: (v) => setState(() => layout = v),
                      options: [for (final e in posterLayouts.entries) (e.key, e.value.$1, null)],
                    ),
                  ),
                  const SizedBox(height: 18),
                  CButton.primary(
                    '開啟列印頁',
                    icon: Icons.print_outlined,
                    expand: true,
                    onPressed: () => _open('$base/poster/$id?layout=$layout'),
                  ),
                  const SizedBox(height: 8),
                  CButton('下載 SVG', icon: Icons.download_rounded, expand: true, onPressed: _download),
                  const SizedBox(height: 18),
                  const Text('表單網址', style: CText.label),
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: url,
                    builder: (context, snap) {
                      final u = snap.data;
                      return Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: C.inset,
                          borderRadius: BorderRadius.circular(C.rControl),
                          border: Border.all(color: C.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: snap.hasError
                                  ? const Text('暫時拿不到網址，請稍後再試', style: CText.small)
                                  : SelectableText(u ?? '讀取中…', style: CText.mono.copyWith(color: C.ink2)),
                            ),
                            CButton(
                              '複製表單網址',
                              icon: Icons.copy_rounded,
                              onPressed: u == null
                                  ? null
                                  : () {
                                      Clipboard.setData(ClipboardData(text: u));
                                      cToast(context, '已複製表單網址');
                                    },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const CNotice(
                    icon: Icons.qr_code_2_rounded,
                    text: 'QR Code 裡是這份表單的固定網址，之後修改題目或截止日期都不會變。已經印出去、貼出去的海報可以一直用，不用重印。',
                  ),
                  if (widget.f.status == FStatus.closed) ...[
                    const SizedBox(height: 8),
                    const CNotice(
                      icon: Icons.lock_outline_rounded,
                      tone: CTone.warn,
                      text: '這份表單目前停止收件，民眾掃了會看到「已停止收件」。重新開放後，同一張海報又能用了。',
                    ),
                  ],
                ],
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QR Code 海報', style: CText.title),
                  const SizedBox(height: 4),
                  Text('「${widget.f.displayTitle}」　民眾用台北通掃描就能填寫', style: CText.small),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        preview,
                        const SizedBox(width: 24),
                        Expanded(child: side),
                      ],
                    )
                  else ...[
                    preview,
                    const SizedBox(height: 18),
                    side,
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CButton('關閉', onPressed: () => Navigator.pop(context)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// CanvasKit 不能用 Image.network 畫 SVG：改用瀏覽器原生的 <img>。
class _SvgImage extends StatelessWidget {
  const _SvgImage({super.key, required this.src, required this.label});
  final String src;
  final String label;

  static final Set<String> _registered = {};

  @override
  Widget build(BuildContext context) {
    final viewType = 'poster-img:$src';
    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final img = web.HTMLImageElement()
          ..src = src
          ..alt = label;
        img.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = 'contain'
          ..display = 'block'
          ..pointerEvents = 'none';
        return img;
      });
    }
    return Semantics(
      label: label,
      image: true,
      child: HtmlElementView(viewType: viewType),
    );
  }
}
