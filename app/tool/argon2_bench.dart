// SPDX-License-Identifier: GPL-3.0-or-later
// Консольный замер Argon2id (MAIN-19). Для честных цифр компилировать:
//   cd app && dart compile exe tool/argon2_bench.dart -o /tmp/argon2_bench
//   /tmp/argon2_bench
// (`dart run` — это JIT, он заметно медленнее и не отражает релизную сборку).
import 'dart:io';

import 'argon2_bench_lib.dart';

Future<void> main() async {
  stdout.writeln(
    'Платформа: ${Platform.operatingSystem}, ядер: ${Platform.numberOfProcessors}',
  );
  stdout.writeln(formatTable(await runBench()));
}
