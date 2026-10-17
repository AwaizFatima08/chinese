import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lingodaily/app.dart';
import 'package:lingodaily/core/providers.dart';
import 'package:lingodaily/core/theme/app_theme.dart';
import 'package:lingodaily/l10n/l10n.dart';
import 'package:lingodaily/core/services/listener.dart';
import 'package:lingodaily/features/home/home_shell.dart';
import 'package:lingodaily/data/progress_models.dart';
import 'package:lingodaily/features/lesson/views/view_support.dart';
import 'package:lingodaily/features/progress/progress_state.dart';
import 'package:lingodaily/features/speak/say_panel.dart';
import 'package:lingodaily/features/speak/speak_content.dart';
import 'package:lingodaily/features/speak/speak_providers.dart';
import 'package:lingodaily/features/speak/speak_session_screen.dart';
import 'package:lingodaily/features/speak/speak_steps.dart';
import 'package:lingodaily/features/speak/talk_view.dart';
import 'package:lingodaily/features/speak/melody_view.dart';
import 'package:lingodaily/features/speak/prosody.dart';
import 'package:lingodaily/core/services/audio_capture.dart';
import 'package:lingodaily/core/services/speaker.dart';
import 'package:lingodaily/core/util/pcm.dart';
import 'helpers/synthetic_voice.dart';

import 'helpers/file_bundle.dart';
import 'helpers/test_app.dart';

