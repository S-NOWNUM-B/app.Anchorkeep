# Architecture Decision Records

ADR — короткий документ об одном архитектурном решении: контекст, выбор, отвергнутые альтернативы и последствия. Нужен, чтобы через месяц (или на защите) было понятно, **почему** сделано так.

Когда писать — см. [`CONTRIBUTING.md`](../../CONTRIBUTING.md#adr).

## Формат

- Имя файла: `NNNN-short-title.md`, `NNNN` — 4-значный порядковый номер, `short-title` — kebab-case на английском.
- Шаблон: [`0000-template.md`](0000-template.md).
- Статусы: `Proposed` → `Accepted` → (`Deprecated` | `Superseded by NNNN`).
- Принятый ADR не переписываем: новое решение — новый ADR со ссылкой на старый.

## Список

| № | Решение | Задача | Статус |
|---|---|---|---|
| [0001](0001-license-gpl-3.md) | Лицензия GPL-3.0-or-later | — | Accepted |
| 0002 | Параметры Argon2id (memory / iterations / isolate) | AK-03 | будет |
| [0003](0003-dart-solana-client.md) | Dart-клиент Solana: `solana` с ручной Anchor-сериализацией | AK-04 | Accepted |
| [0004](0004-toolchain-versions.md) | Версии Flutter / Anchor / Solana CLI | AK-05 | Accepted |
| [0005](0005-vault-aad.md) | AAD и целостность файла `.akv` | AK-10, AK-11 | Proposed |
| [0006](0006-onchain-version-is-revision.md) | On-chain `version` = `revision` файла | AK-14, AK-43 | Proposed |
