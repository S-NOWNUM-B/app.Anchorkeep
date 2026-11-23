import 'package:flutter_test/flutter_test.dart';

import '../../tool/argon2_bench_lib.dart';

void main() {
  test('medianOf берёт середину отсортированных значений', () {
    expect(medianOf([30, 10, 20]), 20);
    expect(medianOf([5]), 5);
    expect(medianOf([9, 1, 5, 7, 3]), 5);
  });

  test('formatTable даёт markdown-таблицу для вставки в ADR', () {
    final table = formatTable([
      const BenchRow(
        memoryKiB: 32768,
        iterations: 3,
        mainMs: 410,
        maxPauseMs: 12,
      ),
    ]);
    expect(
      table,
      contains('| Память | Итераций | Время, мс | Макс. пауза UI, мс |'),
    );
    expect(table, contains('| 32 MiB | 3 | 410 | 12 |'));
  });

  test(
    'runBench измеряет время и паузу для каждого набора параметров',
    () async {
      final rows = await runBench(cases: const [(1024, 1), (2048, 2)], runs: 1);
      expect(rows.map((r) => (r.memoryKiB, r.iterations)), [
        (1024, 1),
        (2048, 2),
      ]);
      for (final r in rows) {
        expect(r.mainMs, greaterThanOrEqualTo(0));
        expect(r.maxPauseMs, greaterThanOrEqualTo(0));
      }
    },
  );
}
