<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/branding/anchorkeep-mark-paper.svg">
  <img src="docs/branding/anchorkeep-mark-ink.svg" width="64" height="64" alt="Логотип Anchorkeep">
</picture>

# Anchorkeep

**Офлайн-сейф для паролей и заметок с заверением бэкапов в Solana**

![Flutter 3.47.7](https://img.shields.io/badge/Flutter-3.47.7-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Anchor 1.2.1](https://img.shields.io/badge/Anchor-1.2.1-000000?style=for-the-badge&logo=rust&logoColor=white)
![Solana 4.1.2](https://img.shields.io/badge/Solana-4.1.2_devnet-9945FF?style=for-the-badge&logo=solana&logoColor=white)
![License GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-A42E2B?style=for-the-badge&logo=gnu&logoColor=white)

</div>

---

## Содержание

- [О проекте](#о-проекте)
- [Возможности](#возможности)
- [Как работает проверка бэкапа](#как-работает-проверка-бэкапа)
- [Структура репозитория](#структура-репозитория)
- [Быстрый старт](#быстрый-старт)
- [Команда](#команда)
- [Документация](#документация)
- [Лицензия](#лицензия)

---

## О проекте

Облачные менеджеры паролей требуют доверять чужому серверу. У локальных другая
проблема: бэкап можно подменить или откатить на старую версию, и пользователь
этого не заметит. AES-GCM защищает от порчи данных, но не от отката к старому
валидному файлу.

Anchorkeep хранит сейф локально, без регистрации и сервера. При каждом бэкапе
SHA-256 зашифрованного файла и номер версии записываются в Solana Devnet. При
восстановлении приложение сверяет файл с on-chain записью. Секреты в блокчейн
не попадают.

Платформы MVP: **Android 8+ (API 26)** и **Windows 10+**.

---

## Возможности

<div align="center">

| **Возможность** | **Для чего нужна** |
|:---|:---|
| Сейф и мастер-пароль | Argon2id + AES-256-GCM, пароль нигде не хранится и не восстанавливается |
| Пароли и заметки | CRUD записей, генератор паролей, копирование с очисткой буфера через 30 с |
| Поиск | По названию и URL среди паролей и заметок |
| Бэкап и восстановление | Экспорт и импорт зашифрованного файла `.akbackup` |
| Заверение версии | Хеш и номер версии бэкапа записываются в программу `vault_registry` |
| Проверка бэкапа | Статус Verified / Outdated / Unknown при импорте и по кнопке |
| Автоблокировка | По таймауту (5 мин по умолчанию) и при сворачивании приложения |

</div>

---

## Как работает проверка бэкапа

1. **Сохранить бэкап.** Приложение шифрует сейф и записывает `.akbackup` с номером ревизии.
2. **Заверить версию.** SHA-256 файла и номер версии уходят в PDA `["vault", owner, vault_id]`.
3. **Перенести файл.** Бэкап копируется на другое устройство любым способом.
4. **Проверить при импорте.** Хеш файла сравнивается с on-chain записью.

<div align="center">

| **Статус** | **Что значит** |
|:---|:---|
| ✅ Verified | Хеш совпадает — это последняя заверенная версия |
| ⚠️ Outdated | Ревизия файла старше on-chain версии — подсунули старый бэкап |
| ❌ Unknown | Файл не заверялся или изменён |
| ℹ️ Offline | Нет сети или записи в блокчейне |

</div>

---

## Структура репозитория

<div align="center">

| **Папка** | **Что внутри** |
|:---|:---|
| [`app/`](app) | Flutter-приложение: Riverpod, go_router, Material 3 |
| [`program/`](program) | Anchor workspace, программа `vault_registry` |
| [`docs/`](docs) | PRD, архитектура, бэклог, ADR, брендинг |
| [`.github/`](.github) | CI, шаблоны PR и issue |

</div>

---

## Быстрый старт

Нужны Flutter 3.47 stable, Rust 1.89, Solana CLI 4.1.2, Anchor 1.2.1 через `avm`,
Node 24 и yarn. Версии зафиксированы в [ADR 0004](docs/adr/0004-toolchain-versions.md).

```bash
cd app && flutter pub get && flutter run -d windows
```

```bash
cd program && yarn install && anchor build && anchor test --validator legacy
```

Подробнее — в [app/README.md](app/README.md) и [program/README.md](program/README.md).

---

## Команда

<div align="center">

| **Участник** | **Зона** |
|:---|:---|
| Aliar | Core — криптография, формат vault, безопасность |
| Bekzat | UI — Flutter-экраны, дизайн, адаптивность |
| Stas | Chain — Anchor-программа, Solana-адаптер, CI |

</div>

Задачи ведутся в Linear, проект «Anchorkeep MVP». Ветки, коммиты и PR описаны
в [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Документация

- [Описание продукта](docs/PRD.md) — проблема, scope MVP и метрики демо;
- [Архитектура](docs/ARCHITECTURE.md) — криптосхема, формат файла, Solana-программа;
- [Бэклог](docs/BACKLOG.md) — задачи по неделям и критический путь;
- [Технические решения](docs/adr/README.md) — обоснование принятых решений;
- [Разработка](CONTRIBUTING.md) — ветки, коммиты, PR и Definition of Done;
- [Безопасность](SECURITY.md) — как сообщить об уязвимости.

---

## Лицензия

[GPL-3.0-or-later](LICENSE). Код можно использовать, изменять и распространять,
а производные работы тоже должны оставаться открытыми под GPL. Почему выбрана
эта лицензия — в [ADR 0001](docs/adr/0001-license-gpl-3.md).
