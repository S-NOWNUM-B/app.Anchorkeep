<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../docs/branding/anchorkeep-mark-paper.svg">
  <img src="../docs/branding/anchorkeep-mark-ink.svg" width="64" height="64" alt="Логотип Anchorkeep">
</picture>

# Anchorkeep App

**Flutter-клиент для Android и Windows: сейф, бэкап и проверка версии**

![Flutter 3.47.7](https://img.shields.io/badge/Flutter-3.47.7-02569B?style=for-the-badge&logo=flutter&logoColor=white)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Локальная разработка](#локальная-разработка)
- [Правила](#правила)

---

## Назначение

Единая кодовая база для Android и Windows с адаптивным layout. Всё, кроме
заверения и проверки бэкапа, работает офлайн. macOS, Linux и iOS должны
собираться, но не тестируются и не входят в DoD.

---

## Что хранится здесь

<div align="center">

| **Путь** | **Содержимое** |
|:---|:---|
| `lib/app/` | Корневой виджет, роутер, тема |
| `lib/core/crypto/` | KDF, AEAD, wrap/unwrap ключа — чистый Dart |
| `lib/core/vault/` | Формат `.akv`, атомарная запись |
| `lib/core/solana/` | RPC, PDA, инструкции `vault_registry` |
| `lib/core/security/` | Автоблокировка, очистка буфера |
| `lib/features/` | Экраны по фичам: `data/`, `domain/`, `presentation/` |
| `lib/shared/` | Общие виджеты и адаптивный layout |

</div>

Папки создаются вместе с первой задачей, которой они нужны. Пустые слои не заводим.

---

## Локальная разработка

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter run -d windows
```

Android: нужны cmdline-tools и принятые лицензии SDK (`flutter doctor --android-licenses`).
Windows-сборка — только на Windows с Visual Studio (Desktop development with C++).

---

## Правила

- Бизнес-логика не живёт в виджетах; состояние — через Riverpod.
- Импорты только `package:anchorkeep/...`, `print` запрещён линтером.
- Ключи, пароли и расшифрованные данные не попадают в логи и на диск.
- Тесты обязательны для `core/crypto`, `core/vault`, `core/solana`.
