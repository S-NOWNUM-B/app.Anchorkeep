import 'package:anchorkeep/core/vault/entry.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> valid() => {
  'id': 'abc',
  'type': 'password',
  'title': 'Gmail',
  'fields': {'login': 'me'},
  'createdAt': '2026-10-21T12:00:00.000Z',
  'updatedAt': '2026-10-21T12:05:00.000Z',
};

void main() {
  test('toJson → fromJson сохраняет все поля', () {
    final e = Entry.fromJson(valid());
    final back = Entry.fromJson(e.toJson());
    expect(back.id, 'abc');
    expect(back.type, EntryType.password);
    expect(back.fields, {'login': 'me'});
    expect(back.createdAt, DateTime.utc(2026, 10, 21, 12));
    expect(back.updatedAt, DateTime.utc(2026, 10, 21, 12, 5));
  });

  void rejects(String why, void Function(Map<String, Object?> j) mutate) {
    test('отклоняет: $why', () {
      final j = valid();
      mutate(j);
      expect(() => Entry.fromJson(j), throwsFormatException);
    });
  }

  rejects('неизвестный type', (j) => j['type'] = 'secret');
  rejects('title не строка', (j) => j['title'] = 5);
  rejects('нет id', (j) => j.remove('id'));
  rejects('fields не словарь', (j) => j['fields'] = [1]);
  rejects('значение fields не строка', (j) => j['fields'] = {'a': 1});
  rejects('битая дата', (j) => j['createdAt'] = 'вчера');
}
