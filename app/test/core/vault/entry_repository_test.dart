import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/core/vault/entry_repository.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:flutter_test/flutter_test.dart';

const pw = 'пароль';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

/// Часы, которые идут на минуту вперёд при каждом обращении.
DateTime Function() clock() {
  var t = DateTime.utc(2026, 10, 21, 12);
  return () {
    final v = t;
    t = t.add(const Duration(minutes: 1));
    return v;
  };
}

class Env {
  Env(this.session, this.repo, this.written);

  final VaultSession session;
  final EntryRepository repo;

  /// Все байты, которые репозиторий «записал на диск».
  final List<Uint8List> written;
}

Future<Env> setup({bool failWrites = false}) async {
  final session = await createVault(pw, kdf: fast());
  final written = <Uint8List>[];
  final repo = EntryRepository(session, (bytes) async {
    if (failWrites) throw const FormatException('диск полон');
    written.add(bytes);
  }, now: clock());
  return Env(session, repo, written);
}

void main() {
  test('add → файл → unlock возвращает ту же запись', () async {
    final e = await setup();
    final added = await e.repo.add(EntryType.password, 'Gmail', {
      'login': 'me@mail.com',
      'password': 'hunter2',
    });
    final reopened = await unlockVault(e.written.last, pw);
    final list = EntryRepository(reopened, (_) async {}).list();
    expect(list, hasLength(1));
    expect(list.single.id, added.id);
    expect(list.single.title, 'Gmail');
    expect(list.single.type, EntryType.password);
    expect(list.single.fields['password'], 'hunter2');
  });

  test('каждая операция увеличивает revision на 1', () async {
    final e = await setup();
    final a = await e.repo.add(EntryType.note, 'Заметка', {'text': 'раз'});
    expect(VaultFile.decode(e.written.last).header.revision, 1);
    await e.repo.update(a.id, title: 'Заметка 2');
    expect(VaultFile.decode(e.written.last).header.revision, 2);
    await e.repo.delete(a.id);
    expect(VaultFile.decode(e.written.last).header.revision, 3);
  });

  test('update меняет updatedAt, но не createdAt и id', () async {
    final e = await setup();
    final a = await e.repo.add(EntryType.note, 'A', {'text': 'x'});
    final b = await e.repo.update(a.id, fields: {'text': 'y'});
    expect(b.id, a.id);
    expect(b.createdAt, a.createdAt);
    expect(b.updatedAt.isAfter(a.updatedAt), isTrue);
    expect(b.title, 'A');
    expect(b.fields['text'], 'y');
  });

  test('delete убирает запись', () async {
    final e = await setup();
    final a = await e.repo.add(EntryType.note, 'A', {'text': 'x'});
    await e.repo.add(EntryType.note, 'B', {'text': 'y'});
    await e.repo.delete(a.id);
    expect(e.repo.list().map((x) => x.title), ['B']);
  });

  test('сбой записи на диск откатывает память и revision', () async {
    final e = await setup(failWrites: true);
    await expectLater(
      e.repo.add(EntryType.note, 'A', {'text': 'x'}),
      throwsA(isA<FormatException>()),
    );
    expect(e.repo.list(), isEmpty);
    expect(e.session.header.revision, 0);
  });

  test('update и delete с неизвестным id → StateError', () async {
    final e = await setup();
    expect(() => e.repo.update('нет', title: 'x'), throwsStateError);
    expect(() => e.repo.delete('нет'), throwsStateError);
  });

  test('list() нельзя изменить снаружи', () async {
    final e = await setup();
    await e.repo.add(EntryType.note, 'A', {'text': 'x'});
    expect(() => e.repo.list().clear(), throwsUnsupportedError);
  });

  test('повреждённый payload → FormatException', () async {
    final e = await setup();
    e.session.payload['entries'] = [
      {'id': '1', 'type': 'secret', 'title': 'A'},
    ];
    expect(() => e.repo.list(), throwsFormatException);
    e.session.payload['entries'] = 'не список';
    expect(() => e.repo.list(), throwsFormatException);
  });
}
