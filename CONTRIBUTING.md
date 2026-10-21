# Как участвовать в Anchorkeep

Перед работой прочитай [`CLAUDE.md`](CLAUDE.md), [`docs/PRD.md`](docs/PRD.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) и [`docs/BACKLOG.md`](docs/BACKLOG.md).

## Команда

| Участник | Роль | Зона ответственности |
|---|---|---|
| Aliar | Core | `core/crypto`, `core/vault`, хранение, безопасность, CI |
| Bekzat | UI | Flutter-экраны, дизайн-система, адаптивность, навигация |
| Stas (SNOWNUMB) | Chain | Anchor-программа `vault_registry`, `core/solana`, CI программы |

## Окружение

| Инструмент | Версия | Зачем |
|---|---|---|
| Flutter | stable | `app/` |
| Android SDK | API 26+ | сборка и проверка на Android |
| Rust | stable (через `rustup`) | `program/` |
| Solana CLI | см. `program/Anchor.toml` | devnet, локальный валидатор |
| Anchor | через `avm`, версия из `program/Anchor.toml` | сборка и тесты программы |

- Программу собираем только на macOS, Linux или WSL (на «голом» Windows Anchor не поддерживается).
- Windows-сборку приложения (`flutter build windows`) — только на Windows.
- Версии Anchor/Solana CLI не выбираем сами: берём из `program/Anchor.toml`.

## Задачи

- Трекер — **Linear**, team **MAIN**, ID вида `MAIN-12`.
- В заголовке задачи — ID из бэклога: `[AK-12] Экран Unlock`.
- GitHub Issues — только для багов и предложений извне; рабочие задачи живут в Linear.
- Одна задача = одна ветка = один PR.

## Ветки

От актуального `main`:

| Префикс | Когда | Пример |
|---|---|---|
| `feat/` | новая функциональность | `feat/MAIN-12-unlock-screen` |
| `fix/` | исправление бага | `fix/MAIN-31-nonce-reuse` |
| `docs/` | документация, ADR | `docs/MAIN-5-argon2-adr` |
| `chore/` | инфраструктура, CI, зависимости | `chore/MAIN-7-ci-app` |

Формат: `<type>/MAIN-<N>-<short-name>`, `short-name` — kebab-case на английском.

## Коммиты

[Conventional Commits](https://www.conventionalcommits.org/ru/v1.0.0/):

```
type(scope): описание

Необязательное тело: что и зачем.

Refs: MAIN-12
```

- `type`: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`.
- `scope` — реальная область: `app`, `crypto`, `vault`, `solana`, `program`, `ui`, `ci`, `docs`.
- Footer: `Refs: MAIN-12` (связь) или `Closes MAIN-12` (закрывает задачу).
- Пример: `feat(crypto): добавил обёртку vault key через AES-256-GCM`.

## История — линейная

- Обновляйся через `git fetch origin && git rebase origin/main`, не через merge.
- Merge-коммиты в `main` запрещены: PR вливаем через **squash** или **rebase merge**.
- `git push --force-with-lease` — только в свою ветку после rebase. В `main` — никогда.

## Pull Request

- Маленькие: 1 задача = 1 PR. Большую задачу дроби в Linear.
- Заполни [шаблон PR](.github/PULL_REQUEST_TEMPLATE.md), укажи `MAIN-N`.
- Нужен **≥ 1 апрув** другого участника и **зелёный CI**.
- UI-изменения — со скриншотами Android и Windows.

## Definition of Done

Из [`CLAUDE.md`](CLAUDE.md):

- `flutter analyze` и `flutter test` зелёные, Anchor-тесты зелёные.
- Фича проверена вручную на Android **и** Windows (если затрагивает UI/платформу).
- Нет TODO без тикета, нет секретов в диффе.
- Тесты обязательны для `core/crypto`, `core/vault`, `core/solana` и Anchor-программы.

## Локальные проверки

```bash
# Приложение
cd app
flutter pub get
flutter analyze
dart format --set-exit-if-changed .
flutter test

# Программа (macOS / Linux / WSL)
cd program
anchor build && anchor test --validator legacy
```

## Зависимости

- Добавляй только через `flutter pub add <pkg>` (или `cargo add` в `program/`), версии не придумывай.
- Каждую новую зависимость упомяни в PR: зачем нужна и почему не хватает существующих.
- Без причины зависимости не добавляем.

## Безопасность

Полные правила — в [`CLAUDE.md`](CLAUDE.md#правила-безопасности-жёсткие). Коротко:

- Мастер-пароль, ключи и расшифрованные данные не попадают на диск, в логи, `print`, аналитику и краш-репорты.
- Каждое шифрование AES-GCM — новый случайный 12-байтный nonce.
- Только стойкий ГСЧ и примитивы из `cryptography`; своей криптографии нет.
- Запись vault-файла атомарная: `vault.tmp` → `fsync` → `rename`.
- Ключи, `.env`, keypair-файлы Solana — не коммитим. Нашёл секрет в коде — остановись и сообщи.
- В блокчейн — только публичный ключ, `vault_id`, версия и SHA-256 файла.

Уязвимости сообщай приватно — см. [`SECURITY.md`](SECURITY.md).

## ADR

Architecture Decision Record пишем, когда решение:

- меняет криптосхему, формат vault или контракт программы;
- выбирает библиотеку/инструмент с долгими последствиями;
- фиксирует trade-off, о котором спросят на защите.

Где: `docs/adr/NNNN-title.md` по шаблону [`docs/adr/0000-template.md`](docs/adr/0000-template.md). Список — в [`docs/adr/README.md`](docs/adr/README.md). ADR идёт отдельным PR со scope `docs` или вместе с кодом, который его реализует.

## Лицензия

Проект распространяется под [GPL-3.0-or-later](LICENSE). Отправляя вклад, ты соглашаешься, что он лицензируется на тех же условиях. CLA не требуется.

В новых файлах можно указывать заголовок:

```dart
// SPDX-License-Identifier: GPL-3.0-or-later
```

## Кодекс поведения

Участвуя в проекте, соблюдай [Code of Conduct](CODE_OF_CONDUCT.md).
