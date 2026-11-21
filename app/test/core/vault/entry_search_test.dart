import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/core/vault/entry_search.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime.utc(2026, 11, 21);

Entry password(
  String id,
  String title, {
  String login = '',
  String url = '',
  String pass = '',
}) => Entry(
  id: id,
  type: EntryType.password,
  title: title,
  fields: {'login': login, 'url': url, 'password': pass},
  createdAt: _t,
  updatedAt: _t,
);

Entry note(String id, String title, {String text = ''}) => Entry(
  id: id,
  type: EntryType.note,
  title: title,
  fields: {'text': text},
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  final gmail = password(
    '1',
    'Gmail',
    login: 'me@mail.com',
    url: 'https://gmail.com',
    pass: 'hunter2',
  );
  final bank = password(
    '2',
    'Банк Каспи',
    login: 'aliar',
    url: 'https://kaspi.kz',
  );
  final trip = note('3', 'Поездка в Алматы', text: 'код от сейфа 4821');
  final all = [gmail, bank, trip];

  List<String> ids(List<Entry> r) => r.map((e) => e.id).toList();

  test('ищет по названию без учёта регистра', () {
    expect(ids(searchEntries(all, 'gMaIl')), ['1']);
  });

  test('работает с кириллицей и регистром', () {
    expect(ids(searchEntries(all, 'БАНК')), ['2']);
    expect(ids(searchEntries(all, 'алматы')), ['3']);
  });

  test('у паролей ищет по URL и логину', () {
    expect(ids(searchEntries(all, 'kaspi.kz')), ['2']);
    expect(ids(searchEntries(all, 'me@mail')), ['1']);
  });

  test('сам пароль и текст заметки найти нельзя', () {
    expect(searchEntries(all, 'hunter'), isEmpty);
    expect(searchEntries(all, '4821'), isEmpty);
  });

  test('у заметок URL и логин не учитываются, только название', () {
    final odd = Entry(
      id: '4',
      type: EntryType.note,
      title: 'Рецепт',
      fields: {'url': 'secret.example', 'login': 'tester'},
      createdAt: _t,
      updatedAt: _t,
    );
    expect(searchEntries([odd], 'secret.example'), isEmpty);
    expect(searchEntries([odd], 'tester'), isEmpty);
    expect(ids(searchEntries([odd], 'рецепт')), ['4']);
  });

  test('пустой запрос и пробелы возвращают всё', () {
    expect(ids(searchEntries(all, '')), ['1', '2', '3']);
    expect(ids(searchEntries(all, '   ')), ['1', '2', '3']);
  });

  test('лишние пробелы вокруг запроса игнорируются', () {
    expect(ids(searchEntries(all, '  gmail ')), ['1']);
  });

  test('фильтр по типу записи', () {
    expect(ids(searchEntries(all, '', type: EntryType.note)), ['3']);
    expect(ids(searchEntries(all, 'а', type: EntryType.password)), ['2']);
  });

  test('порядок записей сохраняется', () {
    expect(ids(searchEntries([bank, gmail], '.')), ['2', '1']);
  });

  test('ничего не найдено → пустой список', () {
    expect(searchEntries(all, 'нет такого'), isEmpty);
  });
}
