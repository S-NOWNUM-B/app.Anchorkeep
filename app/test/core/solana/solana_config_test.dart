// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/solana.dart';

void main() {
  test('programId совпадает с адресом в закоммиченном IDL', () async {
    // flutter test запускается из app/
    final idl = jsonDecode(
      await File('../program/idl/vault_registry.json').readAsString(),
    ) as Map<String, Object?>;

    expect(SolanaConfig.programId, idl['address']);
    expect(
      () => Ed25519HDPublicKey.fromBase58(SolanaConfig.programId),
      returnsNormally,
    );
  });

  test('по умолчанию devnet, WebSocket на том же хосте', () {
    expect(SolanaConfig.rpcUrl.toString(), 'https://api.devnet.solana.com');
    expect(SolanaConfig.websocketUrl.toString(), 'wss://api.devnet.solana.com');
  });
}
