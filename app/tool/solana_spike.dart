// SPDX-License-Identifier: GPL-3.0-or-later

// Spike AK-04: Dart → Solana через пакет `solana` (espresso-cash).
// Проверяет airdrop, перевод и чтение аккаунта, затем собирает Anchor-инструкцию
// initialize_vault вручную (PDA, discriminator, borsh). Если vault_registry
// задеплоена в кластере — отправляет её и читает VaultRecord обратно.
//
// Запуск из app/:
//   dart run tool/solana_spike.dart
//   dart run tool/solana_spike.dart --keypair ~/.config/solana/id.json
//   dart run tool/solana_spike.dart --url http://127.0.0.1:8899
//
// Без --keypair создаётся одноразовый ключ и запрашивается airdrop. Публичный
// faucet devnet часто отвечает лимитом — тогда передай свой devnet-кошелёк.
// Секретный ключ никуда не выводится.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:solana/anchor.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

const _devnetUrl = 'https://api.devnet.solana.com';

// Program ID vault_registry из program/Anchor.toml
const _programId = 'Y8ik6bx8kAoeMr3Ugu7SmhKtvChTkBTd1hZLdWggHNg';

const _airdropLamports = lamportsPerSol ~/ 2;
const _transferLamports = 1000000; // 0.001 SOL

Future<void> main(List<String> args) async {
  final rpcUrl = Uri.parse(_arg(args, '--url') ?? _devnetUrl);
  final client = SolanaClient(rpcUrl: rpcUrl, websocketUrl: _wsUrl(rpcUrl));
  _log('cluster', rpcUrl.toString());

  final payer = await _loadPayer(_arg(args, '--keypair'));
  _log('payer', payer.publicKey.toBase58());

  // 1. Airdrop: только для одноразового ключа, свой кошелёк уже с балансом
  if (_arg(args, '--keypair') == null) {
    final sw = Stopwatch()..start();
    try {
      final sig = await client.requestAirdrop(
        address: payer.publicKey,
        lamports: _airdropLamports,
        commitment: Commitment.confirmed,
      );
      _log('airdrop', '$sig (${sw.elapsedMilliseconds} ms)');
    } on Object catch (e) {
      _log('airdrop', 'FAILED: $e');
      stderr.writeln(
        'Faucet недоступен — повтори с --keypair <devnet-кошелёк>',
      );
      exitCode = 1;
      return;
    }
  }

  final balance = await client.rpcClient.getBalance(
    payer.publicKey.toBase58(),
    commitment: Commitment.confirmed,
  );
  _log('balance', '${balance.value / lamportsPerSol} SOL');

  // 2. Transfer на новый адрес
  final recipient = await Ed25519HDKeyPair.random();
  final sw = Stopwatch()..start();
  final transferSig = await client.transferLamports(
    source: payer,
    destination: recipient.publicKey,
    lamports: _transferLamports,
    commitment: Commitment.confirmed,
  );
  _log('transfer', '$transferSig (${sw.elapsedMilliseconds} ms)');

  // 3. Чтение аккаунта получателя
  final account = await _readAccount(client, recipient.publicKey);
  if (account == null) {
    _log('account', 'NOT FOUND');
    exitCode = 1;
    return;
  }
  _log(
    'account',
    'lamports=${account.lamports} owner=${account.owner} '
        'executable=${account.executable}',
  );

  // 4. Anchor-инструкция vault_registry без IDL-клиента
  await _vaultRegistry(client, payer);
}

