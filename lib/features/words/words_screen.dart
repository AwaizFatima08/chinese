import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/pinyin.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../l10n/l10n.dart';
import '../../languages/models.dart';
import '../progress/progress_state.dart';
import 'word_detail_sheet.dart';

/// Search text for each word: script, plain romanization and meanings.
final wordIndexProvider = Provider<List<(Word, String)>?>((ref) {
  final content = ref.watch(contentProvider).value;
  if (content == null) return null;
  return [
    for (final w in content.allWords)
      (
        w,
        '${w.text} ${w.altText} ${stripTones(w.romanization)} ${w.meanings.join(' ').toLowerCase()}',
      ),
  ];
});

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  String _query = '';
  int? _level;

  List<Word> _filter(List<(Word, String)> index) {
    final q = stripTones(_query.trim().toLowerCase().replaceAll(' ', ''));
    final raw = _query.trim().toLowerCase();
    return [
      for (final (w, haystack) in index)
        if ((_level == null || w.level == _level) &&
            (raw.isEmpty ||
                haystack.contains(raw) ||
                stripTones(w.romanization).replaceAll(' ', '').contains(q)))
          w,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    final index = ref.watch(wordIndexProvider);
    final progress = ref.watch(progressProvider).value;
    if (content == null || index == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.wordsTitle)),
        body: MessageView(message: l.commonLoading, loading: true),
      );
    }
    final results = _filter(index);
    return Scaffold(
      appBar: AppBar(title: Text(l.wordsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l.wordsSearch(content.pack.romanizationLabel),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(l.wordsAll),
                    selected: _level == null,
                    onSelected: (_) => setState(() => _level = null),
                  ),
                ),
                for (final info in content.pack.levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(info.name),
                      selected: _level == info.number,
                      onSelected: (_) => setState(() => _level = info.number),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? MessageView(
                    message: l.wordsNone,
                    icon: Icons.search_off_rounded,
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemExtent: 76,
                    itemBuilder: (context, i) {
                      final w = results[i];
                      final learned = progress?.words[w.id]?.isLearned ?? false;
                      return ListTile(
                        onTap: () => showWordDetail(context, w),
                        leading: SizedBox(
                          width: 84,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              w.text,
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
                        title: Text(
                          w.romanization,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          w.primaryMeaning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: learned
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.appColors.success,
                                semanticLabel: l.wordsLearnedBadge,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
