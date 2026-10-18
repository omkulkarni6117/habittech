import 'json_helpers.dart';

class Reflection {
  Reflection({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// The day the reflection is about, `yyyy-MM-dd`.
  final String date;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reflection copyWith({String? date, String? content, DateTime? updatedAt}) =>
      Reflection(
        id: id,
        date: date ?? this.date,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Json toJson() => {
        'id': id,
        'date': date,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Reflection.fromJson(Json j) => Reflection(
        id: reqString(j, 'id'),
        date: reqDateKey(j, 'date'),
        content: reqString(j, 'content'),
        createdAt: reqDateTime(j, 'createdAt'),
        updatedAt: reqDateTime(j, 'updatedAt'),
      );
}
