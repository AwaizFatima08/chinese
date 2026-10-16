import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How romanization (pinyin) is shown next to the script.
enum RomanizationMode { always, tapToReveal, hidden }

@immutable
class AppSettings {
  const AppSettings({
    this.languageId = 'zh',
    this.levels = const {},
    this.dailyGoalMinutes = 15,
    this.slowSpeech = false,
    this.autoPlay = true,
    this.romanization = RomanizationMode.always,
    this.toneColors = true,
    this.haptics = true,
    this.unlockAll = false,
    this.onboardingDone = false,
  });

  /// Language currently being learned.
  final String languageId;

  /// Level number being worked on, per language id.
  final Map<String, int> levels;

  /// Daily study goal; capped at 15 minutes by design.
  final int dailyGoalMinutes;

  /// Slow the teacher voice (useful while learning tones).
  final bool slowSpeech;

  /// Speak words automatically when they appear.
  final bool autoPlay;
  final RomanizationMode romanization;

  /// Colour pinyin and characters by tone.
  final bool toneColors;
  final bool haptics;

  /// Open every lesson instead of unlocking in order.
  final bool unlockAll;
  final bool onboardingDone;

  int levelFor(String language) => levels[language] ?? 1;

  AppSettings copyWith({
    String? languageId,
    Map<String, int>? levels,
    int? dailyGoalMinutes,
    bool? slowSpeech,
    bool? autoPlay,
    RomanizationMode? romanization,
    bool? toneColors,
    bool? haptics,
    bool? unlockAll,
    bool? onboardingDone,
  }) => AppSettings(
    languageId: languageId ?? this.languageId,
    levels: levels ?? this.levels,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    slowSpeech: slowSpeech ?? this.slowSpeech,
    autoPlay: autoPlay ?? this.autoPlay,
    romanization: romanization ?? this.romanization,
    toneColors: toneColors ?? this.toneColors,
    haptics: haptics ?? this.haptics,
    unlockAll: unlockAll ?? this.unlockAll,
    onboardingDone: onboardingDone ?? this.onboardingDone,
  );
}

/// Reads and writes [AppSettings] in SharedPreferences.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const maxDailyGoalMinutes = 15;

  AppSettings load() {
    final lang = _prefs.getString('language') ?? 'zh';
    final levels = <String, int>{
      for (final k in _prefs.getKeys().where((k) => k.startsWith('level.')))
        k.substring('level.'.length): _prefs.getInt(k) ?? 1,
    };
    final modeName = _prefs.getString('romanization');
    return AppSettings(
      languageId: lang,
      levels: levels,
      dailyGoalMinutes: (_prefs.getInt('dailyGoal') ?? maxDailyGoalMinutes)
          .clamp(5, maxDailyGoalMinutes),
      slowSpeech: _prefs.getBool('slowSpeech') ?? false,
      autoPlay: _prefs.getBool('autoPlay') ?? true,
      romanization: RomanizationMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => RomanizationMode.always,
      ),
      toneColors: _prefs.getBool('toneColors') ?? true,
      haptics: _prefs.getBool('haptics') ?? true,
      unlockAll: _prefs.getBool('unlockAll') ?? false,
      onboardingDone: _prefs.getBool('onboardingDone') ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setString('language', s.languageId);
    for (final e in s.levels.entries) {
      await _prefs.setInt('level.${e.key}', e.value);
    }
    await _prefs.setInt('dailyGoal', s.dailyGoalMinutes);
    await _prefs.setBool('slowSpeech', s.slowSpeech);
    await _prefs.setBool('autoPlay', s.autoPlay);
    await _prefs.setString('romanization', s.romanization.name);
    await _prefs.setBool('toneColors', s.toneColors);
    await _prefs.setBool('haptics', s.haptics);
    await _prefs.setBool('unlockAll', s.unlockAll);
    await _prefs.setBool('onboardingDone', s.onboardingDone);
  }
}
