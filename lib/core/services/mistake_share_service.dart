import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../database/models/mistake.dart';
import '../utils/latex_helper.dart';

class MistakeShareService {
  MistakeShareService._();

  static Future<void> shareMistake(Mistake mistake) async {
    final summary = _buildSummary(mistake);
    final files = <XFile>[];

    if (mistake.imagePath.isNotEmpty) {
      final file = File(mistake.imagePath);
      if (await file.exists()) {
        files.add(XFile(file.path));
      }
    }

    final params = ShareParams(
      text: summary,
      subject: 'LuckBuilder 錯題分享',
      files: files.isEmpty ? null : files,
    );

    await SharePlus.instance.share(params);
  }

  static String _buildSummary(Mistake mistake) {
    final title = LatexHelper.toReadableText(mistake.title, fallback: '未命名題目');
    final chapter = mistake.resolvedChapter;
    final concepts = mistake.resolvedKeyConcepts.take(3).join('、');

    return [
      '我在 LuckBuilder 整理了一張錯題卡',
      '',
      '題目：$title',
      '科目：${mistake.subject}',
      '分類：${mistake.category}',
      if (chapter != null && chapter.isNotEmpty) '章節：$chapter',
      if (concepts.isNotEmpty) '觀念：$concepts',
      '',
      '一起討論這題吧。',
    ].join('\n');
  }
}
