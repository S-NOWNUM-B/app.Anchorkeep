# 0004. Версии тулчейна

- **Статус:** Accepted
- **Дата:** 2026-10-21
- **Задача:** AK-05

## Контекст

ARCHITECTURE.md требует зафиксировать актуальные stable-версии Anchor и Solana CLI на старте. Команда собирает на разных машинах (macOS, Windows + WSL), CI — на Linux.

## Решение

| Инструмент | Версия | Где зафиксировано |
|---|---|---|
| Flutter | 3.47.7 stable (Dart 3.13) | `app/pubspec.yaml` (`environment.sdk`), CI |
| Anchor CLI / `anchor-lang` | 1.2.1 | `program/Anchor.toml` `[toolchain]`, `Cargo.toml` |
| Solana (Agave) CLI | 4.1.2 | `program/Anchor.toml` `[toolchain]` |
| Rust | 1.89.0 | `program/rust-toolchain.toml` |

Локальные тесты программы: `anchor test --validator legacy` (`solana-test-validator`).

## Альтернативы

| Вариант | Почему отвергнут |
|---|---|
| Solana CLI 3.1.x | Anchor 1.2.1 собирает SBPF v3, валидатор 3.1 его не исполняет |
| `surfpool` (валидатор по умолчанию в Anchor 1.x) | surfpool 1.0.0 падает на SBPF v3 (`This program may not be used for executing instructions`) |

## Последствия

- Обновление версий — только отдельным PR с правкой этого ADR.
- Если surfpool починят — можно убрать `--validator legacy`.
