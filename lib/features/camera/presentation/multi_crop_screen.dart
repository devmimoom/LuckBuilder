import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/analysis_provider.dart';
import '../providers/crop_provider.dart';
import 'analysis_progress_page.dart';
import 'widgets/box_painter.dart';

class MultiCropScreen extends ConsumerStatefulWidget {
  final File? imageFile;
  const MultiCropScreen({super.key, this.imageFile});

  @override
  ConsumerState<MultiCropScreen> createState() => _MultiCropScreenState();
}

class _MistakeCropContent extends ConsumerStatefulWidget {
  final File? imageFile;
  const _MistakeCropContent({this.imageFile});

  @override
  ConsumerState<_MistakeCropContent> createState() => _MistakeCropContentState();
}

class _MistakeCropContentState extends ConsumerState<_MistakeCropContent> {
  Offset? _startPos;
  Offset? _lastErasePos;  // 用於塗掉模式的連續繪製
  final GlobalKey _imageKey = GlobalKey();

  Future<void> _processCrops() async {
    final cropState = ref.read(cropControllerProvider);
    final rects = cropState.rects;
    final erasePaths = cropState.erasePaths;
    final imagePath = widget.imageFile?.path;
    
    // 獲取圖片在螢幕上的實際渲染大小
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size;

    if (imagePath != null && size != null && rects.isNotEmpty) {
      // 1. 先 watch provider 確保它不會被銷毀
      ref.read(analysisQueueProvider);
      
      // 2. 初始化並開始真正的裁切與 API 隊列（傳遞筆刷遮罩）
      ref.read(analysisQueueProvider.notifier).startAnalysis(
        imagePath: imagePath,
        rects: rects,
        displaySize: size,
        erasePaths: erasePaths, // 傳遞筆刷路徑用於實際遮罩
      );
      
      // 3. 等待一小段時間確保狀態已初始化
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 4. 跳轉到進度頁面
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AnalysisProgressPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cropState = ref.watch(cropControllerProvider);
    final controller = ref.read(cropControllerProvider.notifier);

    return Stack(
      children: [
        // 1. 底層照片
        Positioned.fill(
          child: Opacity(
            opacity: 0.8,
            child: widget.imageFile != null
                ? Image.file(
                    widget.imageFile!, 
                    key: _imageKey, // 用於獲取顯示尺寸
                    fit: BoxFit.contain,
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, color: Colors.white24, size: 64),
                        SizedBox(height: 16),
                        Text("模擬拍照背景", style: TextStyle(color: Colors.white24)),
                      ],
                    ),
                  ),
          ),
        ),

        // 2. 互動與繪製層
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (details) {
              if (cropState.mode == EditMode.select) {
                // 框選模式
                _startPos = details.localPosition;
              } else {
                // 塗掉模式
                _lastErasePos = details.localPosition;
                controller.startErase(details.localPosition);
              }
            },
            onPanUpdate: (details) {
              if (cropState.mode == EditMode.select) {
                // 框選模式
                if (_startPos != null) {
                  controller.updateCurrentRect(_startPos!, details.localPosition);
                }
              } else {
                // 塗掉模式
                final currentPos = details.localPosition;
                if (_lastErasePos != null) {
                  controller.updateErasePath(currentPos);
                  _lastErasePos = currentPos;
                }
              }
            },
            onPanEnd: (_) {
              if (cropState.mode == EditMode.select) {
                // 框選模式
                _startPos = null;
                controller.addRect();
              } else {
                // 塗掉模式
                controller.finishErase();
                _lastErasePos = null;
              }
            },
            child: CustomPaint(
              painter: SelectionPainter(
                rects: cropState.rects,
                current: cropState.currentRect,
                erasePath: cropState.erasePath,
                erasePaths: cropState.erasePaths,
                mode: cropState.mode,
              ),
            ),
          ),
        ),

        // 3. 提示文字（根據模式顯示不同提示）
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cropState.mode == EditMode.select
                    ? "請在考卷上拖拉，框出想要檢討的題目"
                    : "用手指塗掉不想顯示的題目",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),

        // 4. 底部動作列
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Column(
            children: [
              // 模式切換按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildModeButton(
                    context: context,
                    controller: controller,
                    mode: EditMode.select,
                    currentMode: cropState.mode,
                    icon: Icons.crop_free,
                    label: "框選",
                  ),
                  const SizedBox(width: 12),
                  _buildModeButton(
                    context: context,
                    controller: controller,
                    mode: EditMode.erase,
                    currentMode: cropState.mode,
                    icon: Icons.brush,
                    label: "塗掉",
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (cropState.rects.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "已選取 ${cropState.rects.length} 個區塊",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cropState.rects.isEmpty ? null : _processCrops,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  ),
                  child: const Text("開始 AI 智能解析"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 模式切換按鈕
  Widget _buildModeButton({
    required BuildContext context,
    required CropController controller,
    required EditMode mode,
    required EditMode currentMode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = mode == currentMode;
    return GestureDetector(
      onTap: () {
        controller.setMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.highlight : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.highlight : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiCropScreenState extends ConsumerState<MultiCropScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.read(cropControllerProvider.notifier);
    final cropState = ref.watch(cropControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("框選題目", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {
              if (cropState.mode == EditMode.select) {
                controller.removeLast();
              } else {
                controller.removeLastErase();
              }
            },
            icon: const Icon(Icons.undo),
            tooltip: cropState.mode == EditMode.select ? "撤銷上一個框選" : "撤銷上一個塗掉",
          ),
          IconButton(
            onPressed: () => controller.clearAll(),
            icon: const Icon(Icons.refresh),
            tooltip: "清空",
          ),
        ],
      ),
      body: _MistakeCropContent(imageFile: widget.imageFile),
    );
  }
}
