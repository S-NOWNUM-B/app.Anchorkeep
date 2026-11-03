// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/vault/atomic_write.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/core/vault/entry_repository.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EntriesController extends Notifier<List<Entry>> {
  @override
  List<Entry> build() {
    final session = ref.watch(vaultSessionProvider);
    if (session == null) return const [];
    return EntryRepository(session, _write).list();
  }

  Future<void> _write(List<int> bytes) async {
    final path = await ref.read(vaultPathProvider.future);
    await writeFileAtomic(path, bytes);
  }

  EntryRepository get _repository {
    final session = ref.read(vaultSessionProvider);
    if (session == null) throw StateError('vault locked');
    return EntryRepository(session, _write);
  }

  Future<Entry> add(
    EntryType type,
    String title,
    Map<String, String> fields,
  ) async {
    final repository = _repository;
    final entry = await repository.add(type, title, fields);
    state = repository.list();
    return entry;
  }

  Future<Entry> update(
    String id, {
    String? title,
    Map<String, String>? fields,
  }) async {
    final repository = _repository;
    final entry = await repository.update(id, title: title, fields: fields);
    state = repository.list();
    return entry;
  }

  Future<void> delete(String id) async {
    final repository = _repository;
    await repository.delete(id);
    state = repository.list();
  }
}

final entriesProvider = NotifierProvider<EntriesController, List<Entry>>(
  EntriesController.new,
);
