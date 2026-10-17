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
    await c.read(languageRegistryProvider.future);
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
    expect(find.textContaining('Coming soon'), findsWidgets);
    for (final _ in [1, 2, 3]) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Start learning'), findsOneWidget);
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
  });

  /// Plays the open lesson to the end by tapping whatever the screen asks for.
  Future<void> playLesson(WidgetTester tester) async {
    var guard = 0;
    while (find.text('Lesson complete!').evaluate().isEmpty && guard++ < 160) {
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text('Lesson complete!').evaluate().isNotEmpty) break;

      final cont = find.widgetWithText(FilledButton, 'Continue');
      final gotIt = find.widgetWithText(FilledButton, 'Got it');
      final check = find.widgetWithText(FilledButton, 'Check');
      final skip = find.widgetWithText(TextButton, 'Skip');
      final saidIt = find.text('I said it');
      final field = find.byType(TextField);

      if (field.evaluate().isNotEmpty && check.evaluate().isNotEmpty) {
        // Spelling practice: type something and check it.
        await tester.enterText(field.first, 'x');
        await tester.pump();
        await tester.tap(check.first, warnIfMissed: false);
      } else if (cont.evaluate().isNotEmpty) {
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
          await tester.ensureVisible(bank.at(i));
          await tester.pump();
          await tester.tap(bank.at(i), warnIfMissed: false);
          await tester.pump();
        }
        if (check.evaluate().isNotEmpty) {
          await tester.ensureVisible(check.first);
          await tester.pump();
          await tester.tap(check.first, warnIfMissed: false);
        }
      } else if (saidIt.evaluate().isNotEmpty) {
        await tester.tap(saidIt);
      } else if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip.first);
      } else {
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
  }

  void setScreen(
    WidgetTester tester, {
    required double w,
    required double h,
    double textScale = 1,
  }) {
    tester.view.physicalSize = Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  testWidgets('a whole lesson can be played through the UI', (tester) async {
    setScreen(tester, w: 360, h: 800);
    final t = await makeContainer();
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);

    expect(find.text("Today's goal"), findsOneWidget);
    expect(find.text('Lesson 1'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    await playLesson(tester);
    final p = t.container.read(progressProvider).value!;
    expect(p.isLessonDone('zh-hsk1-u01-l01'), isTrue);
  });

  // The Samsung A12 test phone: about 339 dp wide, 1.3x font. Any overflow
  // raises a test error, so this guards the layouts that broke before.
  testWidgets('every tab and a full lesson fit a small phone with large text', (
    tester,
  ) async {
    setScreen(tester, w: 339, h: 705, textScale: 1.3);
    final t = await makeContainer();
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);

    for (final tab in ['Path', 'Progress', 'Settings', 'Today']) {
      await tester.tap(find.widgetWithText(NavigationDestination, tab));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text("Today's goal"), findsOneWidget);
    // The primary action must be visible without scrolling, above the nav bar.
    final start = tester.getCenter(find.text('Start'));
    expect(start.dy, lessThan(705 - 90), reason: 'Start hidden: $start');
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    await playLesson(tester);
  });

  testWidgets('German: switch language, then play a lesson on a small phone', (
    tester,
  ) async {
    setScreen(tester, w: 339, h: 705, textScale: 1.3);
    final t = await makeContainer(language: 'de');
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);

    expect(find.text("Today's goal"), findsOneWidget);
    expect(find.textContaining('A1'), findsWidgets);
    final start = tester.getCenter(find.text('Start'));
    expect(start.dy, lessThan(705 - 90), reason: 'Start hidden: $start');
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    await playLesson(tester);
    final p = t.container.read(progressProvider).value!;
    expect(p.isLessonDone('de-a1-u01-l01'), isTrue);
  });

  testWidgets('choosing German in onboarding changes the levels offered', (
    tester,
  ) async {
    setScreen(tester, w: 360, h: 800);
    final t = await makeContainer(onboardingDone: false);
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Chinese (Mandarin)'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);

    // Same switch the German card performs, with real async work allowed.
    await tester.runAsync(() async {
      await t.container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(languageId: 'de'));
      await t.container.read(contentProvider.future);
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('A2 · Everyday life', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('HSK'), findsNothing);
  });

  testWidgets('switching language in Settings shows the other course', (
    tester,
  ) async {
    setScreen(tester, w: 360, h: 800);
    final t = await makeContainer();
    addTearDown(t.container.dispose);
    await pumpApp(tester, t.container);
    expect(find.textContaining('HSK 1'), findsWidgets);

    await t.container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(languageId: 'de'));
    await tester.runAsync(() async {
      await t.container.read(contentProvider.future);
      await t.container.read(progressProvider.future);
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('A1'), findsWidgets);
    expect(find.textContaining('HSK'), findsNothing);
  });
}
