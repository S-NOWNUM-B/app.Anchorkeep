// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/vault/entry.dart';

/// Поиск по записям в памяти (F5), без учёта регистра. Совпадение по названию;
/// у паролей ещё по логину и URL. Сам пароль и текст заметки не ищутся:
/// их содержимое не должно «просвечивать» через поисковую строку.
/// Пустой запрос возвращает все записи нужного [type]. Порядок сохраняется.
List<Entry> searchEntries(
  List<Entry> entries,
  String query, {
  EntryType? type,
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final e in entries)
      if ((type == null || e.type == type) && (q.isEmpty || _matches(e, q))) e,
  ];
}

bool _matches(Entry e, String q) =>
    e.title.toLowerCase().contains(q) ||
    (e.type == EntryType.password &&
        [
          'login',
          'url',
        ].any((key) => (e.fields[key] ?? '').toLowerCase().contains(q)));