void main() {
  late SpeakContent content;

  setUpAll(() async {
    content = await SpeakContent.load(bundle: FileAssetBundle());
  });

  group('content', () {
    test('has the expected amount, all with pronunciation guides', () {
      expect(content.sounds.length, 18);
      expect(content.sounds.expand((s) => s.pairs).length, greaterThan(120));
      expect(content.vocabWordCount, 300);
      expect(content.twisters.length, 24);
      expect(content.shadow.expand((s) => s.items).length, greaterThan(100));
      for (final u in content.vocab) {
        for (final w in u.words) {
          expect(w.ipa, isNotEmpty, reason: w.word);
          expect(w.definition, isNotEmpty);
          expect(w.example.toLowerCase(), contains(w.word.substring(0, 3)));
        }
      }
    });

    test('minimal pairs really differ and have different IPA', () {
      for (final s in content.sounds) {
        for (final p in s.pairs) {
          expect(p.a.toLowerCase(), isNot(p.b.toLowerCase()), reason: s.id);
          expect(p.ipaA, isNot(p.ipaB), reason: '${p.a}/${p.b}');
        }
        expect(s.phrases, isNotEmpty);
      }
    });

    test('stress words have two or more syllables and a marked stress', () {
      for (final s in content.stress) {
        expect(s.words.length, greaterThanOrEqualTo(8), reason: s.id);
        for (final w in s.words) {
          expect(w.syllables.length, greaterThanOrEqualTo(2), reason: w.word);
          expect(w.stress, inInclusiveRange(1, w.syllables.length));
          expect(w.syllables[w.stress - 1], startsWith('ˈ'), reason: w.word);
        }
      }
    });

    test('noun and verb readings put the stress in different places', () {
      final set = content.stressSet('noun-verb')!;
      final record = set.words.where((w) => w.word == 'record').toList();
      expect(record.length, 2);
      expect(record.first.stress, 1);
      expect(record.last.stress, 2);
    });

    test('role-plays are complete and their replies fit their topic', () {
      expect(content.talks.length, 9);
      for (final t in content.talks) {
        expect(t.turns.length, 6, reason: t.id);
        expect(t.phrases, isNotEmpty);
        for (final turn in t.turns) {
          expect(turn.replies.length, 3, reason: t.id);
          for (final r in turn.replies) {
            expect(
              isOnTopic(turn, r),
              isTrue,
              reason: '${t.id}: "${turn.say}" -> "$r"',
            );
          }
        }
      }
    });

    test('free answers must be a few words and on topic', () {
      const turn = TalkTurn(
        say: 'What would you like?',
        replies: ['A coffee, please.'],
        keywords: ['coffee', 'tea'],
      );
      expect(isOnTopic(turn, 'I would like a coffee please'), isTrue);
      expect(isOnTopic(turn, 'coffee'), isFalse, reason: 'too short');
      expect(isOnTopic(turn, 'the weather is lovely today'), isFalse);
      expect(isOnTopic(turn, ''), isFalse);
    });

    test('vocabulary ids are unique and groups are complete', () {
      final ids = [
        for (final u in content.vocab)
          for (final w in u.words) w.id,
      ];
      expect(ids.toSet().length, ids.length);
      final sets = content.allSets.toList();
      expect(sets.map((s) => s.id).toSet().length, sets.length);
      expect(sets.length, greaterThan(100));
    });
  });

  group('step builder', () {
    test('every practice set builds a sensible session', () {
      for (final set in content.allSets) {
        final steps = SpeakStepBuilder(content, seed: 7).forSet(set.id);
        expect(steps, isNotEmpty, reason: set.id);
        expect(steps.length, lessThanOrEqualTo(24), reason: set.id);
        for (final step in steps) {
          if (step is ListenPickStep) {
            expect(step.options.length, 2);
            expect(step.answerIndex, isNonNegative);
          }
          if (step is VocabRecallStep) {
            expect(step.options.length, 4);
            expect(step.options.map((o) => o.id).toSet().length, 4);
            expect(step.answerIndex, isNonNegative);
          }
        }
      }
    });

    test('the same seed gives the same session', () {
      String sig(List<SpeakStep> l) => l.map((s) => s.runtimeType).join(',');
      expect(
        sig(SpeakStepBuilder(content, seed: 3).forSet('snd:ih-ee')),
        sig(SpeakStepBuilder(content, seed: 3).forSet('snd:ih-ee')),
      );
    });

    test('a sound set teaches, listens, then speaks', () {
      final steps = SpeakStepBuilder(content, seed: 1).forSet('snd:th-s');
      expect(steps.first, isA<TipStep>());
      expect(steps.whereType<ListenPickStep>().length, 4);
      expect(steps.whereType<SayWordStep>().length, 4);
      expect(steps.whereType<SayTextStep>().length, 2);
      expect(
        steps.whereType<SayWordStep>().every((s) => s.contrast != null),
        isTrue,
      );
    });

    test('a vocabulary part meets, recalls and says five words', () {
      final steps = SpeakStepBuilder(content, seed: 1).forSet('voc:work:1');
      expect(steps.whereType<VocabIntroStep>().length, 5);
      expect(steps.whereType<VocabRecallStep>().length, 5);
      expect(steps.whereType<SayWordStep>().length, 5);
    });

    test('a role-play opens with phrases, then one step per turn', () {
      final steps = SpeakStepBuilder(content, seed: 1).forSet('talk:hotel');
      expect(steps.first, isA<TipStep>());
      expect((steps.first as TipStep).phrases, isNotEmpty);
      final turns = steps.whereType<TalkTurnStep>().toList();
      expect(turns.length, 6);
      expect(turns.last.number, 6);
      expect(turns.first.partner, contains('Maria'));
    });

    test('noun and verb stress words are not played, others are', () {
      final steps = SpeakStepBuilder(
        content,
        seed: 1,
      ).forSet('str:noun-verb').whereType<StressPickStep>();
      expect(steps.every((s) => !s.canPlay), isTrue);
      final plain = SpeakStepBuilder(
        content,
        seed: 1,
      ).forSet('str:long-words').whereType<StressPickStep>();
      expect(plain.every((s) => s.canPlay), isTrue);
    });

    test('unknown sets give nothing', () {
      expect(SpeakStepBuilder(content, seed: 1).forSet('nope:x'), isEmpty);
      expect(SpeakStepBuilder(content, seed: 1).forSet('voc:work:99'), isEmpty);
    });
  });

  group('say panel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required String target,
      required List<ListenResult> script,
      String? contrast,
      SayDone? onDone,
    }) async {
      final t = await makeContainer(listener: ScriptedListener(script: script));
      addTearDown(t.container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: t.container,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SayPanel(
                target: target,
                contrast: contrast,
                tip: 'Tongue between the teeth.',
                onDone: onDone ?? (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<List<(bool, double)>> pumpTalk(
      WidgetTester tester,
      List<ListenResult> script,
    ) async {
      final answers = <(bool, double)>[];
      final t = await makeContainer(listener: ScriptedListener(script: script));
      addTearDown(t.container.dispose);
      final talk = content.talk('coffee')!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: t.container,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TalkTurnView(
                step: TalkTurnStep(
                  partner: talk.partner,
                  turn: talk.turns.first,
                  number: 1,
                  total: 6,
                ),
                onAnswered: (ok, score, {reveal, vocabId}) =>
                    answers.add((ok, score)),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      return answers;
    }

    testWidgets('a role-play reply read out loud is scored', (tester) async {
      final answers = await pumpTalk(tester, [
        const ListenResult.heard("I'd like a medium cappuccino, please."),
      ]);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(answers.single.$1, isTrue);
    });

    testWidgets('an own-words reply passes when on topic only', (tester) async {
      final answers = await pumpTalk(tester, [
        const ListenResult.heard('the weather is nice today'),
        const ListenResult.heard('can I get a tea please'),
      ]);
      await tester.tap(find.byKey(const ValueKey('toggle-own')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('own-mic')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(answers, isEmpty);
      expect(find.textContaining('did not seem to answer'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('own-mic')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(answers.single, (true, talkFreeScore));
    });

    Future<List<(bool, double)>> pumpMelody(
      WidgetTester tester, {
      required List<Pcm?> recordings,
      bool withModel = true,
    }) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final answers = <(bool, double)>[];
      final speaker = SilentSpeaker();
      if (withModel) {
        speaker.wav = wavBytes(
          voice(seconds: 2, semitones: riseFall, rate: 24000),
        );
      }
      final t = await makeContainer(
        capture: ScriptedCapture(script: recordings),
        speaker: speaker,
        extraOverrides: [
          prosodyAnalyzerProvider.overrideWithValue(
            (pcm) async => extractProsody(pcm),
          ),
        ],
      );
      addTearDown(t.container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: t.container,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MelodyView(
                step: const MelodyStep(text: 'Are you coming to the party?'),
                onAnswered: (ok, score, {reveal, vocabId}) =>
                    answers.add((ok, score)),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return answers;
    }

    Future<void> tapMelodyMic(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('melody-mic')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('copying the model melody passes', (tester) async {
      final answers = await pumpMelody(
        tester,
        recordings: [voice(seconds: 2.2, base: 200, semitones: riseFall)],
      );
      await tapMelodyMic(tester);
      expect(answers.single.$1, isTrue);
      expect(find.text('Well matched!'), findsOneWidget);
    });

    testWidgets('a flat voice is told so and may try again', (tester) async {
      final answers = await pumpMelody(
        tester,
        recordings: [
          voice(seconds: 2, semitones: (u) => 0),
          voice(seconds: 2, base: 180, semitones: riseFall),
        ],
      );
      await tapMelodyMic(tester);
      expect(answers, isEmpty);
      expect(find.textContaining('too flat'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('melody-again')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(answers.single.$1, isTrue);
    });

    testWidgets('a failed recording asks for a clearer voice', (tester) async {
      final answers = await pumpMelody(tester, recordings: [null]);
      await tapMelodyMic(tester);
      expect(answers, isEmpty);
      expect(
        find.textContaining('could not hear a clear voice'),
        findsOneWidget,
      );
    });

    testWidgets('without a model recording the learner marks themselves', (
      tester,
    ) async {
      final answers = await pumpMelody(
        tester,
        recordings: const [],
        withModel: false,
      );
      expect(
        find.textContaining('cannot record the model voice'),
        findsOneWidget,
      );
      await tester.tap(find.text('I said it'));
      await tester.pump();
      expect(answers.single.$1, isTrue);
    });

    testWidgets('a clear attempt passes', (tester) async {
      bool? passed;
      await pumpPanel(
        tester,
        target: 'ship',
        script: [const ListenResult.heard('ship')],
        onDone: (p, a) => passed = p,
      );
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(passed, isTrue);
      expect(find.text('Clear!'), findsOneWidget);
    });

    testWidgets('a mix-up is named and the learner may try again', (
      tester,
    ) async {
      bool? passed;
      await pumpPanel(
        tester,
        target: 'ship',
        contrast: 'sheep',
        script: [
          const ListenResult.heard('sheep'),
          const ListenResult.heard('ship'),
        ],
        onDone: (p, a) => passed = p,
      );
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(passed, isNull);
      expect(find.textContaining('sounded like'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(passed, isTrue);
    });

    testWidgets('nothing heard asks to check the microphone', (tester) async {
      await pumpPanel(
        tester,
        target: 'hello',
        script: [const ListenResult.failed(ListenFailure.noSpeech)],
      );
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('did not hear'), findsOneWidget);
    });

    testWidgets('skipping ends the step as not passed', (tester) async {
      bool? passed;
      await pumpPanel(
        tester,
        target: 'hello',
        script: const [],
        onDone: (p, a) => passed = p,
      );
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(passed, isFalse);
    });

    testWidgets('without speech recognition the learner marks themselves', (
      tester,
    ) async {
      bool? passed;
      final t = await makeContainer(); // listener unavailable by default
      addTearDown(t.container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: t.container,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SayPanel(target: 'hello', onDone: (p, a) => passed = p),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('I said it'), findsOneWidget);
      await tester.tap(find.text('I said it'));
      expect(passed, isTrue);
    });
  });

  group('session', () {
    testWidgets('every kind of set runs on a narrow phone at larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(678, 1410);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final t = await makeContainer(
        extraOverrides: [
          speakContentProvider.overrideWith(
            (ref) => SpeakContent.load(bundle: FileAssetBundle()),
          ),
        ],
      );
      addTearDown(t.container.dispose);
      await tester.runAsync(() async {
        await t.container.read(contentProvider.future);
        await t.container.read(progressProvider.future);
        await t.container.read(speakerReadyProvider.future);
        await t.container.read(languageRegistryProvider.future);
        await t.container.read(adsReadyProvider.future);
        await t.container.read(speakContentProvider.future);
        await t.container.read(speakProgressProvider.future);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: t.container,
          child: const LingoDailyApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Speak').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'home tab');

      for (final id in [
        'snd:th-s',
        'str:noun-verb',
        'str:long-words',
        'voc:behaviour:2',
        'sh:interview',
        'tw:2',
        'talk:coffee',
        'mel:interview',
      ]) {
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        unawaited(router.push('/speak/${Uri.encodeComponent(id)}'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(milliseconds: 400));
        var guard = 0;
        while (find.text('Session complete!').evaluate().isEmpty &&
            guard++ < 80) {
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: '$id step $guard');
          if (find.text('Session complete!').evaluate().isNotEmpty) break;
          final go = find.widgetWithText(FilledButton, "Let's go");
          final cont = find.widgetWithText(FilledButton, 'Continue');
          final self = find.text('I said it');
          final options = find.byType(OptionButton);
          final syl = find.byKey(const ValueKey('syllable-0'));
          Future<void> press(Finder f) async {
            final list = find
                .descendant(
                  of: find.byType(SpeakSessionScreen),
                  matching: find.byType(Scrollable),
                )
                .first;
            for (var i = 0; i < 12; i++) {
              if (tester.getRect(f.first).bottom < 640) break;
              await tester.drag(list, const Offset(0, -160));
              await tester.pump();
            }
            await tester.tap(f.first);
          }

          if (go.evaluate().isNotEmpty) {
            await press(go);
          } else if (cont.evaluate().isNotEmpty) {
            await press(cont);
          } else if (self.evaluate().isNotEmpty) {
            await press(self);
          } else if (options.evaluate().isNotEmpty) {
            await press(options);
          } else if (syl.evaluate().isNotEmpty) {
            await press(syl);
          }
        }
        if (find.text('Session complete!').evaluate().isEmpty) {
          debugPrint(
            'STUCK $id: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(25).toList()}',
          );
        }
        expect(find.text('Session complete!'), findsOneWidget, reason: id);
        await tester.tap(find.text('Back to Speak'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: id);
      }
    });
    testWidgets('play a sound set through: stars and study time are saved', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final t = await makeContainer(
        extraOverrides: [
          speakContentProvider.overrideWith(
            (ref) => SpeakContent.load(bundle: FileAssetBundle()),
          ),
        ],
      );
      addTearDown(t.container.dispose);
      await tester.runAsync(() async {
        await t.container.read(contentProvider.future);
        await t.container.read(progressProvider.future);
        await t.container.read(speakerReadyProvider.future);
        await t.container.read(languageRegistryProvider.future);
        await t.container.read(adsReadyProvider.future);
        await t.container.read(speakContentProvider.future);
        await t.container.read(speakProgressProvider.future);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: t.container,
          child: const LingoDailyApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Open the Speak tab and the first sound set.
      await tester.tap(find.text('Speak').last);
      await tester.pumpAndSettle();
      expect(find.text('Speak English'), findsOneWidget);
      await tester.tap(find.text('Sounds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ship vs sheep'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      var guard = 0;
      while (find.text('Session complete!').evaluate().isEmpty &&
          guard++ < 80) {
        await tester.pump(const Duration(milliseconds: 300));
        if (find.text('Session complete!').evaluate().isNotEmpty) break;
        final go = find.widgetWithText(FilledButton, "Let's go");
        final cont = find.widgetWithText(FilledButton, 'Continue');
        final self = find.text('I said it');
        final skip = find.widgetWithText(TextButton, 'Skip');
        final options = find.byType(OptionButton);
        if (go.evaluate().isNotEmpty) {
          await tester.tap(go);
        } else if (cont.evaluate().isNotEmpty) {
          await tester.tap(cont.first);
        } else if (self.evaluate().isNotEmpty) {
          await tester.tap(self.first);
        } else if (skip.evaluate().isNotEmpty) {
          await tester.tap(skip.first, warnIfMissed: false);
        } else if (options.evaluate().isNotEmpty) {
          await tester.tap(options.first);
        }
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Session complete!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final saved = await t.repo.lessonResults(speakLanguage);
      expect(saved.keys, contains('snd:ih-ee'));
      expect(saved['snd:ih-ee']!.stars, inInclusiveRange(1, 3));
      expect(await t.repo.totalSeconds(), greaterThanOrEqualTo(0));
      expect((await t.repo.dayLog(dayNumber(t.time.now))).lessons, 1);
    });
  });
}
