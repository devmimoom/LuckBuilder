import 'package:flutter/foundation.dart';

@immutable
class SearchSuggestionsData {
  final List<String> suggested;
  final List<String> trending;
  final List<String> suggestedZh;
  final List<String> trendingZh;

  const SearchSuggestionsData({
    required this.suggested,
    required this.trending,
    required this.suggestedZh,
    required this.trendingZh,
  });
}

