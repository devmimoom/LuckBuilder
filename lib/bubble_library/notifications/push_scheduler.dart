import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/content_item.dart';
import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../models/user_library.dart';

class PushTask {
  final String productId;
  final DateTime when;
  final ContentItem item;
  /// 是否為該產品的最後一則內容（完成此則即完成產品）
  final bool isLastInProduct;

  PushTask({
    required this.productId,
    required this.when,
    required this.item,
    this.isLastInProduct = false,
  });
}

class PushScheduler {
  // ✅ 新的8个固定2小时时间段定义（时间范围）
  static const Map<String, TimeRange> presetSlotRanges = {
    '7-9': TimeRange(TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 9, minute: 0)),
    '9-11': TimeRange(TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 11, minute: 0)),
    '11-13': TimeRange(TimeOfDay(hour: 11, minute: 0), TimeOfDay(hour: 13, minute: 0)),
    '13-15': TimeRange(TimeOfDay(hour: 13, minute: 0), TimeOfDay(hour: 15, minute: 0)),
    '15-17': TimeRange(TimeOfDay(hour: 15, minute: 0), TimeOfDay(hour: 17, minute: 0)),
    '17-19': TimeRange(TimeOfDay(hour: 17, minute: 0), TimeOfDay(hour: 19, minute: 0)),
    '19-21': TimeRange(TimeOfDay(hour: 19, minute: 0), TimeOfDay(hour: 21, minute: 0)),
    '21-23': TimeRange(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 23, minute: 0)),
  };

  static int _todToMin(TimeOfDay t) => t.hour * 60 + t.minute;

  static bool _inQuiet(TimeRange q, TimeOfDay t) {
    final start = _todToMin(q.start);
    final end = _todToMin(q.end);
    final cur = _todToMin(t);

    // ✅ 修復：start == end 時視為「無勿擾時段」（例如 0:0 - 0:0）
    if (start == end) {
      if (kDebugMode) {
        debugPrint('  ℹ️ _inQuiet: 無勿擾時段（start == end），時間 ${formatTimeOfDay(t)} 不在勿擾時段');
      }
      return false;
    }

    bool result;
    if (start < end) {
      result = cur >= start && cur < end; // same-day
    } else {
      result = cur >= start || cur < end; // crosses midnight
    }
    
    if (kDebugMode && result) {
      debugPrint('  ⚠️ _inQuiet: 時間 ${formatTimeOfDay(t)} 在勿擾時段內（${formatTimeRange(q)}）');
    }
    
    return result;
  }

  static DateTime _at(DateTime date, TimeOfDay tod) =>
      DateTime(date.year, date.month, date.day, tod.hour, tod.minute);

  /// 在时间范围内完全随机生成时间点
  /// 确保间隔至少 minIntervalMinutes（硬编码为3分钟）
  static List<TimeOfDay> _generateTimesInRange(
    TimeRange range,
    int minIntervalMinutes, // 固定为3
  ) {
    final startMin = _todToMin(range.start);
    final endMin = _todToMin(range.end);
    final random = Random(); // 每次调用都创建新的 Random 实例，确保随机性
    
    // 计算时间范围的总分钟数
    int rangeMinutes;
    if (startMin < endMin) {
      rangeMinutes = endMin - startMin;
    } else {
      // 跨天情况
      rangeMinutes = (24 * 60 - startMin) + endMin;
    }
    
    if (rangeMinutes < minIntervalMinutes) {
      return [range.start];
    }
    
    // 计算理论上最多可以生成多少个时间点（以3分钟间隔）
    final maxPossibleTimes = (rangeMinutes / minIntervalMinutes).floor();
    
    // 生成尽可能多的时间点（但不超过50个），确保有足够的候选点
    final targetCount = maxPossibleTimes.clamp(1, 50);
    
    final selectedTimes = <TimeOfDay>[];
    int attempts = 0;
    final maxAttempts = targetCount * 30; // 增加尝试次数以确保随机性
    
    while (selectedTimes.length < targetCount && attempts < maxAttempts) {
      attempts++;
      
      // 在范围内完全随机生成一个时间点
      int randomOffset = random.nextInt(rangeMinutes);
      int randomMin = startMin + randomOffset;
      
      // 处理跨天情况：如果超过24小时，取模
      if (randomMin >= 24 * 60) {
        randomMin = randomMin % (24 * 60);
      }
      
      final candidateTime = TimeOfDay(
        hour: (randomMin ~/ 60) % 24,
        minute: randomMin % 60,
      );
      
      // 检查是否在范围内
      bool inRange;
      if (startMin < endMin) {
        // 同一天范围
        inRange = randomMin >= startMin && randomMin < endMin;
      } else {
        // 跨天范围：randomMin 应该在 startMin 之后或 endMin 之前
        inRange = randomMin >= startMin || randomMin < endMin;
      }
      
      if (!inRange) continue;
      
      // 检查与已选时间点的间隔（必须至少3分钟）
      bool canAdd = true;
      for (final selected in selectedTimes) {
        final selectedMin = _todToMin(selected);
        int diff;
        
        if (randomMin >= selectedMin) {
          diff = randomMin - selectedMin;
        } else {
          // 跨天情况
          diff = (24 * 60 - selectedMin) + randomMin;
        }
        
        if (diff < minIntervalMinutes) {
          canAdd = false;
          break;
        }
      }
      
      if (canAdd) {
        selectedTimes.add(candidateTime);
      }
    }
    
    // 如果随机生成失败，至少返回范围开始时间
    if (selectedTimes.isEmpty) {
      selectedTimes.add(range.start);
    }
    
    // 按时间排序返回（保持时间顺序，但生成过程是完全随机的）
    selectedTimes.sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
    return selectedTimes;
  }

  static List<TimeOfDay> _resolveTimes(PushConfig cfg) {
    // ✅ timeMode 完全分離：
    // - custom：只看 customTimes，不再 fallback 到 presetSlots
    // - preset：只看 presetSlots，不理會 customTimes
    if (cfg.timeMode == PushTimeMode.custom) {
      if (cfg.customTimes.isNotEmpty) {
        if (kDebugMode) {
          final customTimesStr = cfg.customTimes
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('✅ _resolveTimes: 使用自訂時間模式，customTimes: [$customTimesStr]');
        }
        final list = List<TimeOfDay>.from(cfg.customTimes)
          ..sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
        final result = list.take(5).toList();
        if (kDebugMode) {
          final resultStr = result
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('✅ _resolveTimes: 返回自訂時間列表: [$resultStr]');
        }
        return result;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ _resolveTimes: timeMode=custom 但 customTimes 為空，將不排程此產品的推播時間');
        }
        // 自訂模式且沒有任何時間 → 不使用預設區段，直接回傳空列表
        return const [];
      }
    }
    if (kDebugMode) {
      debugPrint('ℹ️ _resolveTimes: 使用預設時間模式，timeMode: ${cfg.timeMode.name}, customTimes.isEmpty: ${cfg.customTimes.isEmpty}');
    }
    
    // ✅ 为每个选中的时间范围生成时间点（只支持新的时间范围格式：7-9, 9-11, 11-13, 13-15, 15-17, 17-19, 19-21, 21-23）
    final slots = cfg.presetSlots.isEmpty ? ['21-23'] : cfg.presetSlots;
    final allTimes = <TimeOfDay>[];
    
    for (final slot in slots) {
      final range = presetSlotRanges[slot];
      if (range != null) {
        // ✅ 在范围内生成时间点，使用硬编码3分钟间隔
        final timesInRange = _generateTimesInRange(range, 3);
        allTimes.addAll(timesInRange);
      } else {
        // ✅ 忽略旧的预设值（morning, noon, evening, night）和未知的时间段
        if (kDebugMode) {
          final isOldPreset = ['morning', 'noon', 'evening', 'night'].contains(slot);
          if (isOldPreset) {
            debugPrint('  ⚠️ _resolveTimes: 已移除旧预设值 "$slot"，请使用新的时间范围格式（如 "7-9", "13-15" 等），已忽略');
          } else {
            debugPrint('  ⚠️ _resolveTimes: 未知的预设时间段 "$slot"，已忽略');
          }
        }
      }
    }
    
    // 排序并去重
    allTimes.sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
    final uniqueTimes = <TimeOfDay>[];
    TimeOfDay? lastTime;
    for (final time in allTimes) {
      if (lastTime == null || _todToMin(time) != _todToMin(lastTime)) {
        uniqueTimes.add(time);
        lastTime = time;
      }
    }
    
    // ✅ 不在这里限制数量，让所有时间段的时间点都可用，以便后续随机选择
    // 注意：这里不强制全局最小间隔，因为不同时间段的时间点可能很近
    // 全局最小间隔会在 _applyFreq 和 _enforceGlobalMinInterval 中处理
    return uniqueTimes;
  }

  static List<TimeOfDay> _applyFreq(List<TimeOfDay> times, int freq, PushTimeMode timeMode, int minIntervalMinutes) {
    freq = freq.clamp(1, 5);
    
    // ✅ 预设模式：如果 times 为空，使用默认时间段 21-23 生成时间点
    if (times.isEmpty && timeMode == PushTimeMode.preset) {
      final defaultRange = presetSlotRanges['21-23']!;
      times = _generateTimesInRange(defaultRange, 3); // 硬编码3分钟间隔
    }
    
    if (times.isEmpty) {
      // 自訂模式：若沒有任何時間，維持「不排程」行為，不再 fallback 到預設時段
      if (timeMode == PushTimeMode.custom) {
        if (kDebugMode) {
          debugPrint('ℹ️ _applyFreq: timeMode=custom 且 times 為空，直接回傳空列表（不排程）');
        }
        return const [];
      }
      // 其他情況（例如 timeMode=preset 但仍為空）：使用預設時間 21-23 的起點
      return [presetSlotRanges['21-23']!.start];
    }

    // ✅ 预设模式：从所有时间点中随机选择 freq 个，确保真正随机分布
    if (timeMode == PushTimeMode.preset) {
      if (times.isEmpty) {
        return times;
      }
      
      // ✅ 完全随机选择：打乱所有时间点，然后取前 freq 个
      final shuffled = List<TimeOfDay>.from(times)..shuffle(Random());
      final selected = shuffled.take(freq).toList();
      
      // ✅ 确保选中的时间点之间至少间隔3分钟
      final enforced = <TimeOfDay>[];
      TimeOfDay? lastTime;
      
      for (final time in selected) {
        if (lastTime == null) {
          enforced.add(time);
          lastTime = time;
        } else {
          final timeMin = _todToMin(time);
          final lastMin = _todToMin(lastTime);
          int diff;
          if (timeMin >= lastMin) {
            diff = timeMin - lastMin;
          } else {
            // 跨天情况
            diff = (24 * 60 - lastMin) + timeMin;
          }
          if (diff >= minIntervalMinutes) {
            enforced.add(time);
            lastTime = time;
          }
        }
      }
      
      // ✅ 如果因为间隔限制导致数量不足，从剩余时间点中补充
      if (enforced.length < freq && enforced.length < shuffled.length) {
        final remaining = shuffled.where((t) => !enforced.contains(t)).toList();
        for (final time in remaining) {
          if (enforced.length >= freq) break;
          
          final timeMin = _todToMin(time);
          final lastMin = _todToMin(lastTime!);
          int diff;
          if (timeMin >= lastMin) {
            diff = timeMin - lastMin;
          } else {
            diff = (24 * 60 - lastMin) + timeMin;
          }
          if (diff >= minIntervalMinutes) {
            enforced.add(time);
            lastTime = time;
          }
        }
      }
      
      // 按时间排序返回
      enforced.sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
      return enforced;
    }

    if (timeMode == PushTimeMode.custom) {
      // ✅ 實作方案 A：
      // custom 模式下「每天推幾則」完全由 customTimes 決定，
      // 不再依據 freqPerDay 擴充時間點，只保留最多 5 個自訂時間。
      final base = List<TimeOfDay>.from(times)
        ..sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
      return base.take(5).toList();
    }

    // 其他情况：直接返回前 freq 个
    return times.take(freq).toList();
  }

  static bool _allowedDay(GlobalPushSettings g, PushConfig p, DateTime d) {
    final w = d.weekday; // 1..7
    return g.daysOfWeek.contains(w) && p.daysOfWeek.contains(w);
  }

  static List<DateTime> _enforceMinInterval(
      List<DateTime> dt, int minIntervalMinutes) {
    if (dt.length <= 1) return dt;
    final out = <DateTime>[];
    DateTime? last;
    for (final t in dt) {
      if (last == null) {
        out.add(t);
        last = t;
      } else {
        final diff = t.difference(last).inMinutes;
        if (diff >= minIntervalMinutes) {
          out.add(t);
          last = t;
        } else {
          final pushed = last.add(Duration(minutes: minIntervalMinutes));
          out.add(pushed);
          last = pushed;
        }
      }
    }
    return out;
  }

  /// 檢測商品是否已全部學習完成
  static bool isAllLearned({
    required List<ContentItem> items,
    required Map<String, SavedContent> savedMap,
  }) {
    if (items.isEmpty) return false;
    return items.every((e) => savedMap[e.id]?.learned ?? false);
  }

  /// 按順序推播未學習的內容：從 nextSeq 起依序找第一個未學習的。
  /// 回傳 (picked, isLastInProduct)。若全部已學習則 picked 為 null。
  static (ContentItem? picked, bool isLastInProduct) _pickSequentialUnlearned({
    required List<ContentItem> itemsSorted,
    required ProgressState progress,
    required Map<String, SavedContent> savedMap,
    Set<String> missedContentItemIds = const {},
  }) {
    if (itemsSorted.isEmpty) return (null, false);

    ContentItem? bySeq(int seq) {
      final idx = itemsSorted.indexWhere((e) => e.seq == seq);
      return idx >= 0 ? itemsSorted[idx] : null;
    }

    final maxSeq = itemsSorted.map((e) => e.seq).reduce((a, b) => a > b ? a : b);

    for (int seq = progress.nextSeq; seq <= maxSeq; seq++) {
      final item = bySeq(seq);
      if (item == null) continue;
      if (savedMap[item.id]?.learned ?? false) continue;
      // ✅ 已被使用者滑掉/判定 missed 的內容：重排時排除，避免一直推同一則
      if (missedContentItemIds.contains(item.id)) continue;
      final isLast = (seq == maxSeq);
      return (item, isLast);
    }
    return (null, false);
  }

  static List<PushTask> buildSchedule({
    required DateTime now,
    required int days,
    required GlobalPushSettings global,
    required Map<String, UserLibraryProduct> libraryByProductId,
    required Map<String, List<ContentItem>> contentByProduct,
    required Map<String, SavedContent> savedMap,
    required int iosSafeMaxScheduled, // <= 60

    // ✅ 新增：真排序用的「日常順序」(本機)
    List<String>? productOrder,
    
    // ✅ 新增：收集已全部完成的商品列表（供後續自動暫停）
    List<String>? outCompletedProductIds,
    
    // ✅ 新增：missed 的 contentItemId（用於排除已滑掉/錯過的內容）
    Set<String> missedContentItemIds = const {},
  }) {
    if (!global.enabled) return [];

    // ✅ 建立 order index map
    final orderIdx = <String, int>{};
    if (productOrder != null && productOrder.isNotEmpty) {
      for (int i = 0; i < productOrder.length; i++) {
        orderIdx[productOrder[i]] = i;
      }
    }
    int idxOf(String pid) => orderIdx[pid] ?? 1 << 20; // 沒在日常裡的放後面

    final tasks = <PushTask>[];
    final startDate = DateTime(now.year, now.month, now.day);

    for (int di = 0; di < days; di++) {
      final date = startDate.add(Duration(days: di));
      final dayCandidates = <PushTask>[];

      for (final entry in libraryByProductId.entries) {
        final lp = entry.value;
        if (lp.isHidden) continue;
        if (!lp.pushEnabled) continue;
        if (!_allowedDay(global, lp.pushConfig, date)) continue;

        final baseTimes = _resolveTimes(lp.pushConfig);
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final baseTimesStr = baseTimes
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，baseTimes: [$baseTimesStr]');
        }
        
        final times = _applyFreq(baseTimes, lp.pushConfig.freqPerDay, lp.pushConfig.timeMode, lp.pushConfig.minIntervalMinutes);
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final timesStr = times
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，應用頻率後 times: [$timesStr] (freq: ${lp.pushConfig.freqPerDay})');
        }

        // 避開 quiet hours（僅全域）
        final filtered = times.where((t) {
          final inGlobal = _inQuiet(global.quietHours, t);
          return !inGlobal;
        }).toList();
        
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final filteredStr = filtered
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          final removedCount = times.length - filtered.length;
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，勿擾時段過濾後: [$filteredStr] (移除了 $removedCount 個時間)');
        }
        
        if (filtered.isEmpty) {
          if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
            debugPrint('  ⚠️ buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，所有自訂時間都被過濾掉！');
          }
          continue;
        }

        final dts = filtered.map((t) => _at(date, t)).toList()..sort();
        
        // ✅ 预设模式：使用硬编码3分钟间隔；自訂時間模式：即使小於最短間隔，仍以自訂時間為主
        final enforced = lp.pushConfig.timeMode == PushTimeMode.custom
            ? dts.take(5).toList() // 自訂時間模式：不強制執行最短間隔
            : _enforceMinInterval(dts, 3) // ✅ 预设模式：硬编码3分钟间隔
                .take(5)
                .toList();
        
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final enforcedStr = enforced
              .map((dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，最終排程時間: [$enforcedStr] (自訂時間模式，不強制最短間隔)');
        }

        final items =
            List<ContentItem>.from(contentByProduct[lp.productId] ?? const [])
              ..sort((a, b) => a.seq.compareTo(b.seq));

        // ✅ 檢測是否全部完成
        if (isAllLearned(items: items, savedMap: savedMap)) {
          // 記錄已完成的商品（供後續自動暫停）
          outCompletedProductIds?.add(lp.productId);
          // 跳過該商品，不再產生推播任務
          continue;
        }

        // ✅ 使用順序推播未學習內容（支援排除 missed 內容）
        final (picked, isLastInProduct) = _pickSequentialUnlearned(
          itemsSorted: items,
          progress: lp.progress,
          savedMap: savedMap,
          missedContentItemIds: missedContentItemIds,
        );
        if (picked == null) continue;

        for (final when in enforced) {
          if (di == 0 && when.isBefore(now.add(const Duration(minutes: 1)))) {
            continue;
          }
          dayCandidates.add(PushTask(
            productId: lp.productId,
            when: when,
            item: picked,
            isLastInProduct: isLastInProduct,
          ));
        }
      }

      // 全域每日上限
      final dailyCap = global.dailyTotalCap.clamp(1, 50);
      
      if (dayCandidates.length > dailyCap) {
        // ✅ 修復：按產品分組，確保同一個產品的多個排程優先保留
        // 計算每個產品的優先分數
        int productPrio(String productId) {
          final lp = libraryByProductId[productId]!;
          int score = 0;
          
          final oi = idxOf(productId);
          score += (1000000 - oi).clamp(0, 1000000);
          
          if (lp.isFavorite) score += 2000;
          if (lp.lastOpenedAt != null) score += 300;
          score += lp.purchasedAt.millisecondsSinceEpoch ~/ 100000000;
          
          return score;
        }
        
        // 按產品分組
        final byProduct = <String, List<PushTask>>{};
        for (final task in dayCandidates) {
          byProduct.putIfAbsent(task.productId, () => []).add(task);
        }
        
        // ✅ 頻率優先於產品優先分數：先依 freqPerDay 降序，再依 productPrio
        int freqOf(String pid) => libraryByProductId[pid]!.pushConfig.freqPerDay;
        final sortedProducts = byProduct.keys.toList()
          ..sort((a, b) {
            final fa = freqOf(a);
            final fb = freqOf(b);
            if (fa != fb) return fb.compareTo(fa);
            return productPrio(b).compareTo(productPrio(a));
          });
        
        // 優先保留高頻率／高優先產品的所有排程
        final kept = <PushTask>[];
        for (final productId in sortedProducts) {
          final productTasks = byProduct[productId]!;
          // 按時間排序
          productTasks.sort((a, b) => a.when.compareTo(b.when));
          
          if (kept.length + productTasks.length <= dailyCap) {
            // 空間足夠，保留該產品的所有排程
            kept.addAll(productTasks);
          } else {
            // 空間不足，只保留能放下的部分
            final remaining = dailyCap - kept.length;
            if (remaining > 0) {
              kept.addAll(productTasks.take(remaining));
            }
            break;
          }
        }
        
        kept.sort((a, b) => a.when.compareTo(b.when));
        tasks.addAll(kept);
      } else {
        dayCandidates.sort((a, b) => a.when.compareTo(b.when));
        tasks.addAll(dayCandidates);
      }
    }

    tasks.sort((a, b) {
      final t = a.when.compareTo(b.when);
      if (t != 0) return t;

      // ✅ 同一時間：日常順序小的排前
      final ao = idxOf(a.productId);
      final bo = idxOf(b.productId);
      if (ao != bo) return ao.compareTo(bo);

      // ✅ 再穩定：productId
      return a.productId.compareTo(b.productId);
    });
    
    // ✅ 全局最小间隔强制执行（硬编码3分钟，跨产品）
    const globalMinInterval = 3; // 全局最小间隔（分钟）
    final finalTasks = _enforceGlobalMinInterval(tasks, globalMinInterval);
    
    return finalTasks.take(iosSafeMaxScheduled).toList();
  }

  /// ✅ 全局最小间隔强制执行（跨产品）
  /// 确保所有产品的通知之间至少间隔 minIntervalMinutes 分钟
  static List<PushTask> _enforceGlobalMinInterval(List<PushTask> tasks, int minIntervalMinutes) {
    if (tasks.length <= 1) return tasks;
    
    // 按时间排序
    final sorted = List<PushTask>.from(tasks)
      ..sort((a, b) => a.when.compareTo(b.when));
    
    final result = <PushTask>[];
    DateTime? lastTime;
    
    for (final task in sorted) {
      if (lastTime == null) {
        result.add(task);
        lastTime = task.when;
      } else {
        // ✅ 计算时间间隔（已排序，所以 task.when >= lastTime）
        final diffMinutes = task.when.difference(lastTime).inMinutes;
        
        if (diffMinutes >= minIntervalMinutes) {
          // 间隔足够，直接添加
          result.add(task);
          lastTime = task.when;
        } else {
          // ✅ 间隔不足，调整时间：将当前任务的时间向后移动
          final adjustedTime = lastTime.add(Duration(minutes: minIntervalMinutes));
          result.add(PushTask(
            productId: task.productId,
            when: adjustedTime,
            item: task.item,
            isLastInProduct: task.isLastInProduct,
          ));
          lastTime = adjustedTime;
          
          if (kDebugMode) {
            debugPrint('  ⏰ _enforceGlobalMinInterval: 调整任务时间 ${task.productId} 从 ${task.when.hour}:${task.when.minute.toString().padLeft(2, '0')} 到 ${adjustedTime.hour}:${adjustedTime.minute.toString().padLeft(2, '0')}（间隔 $diffMinutes 分钟 < $minIntervalMinutes 分钟）');
          }
        }
      }
    }
    
    // ✅ 重新排序以确保时间顺序正确（因为调整后可能改变顺序）
    result.sort((a, b) => a.when.compareTo(b.when));
    
    return result;
  }
}
