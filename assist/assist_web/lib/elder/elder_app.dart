import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../shared/theme.dart';
import '../shared/tp_colors.dart';
import '../shared/widgets.dart';
import 'elder_controller.dart';

const _phoneSize = Size(400, 860);

/// 長輩的手機（模擬台北通 App）。寬螢幕時放進手機外框裡。
class ElderApp extends StatefulWidget {
  const ElderApp({super.key, this.showCaption = true});
  final bool showCaption;
  @override
  State<ElderApp> createState() => _ElderAppState();
}

class _ElderAppState extends State<ElderApp> {
  final c = ElderController();
  final navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    c.loadDemoAccounts();
    c.onNeedsAttention = () => navKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = Theme(
      data: buildTheme(),
      child: ScaffoldMessenger(
        child: HeroControllerScope.none(
          child: Navigator(
            key: navKey,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => ListenableBuilder(
                listenable: c,
                builder: (context, _) => _ElderRoot(c: c),
              ),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 460) return phone;
        return Container(
          color: const Color(0xFFE9EEF0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showCaption) ...[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_iphone_rounded, size: 18, color: TPColors.grayscale600),
                        SizedBox(width: 6),
                        Text('長輩的手機　·　模擬已實名登入的台北通 App', style: TextStyle(color: TPColors.grayscale600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Flexible(
                    child: FittedBox(child: _PhoneFrame(child: phone)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: _phoneSize.width + 24,
      height: _phoneSize.height + 24,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15191B),
        borderRadius: BorderRadius.circular(60),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 50, offset: Offset(0, 24)),
          BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: _phoneSize,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            textScaler: TextScaler.noScaling,
          ),
          child: SizedBox.fromSize(
            size: _phoneSize,
            child: Column(
              children: [
                const _StatusBar(),
                Expanded(child: child),
                Container(
                  color: TPColors.white,
                  height: 22,
                  alignment: Alignment.center,
                  child: Container(
                    width: 130,
                    height: 5,
                    decoration: BoxDecoration(color: TPColors.grayscale900, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: TPColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: EverySecond(
              builder: (_, now) => Text(
                hm(now),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: TPColors.grayscale900),
              ),
            ),
          ),
          Container(
            width: 110,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFF15191B), borderRadius: BorderRadius.circular(16)),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.signal_cellular_alt_rounded, size: 18),
                SizedBox(width: 4),
                Icon(Icons.wifi_rounded, size: 18),
                SizedBox(width: 4),
                Icon(Icons.battery_full_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 畫面切換

class _ElderRoot extends StatelessWidget {
  const _ElderRoot({required this.c});
  final ElderController c;

  @override
  Widget build(BuildContext context) {
    Widget screen;
    String key;
    if (!c.loggedIn) {
      screen = _ElderLogin(c: c);
      key = 'login';
    } else if (c.active != null) {
      final s = c.active!;
      screen = s.isReviewing ? _ReviewScreen(c: c, s: s) : _SessionScreen(c: c, s: s);
      key = 'session-${s.id}-${s.phase}';
    } else if (c.incoming != null) {
      screen = _IncomingScreen(c: c, s: c.incoming!);
      key = 'incoming-${c.incoming!.id}';
    } else if (c.trustRequests.isNotEmpty) {
      final r = c.trustRequests.first;
      screen = _TrustRequestScreen(c: c, r: r);
      key = 'trust-${r.id}';
    } else if (c.result != null) {
      screen = _ResultScreen(c: c, s: c.result!);
      key = 'result';
    } else {
      screen = _ElderHome(c: c);
      key = 'home';
    }

    // 陪辦人員請求的欄位優先；否則是長輩自己點開的欄位
    var auth = c.active?.pendingAuthField;
    var selfAuth = false;
    final a = c.active;
    if (auth == null && c.selfAuthKey != null && a != null && !a.isReviewing) {
      final fd = c.serviceDefs[a.serviceId]?.field(c.selfAuthKey!);
      final st = a.field(c.selfAuthKey!);
      if (fd != null && a.elderSelfAuth && st.status != 'authorized' && st.preview != null) {
        auth = FieldDef({...fd.raw, 'value': st.preview});
        selfAuth = true;
      }
    }
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(key), child: screen),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, a) => SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
          child: auth == null
              ? const SizedBox.shrink(key: ValueKey('no-auth'))
              : _AuthScreen(key: ValueKey('auth-${auth.key}-$selfAuth'), c: c, s: c.active!, f: auth, self: selfAuth),
        ),
      ],
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    if (context.mounted) showApiError(context, e);
  }
}

// 長輩端字級：最小 18，主要內容 20 以上
const _tBody = TextStyle(fontSize: 20, height: 1.6, color: TPColors.grayscale800);
const _tTitle = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.35, color: TPColors.grayscale900);

class _BigButton extends StatelessWidget {
  const _BigButton(
    this.label, {
    required this.onPressed,
    this.color = TPColors.primary500,
    this.outlined = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 26), const SizedBox(width: 10)],
        Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shape: shape,
                backgroundColor: TPColors.white,
              ),
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: TPColors.white, shape: shape),
              child: child,
            ),
    );
  }
}

// ═════════════════════════════════════════════ Demo 登入

