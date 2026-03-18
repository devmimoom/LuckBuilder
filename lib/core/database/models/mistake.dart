import 'dart:convert';

class Mistake {
  final int? id;
  final String imagePath;
  final String title;
  final List<String> tags;
  final List<String> solutions;
  final String subject;      // 新增：科目 (數學, 英文...)
  final String category;     // 新增：分類 (幾何, 文法...)
  final String? errorReason; // 新增：錯誤原因 (粗心, 觀念不懂...)
  final DateTime createdAt;

  Mistake({
    this.id,
    required this.imagePath,
    required this.title,
    required this.tags,
    required this.solutions,
    required this.subject,
    required this.category,
    this.errorReason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'title': title,
      'tags': jsonEncode(tags),
      'solutions': jsonEncode(solutions),
      'subject': subject,
      'category': category,
      'error_reason': errorReason,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Mistake.fromMap(Map<String, dynamic> map) {
    return Mistake(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      title: map['title'] as String,
      tags: List<String>.from(jsonDecode(map['tags'] as String)),
      solutions: List<String>.from(jsonDecode(map['solutions'] as String)),
      subject: map['subject'] as String? ?? '其他',
      category: map['category'] as String? ?? '一般',
      errorReason: map['error_reason'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
