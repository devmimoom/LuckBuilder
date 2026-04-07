import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/latex_helper.dart';
import '../providers/mistakes_provider.dart';

/// 使用範例：如何在 UI 中使用錯題本功能
///
/// 這個檔案展示了如何使用 Riverpod AsyncNotifier 來管理錯題本的 CRUD 操作
class MistakesExamplePage extends ConsumerWidget {
  const MistakesExamplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 ref.watch 監聽錯題列表
    final mistakesAsync = ref.watch(mistakesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("錯題本")),
      body: mistakesAsync.when(
        data: (mistakes) => ListView.builder(
          itemCount: mistakes.length,
          itemBuilder: (context, index) {
            final mistake = mistakes[index];
            return ListTile(
              title: Text(
                  LatexHelper.toReadableText(mistake.title, fallback: '未命名題目')),
              subtitle: Text(mistake.tagsForDisplay.join(', ')),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  // 刪除錯題
                  ref
                      .read(mistakesProvider.notifier)
                      .deleteMistake(mistake.id!);
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('載入失敗: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addExampleMistake(ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 範例：新增錯題
  Future<void> _addExampleMistake(WidgetRef ref) async {
    // 1. 假設你有一個圖片檔案
    // final imageFile = File('/path/to/image.jpg');

    // 2. 使用 ImagePathHelper 儲存圖片並取得路徑
    // final imagePath = await ImagePathHelper.saveImage(imageFile);

    // 3. 新增錯題到資料庫
    await ref.read(mistakesProvider.notifier).addMistake(
          imagePath:
              '/path/to/image.jpg', // 使用 ImagePathHelper.saveImage() 取得的路徑
          title: '幾何題 - 相似三角形',
          tags: ['幾何', '必考題'],
          solutions: ['解法一：使用相似三角形性質', '解法二：使用比例'],
          subject: '數學',
          category: '幾何',
          chapter: '相似形',
        );
  }
}

/// 範例：如何讀取單一錯題
class MistakeDetailExample extends ConsumerWidget {
  final int mistakeId;

  const MistakeDetailExample({super.key, required this.mistakeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 ref.watch 監聽單一錯題
    final mistakeAsync = ref.watch(mistakeByIdProvider(mistakeId));

    return mistakeAsync.when(
      data: (mistake) {
        if (mistake == null) {
          return const Center(child: Text('找不到此錯題'));
        }

        return Column(
          children: [
            // 顯示圖片（只存路徑，不存圖片本身）
            Image.file(File(mistake.imagePath)),
            Text(LatexHelper.toReadableText(mistake.title, fallback: '未命名題目')),
            Text('標籤: ${mistake.tagsForDisplay.join(', ')}'),
            // ... 其他 UI
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
