import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';
import '../data/settings.dart';
import '../languages/language_content.dart';
import '../languages/language_tools.dart';
import 'services/ad_service.dart';
import 'services/listener.dart';
import 'services/speaker.dart';

// ---- composition-root overrides -------------------------------------------

/// Overridden in `main()` once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider not overridden'),
);

/// Overridden in `main()` once the database is open.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('appDatabaseProvider not overridden'),
);

final languageRegistryProvider = FutureProvider<LanguageRegistry>(
  (ref) => LanguageRegistry.load(),
);

// ---- services ---------------------------------------------------------------

final clockProvider = Provider<Clock>((ref) => const Clock());

/// Today's day number in the learner's calendar. Computed on every call
/// (never cached) so an app left open past midnight stays correct.
extension TodayRef on Ref {
  int get today => dayNumber(read(clockProvider).now());
}

final speakerProvider = Provider<Speaker>((ref) => DeviceSpeaker());
final voiceListenerProvider = Provider<VoiceListener>(
  (ref) => DeviceVoiceListener(),
);
final adServiceProvider = Provider<AdService>((ref) => const NoAdService());

// ---- data ---------------------------------------------------------------------

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SqliteProgressRepository(ref.watch(appDatabaseProvider)),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(sharedPreferencesProvider)),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).load();

  Future<void> update(AppSettings Function(AppSettings) change) async {
    final next = change(state);
    await ref.read(settingsStoreProvider).save(next);
    state = next;
  }

  Future<void> setLevel(String language, int level) =>
      update((s) => s.copyWith(levels: {...s.levels, language: level}));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ---- content ------------------------------------------------------------------

/// Content of the language currently being learned.
final contentProvider = FutureProvider<LanguageContent>((ref) {
  final id = ref.watch(settingsProvider.select((s) => s.languageId));
  return LanguageContent.load(id);
});

/// Language-specific text tools (tiles, speech matching) for the current pack.
final languageToolsProvider = Provider<LanguageTools?>((ref) {
  final content = ref.watch(contentProvider).asData?.value;
  return content == null
      ? null
      : LanguageTools.forPack(content.pack, content.words.values);
});
