// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:anchorkeep/core/solana/chain_failure.dart';
import 'package:anchorkeep/core/solana/devnet_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/solana.dart';

final owner = Ed25519HDPublicKey.fromBase58(
  'FZ3GPBucdPk3J135uzNgSKwGKMoA3voqypEz3vKXgZcz',
);

void main() {
  test('balance возвращает lamports', () async {
    final wallet = DevnetWallet((_) async => 42, (_, _) async => 'sig');
    expect(await wallet.balance(owner), 42);
  });

  test('airdrop просит 0.1 SOL и возвращает новый баланс', () async {
    int? asked;
    var balance = 0;
    final wallet = DevnetWallet((_) async => balance, (_, lamports) async {
      asked = lamports;
      balance += lamports;
      return 'sig';
    });
    expect(await wallet.requestAirdrop(owner), lamportsPerSol ~/ 10);
    expect(asked, 100000000);
  });

  test('нет сети → OfflineFailure', () {
    final wallet = DevnetWallet(
      (_) async => throw const SocketException('down'),
      (_, _) async => 'sig',
    );
    expect(wallet.balance(owner), throwsA(isA<OfflineFailure>()));
  });

  test('HTTP 429 на airdrop → RateLimitedFailure', () {
    final wallet = DevnetWallet(
      (_) async => 0,
      (_, _) async => throw const HttpException(429, 'slow down'),
    );
    expect(wallet.requestAirdrop(owner), throwsA(isA<RateLimitedFailure>()));
  });

  test('JSON-RPC «rate limit» от faucet → RateLimitedFailure', () {
    final wallet = DevnetWallet(
      (_) async => 0,
      (_, _) async => throw const JsonRpcException(
        'Airdrop request failed. This can happen when the rate limit is reached.',
        -32603,
        null,
      ),
    );
    expect(wallet.requestAirdrop(owner), throwsA(isA<RateLimitedFailure>()));
  });

  test('ошибка баланса после airdrop → ChainFailure', () {
    final wallet = DevnetWallet(
      (_) async => throw const JsonRpcException('boom', -32000, null),
      (_, _) async => 'sig',
    );
    expect(wallet.requestAirdrop(owner), throwsA(isA<UnknownFailure>()));
  });

  test('classifyChainError: insufficient в тексте → NoSolFailure', () {
    expect(
      classifyChainError(
        const JsonRpcException(
          'insufficient lamports 0, need 5000',
          -32002,
          null,
        ),
      ),
      isA<NoSolFailure>(),
    );
  });
}
