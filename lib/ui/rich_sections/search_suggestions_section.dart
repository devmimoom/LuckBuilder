import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/v2_providers.dart';
import '../../data/search_suggestions_data.dart';
import '../../theme/app_tokens.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_language.dart';
import '../../localization/app_strings.dart';

class SearchSuggestionsSection extends ConsumerWidget {
  final void Function(String) onTap;
  const SearchSuggestionsSection({super.key, required this.onTap});

  static const _fallbackSuggested = [
    'flutter UI design',
    'flashcards app',
    'notification habits',
  ];
  static const _fallbackTrending = [
    'AI',
    'Space',
    'Aesthetics',
    'Health',
    'Finance',
    'Mindset',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchSuggestionsProvider);

    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    return async.when(
      data: (SearchSuggestionsData data) {
        // 若為繁中且有對應欄位，優先使用 suggestedZh / trendingZh，否則退回英文欄位
        final useSuggested = (lang == AppLanguage.zhTw &&
                data.suggestedZh.isNotEmpty)
            ? data.suggestedZh
            : data.suggested;
        final useTrending = (lang == AppLanguage.zhTw &&
                data.trendingZh.isNotEmpty)
            ? data.trendingZh
            : data.trending;
        return _buildContent(
          tokens: tokens,
          suggested: useSuggested,
          trending: useTrending,
          lang: lang,
        );
      },
      loading: () => _buildContent(
        tokens: tokens,
        suggested: _fallbackSuggested,
        trending: _fallbackTrending,
        lang: lang,
      ),
      error: (_, __) => _buildContent(
        tokens: tokens,
        suggested: _fallbackSuggested,
        trending: _fallbackTrending,
        lang: lang,
      ),
    );
  }

  Widget _buildContent({
    required AppTokens tokens,
    required List<String> suggested,
    required List<String> trending,
    required AppLanguage lang,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(uiString(lang, 'search_suggested_title'),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: tokens.sectionTitleColor)),
        const SizedBox(height: 8),
        ...suggested.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(e),
            )),
        const SizedBox(height: 10),
        Text(uiString(lang, 'search_trending_title'),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: tokens.sectionTitleColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: trending
              .map((t) => ActionChip(
                    label: Text(t),
                    onPressed: () => onTap(t),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
