// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/solana/backup_verification.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:anchorkeep/core/vault/change_password.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/solana.dart';

const pw = 'пароль';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

late Ed25519HDPublicKey owner;

/// Запись в цепочке так, будто заверили именно [anchored].
Future<VaultRecord> recordFor(Uint8List anchored) async {
  final h = VaultFile.decode(anchored).header;
  return VaultRecord(
    owner: owner,
    vaultId: h.vaultId,
    version: h.revision,
    hash: Uint8List.fromList((await Sha256().hash(anchored)).bytes),
    updatedAt: DateTime.utc(2026, 10, 21),
    bump: 255,
  );
}

/// Чтение из «цепочки», где лежит [record].
FetchVaultRecord chainWith(VaultRecord? record) =>
    (_, _) async => record;

Future<AnchorStatus> verify(Uint8List file, FetchVaultRecord fetch) =>
    verifyVaultFile(fileBytes: file, owner: owner, fetch: fetch);

void main() {
  late VaultSession session;

  setUp(() async {
    owner = (await Ed25519HDKeyPair.random()).publicKey;
    session = await createVault(pw, kdf: fast());
  });

  test('сейф не заверяли → notAnchored', () async {
    final file = await saveVault(session);
    expect(await verify(file, chainWith(null)), AnchorStatus.notAnchored);
  });

  test('заверен этот же файл → verified', () async {
    final file = await saveVault(session);
    final record = await recordFor(file);
    expect(await verify(file, chainWith(record)), AnchorStatus.verified);
  });

  test('старый бэкап при заверенной новой версии → outdated', () async {
    final backup = await saveVault(session); // revision 1
    await saveVault(session);
    final current = await saveVault(session); // revision 3, заверен

    final chain = chainWith(await recordFor(current));
    expect(await verify(backup, chain), AnchorStatus.outdated);
  });

  test('новый файл, ещё не заверенный → unknown', () async {
    final anchored = await saveVault(session); // revision 1, заверен
    final newer = await saveVault(session); // revision 2

    final chain = chainWith(await recordFor(anchored));
    expect(await verify(newer, chain), AnchorStatus.unknown);
  });

  test('та же версия, другие байты (подмена) → unknown', () async {
    final file = await saveVault(session);
    final record = await recordFor(file);
    final forged = VaultRecord(
      owner: record.owner,
      vaultId: record.vaultId,
      version: record.version,
      hash: Uint8List(32),
      updatedAt: record.updatedAt,
      bump: record.bump,
    );
    expect(await verify(file, chainWith(forged)), AnchorStatus.unknown);
  });

  group('смена мастер-пароля (ADR 0007)', () {
    test(
      'бэкап до смены при заверенной версии после смены → outdated',
      () async {
        final before = await saveVault(session); // revision 1
        late Uint8List after;
        await changeMasterPassword(
          session,
          pw,
          'новый',
          (b) async => after = b,
        );

        final chain = chainWith(await recordFor(after)); // revision 2 заверен
        expect(await verify(before, chain), AnchorStatus.outdated);
        expect(await verify(after, chain), AnchorStatus.verified);
      },
    );

    test('файл после смены, ещё не заверенный → unknown', () async {
      final before = await saveVault(session); // revision 1, заверен
      late Uint8List after;
      await changeMasterPassword(session, pw, 'новый', (b) async => after = b);

      final chain = chainWith(await recordFor(before));
      expect(await verify(after, chain), AnchorStatus.unknown);
    });
  });

  group('сеть', () {
    for (final (name, error) in [
      ('нет сети', const SocketException('нет сети')),
      ('таймаут', TimeoutException('RPC молчит')),
    ]) {
      test('$name → offline', () async {
        final file = await saveVault(session);
        expect(
          await verify(file, (_, _) async => throw error),
          AnchorStatus.offline,
        );
      });
    }

    test('по адресу не VaultRecord → unknown', () async {
      final file = await saveVault(session);
      expect(
        await verify(
          file,
          (_, _) async => throw const FormatException('чужой аккаунт'),
        ),
        AnchorStatus.unknown,
      );
    });
  });

  test('в чтение уходят owner и vaultId из файла', () async {
    final file = await saveVault(session);
    Ed25519HDPublicKey? askedOwner;
    List<int>? askedVaultId;
    await verify(file, (o, id) async {
      askedOwner = o;
      askedVaultId = id;
      return null;
    });

    expect(askedOwner, owner);
    expect(askedVaultId, session.header.vaultId);
  });

  test('не файл сейфа → FormatException, сеть не трогаем', () async {
    var called = false;
    await expectLater(
      verify(Uint8List.fromList([1, 2, 3]), (_, _) async {
        called = true;
        return null;
      }),
      throwsFormatException,
    );
    expect(called, isFalse);
  });
}
