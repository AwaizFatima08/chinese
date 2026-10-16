import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/app.dart';
import 'package:lingodaily/core/providers.dart';
import 'package:lingodaily/features/home/home_shell.dart';
import 'package:lingodaily/features/lesson/views/view_support.dart';
import 'package:lingodaily/features/progress/progress_state.dart';

import 'helpers/test_app.dart';

Future<void> pumpApp(WidgetTester tester, ProviderContainer c) async {
  await tester.runAsync(() async {
    await c.read(contentProvider.future);
    await c.read(progressProvider.future);
    await c.read(speakerReadyProvider.future);
    await c.read(adsReadyProvider.future);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const LingoDailyApp()),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('first launch shows onboarding, then Today', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final t = await makeContainer(onboardingDone: false);
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);

    expect(find.text('Learn a language in 15 minutes a day'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to learn?'), findsOneWidget);
    expect(find.text('Coming soon'), findsWidgets);
    for (final _ in [1, 2, 3]) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Start learning'), findsOneWidget);
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
  });

  testWidgets('a whole lesson can be played through the UI', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final t = await makeContainer();
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);

    expect(find.text("Today's goal"), findsOneWidget);
    expect(find.text('Lesson 1'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));

    var guard = 0;
    while (find.text('Lesson complete!').evaluate().isEmpty && guard++ < 120) {
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text('Lesson complete!').evaluate().isNotEmpty) break;

      final cont = find.widgetWithText(FilledButton, 'Continue');
      final gotIt = find.widgetWithText(FilledButton, 'Got it');
      final check = find.widgetWithText(FilledButton, 'Check');
      final skip = find.widgetWithText(TextButton, 'Skip');
      final saidIt = find.text('I said it');

      if (cont.evaluate().isNotEmpty) {
        await tester.tap(cont.first);
      } else if (gotIt.evaluate().isNotEmpty) {
        await tester.tap(gotIt.first);
      } else if (check.evaluate().isNotEmpty ||
          find.text('Tap the words below').evaluate().isNotEmpty) {
        // Word order: tap every tile in the bank, then Check.
        final bank = find.descendant(
          of: find.byType(Wrap).last,
          matching: find.byType(InkWell),
        );
        final n = bank.evaluate().length;
        for (var i = 0; i < n; i++) {
          await tester.tap(bank.at(i), warnIfMissed: false);
          await tester.pump();
        }
        if (check.evaluate().isNotEmpty) {
          await tester.tap(check.first, warnIfMissed: false);
        }
      } else if (saidIt.evaluate().isNotEmpty) {
        await tester.tap(saidIt);
      } else if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip.first);
      } else {
        // A choice question: tap the first option.
        final options = find.byType(OptionButton);
        if (options.evaluate().isNotEmpty) {
          await tester.tap(options.first, warnIfMissed: false);
        }
      }
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 800));
    if (find.text('Lesson complete!').evaluate().isEmpty) {
      // ignore: avoid_print
      print(
        'STUCK after $guard steps: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList()}',
      );
    }
    expect(find.text('Lesson complete!'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    final p = t.container.read(progressProvider).value!;
    expect(p.isLessonDone('zh-hsk1-u01-l01'), isTrue);
  });
}
