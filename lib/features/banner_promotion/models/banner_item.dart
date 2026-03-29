class BannerItem {
  const BannerItem({
    required this.itemId,
    required this.segment,
    required this.topicId,
    required this.semester,
    required this.subSegment,
    required this.productId,
    required this.anchor,
    required this.content,
    required this.pushTitle,
    this.seq,
    this.pushOrder,
    this.sourceSheet,
  });

  final String itemId;
  final String segment;
  final int topicId;
  /// 學期縮寫，如「七上」「八下」
  final String semester;
  /// 子科目，如「歷史」「地理」「生物」「理化」；無子分類時為空字串
  final String subSegment;
  final String productId;
  final String anchor;
  final String content;
  final String pushTitle;
  final num? seq;
  final num? pushOrder;
  final String? sourceSheet;

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      itemId: json['itemId'] as String,
      segment: json['segment'] as String? ?? '',
      topicId: (json['topicId'] as num).toInt(),
      semester: json['semester'] as String? ?? '',
      subSegment: json['subSegment'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      anchor: json['anchor'] as String? ?? '',
      content: json['content'] as String? ?? '',
      pushTitle: json['pushTitle'] as String? ?? '',
      seq: json['seq'] as num?,
      pushOrder: json['pushOrder'] as num?,
      sourceSheet: json['sourceSheet'] as String?,
    );
  }

  int get sortKey {
    final o = pushOrder ?? seq;
    if (o is int) return o;
    if (o is double) return o.round();
    return 0;
  }
}
