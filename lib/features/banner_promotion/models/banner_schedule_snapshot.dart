/// 已開啟橫幅推播時儲存的範圍與頻率（供設定頁顯示「目前推播」摘要）。
class BannerScheduleSnapshot {
  const BannerScheduleSnapshot({
    required this.segment,
    required this.semester,
    required this.subSegment,
    required this.productIds,
    required this.frequency,
    required this.useDefaultSlots,
    required this.slotIndices,
    required this.customTimeStrings,
  });

  final String segment;
  final String semester;
  final String subSegment;
  final List<String> productIds;
  final int frequency;
  final bool useDefaultSlots;
  final List<int> slotIndices;
  final List<String> customTimeStrings;

  Map<String, dynamic> toJson() => {
        'segment': segment,
        'semester': semester,
        'subSegment': subSegment,
        'productIds': productIds,
        'frequency': frequency,
        'useDefaultSlots': useDefaultSlots,
        'slotIndices': slotIndices,
        'customTimeStrings': customTimeStrings,
      };

  factory BannerScheduleSnapshot.fromJson(Map<String, dynamic> json) {
    return BannerScheduleSnapshot(
      segment: json['segment'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      subSegment: json['subSegment'] as String? ?? '',
      productIds: (json['productIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      frequency: (json['frequency'] as num?)?.toInt() ?? 1,
      useDefaultSlots: json['useDefaultSlots'] as bool? ?? true,
      slotIndices: (json['slotIndices'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      customTimeStrings: (json['customTimeStrings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
