import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lingodaily/core/providers.dart';
import 'package:lingodaily/core/services/listener.dart';
import 'package:lingodaily/core/services/speaker.dart';
import 'package:lingodaily/data/progress_repository.dart';
import 'package:lingodaily/languages/language_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_bundle.dart';

/// A mutable test clock.
class TestClock {
  TestClock(this.now);

  DateTime now;

  Clock get clock => Clock(() => now);
}

/// A provider container wired with in-memory storage, real content from
/// disk, a silent teacher voice and no ads.
Future<
  ({
    ProviderContainer container,
    TestClock time,
    InMemoryProgressRepository repo,
  })
>
makeContainer({
  bool onboardingDone = true,
  DateTime? start,
  String language = 'zh',
}) async {
  SharedPreferences.setMockInitialValues({
    'onboardingDone': onboardingDone,
    'language': language,
  });
  final prefs = await SharedPreferences.getInstance();
  final time = TestClock(start ?? DateTime(2026, 10, 17, 9));
  final repo = InMemoryProgressRepository();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      progressRepositoryProvider.overrideWithValue(repo),
      contentProvider.overrideWith(
        (ref) => LanguageContent.load(
          ref.watch(settingsProvider.select((s) => s.languageId)),
          bundle: FileAssetBundle(),
        ),
      ),
      clockProvider.overrideWith((ref) => time.clock),
      speakerProvider.overrideWithValue(SilentSpeaker()),
      voiceListenerProvider.overrideWithValue(
        ScriptedListener(isAvailable: false),
      ),
    ],
  );
  return (container: container, time: time, repo: repo);
}
