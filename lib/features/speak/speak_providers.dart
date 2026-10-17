import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/util/pcm.dart';
import '../../data/progress_models.dart';
import 'prosody.dart';
import 'speak_content.dart';

/// Spoken-English progress is saved under this language id.
const speakLanguage = 'en';

final speakContentProvider = FutureProvider<SpeakContent>(
  (ref) => SpeakContent.load(),
);

/// Saved stars per practice set and the review schedule of English words.
class SpeakProgress {
  const SpeakProgress({required this.sets, required this.words});

  final Map<String, LessonResult> sets;
  final Map<int, WordProgress> words;

  int starsFor(String setId) => sets[setId]?.stars ?? 0;
  int get setsDone => sets.length;
  int get wordsLearned => words.values.where((w) => w.isLearned).length;

  /// Vocabulary due for review today, most overdue first.
  List<int> dueWordIds(int today) {
    final due = words.values.where((w) => w.dueDay <= today).toList()
      ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
    return [for (final w in due) w.wordId];
  }
}

final speakProgressProvider = FutureProvider<SpeakProgress>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return SpeakProgress(
    sets: await repo.lessonResults(speakLanguage),
    words: await repo.wordProgress(speakLanguage),
  );
});

/// Reads pitch and loudness from a recording. Runs off the main isolate so
/// the screen stays smooth; tests replace it with a direct call.
final prosodyAnalyzerProvider = Provider<Future<Prosody> Function(Pcm)>(
  (ref) =>
      (pcm) => compute(extractProsody, pcm),
);
