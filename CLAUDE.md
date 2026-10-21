# Anchorkeep — инструкции для Claude Code

Офлайн-сейф для паролей и заметок. Каждая версия бэкапа заверяется в Solana, поэтому старую или подменённую копию нельзя выдать за актуальную.

Перед работой прочитай:
- `docs/PRD.md` — что строим и что НЕ строим
- `docs/ARCHITECTURE.md` — структура, криптоформат, Solana-программа
- `docs/BACKLOG.md` — задачи по неделям
- `docs/adr/` — принятые решения (версии тулчейна — ADR 0004)

## Контекст команды
- 3 разработчика, 8 недель, университетский стартап, цель — рабочий MVP + демо.
- Роли: **Aliar** — Core (крипто, vault, безопасность), **Bekzat** — UI (Flutter-экраны), **Stas (SNOWNUMB)** — Chain (Anchor, Solana-адаптер, CI).
- Задачи ведутся в Linear: проект «Anchorkeep MVP», ID вида `MAIN-12`, в заголовке — `[AK-xx]` из BACKLOG. Ветка: `feat/MAIN-12-short-name`, коммиты — Conventional Commits. Подробно — `CONTRIBUTING.md`.
- Лицензия GPL-3.0-or-later (`docs/adr/0001-license-gpl-3.md`).
- Целевые платформы MVP: **Android + Windows**. macOS/Linux/iOS — должны собираться, но не тестируются и не входят в DoD.

## Стек
- Flutter (stable), Dart, Material 3, flutter_riverpod, go_router
- Крипто: `cryptography` + `cryptography_flutter`, `flutter_secure_storage`
- Хранение: `dart:io`, `path_provider`, `path`, `file_picker`
- Блокчейн: Solana **Devnet**, Anchor (Rust) — программа `vault_registry`; Dart-клиент — пакет `solana` (espresso-cash)
- Версии пакетов не придумывай: ставь через `flutter pub add` / `cargo add` и сверяй с pub.dev / docs.

## Правила кода
- Имена — на английском, комментарии — на русском.
- Feature-first структура (см. ARCHITECTURE.md). Бизнес-логика не живёт в виджетах.
- Минимальный scope: делай только задачу из тикета, без «заодно улучшил».
- Не добавляй зависимости без причины; новая зависимость — упомяни в PR.
- Тесты обязательны для `core/crypto`, `core/vault`, `core/solana` и Anchor-программы.

## Правила безопасности (жёсткие)
1. Мастер-пароль, ключи и расшифрованные данные **никогда** не пишутся на диск, в логи, в `print`, в аналитику, в краш-репорты.
2. Каждое шифрование AES-GCM — новый случайный 12-байтный nonce. Переиспользование nonce = критический баг.
3. Только криптографически стойкий ГСЧ (`SecretKeyData.random` / `Random.secure()`).
4. Свою криптографию не изобретаем: только примитивы из `cryptography`.
5. Запись vault-файла — атомарная: `vault.tmp` → `fsync` → `rename`.
6. Приватные ключи, `.env`, keypair-файлы Solana — в `.gitignore`. Если видишь секрет в коде — останови работу и сообщи.
7. В блокчейн уходят только: публичный ключ, `vault_id`, номер версии, SHA-256 зашифрованного файла. Ничего больше.
8. Ограничение Dart: память нельзя гарантированно обнулить. Минимизируй время жизни ключей, обнуляй `Uint8List` после использования, при блокировке сбрасывай провайдеры с ключами.

## Команды
```bash
# Flutter
cd app && flutter pub get
flutter analyze && dart format --set-exit-if-changed .
flutter test
flutter run -d windows   # или -d <android-device>

# Anchor (Linux/macOS или WSL на Windows)
cd program && yarn install && anchor build
anchor test --validator legacy   # surfpool пока не поддерживает SBPF v3, см. ADR 0004
anchor deploy --provider.cluster devnet
```

## Definition of Done
- `flutter analyze` и `flutter test` зелёные, Anchor-тесты зелёные.
- Фича проверена вручную на Android **и** Windows (если затрагивает UI/платформу).
- Нет TODO без тикета, нет секретов в диффе.
