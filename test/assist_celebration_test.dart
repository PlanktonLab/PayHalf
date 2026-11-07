import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/page/assist/widget/assist_celebration.dart';

void main() {
  testWidgets('helper celebration plays and settles within 1.5 seconds', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Center(child: AssistCelebration.gratitude()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
