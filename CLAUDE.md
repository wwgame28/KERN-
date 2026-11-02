# CLAUDE.md (корень репозитория)

Основной проект в этом репозитории — Godot-игра **COSMIC SANDBOX** в папке `COSMIC_SANDBOX/`.
Перед любой работой над игрой прочитай `COSMIC_SANDBOX/CLAUDE.md` и документы в `COSMIC_SANDBOX/docs/`.

- Godot-проект: `COSMIC_SANDBOX/project.godot`.
- Готовый архив для Xogot: `dist/COSMIC_SANDBOX.zip` (пересобирать после изменений проекта).
- Статическая проверка проекта (без движка): `python3 tools/validate_godot_project.py COSMIC_SANDBOX`.
- Самопроверка этапа 1 в движке: сцена `res://tests/stage1_self_test.tscn` (в headless-режиме код выхода = число FAIL).
- Промпты этапов: `COSMIC_SANDBOX/docs/prompts/` (MASTER_PROMPT_RU.md, PHASE_01_PROMPT_RU.md).
- Файлы в корне (`Dockerfile`, `start.sh`, `openclaw.json`, `amvera.yml`, `.env.example`) относятся
  к отдельному деплою OpenClaw на Amvera. Не изменяй их при работе над игрой.