/// Собирает initialize_vault вручную; если программа задеплоена — отправляет
/// и сверяет VaultRecord с отправленными аргументами.
Future<void> _vaultRegistry(SolanaClient client, Ed25519HDKeyPair owner) async {
  final programId = Ed25519HDPublicKey.fromBase58(_programId);
  final rnd = Random.secure();
  final vaultId = List<int>.generate(16, (_) => rnd.nextInt(256));
  final hash = List<int>.generate(32, (_) => rnd.nextInt(256));
  const version = 42;

  final record = await Ed25519HDPublicKey.findProgramAddress(
    seeds: [utf8.encode('vault'), owner.publicKey.bytes, vaultId],
    programId: programId,
  );
  _log('pda', record.toBase58());

  // borsh: [u8;16] и [u8;32] — сырые байты, u64 — little-endian
  final versionLe = ByteData(8)..setUint64(0, version, Endian.little);
  final ix = await AnchorInstruction.forMethod(
    programId: programId,
    method: 'initialize_vault',
    namespace: 'global',
    accounts: [
      AccountMeta.writeable(pubKey: owner.publicKey, isSigner: true),
      AccountMeta.writeable(pubKey: record, isSigner: false),
      AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
    ],
    arguments: ByteArray([
      ...vaultId,
      ...hash,
      ...versionLe.buffer.asUint8List(),
    ]),
  );
  final data = ix.data.toList();
  _log('ix.discriminator', _hex(data.sublist(0, 8)));
  _log('ix.data.length', '${data.length} (8 + 16 + 32 + 8)');

  final program = await _readAccount(client, programId);
  if (program == null || !program.executable) {
    _log('vault_registry', 'не задеплоена в кластере — отправка пропущена');
    return;
  }

  final sw = Stopwatch()..start();
  final sig = await client.sendAndConfirmTransaction(
    message: Message.only(ix),
    signers: [owner],
    commitment: Commitment.confirmed,
  );
  _log('initialize_vault', '$sig (${sw.elapsedMilliseconds} ms)');

  final stored = await _readAccount(client, record);
  final bytes = switch (stored?.data) {
    BinaryAccountData(:final data) => Uint8List.fromList(data),
    _ => null,
  };
  if (bytes == null) {
    _log('VaultRecord', 'NOT FOUND');
    exitCode = 1;
    return;
  }

  // Раскладка: disc 8 | owner 32 | vault_id 16 | version 8 | hash 32 |
  // updated_at 8 | bump 1
  final view = ByteData.sublistView(bytes);
  final accountDisc = await computeDiscriminator('account', 'VaultRecord');
  final checks = {
    'discriminator': _eq(bytes.sublist(0, 8), accountDisc),
    'owner': _eq(bytes.sublist(8, 40), owner.publicKey.bytes),
    'vault_id': _eq(bytes.sublist(40, 56), vaultId),
    'version': view.getUint64(56, Endian.little) == version,
    'hash': _eq(bytes.sublist(64, 96), hash),
    'updated_at': view.getInt64(96, Endian.little) > 0,
  };
  _log('VaultRecord', '${bytes.length} байт, $checks');
  if (checks.containsValue(false)) exitCode = 1;
}

Future<Account?> _readAccount(
  SolanaClient client,
  Ed25519HDPublicKey key,
) async {
  final info = await client.rpcClient.getAccountInfo(
    key.toBase58(),
    encoding: Encoding.base64,
    commitment: Commitment.confirmed,
  );
  return info.value;
}

/// Ключ из JSON-файла solana CLI (массив из 64 байт) или одноразовый.
Future<Ed25519HDKeyPair> _loadPayer(String? path) async {
  if (path == null) return Ed25519HDKeyPair.random();

  final file = File(path.replaceFirst('~', Platform.environment['HOME']!));
  final bytes = (jsonDecode(await file.readAsString()) as List).cast<int>();
  // Первые 32 байта — seed приватного ключа. Keypair хранит ссылку на seed
  // без копии, поэтому затирать seed здесь нельзя — сломается подпись.
  // Затираем только исходный буфер из файла.
  final seed = Uint8List.fromList(bytes.sublist(0, 32));
  try {
    return await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed);
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}

/// WebSocket solana-test-validator слушает порт RPC + 1.
Uri _wsUrl(Uri rpc) => rpc.replace(
  scheme: rpc.scheme == 'https' ? 'wss' : 'ws',
  port: rpc.hasPort ? rpc.port + 1 : null,
);

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  return i == -1 || i + 1 >= args.length ? null : args[i + 1];
}

bool _eq(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void _log(String key, String value) =>
    stdout.writeln('${key.padRight(22)} $value');
