import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'crop_provider.g.dart';

enum EditMode {
  select, // 框選模式
  erase, // 塗掉模式
}

class CropState {
  final List<Rect> rects;
  final Rect? currentRect;
  final EditMode mode; // 當前模式
  final Path erasePath; // 當前正在塗掉的路徑
  final List<Path> erasePaths; // 所有塗掉的路徑（用於實際遮罩）

  CropState({
    this.rects = const [],
    this.currentRect,
    this.mode = EditMode.select,
    Path? erasePath,
    List<Path>? erasePaths,
  })  : erasePath = erasePath ?? Path(),
        erasePaths = erasePaths ?? const [];

  CropState copyWith({
    List<Rect>? rects,
    Rect? currentRect,
    bool clearCurrent = false,
    EditMode? mode,
    Path? erasePath,
    List<Path>? erasePaths,
    bool clearErasePath = false,
  }) {
    return CropState(
      rects: rects ?? this.rects,
      currentRect: clearCurrent ? null : (currentRect ?? this.currentRect),
      mode: mode ?? this.mode,
      erasePath: clearErasePath ? Path() : (erasePath ?? this.erasePath),
      erasePaths: erasePaths ?? this.erasePaths,
    );
  }
}

@riverpod
class CropController extends _$CropController {
  @override
  CropState build() => CropState();

  // 切換模式
  void setMode(EditMode mode) {
    state =
        state.copyWith(mode: mode, clearCurrent: true, clearErasePath: true);
  }

  // 框選模式：更新當前矩形
  void updateCurrentRect(Offset start, Offset current) {
    if (state.mode != EditMode.select) return;
    state = state.copyWith(
      currentRect: Rect.fromPoints(start, current),
    );
  }

  // 框選模式：添加矩形
  void addRect() {
    if (state.mode != EditMode.select) return;
    if (state.currentRect != null && state.currentRect!.width > 10) {
      state = state.copyWith(
        rects: [...state.rects, state.currentRect!],
        clearCurrent: true,
      );
    } else {
      state = state.copyWith(clearCurrent: true);
    }
  }

  // 塗掉模式：開始塗掉
  void startErase(Offset position) {
    if (state.mode != EditMode.erase) return;
    final newPath = Path()..moveTo(position.dx, position.dy);
    state = state.copyWith(erasePath: newPath);
  }

  // 塗掉模式：更新塗掉路徑
  void updateErasePath(Offset position) {
    if (state.mode != EditMode.erase) return;
    final newPath = Path.from(state.erasePath)
      ..lineTo(position.dx, position.dy);
    state = state.copyWith(erasePath: newPath);
  }

  // 塗掉模式：結束塗掉並保存路徑
  void finishErase() {
    if (state.mode != EditMode.erase) return;
    if (state.erasePath.computeMetrics().isNotEmpty) {
      state = state.copyWith(
        erasePaths: [...state.erasePaths, Path.from(state.erasePath)],
        clearErasePath: true,
      );
    } else {
      state = state.copyWith(clearErasePath: true);
    }
  }

  // 框選模式：移除最後一個矩形
  void removeLast() {
    if (state.rects.isNotEmpty) {
      state = state.copyWith(
        rects: List.from(state.rects)..removeLast(),
      );
    }
  }

  // 塗掉模式：移除最後一個塗掉路徑
  void removeLastErase() {
    if (state.erasePaths.isNotEmpty) {
      final newPaths = List<Path>.from(state.erasePaths)..removeLast();
      state = state.copyWith(erasePaths: newPaths);
    }
  }

  void clearAll() {
    state = CropState(mode: state.mode); // 保留當前模式
  }
}
