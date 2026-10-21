<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../docs/branding/anchorkeep-mark-paper.svg">
  <img src="../docs/branding/anchorkeep-mark-ink.svg" width="64" height="64" alt="Логотип Anchorkeep">
</picture>

# Anchorkeep Program

**Anchor-программа vault_registry: реестр версий бэкапов в Solana Devnet**

![Anchor 1.2.1](https://img.shields.io/badge/Anchor-1.2.1-000000?style=for-the-badge&logo=rust&logoColor=white)
![Solana 4.1.2](https://img.shields.io/badge/Solana-4.1.2_devnet-9945FF?style=for-the-badge&logo=solana&logoColor=white)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Локальная разработка](#локальная-разработка)
- [Правила](#правила)

---

## Назначение

Программа хранит для каждого сейфа PDA `VaultRecord` с seeds
`["vault", owner, vault_id]`: владельца, номер версии, SHA-256 файла бэкапа и
время обновления. Инструкции `initialize_vault` и `commit_version` описаны в
[ARCHITECTURE.md](../docs/ARCHITECTURE.md#solana-программа-vault_registry).
Версия `version` хранит `revision` заверенного файла и только растёт
(см. [ADR 0006](../docs/adr/0006-onchain-version-is-revision.md)).
Ошибки: `Unauthorized` (signer не владелец), `VersionMismatch` (версия не больше текущей).

---

## Что хранится здесь

<div align="center">

| **Путь** | **Содержимое** |
|:---|:---|
| `programs/vault_registry/src/lib.rs` | Код программы |
| `tests/vault_registry.ts` | TS-тесты на mocha |
| `idl/vault_registry.json` | IDL задеплоенной версии; Program ID сверяется тестом в `app/` |
| `Anchor.toml` | Версии Anchor/Solana, program ID, кластер |
| `migrations/deploy.ts` | Скрипт деплоя |

</div>

---

## Локальная разработка

Сборка — на macOS, Linux или WSL.

```bash
yarn install
anchor build
anchor test --validator legacy
anchor deploy --provider.cluster devnet
```

`--validator legacy` нужен, пока surfpool не поддерживает SBPF v3 —
см. [ADR 0004](../docs/adr/0004-toolchain-versions.md).

### Devnet

Программа задеплоена: `Y8ik6bx8kAoeMr3Ugu7SmhKtvChTkBTd1hZLdWggHNg`,
upgrade authority — `FZ3GPBucdPk3J135uzNgSKwGKMoA3voqypEz3vKXgZcz`.
IDL выложен в цепочку при деплое. После изменения контракта:

```bash
anchor build
anchor deploy --provider.cluster devnet --provider.wallet ~/.config/solana/id.json
cp target/idl/vault_registry.json idl/
```

Кошелёк передаём явно: глобальный конфиг `solana` CLI может указывать на чужой ключ.

---

## Правила

- В блокчейн уходят только публичный ключ, `vault_id`, номер версии и SHA-256 файла.
- Keypair-файлы (`target/deploy/*-keypair.json`, `id.json`) не коммитим.
- Каждая инструкция покрыта тестами, включая ошибки `Unauthorized` и `VersionMismatch`.
