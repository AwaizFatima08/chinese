import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/app.dart';
import 'package:lingodaily/core/providers.dart';
import 'package:lingodaily/features/account/account_controller.dart';
import 'package:lingodaily/features/home/home_shell.dart';
import 'package:lingodaily/features/progress/progress_state.dart';

import 'helpers/fake_cloud.dart';
import 'helpers/test_app.dart';

Future<void> openSettings(WidgetTester tester, ProviderContainer c) async {
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
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
}

/// Scrolls the Settings list until [text] sits well inside the screen, clear
/// of the navigation bar.
Future<void> reveal(WidgetTester tester, String text) async {
  final finder = find.text(text);
  for (var i = 0; i < 30; i++) {
    if (finder.evaluate().isNotEmpty) {
      final y = tester.getCenter(finder).dy;
      if (y > 120 && y < 520) break;
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  void narrowPhone(WidgetTester tester) {
    // The Samsung A12 at 1.3x text: about 339 dp wide.
    tester.view.physicalSize = const Size(678, 1500);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('without Firebase the account section is hidden', (tester) async {
    narrowPhone(tester);
    final t = await makeContainer();
    addTearDown(t.container.dispose);
    await openSettings(tester, t.container);
    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Back up and sync your progress'), findsNothing);
  });

  testWidgets('sign in, sync, sign out from Settings', (tester) async {
    narrowPhone(tester);
    final auth = FakeAuth();
    final cloud = FakeCloud();
    final t = await makeContainer(
      extraOverrides: [
        authServiceProvider.overrideWithValue(auth),
        cloudStoreProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(t.container.dispose);
    await openSettings(tester, t.container);

    expect(find.text('Back up and sync your progress'), findsOneWidget);
    await reveal(tester, 'Sign in with Google');
    await tester.runAsync(() async {
      await tester.tap(find.text('Sign in with Google'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(t.container.read(accountProvider).user!.email, 'a@b.c');
    expect(t.container.read(accountProvider).lastSynced, isNotNull);
    await reveal(tester, 'Delete account and cloud data');
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Delete account and cloud data'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await reveal(tester, 'Sign out');
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(
      find.text('Signed out. Your progress stays on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting the account needs a confirmation', (tester) async {
    narrowPhone(tester);
    final auth = FakeAuth();
    final cloud = FakeCloud();
    final t = await makeContainer(
      extraOverrides: [
        authServiceProvider.overrideWithValue(auth),
        cloudStoreProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(t.container.dispose);
    await openSettings(tester, t.container);
    await reveal(tester, 'Sign in with Google');
    await tester.runAsync(() async {
      await tester.tap(find.text('Sign in with Google'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    await reveal(tester, 'Delete account and cloud data');
    await tester.tap(find.text('Delete account and cloud data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(t.container.read(accountProvider).signedIn, isTrue);

    await reveal(tester, 'Delete account and cloud data');
    await tester.tap(find.text('Delete account and cloud data'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Delete').last);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
