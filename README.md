# OpenClaw on Amvera + Qwen

Этот репозиторий подготовлен для запуска OpenClaw Gateway в Amvera Cloud без ПК.

## Что уже настроено

- официальный Docker-образ `ghcr.io/openclaw/openclaw:latest`;
- OpenClaw Gateway на порту `18789`;
- постоянное хранилище Amvera в `/data`;
- Qwen подключён напрямую через OpenAI-compatible endpoint Alibaba DashScope;
- модель по умолчанию: `qwen3.5-plus`;
- секреты не хранятся в GitHub.

## Что добавить в Amvera

В разделе **Переменные / Секреты** создай:

- `QWEN_API_KEY` — API-ключ Qwen/Alibaba Model Studio;
- `OPENCLAW_GATEWAY_TOKEN` — длинный случайный токен для доступа к Gateway.

После добавления переменных перезапусти приложение.

## Amvera

Amvera автоматически прочитает `amvera.yml`, соберёт `Dockerfile`, подключит `/data` как постоянное хранилище и направит сервис на порт `18789`.

## Файлы

- `Dockerfile` — обёртка над официальным OpenClaw image;
- `start.sh` — создаёт начальную конфигурацию при первом запуске и запускает Gateway;
- `openclaw.json` — конфигурация Qwen;
- `amvera.yml` — конфигурация деплоя Amvera;
- `.env.example` — только названия нужных секретов.

Исходный проект KERN не уничтожен безвозвратно: его история остаётся в предыдущих Git-коммитах.

## Particle Strike (мобильная игра на Godot 4)

В папке [`particle_strike/`](particle_strike/) лежит проект мобильного 3D-шутера с разрушаемым миром из частиц: 4 локации, 6 видов оружия, волны врагов и боссы, улучшения. Готовый архив для Xogot на iPhone — [`ParticleStrike.zip`](ParticleStrike.zip). Инструкция по запуску и описание механик — в [`particle_strike/README.md`](particle_strike/README.md).
