// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';

const _magic = 'AKV';
const _formatVersion = 1;

/// Верхние границы KDF: чужой файл не должен заставить приложение
/// выделить гигабайты памяти при разблокировке.
const _maxMemoryKiB = 256 * 1024;
const _maxIterations = 10;

/// Бюджет работы memoryKiB × iterations (1 GiB·проход): дефолт 64 MiB × 3
/// укладывается с запасом, а 256 MiB × 10 — нет.
const _maxWorkKiB = 1024 * 1024;
const _maxParallelism = 8;

// Argon2 требует минимум 8 KiB памяти на поток (см. проверку ниже).

/// Открытая часть файла. Целиком входит в AAD payload (ADR 0005).
class VaultHeader {
  const VaultHeader({
    required this.vaultId,
    required this.revision,
    required this.kdf,
    required this.wrappedKey,
  });

  final Uint8List vaultId;
  final int revision;
  final KdfParams kdf;
  final Sealed wrappedKey;

  VaultHeader withRevision(int value) => VaultHeader(
    vaultId: vaultId,
    revision: value,
    kdf: kdf,
    wrappedKey: wrappedKey,
  );

  /// Порядок ключей зафиксирован здесь — это и есть «канонический JSON».
  Map<String, Object> toJson() => {
    'magic': _magic,
    'formatVersion': _formatVersion,
    'vaultId': base64.encode(vaultId),
    'revision': revision,
    'kdf': {
      'alg': KdfParams.alg,
      'memoryKiB': kdf.memoryKiB,
      'iterations': kdf.iterations,
      'parallelism': kdf.parallelism,
      'salt': base64.encode(kdf.salt),
    },
    'wrappedKey': _sealedToJson(wrappedKey),
  };

  /// AAD payload: заголовок, собранный заново из распарсенных полей.
  Uint8List aadBytes() => utf8.encode(jsonEncode(toJson()));
}

/// Файл `.akv` / `.akbackup`: заголовок + зашифрованный payload.
class VaultFile {
  const VaultFile(this.header, this.payload);

  final VaultHeader header;
  final Sealed payload;

  Uint8List encode() => utf8.encode(
    jsonEncode({...header.toJson(), 'payload': _sealedToJson(payload)}),
  );

  /// Строгий разбор: любое отклонение от формата → [FormatException]
  /// до того, как запустится KDF.
  static VaultFile decode(List<int> bytes) {
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('vault: не JSON');
    }
    final j = _object(root, const {
      'magic',
      'formatVersion',
      'vaultId',
      'revision',
      'kdf',
      'wrappedKey',
      'payload',
    });
    if (j['magic'] != _magic || j['formatVersion'] != _formatVersion) {
      throw const FormatException('vault: неизвестный формат');
    }
    final kdf = _object(j['kdf'], const {
      'alg',
      'memoryKiB',
      'iterations',
      'parallelism',
      'salt',
    });
    if (kdf['alg'] != KdfParams.alg) {
      throw const FormatException('vault: неизвестный KDF');
    }
    final parallelism = _int(kdf['parallelism'], 1, _maxParallelism);
    final memoryKiB = _int(kdf['memoryKiB'], 8 * parallelism, _maxMemoryKiB);
    final iterations = _int(kdf['iterations'], 1, _maxIterations);
    if (memoryKiB * iterations > _maxWorkKiB) {
      throw const FormatException('vault: слишком тяжёлый KDF');
    }
    final header = VaultHeader(
      vaultId: _bytes(j['vaultId'], 16),
      revision: _int(j['revision'], 0, 1 << 53),
      kdf: KdfParams(
        memoryKiB: memoryKiB,
        iterations: iterations,
        parallelism: parallelism,
        salt: _bytes(kdf['salt'], 16),
      ),
      wrappedKey: _sealed(j['wrappedKey'], exactCiphertext: 32 + 16),
    );
    return VaultFile(header, _sealed(j['payload']));
  }
}

Map<String, Object> _sealedToJson(Sealed s) => {
  'nonce': base64.encode(s.nonce),
  'ciphertext': base64.encode(s.ciphertext),
};

Sealed _sealed(Object? value, {int? exactCiphertext}) {
  final j = _object(value, const {'nonce', 'ciphertext'});
  final ct = _bytes(j['ciphertext'], exactCiphertext);
  if (ct.length < 16) {
    throw const FormatException('vault: короткий шифротекст');
  }
  return Sealed(_bytes(j['nonce'], 12), ct);
}

Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw const FormatException('vault: неверная структура');
  }
  return value;
}

int _int(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('vault: число вне диапазона');
  }
  return value;
}

Uint8List _bytes(Object? value, [int? length]) {
  if (value is! String) throw const FormatException('vault: ожидался base64');
  final b = base64.decode(value); // при битом base64 сам кидает FormatException
  if (length != null && b.length != length) {
    throw const FormatException('vault: неверная длина поля');
  }
  return b;
}
