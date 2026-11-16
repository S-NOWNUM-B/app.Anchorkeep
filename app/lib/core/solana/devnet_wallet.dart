// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/solana/chain_failure.dart';
import 'package:solana/solana.dart';

/// Читает баланс в lamports.
typedef GetBalance = Future<int> Function(Ed25519HDPublicKey owner);

/// Просит airdrop; возвращает подпись.
typedef RequestAirdrop = Future<String> Function(
  Ed25519HDPublicKey owner,
  int lamports,
);

/// Размер тестового пополнения: 0.1 SOL.
const devnetAirdropLamports = lamportsPerSol ~/ 10;

/// Тестовый кошелёк Devnet: баланс и airdrop. Ошибки — [ChainFailure].
class DevnetWallet {
  DevnetWallet(this._getBalance, this._airdrop);

  /// Обёртка над настоящим RPC-клиентом.
  factory DevnetWallet.fromClient(SolanaClient client) => DevnetWallet(
    (owner) async => (await client.rpcClient.getBalance(
      owner.toBase58(),
      commitment: Commitment.confirmed,
    )).value,
    (owner, lamports) => client.requestAirdrop(
      address: owner,
      lamports: lamports,
      commitment: Commitment.confirmed,
    ),
  );

  final GetBalance _getBalance;
  final RequestAirdrop _airdrop;

  /// Баланс [owner] в lamports.
  Future<int> balance(Ed25519HDPublicKey owner) async {
    try {
      return await _getBalance(owner);
    } on Object catch (error) {
      throw classifyChainError(error);
    }
  }

  /// Запрашивает 0.1 SOL и возвращает новый баланс в lamports.
  /// Лимит faucet → [RateLimitedFailure].
  Future<int> requestAirdrop(Ed25519HDPublicKey owner) async {
    try {
      await _airdrop(owner, devnetAirdropLamports);
      return await _getBalance(owner);
    } on Object catch (error) {
      throw classifyChainError(error);
    }
  }
}