class _ElderLogin extends StatelessWidget {
  const _ElderLogin({required this.c});
  final ElderController c;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
        children: [
          Image.asset('assets/splash_logo.png', height: 120, fit: BoxFit.cover),
          const SizedBox(height: 8),
          const Text('Demo：這支手機登入的是誰？', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            '正式版中，長輩的手機已經登入台北通並通過實名認證，不需要這一步。',
            style: TextStyle(fontSize: 15, color: TPColors.grayscale600, height: 1.6),
          ),
          const SizedBox(height: 24),
          if (c.accountsLoading) const Center(child: CircularProgressIndicator()),
          if (c.accountsFailed)
            Row(
              children: [
                const Expanded(child: Text('連不到後端，請先啟動 assist_backend。', style: TextStyle(fontSize: 16))),
                TextButton(onPressed: c.loadDemoAccounts, child: const Text('重試')),
              ],
            ),
          for (final e in c.demoAccounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TPCard(
                padding: const EdgeInsets.all(20),
                onTap: () => _run(context, () => c.login(e['id'] as String)),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: TPColors.secondary100,
                      child: Icon(Icons.elderly_rounded, color: TPColors.secondary700, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['name'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                          Text('生日 ${e['birthday']}', style: const TextStyle(color: TPColors.grayscale600)),
                        ],
                      ),
                    ),
                    const StatusPill(
                      '實名認證',
                      color: TPColors.green700,
                      background: TPColors.green50,
                      icon: Icons.verified_rounded,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 首頁（仿台北通）

class _ElderHome extends StatefulWidget {
  const _ElderHome({required this.c});
  final ElderController c;
  @override
  State<_ElderHome> createState() => _ElderHomeState();
}

class _ElderHomeState extends State<_ElderHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final titles = ['首頁', '陪辦紀錄', '法規與說明'];
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: AppBar(
        backgroundColor: TPColors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          tooltip: '切換 Demo 帳號',
          onPressed: c.logout,
          icon: const Icon(Icons.person_outline_rounded, color: TPColors.grayscale700, size: 28),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab == 0) ...[const TownPassLogo(size: 22), const SizedBox(width: 8)],
            Text(
              titles[tab],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: TPColors.grayscale800),
            ),
          ],
        ),
        actions: const [SizedBox(width: 56)],
      ),
      body: switch (tab) {
        1 => _RecordsTab(c: c),
        2 => _LegalTab(c: c),
        _ => _HomeTab(c: c),
      },
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: TPColors.white,
        indicatorColor: TPColors.primary100,
        surfaceTintColor: Colors.transparent,
        selectedIndex: tab,
        onDestinationSelected: (i) {
          setState(() => tab = i);
          if (i == 1) c.refreshRecords();
        },
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 15,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? TPColors.primary600 : TPColors.grayscale500,
          ),
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 28),
            selectedIcon: Icon(Icons.home_rounded, size: 28, color: TPColors.primary600),
            label: '首頁',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, size: 28),
            selectedIcon: Icon(Icons.receipt_long_rounded, size: 28, color: TPColors.primary600),
            label: '陪辦紀錄',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined, size: 28),
            selectedIcon: Icon(Icons.gavel_rounded, size: 28, color: TPColors.primary600),
            label: '法規說明',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.c});
  final ElderController c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          children: [
            Text('${c.name} 您好', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            const StatusPill(
              '已實名認證',
              color: TPColors.green700,
              background: TPColors.green50,
              icon: Icons.verified_rounded,
              fontSize: 14,
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: c.pairing == null ? _AskHelpCard(c: c) : _PairingCard(c: c),
        ),
        // 信任的人只在按了「請人陪我辦」之後出現，跟 QR Code 放在一起
        if (c.pairing != null) ...[const SizedBox(height: 18), _TrustedSection(c: c)],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: TPColors.red50, borderRadius: BorderRadius.circular(18)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_rounded, color: TPColors.red600, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '市府、里長、1999 都不會要您轉帳、給密碼或簡訊驗證碼。',
                  style: TextStyle(fontSize: 19, height: 1.55, color: TPColors.red700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text('常用服務', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: const [
            _ServiceTile(Icons.credit_card_rounded, '敬老卡'),
            _ServiceTile(Icons.local_hospital_outlined, '掛號看病'),
            _ServiceTile(Icons.support_agent_rounded, '1999'),
            _ServiceTile(Icons.holiday_village_outlined, '里辦公處'),
            _ServiceTile(Icons.receipt_outlined, '繳費'),
            _ServiceTile(Icons.directions_bus_outlined, '公車動態'),
          ],
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34, color: TPColors.primary500),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}

class _AskHelpCard extends StatelessWidget {
  const _AskHelpCard({required this.c});
  final ElderController c;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: TPColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x335AB4C5), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.handshake_rounded, color: TPColors.white, size: 34),
              SizedBox(width: 10),
              Text(
                '不會用嗎？',
                style: TextStyle(color: TPColors.white, fontSize: 26, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '請里長、家人或 1999 客服，\n陪您一起用手機辦。',
            style: TextStyle(color: TPColors.white, fontSize: 19, height: 1.55),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 62,
            child: FilledButton.icon(
              onPressed: () => _run(context, c.createPairingCode),
              style: FilledButton.styleFrom(
                backgroundColor: TPColors.white,
                foregroundColor: TPColors.primary700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 28),
              label: const Text('請人陪我辦', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.c});
  final ElderController c;

  @override
  Widget build(BuildContext context) {
    final p = c.pairing!;
    final code = p['code'] as String;
    final expires = DateTime.fromMillisecondsSinceEpoch((p['expiresAt'] as num).toInt());
    return TPCard(
      padding: const EdgeInsets.all(22),
      border: Border.all(color: TPColors.primary300, width: 2),
      child: EverySecond(
        builder: (_, now) {
          final left = expires.difference(now);
          final expired = left.isNegative;
          return Column(
            children: [
              const Text('請把這個畫面給幫忙的人看', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Opacity(
                opacity: expired ? 0.15 : 1,
                child: QrImageView(
                  data: p['qrPayload'] as String,
                  size: 170,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: TPColors.primary800),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: TPColors.primary800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                expired ? '------' : '${code.substring(0, 3)} ${code.substring(3)}',
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 6,
                  color: TPColors.primary800,
                ),
              ),
              Text(
                expired ? '配對碼已失效' : '${mmss(left)} 後失效，只能用一次',
                style: TextStyle(fontSize: 17, color: expired ? TPColors.red600 : TPColors.grayscale600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: c.hidePairing,
                      child: const Text('不用了', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _run(context, c.createPairingCode),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('換一組', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════ 有人想協助您

class _IncomingScreen extends StatelessWidget {
  const _IncomingScreen({required this.c, required this.s});
  final ElderController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final h = s.helper!;
    return Scaffold(
      backgroundColor: TPColors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(99)),
                    child: const Text(
                      '有人想幫您',
                      style: TextStyle(fontSize: 17, color: TPColors.primary700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: h.verified ? TPColors.primary100 : TPColors.secondary100,
                    child: Icon(
                      helperIcon(h.helperType),
                      size: 50,
                      color: h.verified ? TPColors.primary600 : TPColors.secondary700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: _NameWithHeart(
                    h.name,
                    trusted: s.helperTrusted,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
                  ),
                ),
                Center(
                  child: Text(h.title, style: const TextStyle(fontSize: 21, color: TPColors.grayscale600)),
                ),
                const SizedBox(height: 10),
                Center(
                  child: HelperBadge(helperType: h.helperType, verified: h.verified, large: true),
                ),
                if (h.org != null) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Text(h.org!, style: const TextStyle(fontSize: 15, color: TPColors.grayscale500)),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: TPColors.grayscale50, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    children: [
                      const Text('想陪您辦理', style: TextStyle(fontSize: 19, color: TPColors.grayscale600)),
                      const SizedBox(height: 4),
                      Text('「${s.serviceTitle}」', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!s.helperTrusted && !h.verified)
                  const _Warn(
                    icon: Icons.info_rounded,
                    color: TPColors.secondary800,
                    bg: TPColors.secondary100,
                    text: '這個人不是公務人員。請確認您認識他，而且是您自己想辦這件事。',
                  ),
                const _Warn(
                  icon: Icons.shield_rounded,
                  color: TPColors.red700,
                  bg: TPColors.red50,
                  text: '他看不到您的身分證、地址等資料，這些資料會直接填進申請表，交給承辦機關。\n如果有人要您轉帳、給密碼或驗證碼，一定是詐騙。',
                ),
                EverySecond(
                  builder: (_, now) => Center(
                    child: Text(
                      '${mmss(s.expiresAt!.difference(now))} 後這個請求自動取消',
                      style: const TextStyle(fontSize: 15, color: TPColors.grayscale500),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
            child: Column(
              children: [
                _BigButton(
                  '好，請他幫我',
                  icon: Icons.check_rounded,
                  onPressed: () => _run(context, () => c.respond(s.id, true)),
                ),
                const SizedBox(height: 12),
                _BigButton(
                  '不要',
                  outlined: true,
                  color: TPColors.grayscale600,
                  onPressed: () => _run(context, () => c.respond(s.id, false)),
                ),
                TextButton(
                  onPressed: () => _confirmBlock(context, c, s),
                  child: const Text('我不認識這個人（封鎖並回報）', style: TextStyle(fontSize: 16, color: TPColors.red600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmBlock(BuildContext context, ElderController c, AssistSession s) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      title: const Text('封鎖這個人？', style: TextStyle(fontSize: 24)),
      content: Text('${s.helper!.name} 以後就不能再傳協助請求給您，市府也會收到回報。', style: _tBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消', style: TextStyle(fontSize: 18)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TPColors.red500),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('封鎖', style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await _run(context, () => c.block(s.id));
}

class _Warn extends StatelessWidget {
  const _Warn({required this.icon, required this.color, required this.bg, required this.text});
  final IconData icon;
  final Color color;
  final Color bg;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 18, height: 1.55, color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════ 協辦進行中

class _HelperBanner extends StatelessWidget {
  const _HelperBanner({required this.c, required this.s});
  final ElderController c;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    final h = s.helper!;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: const BoxDecoration(gradient: TPColors.brandGradient),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: TPColors.white,
            child: Icon(helperIcon(h.helperType), color: TPColors.primary600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameWithHeart(
                  '${h.name}${h.helperType == 'village_chief' ? '里長' : ''}',
                  trusted: s.helperTrusted,
                  suffix: ' 正在陪您',
                  style: const TextStyle(color: TPColors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(s.serviceTitle, style: const TextStyle(color: TPColors.primary50, fontSize: 15)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _run(context, () => c.end(s.id)),
            style: FilledButton.styleFrom(
              backgroundColor: TPColors.white,
              foregroundColor: TPColors.red600,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('結束協助', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SessionScreen extends StatelessWidget {
  const _SessionScreen({required this.c, required this.s});
  final ElderController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final def = c.serviceDefs[s.serviceId];
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      body: Column(
        children: [
          _HelperBanner(c: c, s: s),
          if (def == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _stepBody(context, def)),
        ],
      ),
    );
  }

  Widget _stepBody(BuildContext context, ServiceDef def) {
    final step = def.steps[s.currentStep];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Row(
          children: [
            Text(
              '第 ${s.currentStep + 1} 步',
              style: const TextStyle(fontSize: 18, color: TPColors.primary600, fontWeight: FontWeight.w600),
            ),
            Text('，共 ${def.steps.length} 步', style: const TextStyle(fontSize: 18, color: TPColors.grayscale500)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < def.steps.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= s.currentStep ? TPColors.primary500 : TPColors.grayscale200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(step.title, style: _tTitle.copyWith(fontSize: 30)),
        const SizedBox(height: 12),
        Text(step.elderGuide, style: _tBody.copyWith(fontSize: 22)),
        const SizedBox(height: 18),
        for (final f in step.fields) _ElderField(key: ValueKey('${s.id}-${f.key}'), c: c, s: s, f: f),
        if (step.fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const Icon(Icons.hearing_rounded, color: TPColors.primary600, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '請聽 ${s.helper!.name} 說明，聽完可以按「下一頁」。',
                    style: const TextStyle(fontSize: 19, height: 1.5, color: TPColors.primary800),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        _StepNav(c: c, s: s, def: def),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LegalPage(c: c))),
          icon: const Icon(Icons.gavel_rounded),
          label: const Text('我的權利與法規說明', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _ElderField extends StatefulWidget {
  const _ElderField({super.key, required this.c, required this.s, required this.f});
  final ElderController c;
  final AssistSession s;
  final FieldDef f;
  @override
  State<_ElderField> createState() => _ElderFieldState();
}

class _ElderFieldState extends State<_ElderField> {
  /// 文字題：長輩正在打的字
  final text = TextEditingController();
  String? _synced;

  /// 複選題：長輩勾了但還沒按「選好了」（null 表示跟伺服器一樣）
  Set<String>? picked;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _sync(widget.s.field(widget.f.key).value);
  }

  @override
  void didUpdateWidget(covariant _ElderField old) {
    super.didUpdateWidget(old);
    _sync(widget.s.field(widget.f.key).value);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  /// 伺服器上的值變了（例如長輩剛送出）才覆蓋輸入框，打字中不會被洗掉
  void _sync(String? v) {
    if (v == _synced) return;
    _synced = v;
    text.text = v ?? '';
    picked = null;
  }

  Future<void> _send(String value) async {
    setState(() => busy = true);
    await _run(context, () => widget.c.input(widget.s.id, widget.f.key, value));
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      useRootNavigator: false,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 3),
      initialDate: DateTime.tryParse(text.text) ?? now,
      helpText: '選一個日期',
    );
    if (d != null) setState(() => text.text = '${d.year}-${two(d.month)}-${two(d.day)}');
  }

  Widget _done() => const Padding(
    padding: EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded, color: TPColors.green500, size: 26),
        SizedBox(width: 8),
        Text(
          '已經填好了',
          style: TextStyle(fontSize: 19, color: TPColors.green700, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  /// 文字題：輸入框＋「填好了」
  Widget _textInput(FieldDef f, FieldState st) {
    final it = f.inputType;
    final saved = st.value ?? '';
    final cur = text.text.trim();
    final hint = f.hint ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint.isNotEmpty) ...[
          Text(hint, style: const TextStyle(fontSize: 18, height: 1.5, color: TPColors.grayscale600)),
          const SizedBox(height: 10),
        ] else
          const SizedBox(height: 4),
        TextField(
          controller: text,
          readOnly: it == 'date',
          onTap: it == 'date' ? _pickDate : null,
          keyboardType: switch (it) {
            'number' => TextInputType.number,
            'phone' => TextInputType.phone,
            'textarea' => TextInputType.multiline,
            _ => TextInputType.text,
          },
          inputFormatters: it == 'number' ? [FilteringTextInputFormatter.digitsOnly] : null,
          minLines: it == 'textarea' ? 3 : 1,
          maxLines: it == 'textarea' ? 5 : 1,
          maxLength: it == 'textarea' ? 500 : 100,
          style: const TextStyle(fontSize: 22, height: 1.4),
          decoration: InputDecoration(
            hintText: it == 'date' ? '點這裡選日期' : '在這裡輸入',
            hintStyle: const TextStyle(fontSize: 20, color: TPColors.grayscale400),
            counterText: '',
            filled: true,
            fillColor: TPColors.grayscale50,
            suffixIcon: it == 'date' ? const Icon(Icons.calendar_month_rounded, size: 28) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: TPColors.grayscale200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: TPColors.primary500, width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (st.status == 'filled' && cur == saved)
          _done()
        else
          _BigButton(
            st.status == 'filled' ? '改好了' : '填好了',
            icon: Icons.check_rounded,
            onPressed: cur.isEmpty || busy ? null : () => _send(cur),
          ),
      ],
    );
  }

  /// 複選題：可以勾好幾個，最後按「選好了」
  Widget _multiChoice(FieldDef f, FieldState st) {
    final saved = (st.value ?? '').split('、').where((v) => v.isNotEmpty).toSet();
    final cur = picked ?? saved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('可以選好幾個，選完按「選好了」', style: TextStyle(fontSize: 18, color: TPColors.grayscale600)),
        for (final o in f.options)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _ChoiceButton(
              label: o.label,
              multi: true,
              selected: cur.contains(o.value),
              onTap: () => setState(() {
                final next = {...cur};
                if (!next.remove(o.value)) next.add(o.value);
                picked = next;
              }),
            ),
          ),
        const SizedBox(height: 14),
        if (st.status == 'filled' && setEquals(cur, saved))
          _done()
        else
          _BigButton(
            st.status == 'filled' ? '改好了' : '選好了',
            icon: Icons.check_rounded,
            onPressed: cur.isEmpty || busy
                ? null
                : () => _send(f.options.where((o) => cur.contains(o.value)).map((o) => o.value).join('、')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final f = widget.f;
    final st = s.field(f.key);
    final focused = s.focusField == f.key;

    Widget body;
    if (f.type == 'text') {
      body = _textInput(f, st);
    } else if (f.type == 'choice' && f.multi) {
      body = _multiChoice(f, st);
    } else if (f.type == 'choice') {
      body = Column(
        children: [
          for (final o in f.options)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ChoiceButton(
                label: o.label,
                selected: st.value == o.value,
                onTap: () => _run(context, () => widget.c.input(s.id, f.key, o.value)),
              ),
            ),
        ],
      );
    } else if (st.status == 'authorized') {
      body = Row(
        children: [
          Expanded(
            child: _RevealValue(
              fieldKey: f.profileKey ?? f.key,
              label: f.label,
              value: st.value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
            ),
          ),
          _EditButton(c: widget.c, s: s, f: f, value: st.value ?? ''),
          TextButton(
            onPressed: () => _run(context, () => widget.c.revoke(s.id, f.key)),
            child: const Text('撤回', style: TextStyle(fontSize: 17, color: TPColors.red600)),
          ),
        ],
      );
    } else if (f.sensitive && s.elderSelfAuth && s.pendingAuth == null && st.preview != null) {
      // 預設：長輩可以自己點開授權，不用等陪辦人員
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (st.status == 'denied') ...[
            const Text('您剛才選擇不提供，想提供也可以。', style: TextStyle(fontSize: 18, color: TPColors.grayscale600)),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 4),
          _BigButton(
            '填入我的${f.label}',
            outlined: true,
            color: TPColors.primary600,
            onPressed: () => widget.c.openSelfAuth(f.key),
          ),
        ],
      );
    } else {
      body = Text(switch (st.status) {
        'denied' => '您選擇不提供',
        'requested' => '請看跳出來的畫面',
        _ => '等 ${s.helper!.name} 請您確認',
      }, style: TextStyle(fontSize: 18, color: st.status == 'denied' ? TPColors.red600 : TPColors.grayscale500));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: focused ? TPColors.secondary500 : Colors.transparent, width: 3),
        boxShadow: focused
            ? const [BoxShadow(color: Color(0x40F5BA4B), blurRadius: 20, spreadRadius: 2)]
            : const [BoxShadow(color: Color(0x0A0B0D0E), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (focused)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.arrow_circle_right_rounded, color: TPColors.secondary600, size: 24),
                  SizedBox(width: 6),
                  Text(
                    '請看這裡',
                    style: TextStyle(fontSize: 18, color: TPColors.secondary700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Icon(
                f.sensitive
                    ? Icons.lock_rounded
                    : f.type == 'text'
                    ? Icons.edit_rounded
                    : Icons.touch_app_rounded,
                color: f.sensitive ? TPColors.secondary700 : TPColors.primary500,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(f.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              ),
              if (f.sensitive) StatusPill.forField(st, fontSize: 14),
            ],
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.selected, required this.onTap, this.multi = false});
  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TPColors.primary50 : TPColors.grayscale50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? TPColors.primary500 : TPColors.grayscale200, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                multi
                    ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                    : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                color: selected ? TPColors.primary500 : TPColors.grayscale400,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 21, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 授權（全螢幕）

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({super.key, required this.c, required this.s, required this.f, this.self = false});
  final ElderController c;
  final AssistSession s;
  final FieldDef f;

  /// 長輩自己點開的：按「先不要」只是關掉
  final bool self;
  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  bool busy = false;
  String? edited;

  Future<void> answer(bool approve) async {
    if (widget.self && !approve) return widget.c.openSelfAuth(null);
    setState(() => busy = true);
    await _run(
      context,
      () => widget.self
          ? widget.c.selfAuthorize(widget.s.id, widget.f.key, value: edited)
          : widget.c.authorize(widget.s.id, widget.f.key, approve, value: approve ? edited : null),
    );
    if (mounted) setState(() => busy = false);
  }

  Future<void> change() async {
    final v = await _editValue(context, widget.f.label, edited ?? widget.f.value ?? '');
    if (v != null && mounted) {
      setState(() {
        edited = v == widget.f.value ? null : v;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final s = widget.s;
    final high = f.riskLevel == 'high';
    final accent = high ? TPColors.red600 : TPColors.secondary700;
    final accentBg = high ? TPColors.red50 : TPColors.secondary50;

    Widget infoRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: TPColors.primary600),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 18, color: TPColors.grayscale500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 19, height: 1.45, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    return Material(
      color: TPColors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            color: accentBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_rounded, color: accent, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      high ? '重要資料授權' : '資料授權',
                      style: TextStyle(fontSize: 18, color: accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('要提供您的', style: TextStyle(fontSize: 22, color: TPColors.grayscale700)),
                Text('「${f.label}」嗎？', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  decoration: BoxDecoration(color: TPColors.grayscale50, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edited == null ? '將提供' : '將提供（已修改）',
                        style: const TextStyle(fontSize: 18, color: TPColors.grayscale500),
                      ),
                      _RevealValue(
                        key: ValueKey(edited),
                        fieldKey: f.profileKey ?? f.key,
                        label: f.label,
                        value: edited ?? f.value,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                        initiallyRevealed: edited != null,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : change,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('內容不對？我要修改', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 8),
                infoRow(Icons.account_balance_rounded, '給誰用', f.recipient ?? s.agency ?? ''),
                infoRow(Icons.help_outline_rounded, '做什麼用', f.purpose ?? ''),
                infoRow(Icons.schedule_rounded, '保存多久', f.retention ?? ''),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: TPColors.green50, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_rounded, color: TPColors.green700, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${s.helper!.name} 看不到內容。這項資料會直接填進申請表，交給${f.recipient ?? s.agency ?? '承辦機關'}。',
                          style: const TextStyle(fontSize: 19, color: TPColors.green700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: high ? TPColors.red200 : TPColors.secondary200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: accent, size: 26),
                          const SizedBox(width: 8),
                          Text(
                            '請注意',
                            style: TextStyle(fontSize: 21, color: accent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final r in [...f.risks, '不想提供可以按「先不要」，不會有任何處罰。'])
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('・', style: TextStyle(fontSize: 19, color: accent)),
                              Expanded(
                                child: Text(r, style: TextStyle(fontSize: 19, height: 1.5, color: accent)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '法令依據：${f.legalBasis ?? ''}',
                  style: const TextStyle(fontSize: 15, color: TPColors.grayscale500, height: 1.5),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LegalPage(c: widget.c))),
                  icon: const Icon(Icons.gavel_rounded),
                  label: const Text('看我的權利與詳細法規', style: TextStyle(fontSize: 17)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
            child: Row(
              children: [
                Expanded(
                  child: _BigButton(
                    '先不要',
                    outlined: true,
                    color: TPColors.grayscale600,
                    onPressed: busy ? null : () => answer(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _BigButton('同意提供', icon: Icons.check_rounded, onPressed: busy ? null : () => answer(true)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 確認送出

class _ReviewScreen extends StatefulWidget {
  const _ReviewScreen({required this.c, required this.s});
  final ElderController c;
  final AssistSession s;
  @override
  State<_ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewScreen> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = widget.s;
    final def = c.serviceDefs[s.serviceId];
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      body: Column(
        children: [
          _HelperBanner(c: c, s: s),
          Expanded(
            child: def == null
                ? const SizedBox()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    children: [
                      const Text('請確認您的資料', style: _tTitle),
                      const SizedBox(height: 6),
                      Text('「${s.serviceTitle}」', style: const TextStyle(fontSize: 21, color: TPColors.grayscale600)),
                      const SizedBox(height: 14),
                      TPCard(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final f in def.allFields) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.label,
                                            style: const TextStyle(fontSize: 17, color: TPColors.grayscale500),
                                          ),
                                          const SizedBox(height: 2),
                                          if (f.type == 'choice' || f.type == 'text')
                                            Text(
                                              s.field(f.key).value == null || s.field(f.key).value!.isEmpty
                                                  ? '（沒有填）'
                                                  : f.displayValue(s.field(f.key).value),
                                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                                            )
                                          else
                                            _RevealValue(
                                              fieldKey: f.profileKey ?? f.key,
                                              label: f.label,
                                              value: s.field(f.key).value,
                                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (f.sensitive && s.field(f.key).status == 'authorized')
                                      _EditButton(c: c, s: s, f: f, value: s.field(f.key).value ?? ''),
                                  ],
                                ),
                              ),
                              if (f != def.allFields.last) const Divider(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Warn(
                        icon: Icons.send_rounded,
                        color: TPColors.primary800,
                        bg: TPColors.primary50,
                        text: '按下「確認送出」後，這些資料會直接填進申請表，交給 ${s.agency}。${s.helper!.name} 看不到內容。送出鍵只有您能按。',
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              children: [
                _BigButton(
                  '確認送出',
                  icon: Icons.send_rounded,
                  color: TPColors.green500,
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          await _run(context, () => c.submit(s.id, true));
                          if (mounted) setState(() => busy = false);
                        },
                ),
                const SizedBox(height: 10),
                _BigButton(
                  '我要再看一下',
                  outlined: true,
                  color: TPColors.grayscale600,
                  onPressed: busy ? null : () => _run(context, () => c.submit(s.id, false)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 結果

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({required this.c, required this.s});
  final ElderController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final ok = s.status == 'completed';
    final message = switch ((s.endedBy, s.endReason)) {
      (_, 'submitted') => '申請已經送出了！',
      (_, 'timeout') => '太久沒有動作，協助已自動結束。',
      (_, 'blocked') => '已封鎖對方，協助已結束。',
      ('elder', _) => '您已經結束這次協助。',
      _ => '${s.helper?.name ?? '協助者'} 結束了這次協助。',
    };
    return Scaffold(
      backgroundColor: TPColors.white,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? TPColors.green50 : TPColors.grayscale50),
              child: Icon(
                ok ? Icons.check_rounded : Icons.info_outline_rounded,
                size: 72,
                color: ok ? TPColors.green500 : TPColors.grayscale500,
              ),
            ),
            const SizedBox(height: 24),
            Text(message, textAlign: TextAlign.center, style: _tTitle),
            const SizedBox(height: 10),
            Text('「${s.serviceTitle}」', style: const TextStyle(fontSize: 21, color: TPColors.grayscale600)),
            if (ok) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    const Text('案件編號', style: TextStyle(fontSize: 18, color: TPColors.primary700)),
                    const SizedBox(height: 4),
                    Text(
                      s.caseNo ?? '',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: TPColors.primary800),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              '這次是誰陪您、您提供了哪些資料，\n都可以在「陪辦紀錄」查看。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: TPColors.grayscale600, height: 1.6),
            ),
            const Spacer(),
            _BigButton('回到首頁', onPressed: c.dismissResult),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 紀錄與法規

class _RecordsTab extends StatelessWidget {
  const _RecordsTab({required this.c});
  final ElderController c;

  @override
  Widget build(BuildContext context) {
    final ok = c.auditStatus?['ok'] == true;
    return RefreshIndicator(
      onRefresh: c.refreshRecords,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ok ? TPColors.green50 : TPColors.red50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                  color: ok ? TPColors.green500 : TPColors.red500,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? '紀錄完整，沒有被修改過' : '紀錄異常，請撥 1999',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: ok ? TPColors.green700 : TPColors.red700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('我送出的申請', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (c.applications.isEmpty)
            const Text('還沒有送出的申請', style: TextStyle(fontSize: 18, color: TPColors.grayscale500)),
          for (final a in c.applications)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TPCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['serviceTitle'] as String,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('案件編號 ${a['caseNo']}', style: const TextStyle(fontSize: 18, color: TPColors.primary700)),
                    Text(
                      '${ymdhm(DateTime.fromMillisecondsSinceEpoch((a['submittedAt'] as num).toInt()))}　由 ${a['helper']} 陪同',
                      style: const TextStyle(fontSize: 16, color: TPColors.grayscale500),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Text('誰找過我、我同意了什麼', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TPCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                if (c.audit.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('目前沒有紀錄', style: TextStyle(fontSize: 18)),
                  ),
                for (var i = 0; i < c.audit.length; i++) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _auditIcon(c.audit[i]['type'] as String),
                          color: _auditColor(c.audit[i]['type'] as String),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.audit[i]['summary'] as String, style: const TextStyle(fontSize: 18, height: 1.45)),
                              Text(
                                ymdhm(DateTime.fromMillisecondsSinceEpoch((c.audit[i]['ts'] as num).toInt())),
                                style: const TextStyle(fontSize: 15, color: TPColors.grayscale500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _auditIcon(String type) => switch (type) {
    'field.authorized' => Icons.lock_open_rounded,
    'field.denied' || 'field.revoked' => Icons.lock_rounded,
    'application.submitted' => Icons.send_rounded,
    'lookup.identity' => Icons.person_search_rounded,
    'helper.blocked' || 'helper.auto_blocked' => Icons.block_rounded,
    'request.accepted' => Icons.handshake_rounded,
    _ => Icons.circle_outlined,
  };

  Color _auditColor(String type) => switch (type) {
    'lookup.identity' || 'helper.blocked' || 'helper.auto_blocked' => TPColors.red500,
    'field.authorized' || 'application.submitted' => TPColors.green500,
    _ => TPColors.primary500,
  };
}

class _LegalTab extends StatelessWidget {
  const _LegalTab({required this.c});
  final ElderController c;
  @override
  Widget build(BuildContext context) => _LegalContent(c: c);
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.c});
  final ElderController c;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPColors.grayscale50,
      appBar: AppBar(
        backgroundColor: TPColors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('我的權利與法規', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: _LegalContent(c: c),
    );
  }
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.c});
  final ElderController c;
  @override
  Widget build(BuildContext context) {
    final legal = c.legal;
    if (legal == null) return const Center(child: CircularProgressIndicator());
    final sections = (legal['sections'] as List).cast<Map>();
    final hotlines = (legal['hotlines'] as List).cast<Map>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        for (final sec in sections)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: sec['highlight'] == true ? TPColors.red50 : TPColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sec['title'] as String,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: sec['highlight'] == true ? TPColors.red700 : TPColors.grayscale900,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in (sec['body'] as List).cast<String>())
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('・', style: TextStyle(fontSize: 18)),
                        Expanded(child: Text(line, style: const TextStyle(fontSize: 18, height: 1.55))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const Text('有問題請打電話', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final h in hotlines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TPCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded, color: TPColors.primary500, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(h['label'] as String, style: const TextStyle(fontSize: 18))),
                  Text(
                    h['number'] as String,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: TPColors.primary700),
                  ),
                ],
              ),
            ),
          ),
        Text(
          '最後更新：${legal['updatedAt']}　·　條文為摘要，以全國法規資料庫為準',
          style: const TextStyle(fontSize: 14, color: TPColors.grayscale500),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════ 修改資料與換頁

Future<String?> _editValue(BuildContext context, String label, String initial) {
  final text = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('修改「$label」', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('改成正確的內容。送出前，您還會再看到一次全部的資料。', style: TextStyle(fontSize: 17, height: 1.5)),
          const SizedBox(height: 14),
          TextField(
            controller: text,
            autofocus: true,
            maxLength: 100,
            style: const TextStyle(fontSize: 21),
            decoration: InputDecoration(labelText: label, counterText: '', border: const OutlineInputBorder()),
            onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.of(ctx).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消', style: TextStyle(fontSize: 18)),
        ),
        FilledButton(
          onPressed: () => text.text.trim().isEmpty ? null : Navigator.of(ctx).pop(text.text.trim()),
          child: const Text('改好了', style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.c, required this.s, required this.f, required this.value});
  final ElderController c;
  final AssistSession s;
  final FieldDef f;
  final String value;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      final v = await _editValue(context, f.label, value);
      if (v != null && v != value && context.mounted) await _run(context, () => c.editField(s.id, f.key, v));
    },
    child: const Text(
      '修改',
      style: TextStyle(fontSize: 17, color: TPColors.primary700, fontWeight: FontWeight.w600),
    ),
  );
}

class _StepNav extends StatelessWidget {
  const _StepNav({required this.c, required this.s, required this.def});
  final ElderController c;
  final AssistSession s;
  final ServiceDef def;

  @override
  Widget build(BuildContext context) {
    final name = s.helper!.name;
    final last = def.steps.length - 1;
    if (!s.elderNav) {
      return _Warn(
        icon: Icons.front_hand_rounded,
        color: TPColors.primary800,
        bg: TPColors.primary50,
        text: '$name 會帶您到下一步，請等一下。',
      );
    }
    final waiting = s.pendingAuth != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.currentStep < last)
          _BigButton(
            '下一頁',
            icon: Icons.arrow_forward_rounded,
            onPressed: waiting ? null : () => _run(context, () => c.gotoStep(s.id, s.currentStep + 1)),
          )
        else
          _Warn(
            icon: Icons.send_rounded,
            color: TPColors.primary800,
            bg: TPColors.primary50,
            text: '這是最後一步。$name 會請您確認資料，再由您按送出。',
          ),
        if (s.currentStep > 0) ...[
          const SizedBox(height: 10),
          _BigButton(
            '上一頁',
            icon: Icons.arrow_back_rounded,
            outlined: true,
            onPressed: waiting ? null : () => _run(context, () => c.gotoStep(s.id, s.currentStep - 1)),
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════ 信任的人

/// 名字後面加一顆愛心：是長輩信任的人（像社群平台的認證勾勾）
class _NameWithHeart extends StatelessWidget {
  const _NameWithHeart(this.name, {required this.trusted, required this.style, this.suffix = ''});
  final String name;
  final bool trusted;
  final TextStyle style;
  final String suffix;
  @override
  Widget build(BuildContext context) {
    final size = (style.fontSize ?? 20) * 0.75;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          if (trusted)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: EdgeInsets.all(size * 0.18),
                decoration: const BoxDecoration(color: TPColors.white, shape: BoxShape.circle),
                child: Icon(Icons.favorite_rounded, size: size, color: TPColors.red500),
              ),
            ),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      style: style,
      semanticsLabel: '$name${trusted ? '，您信任的人' : ''}$suffix',
    );
  }
}

/// 「請人陪我辦」底下：點信任的人請他來幫忙；加人、移除也在這裡
class _TrustedSection extends StatefulWidget {
  const _TrustedSection({required this.c});
  final ElderController c;
  @override
  State<_TrustedSection> createState() => _TrustedSectionState();
}

class _TrustedSectionState extends State<_TrustedSection> {
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('找信任的人', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
              ),
              if (c.trusted.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => editing = !editing),
                  child: Text(editing ? '完成' : '編輯', style: const TextStyle(fontSize: 17)),
                ),
            ],
          ),
          Text(
            c.trusted.isEmpty ? '把常幫您的家人加進來，下次不用掃 QR Code。' : '按一下，對方手機會收到通知來幫您。',
            style: const TextStyle(fontSize: 17, height: 1.5, color: TPColors.grayscale600),
          ),
          for (final t in c.trusted) ...[const SizedBox(height: 10), _trustedRow(context, t)],
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showAddTrusted(context, c),
              style: OutlinedButton.styleFrom(
                foregroundColor: TPColors.primary700,
                side: const BorderSide(color: TPColors.primary300, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('加信任的人', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustedRow(BuildContext context, TrustedHelper t) {
    final c = widget.c;
    final h = t.helper;
    final waiting = c.waitingFor(h.id);
    final canCall = !editing && waiting == null;
    final Widget action;
    if (editing) {
      action = TextButton(
        onPressed: () => _confirmRemoveTrusted(context, c, h),
        child: const Text('移除', style: TextStyle(fontSize: 18, color: TPColors.red600)),
      );
    } else if (waiting != null) {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            '已通知，等他回應',
            style: TextStyle(fontSize: 15, color: TPColors.secondary800, fontWeight: FontWeight.w600),
          ),
          TextButton(
            onPressed: () => _run(context, () => c.cancelHelp(waiting.id)),
            child: const Text('取消', style: TextStyle(fontSize: 16, color: TPColors.grayscale600)),
          ),
        ],
      );
    } else {
      action = const Icon(Icons.chevron_right_rounded, color: TPColors.primary600, size: 30);
    }
    return Material(
      color: TPColors.grayscale50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canCall ? () => _run(context, () => c.requestHelp(h.id)) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: TPColors.primary50,
                child: Icon(helperIcon(h.helperType), color: TPColors.primary600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NameWithHeart(
                      h.name,
                      trusted: true,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    if (canCall)
                      const Text(
                        '請他來幫我',
                        style: TextStyle(fontSize: 16, color: TPColors.primary700, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showAddTrusted(BuildContext context, ElderController c) async {
  Map<String, dynamic> inv;
  try {
    inv = await c.createTrustInvite();
  } catch (e) {
    if (context.mounted) showApiError(context, e);
    return;
  }
  if (!context.mounted) return;
  final code = inv['code'] as String;
  final expires = DateTime.fromMillisecondsSinceEpoch((inv['expiresAt'] as num).toInt());
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        // 家人掃了：關掉 QR，讓「要加他嗎？」的畫面出來
        if (c.trustRequests.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) Navigator.pop(ctx);
          });
        }
        return AlertDialog(
          title: const Text('加信任的人', textAlign: TextAlign.center, style: TextStyle(fontSize: 24)),
          content: SizedBox(
            width: 320,
            child: EverySecond(
              builder: (_, now) {
                final left = expires.difference(now);
                final expired = left.isNegative;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '請家人用台北通掃這個 QR Code，\n或輸入下面的號碼。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, height: 1.5, color: TPColors.grayscale600),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: expired ? 0.15 : 1,
                      child: QrImageView(
                        data: inv['qrPayload'] as String,
                        size: 170,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: TPColors.red700),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: TPColors.red700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      expired ? '------' : '${code.substring(0, 3)} ${code.substring(3)}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 6,
                        color: TPColors.red700,
                      ),
                    ),
                    Text(
                      expired ? '號碼已失效，請關掉再按一次' : '${mmss(left)} 後失效',
                      style: TextStyle(fontSize: 16, color: expired ? TPColors.red600 : TPColors.grayscale600),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '只給您信得過的家人。對方掃了之後，您還要再按一次「加入」才算數。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.5, color: TPColors.red700),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },
    ),
  );
}

/// 家人掃了邀請碼：問長輩「要把他加為信任的人嗎？」一定要長輩本人按「加入」
class _TrustRequestScreen extends StatelessWidget {
  const _TrustRequestScreen({required this.c, required this.r});
  final ElderController c;
  final TrustRequest r;

  @override
  Widget build(BuildContext context) {
    final h = r.helper;
    return Scaffold(
      backgroundColor: TPColors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: h.verified ? TPColors.primary100 : TPColors.secondary100,
                    child: Icon(
                      helperIcon(h.helperType),
                      size: 50,
                      color: h.verified ? TPColors.primary600 : TPColors.secondary700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${h.name}\n想成為您信任的人',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, height: 1.35),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(h.title, style: const TextStyle(fontSize: 19, color: TPColors.grayscale600)),
                ),
                const SizedBox(height: 10),
                Center(
                  child: HelperBadge(helperType: h.helperType, verified: h.verified, large: true),
                ),
                const SizedBox(height: 22),
                const Text(
                  '加入後，您可以直接請他來幫忙。\n電話裡有人要您加他，就是詐騙。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, height: 1.6, color: TPColors.grayscale700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              children: [
                _BigButton(
                  '加入',
                  icon: Icons.favorite_rounded,
                  onPressed: () => _run(context, () => c.respondTrustRequest(r.id, true)),
                ),
                const SizedBox(height: 12),
                _BigButton(
                  '不要',
                  outlined: true,
                  color: TPColors.grayscale600,
                  onPressed: () => _run(context, () => c.respondTrustRequest(r.id, false)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 敏感資料：整格模糊，中間寫「點一下查看{label}」，點了才顯示；再點一下又遮起來。
/// 比「遮一半＋眼睛圖示」直覺：長輩不用猜眼睛是什麼意思。
/// 不需要遮的欄位（例如姓名）直接顯示。
class _RevealValue extends StatefulWidget {
  const _RevealValue({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.style,
    this.initiallyRevealed = false,
  });
  final String fieldKey;
  final String label;
  final String? value;
  final TextStyle style;
  final bool initiallyRevealed;
  @override
  State<_RevealValue> createState() => __RevealValueState();
}

class __RevealValueState extends State<_RevealValue> {
  late bool reveal = widget.initiallyRevealed;

  @override
  Widget build(BuildContext context) {
    final v = widget.value ?? '';
    if (maskValue(widget.fieldKey, v) == v) return Text(v, style: widget.style);
    return Semantics(
      button: true,
      label: reveal ? '${widget.label}：$v。點兩下遮住' : '${widget.label}已遮住。點兩下查看',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => reveal = !reveal);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ImageFiltered(
                  enabled: !reveal,
                  imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9, tileMode: TileMode.decal),
                  child: Text(v, style: widget.style),
                ),
              ),
              if (!reveal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: TPColors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 20, color: TPColors.primary700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '點一下查看${widget.label}',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: TPColors.primary700),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Positioned(
                  right: 0,
                  child: Text('點一下遮住', style: TextStyle(fontSize: 14, color: TPColors.grayscale500)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmRemoveTrusted(BuildContext context, ElderController c, HelperInfo h) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      title: Text('移除 ${h.name}？', style: const TextStyle(fontSize: 24)),
      content: const Text('之後他要找您，就要重新掃 QR Code。', style: _tBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消', style: TextStyle(fontSize: 18)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TPColors.red500),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('移除', style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await _run(context, () => c.removeTrusted(h.id));
}
