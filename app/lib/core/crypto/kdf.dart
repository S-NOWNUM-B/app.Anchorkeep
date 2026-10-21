// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:cryptography/cryptography.dart';

/// Параметры Argon2id. Лежат в заголовке сейфа, поэтому их можно
/// менять без миграции старых файлов.
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  /// Стартовые значения из ARCHITECTURE.md; финальные — по бенчмарку
  /// MAIN-19 (ADR 0002).
  factory KdfParams.defaults() => KdfParams(
    memoryKiB: 64 * 1024,
    iterations: 3,
    parallelism: 1,
    salt: randomBytes(16),
  );

  static const alg = 'argon2id';

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final Uint8List salt;
}

/// Мастер-пароль → 32-байтный KEK.
Future<SecretKey> deriveKek(String password, KdfParams params) => Argon2id(
  parallelism: params.parallelism,
  memory: params.memoryKiB,
  iterations: params.iterations,
  hashLength: 32,
).deriveKeyFromPassword(password: password, nonce: params.salt);
