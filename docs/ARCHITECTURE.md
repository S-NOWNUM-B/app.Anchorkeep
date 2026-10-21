# Anchorkeep — архитектура

## Монорепо
```
anchorkeep/
├── CLAUDE.md
├── docs/                    # PRD, ARCHITECTURE, BACKLOG, ADR
│   └── adr/
├── app/                     # Flutter-приложение
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/             # router.dart, theme.dart, app.dart
│   │   ├── core/
│   │   │   ├── crypto/      # KDF, AEAD, key wrapping — чистый Dart, без Flutter
│   │   │   ├── vault/       # формат файла, репозиторий, атомарная запись
│   │   │   ├── solana/      # RPC-клиент, PDA, инструкции vault_registry
│   │   │   └── security/    # автоблокировка, очистка буфера
│   │   ├── features/
│   │   │   ├── onboarding/
│   │   │   ├── unlock/
│   │   │   ├── passwords/
│   │   │   ├── notes/
│   │   │   ├── backup/
│   │   │   ├── verification/
│   │   │   └── settings/
│   │   └── shared/          # общие виджеты, адаптивный layout
│   └── test/
├── program/                 # Anchor workspace
│   ├── programs/vault_registry/src/lib.rs
│   └── tests/vault_registry.ts
└── .github/workflows/       # ci-app.yml, ci-program.yml
```

Каждая feature: `data/` (репозиторий), `domain/` (модели), `presentation/` (экраны + riverpod-провайдеры). Не раздувать: если слой пустой — не создавать.

## Криптосхема

```
master password ──Argon2id(salt, params)──▶ KEK (32 B)
                                              │
                         AES-256-GCM(KEK) unwrap
                                              ▼
random Vault Key (VK, 32 B) ──AES-256-GCM(VK, aad=header)──▶ payload
```

- **Argon2id**: стартовые параметры `memory=64 MiB, iterations=3, parallelism=1`, хранятся в заголовке → можно менять без миграции. Подбираются бенчмарком в AK-03.
  - ⚠️ В `cryptography_flutter` нативно ускорены AES-GCM/ChaCha20, а Argon2id идёт через чистый Dart → может быть медленно на Android. Если бенчмарк > 1.5 с — снизить memory до 32 MiB или вынести в isolate (`compute`), и записать решение в ADR.
- **KEK** только разворачивает VK. Смена пароля = перешифровать VK, payload не трогаем.
- **Nonce**: 12 байт, новый на каждое шифрование.
- **AAD** payload = канонический JSON заголовка (без поля `payload`) → подмена заголовка ломает расшифровку.

## Формат файла `vault.akv` (и `.akbackup` — тот же формат)
JSON-конверт, бинарные поля в base64:
```json
{
  "magic": "AKV",
  "formatVersion": 1,
  "vaultId": "<16 B base64>",
  "revision": 42,
  "kdf": { "alg": "argon2id", "memoryKiB": 65536, "iterations": 3, "parallelism": 1, "salt": "<16 B>" },
  "wrappedKey": { "nonce": "<12 B>", "ciphertext": "<32 B + 16 B tag>" },
  "payload": { "nonce": "<12 B>", "ciphertext": "<...>" }
}
```
- `revision` растёт на 1 при каждом сохранении.
- Расшифрованный payload:
```json
{
  "entries": [ { "id": "uuid", "type": "password|note", "title": "...", "fields": {...}, "createdAt": "...", "updatedAt": "..." } ],
  "settings": { "autoLockMinutes": 5 },
  "solana": { "secretKey": "<64 B>", "lastAnchoredRevision": 41 }
}
```
- Devnet-keypair хранится **внутри** зашифрованного payload, не отдельным файлом.
- Запись: сериализация → шифрование → `vault.tmp` → flush/fsync → `rename` → `vault.akv`.
- MVP: весь payload перешифровывается при каждом сохранении (данных мало — это нормально).

## Solana: программа `vault_registry`

**Account `VaultRecord`** (PDA, seeds = `["vault", owner, vault_id]`):
| поле | тип |
|---|---|
| owner | Pubkey |
| vault_id | [u8; 16] |
| version | u64 — `revision` заверенного файла (см. ADR 0006) |
| hash | [u8; 32] — SHA-256 байт всего `.akv`-файла |
| updated_at | i64 — `Clock::get()?.unix_timestamp` |
| bump | u8 |

**Инструкции:**
- `initialize_vault(vault_id, hash, version)` — создаёт PDA, `version` = `revision` файла. Signer = owner, payer = owner.
- `commit_version(new_hash, new_version)` — `require!(signer == owner)`, `require!(new_version > record.version)` (версия только растёт: защита от гонок и от заверения старого файла), затем `version = new_version`, обновить `hash` и `updated_at`.

**Ошибки:** `Unauthorized`, `VersionMismatch`.

Версии Anchor/Solana CLI — взять актуальные stable на момент старта и зафиксировать в `program/Anchor.toml` + ADR. Сборка программы — на Linux/macOS или WSL.

## Dart-клиент Solana
- Пакет `solana` (espresso-cash): RPC, транзакции, Ed25519, PDA, borsh.
- Discriminator инструкции = первые 8 байт `sha256("global:<method_name>")`; аккаунта = `sha256("account:VaultRecord")`.
- Альтернатива: `coral_xyz` (Anchor-клиент по IDL), но он в beta → только если ручная сериализация не пошла в spike AK-04.
- RPC: `https://api.devnet.solana.com`, вынести в конфиг.

## Поток проверки (F9)
```
файл бэкапа → sha256(bytes) → fetch PDA(owner, vaultId)
  hash == onchain.hash                → ✅ Verified (последняя версия)
  revision < onchain.version          → ⚠️ Outdated (старый бэкап; version = revision заверенного файла)
  иначе                               → ❌ Unknown (не заверен / изменён)
  PDA нет / нет сети                  → ℹ️ Not anchored / Offline
```
`owner` и `vaultId` берутся из бэкапа: `vaultId` — из заголовка, `owner` — из payload после расшифровки.

## Состояние (riverpod)
- `vaultSessionProvider` — `locked | unlocked(VaultSession)`; при lock — invalidate всех зависимых провайдеров.
- go_router redirect: всё, кроме onboarding/unlock, требует `unlocked`.

## CI
- `ci-app.yml`: `flutter analyze`, `flutter test` на ubuntu; сборка Windows на `windows-latest`; Android APK на ubuntu.
- `ci-program.yml`: `anchor build && anchor test`.
