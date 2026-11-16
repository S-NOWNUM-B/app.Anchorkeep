// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io' as io;

import 'package:solana/solana.dart';

/// Типизированная причина отказа операции с цепочкой. UI выбирает текст
/// по типу, а не по `error.toString()`.
sealed class ChainFailure implements Exception {
  const ChainFailure([this.cause]);

  /// Исходное исключение (только для отладки; в логи не пишем).
  final Object? cause;
}

/// Нет сети, RPC не ответил или истёк таймаут.
final class OfflineFailure extends ChainFailure {
  const OfflineFailure([super.cause]);
}

/// На кошельке не хватает SOL на комиссию (или аккаунт ещё не пополняли).
final class NoSolFailure extends ChainFailure {
  const NoSolFailure([super.cause]);
}

/// Faucet или RPC ограничил частоту запросов (HTTP 429 / rate limit).
final class RateLimitedFailure extends ChainFailure {
  const RateLimitedFailure([super.cause]);
}

/// Эта версия сейфа уже заверена: `revision <= record.version`.
final class AlreadyAnchoredFailure extends ChainFailure {
  const AlreadyAnchoredFailure([super.cause]);
}

/// Всё остальное: ошибка программы, битый ответ и т. п.
final class UnknownFailure extends ChainFailure {
  const UnknownFailure([super.cause]);
}

/// Приводит исключение пакета `solana` / `dart:io` к [ChainFailure].
/// Уже типизированную ошибку возвращает как есть.
ChainFailure classifyChainError(Object error) {
  if (error is ChainFailure) return error;
  if (error is io.SocketException || error is TimeoutException) {
    // RpcTimeoutException наследует TimeoutException
    return OfflineFailure(error);
  }
  if (error is HttpException) {
    // Код в пакете приватный, виден только в toString
    final text = error.toString();
    if (text.contains('status code 429')) return RateLimitedFailure(error);
    return UnknownFailure(error);
  }
  if (error is JsonRpcException) {
    final txError = error.transactionError;
    final message = error.message.toLowerCase();
    if (txError == TransactionError.insufficientFundsForFee ||
        txError == TransactionError.accountNotFound ||
        message.contains('insufficient') ||
        message.contains('no record of a prior credit')) {
      return NoSolFailure(error);
    }
    if (message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('429') ||
        message.contains('limit')) {
      return RateLimitedFailure(error);
    }
    return UnknownFailure(error);
  }
  return UnknownFailure(error);
}
