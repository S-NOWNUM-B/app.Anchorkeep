// SPDX-License-Identifier: GPL-3.0-or-later

enum EntryType { password, note }

/// Одна запись сейфа. Неизменяемая: «правка» создаёт новую копию.
class Entry {
  const Entry({
    required this.id,
    required this.type,
    required this.title,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Строгий разбор записи из расшифрованного payload: чужой или
  /// повреждённый формат → [FormatException].
  factory Entry.fromJson(Map<String, Object?> j) {
    final fields = j['fields'];
    if (j['id'] is! String ||
        j['title'] is! String ||
        fields is! Map<String, Object?> ||
        !fields.values.every((v) => v is String)) {
      throw const FormatException('entry: неверная структура');
    }
    final type = EntryType.values.asNameMap()[j['type']];
    if (type == null) throw const FormatException('entry: неизвестный type');
    return Entry(
      id: j['id']! as String,
      type: type,
      title: j['title']! as String,
      fields: Map<String, String>.unmodifiable(fields.cast<String, String>()),
      createdAt: _date(j['createdAt']),
      updatedAt: _date(j['updatedAt']),
    );
  }

  final String id;
  final EntryType type;
  final String title;

  /// Состав полей не фиксируем: для пароля это login/password/url/note,
  /// для заметки — text. UI может добавлять свои.
  final Map<String, String> fields;
  final DateTime createdAt;
  final DateTime updatedAt;

  Entry copyWith({
    String? title,
    Map<String, String>? fields,
    DateTime? updatedAt,
  }) => Entry(
    id: id,
    type: type,
    title: title ?? this.title,
    fields: fields ?? this.fields,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'fields': fields,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

DateTime _date(Object? v) {
  final d = v is String ? DateTime.tryParse(v) : null;
  if (d == null) throw const FormatException('entry: неверная дата');
  return d;
}
