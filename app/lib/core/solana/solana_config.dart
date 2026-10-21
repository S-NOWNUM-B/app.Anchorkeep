// SPDX-License-Identifier: GPL-3.0-or-later

/// Сеть Solana и адрес программы `vault_registry`.
///
/// RPC по умолчанию — devnet. Для локального валидатора:
/// `flutter run --dart-define=SOLANA_RPC_URL=http://127.0.0.1:8899`.
abstract final class SolanaConfig {
  /// Program ID `vault_registry`; совпадает с `program/idl/vault_registry.json`.
  static const programId = 'Y8ik6bx8kAoeMr3Ugu7SmhKtvChTkBTd1hZLdWggHNg';

  static final rpcUrl = Uri.parse(
    const String.fromEnvironment(
      'SOLANA_RPC_URL',
      defaultValue: 'https://api.devnet.solana.com',
    ),
  );

  /// WebSocket того же узла: публичные RPC — тот же хост, локальный
  /// валидатор — порт RPC + 1.
  static Uri get websocketUrl => rpcUrl.replace(
    scheme: rpcUrl.scheme == 'https' ? 'wss' : 'ws',
    port: rpcUrl.hasPort ? rpcUrl.port + 1 : null,
  );
}
