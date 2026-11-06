import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcanvas/core/theme.dart';
import 'package:starcanvas/ui/onboarding_page.dart';

void main() {
  testWidgets('新手引导展示欢迎页并可翻到下一步', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const OnboardingPage(),
      ),
    );

    expect(find.text('新手引导'), findsOneWidget);
    expect(find.text('欢迎来到星绘工坊'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('先建一个空工程'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);
    expect(find.textContaining('新建作品'), findsWidgets);
  });
}
