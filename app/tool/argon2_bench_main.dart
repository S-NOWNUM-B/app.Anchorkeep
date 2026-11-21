// SPDX-License-Identifier: GPL-3.0-or-later
// Замер Argon2id на устройстве (MAIN-19). Запускать ТОЛЬКО в release:
//   flutter run --release -t tool/argon2_bench_main.dart -d <устройство>
// В debug цифры завышены в разы и бесполезны.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'argon2_bench_lib.dart';

void main() => runApp(const _BenchApp());

class _BenchApp extends StatelessWidget {
  const _BenchApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: SafeArea(child: _BenchPage())),
  );
}

class _BenchPage extends StatefulWidget {
  const _BenchPage();

  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage> {
  String _text = 'Замер идёт, интерфейс может подвисать…';

  @override
  void initState() {
    super.initState();
    final mode = kReleaseMode
        ? 'release'
        : (kProfileMode ? 'profile' : 'DEBUG, цифры недостоверны');
    final head =
        'Платформа: ${Platform.operatingSystem}, ядер: ${Platform.numberOfProcessors}, режим: $mode';
    // Даём один кадр отрисоваться, затем считаем (основной поток будет занят).
    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      final table = formatTable(await runBench());
      debugPrint('$head\n$table');
      if (mounted) setState(() => _text = '$head\n\n$table');
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: SingleChildScrollView(
      child: SelectableText(
        _text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    ),
  );
}
