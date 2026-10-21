# 0003. Dart-клиент Solana: пакет `solana` с ручной Anchor-сериализацией

- **Статус:** Accepted
- **Дата:** 2026-10-21
- **Задача:** MAIN-20 / AK-04

## Контекст

Приложению нужно из Dart: запросить devnet-SOL, отправить `initialize_vault` / `commit_version` в `vault_registry` и прочитать `VaultRecord` (F8, F9). Контракт маленький: 2 инструкции, 1 аккаунт, только фиксированные типы (`[u8; 16]`, `[u8; 32]`, `u64`, `i64`, `Pubkey`, `u8`).

Кандидаты из ARCHITECTURE.md:

| | `solana` (espresso-cash) | `coral_xyz` |
|---|---|---|
| Версия | 0.32.0+1, stable | 1.0.0-beta.9 |
| pub points / скачивания за 30 дней | 150 / ~780 | 130 / ~60 |
| Платформы | Android, Windows и остальные | Android, Windows и остальные |
| Подход | RPC, транзакции, PDA, `AnchorInstruction`, `computeDiscriminator`; данные собираем сами | Динамический клиент по IDL |
| Зависимости | уже в `pubspec.yaml` | сам тянет `solana` + `ffi` |

Spike — `app/tool/solana_spike.dart`. Прогон против `solana-test-validator` 4.1.2 с задеплоенной `vault_registry` из `main`:

| Шаг | Результат |
|---|---|
| airdrop 0.5 SOL | ок, 167 мс |
| transfer 0.001 SOL на новый адрес | ок, 479 мс |
| `getAccountInfo` получателя | `lamports=1000000`, owner = System Program |
| PDA `["vault", owner, vault_id]` | `findProgramAddress` |
| discriminator `initialize_vault` | `30bfa32c47813fa4` — совпал с `target/idl/vault_registry.json` |
| отправка `initialize_vault` (ручной borsh, 64 байта данных) | ок, 418 мс |
| чтение `VaultRecord` (105 байт) | discriminator, owner, vault_id, version, hash, updated_at совпали |

Прогон против devnet (`--keypair`, кошелёк пополнен через веб-faucet):

| Шаг | Результат |
|---|---|
| баланс | 4 SOL |
| transfer 0.001 SOL на новый адрес | ок, 1549 мс |
| `getAccountInfo` получателя | `lamports=1000000`, owner = System Program |
| discriminator `initialize_vault` | `30bfa32c47813fa4` |
| отправка `initialize_vault` | пропущена: программа ещё не задеплоена в devnet (AK-26) |

Airdrop из скрипта и через `solana airdrop` на devnet отклонён лимитом публичного faucet — это ограничение faucet, а не клиента; на локальном валидаторе тот же вызов работает.

## Решение

Используем пакет `solana`, Anchor-слой пишем вручную в `core/solana`:

- discriminator инструкций и аккаунта — `computeDiscriminator` / `AnchorInstruction.forMethod` из `package:solana/anchor.dart`;
- аргументы — конкатенация байтов: массивы как есть, `u64` / `i64` — little-endian;
- `VaultRecord` — разбор по фиксированным смещениям: `disc 8 | owner 32 | vault_id 16 | version 8 | hash 32 | updated_at 8 | bump 1`;
- unit-тест сверяет discriminator с IDL, чтобы ловить переименование инструкций.

Fallback на TypeScript-скрипт (BACKLOG) не нужен: связка Dart → программа работает.

## Альтернативы

| Вариант | Почему отвергнут |
|---|---|
| `coral_xyz` (клиент по IDL) | Beta, в 13 раз меньше скачиваний, тянет `ffi` — лишний риск сборки на Android/Windows. Для 2 инструкций с фиксированными типами генерация по IDL не окупается |
| TypeScript-скрипт вне приложения | Fallback из BACKLOG на случай провала spike; spike прошёл, а проверка в UI (F9) без Dart-клиента невозможна |

## Последствия

- Ни одной новой зависимости: `solana` уже в `pubspec.yaml`.
- Раскладку `VaultRecord` и порядок аргументов держим синхронно с `lib.rs` руками. Любое изменение контракта программы = правка `core/solana` + тест сверки с IDL.
- `Ed25519HDKeyPair.fromPrivateKeyBytes` хранит ссылку на переданный seed без копии: затереть его сразу после создания keypair нельзя — адрес останется верным, но подпись станет невалидной (найдено в spike). Seed затираем только когда keypair больше не нужен (блокировка сейфа), исходный буфер из payload — сразу.
- `Ed25519HDKeyPair.random()` использует `Random.secure()` — подходит для AK-31 (правило безопасности 3).
- Для devnet нужен SOL: faucet часто отвечает лимитом, поэтому в AK-32 (баланс и airdrop в настройках) нужна понятная ошибка «попробуйте позже».
- Следующий шаг — AK-30 (MAIN-37): перенести сборку инструкций из spike в `app/lib/core/solana/` с тестами.
