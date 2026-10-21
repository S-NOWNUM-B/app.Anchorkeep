import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Страж: FLAG_SECURE (запрет скриншотов и скрытие в Recent Apps) живёт
/// в нативном коде, и его легко затереть, пересоздав платформенные файлы.
/// Тест проверяет исходник, а не поведение; поведение проверено вручную
/// на эмуляторе (см. PR MAIN-48).
void main() {
  test('MainActivity ставит FLAG_SECURE до super.onCreate', () {
    final src = File(
      'android/app/src/main/kotlin/app/anchorkeep/anchorkeep/MainActivity.kt',
    ).readAsStringSync();
    final flag = src.indexOf('FLAG_SECURE');
    final superCall = src.indexOf('super.onCreate(');
    expect(flag, isNonNegative, reason: 'FLAG_SECURE пропал из MainActivity');
    expect(superCall, isNonNegative);
    expect(flag, lessThan(superCall), reason: 'флаг нужен до super.onCreate');
  });
}
