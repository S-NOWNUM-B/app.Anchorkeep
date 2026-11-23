// SPDX-License-Identifier: GPL-3.0-or-later
// Замер Argon2id для MAIN-19 (ADR 0002). Без Flutter: используется и в
// консольной версии (Mac, Windows), и в мини-приложении для телефона.
import 'dart:async';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';

/// (память KiB, итераций). 19 MiB / 2 — минимум по рекомендации OWASP,
/// 64 MiB / 3 — наши стартовые значения из ARCHITECTURE.md.
const defaultCases = <(int, int)>[
  (19456, 2),
  (32768, 2),
  (32768, 3),
  (65536, 3),
];

class BenchRow {
  const BenchRow({
    required this.memoryKiB,
    required this.iterations,
    required this.mainMs,
    required this.maxPauseMs,
  });

  final int memoryKiB;
  final int iterations;

  /// Сколько длится вывод ключа: столько ждёт пользователь после ввода пароля.
  final int mainMs;

  /// Самая длинная пауза, в которую основной поток не обрабатывал события.
  /// Если она больше ~50 мс, интерфейс на этом устройстве заметно подвисает.
  final int maxPauseMs;
}

int medianOf(List<int> values) => ([...values]..sort())[values.length ~/ 2];

Future<int> _timeMs(Future<void> Function() job) async {
  final sw = Stopwatch()..start();
  await job();
  return sw.elapsedMilliseconds;
}

/// Самая длинная пауза цикла событий за время [job]. Меряется отдельным
/// прогоном: сам таймер-датчик может замедлять работу (проверено на Android),
/// поэтому время и паузу нельзя снимать одновременно.
Future<int> _maxPauseMs(Future<void> Function() job) async {
  final sw = Stopwatch()..start();
  var last = 0;
  var maxGap = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final now = sw.elapsedMilliseconds;
    if (now - last > maxGap) maxGap = now - last;
    last = now;
  });
  await job();
  timer.cancel();
  return maxGap;
}

/// Для каждого набора: прогрев, [runs] чистых замеров времени (медиана),
/// затем отдельные [runs] замеров паузы (худшая: подвисание важно в худшем
/// случае).
Future<List<BenchRow>> runBench({
  List<(int, int)> cases = defaultCases,
  int runs = 3,
}) async {
  final rows = <BenchRow>[];
  for (final (memoryKiB, iterations) in cases) {
    final params = KdfParams(
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: 1,
      salt: randomBytes(16),
    );
    Future<void> derive() async =>
        (await deriveKek('бенчмарк-пароль', params)).destroy();

    await derive(); // прогрев
    final times = [for (var i = 0; i < runs; i++) await _timeMs(derive)];
    var worstPause = 0;
    for (var i = 0; i < runs; i++) {
      final pause = await _maxPauseMs(derive);
      if (pause > worstPause) worstPause = pause;
    }
    rows.add(
      BenchRow(
        memoryKiB: memoryKiB,
        iterations: iterations,
        mainMs: medianOf(times),
        maxPauseMs: worstPause,
      ),
    );
  }
  return rows;
}

/// Markdown-таблица для вставки в ADR.
String formatTable(List<BenchRow> rows) => [
  '| Память | Итераций | Время, мс | Макс. пауза UI, мс |',
  '|---|---|---|---|',
  for (final r in rows)
    '| ${r.memoryKiB ~/ 1024} MiB | ${r.iterations} | ${r.mainMs} | ${r.maxPauseMs} |',
].join('\n');
