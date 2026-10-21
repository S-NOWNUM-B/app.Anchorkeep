// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:uuid/uuid.dart';

/// CRUD записей поверх открытого сейфа. Каждая операция перешифровывает
/// payload (revision + 1) и пишет файл; при сбое записи состояние
/// в памяти возвращается к прежнему.
class EntryRepository {
  EntryRepository(this._session, this._write, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final VaultSession _session;
  final WriteVault _write;
  final DateTime Function() _now;

  List<Entry> list() {
    final raw = _session.payload['entries'];
    if (raw is! List<Object?>) {
      throw const FormatException('vault: entries не список');
    }
    return List.unmodifiable(
      raw.map((e) {
        if (e is! Map<String, Object?>) {
          throw const FormatException('entry: не объект');
        }
        return Entry.fromJson(e);
      }),
    );
  }

  Future<Entry> add(
    EntryType type,
    String title,
    Map<String, String> fields,
  ) async {
    final t = _now();
    final entry = Entry(
      id: const Uuid().v4(),
      type: type,
      title: title,
      fields: Map.unmodifiable(fields),
      createdAt: t,
      updatedAt: t,
    );
    await _commit([...list(), entry]);
    return entry;
  }

  Future<Entry> update(
    String id, {
    String? title,
    Map<String, String>? fields,
  }) async {
    final all = list();
    final i = all.indexWhere((e) => e.id == id);
    if (i < 0) throw StateError('entry $id не найдена');
    final updated = all[i].copyWith(
      title: title,
      fields: fields == null ? null : Map.unmodifiable(fields),
      updatedAt: _now(),
    );
    await _commit([...all]..[i] = updated);
    return updated;
  }

  Future<void> delete(String id) async {
    final all = list();
    if (!all.any((e) => e.id == id)) throw StateError('entry $id не найдена');
    await _commit(all.where((e) => e.id != id).toList());
  }

  Future<void> _commit(List<Entry> entries) async {
    final oldEntries = _session.payload['entries'];
    final oldHeader = _session.header;
    _session.payload['entries'] = entries.map((e) => e.toJson()).toList();
    try {
      await _write(await saveVault(_session));
    } catch (_) {
      _session.payload['entries'] = oldEntries;
      _session.header = oldHeader;
      rethrow;
    }
  }
}
