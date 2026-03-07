import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/push_timeline_list.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';

class PushTimelinePage extends ConsumerWidget {
  const PushTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiString(lang, 'push_timeline_header')),
      ),
      body: const PushTimelineList(showTopBar: true),
    );
  }
}


