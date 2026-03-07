import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_state_store.dart';
import '../../theme/app_tokens.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';

class SearchHistorySection extends StatefulWidget {
  final void Function(String) onTapQuery;
  const SearchHistorySection({super.key, required this.onTapQuery});

  @override
  State<SearchHistorySection> createState() => SearchHistorySectionState();
}

class SearchHistorySectionState extends State<SearchHistorySection> {
  final _store = UserStateStore();
  bool _loading = true;
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _store.getRecentSearches();
    if (mounted) {
      setState(() {
        _recent = r;
        _loading = false;
      });
    }
  }

  Future<void> reload() async {
    await _load();
  }

  Future<void> _clear() async {
    await _store.clearRecentSearches();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Consumer(builder: (context, ref, _) {
                  final lang = ref.watch(appLanguageProvider);
                  return Text(uiString(lang, 'search_history_title'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary));
                })),
            Consumer(builder: (context, ref, _) {
              final lang = ref.watch(appLanguageProvider);
              if (_recent.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline),
                tooltip: uiString(lang, 'clear'),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        if (_recent.isEmpty)
          Consumer(builder: (context, ref, _) {
            final lang = ref.watch(appLanguageProvider);
            return Text(uiString(lang, 'search_history_empty'),
                style: TextStyle(color: tokens.textSecondary));
          })
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent
                .map((q) => ActionChip(
                      label: Text(q),
                      onPressed: () => widget.onTapQuery(q),
                    ))
                .toList(),
          ),
      ],
    );
  }
}
