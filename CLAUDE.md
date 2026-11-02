# CLAUDE.md (корень репозитория)

Основной проект в этом репозитории — Godot-игра **COSMIC SANDBOX** в папке `COSMIC_SANDBOX/`.
Перед любой работой над игрой прочитай `COSMIC_SANDBOX/CLAUDE.md` и документы в `COSMIC_SANDBOX/docs/`.

- Godot-проект: `COSMIC_SANDBOX/project.godot`.
- Готовый архив для Xogot: `dist/COSMIC_SANDBOX.zip` (пересобирать после изменений проекта).
- Статическая проверка проекта (без движка): `python3 tools/validate_godot_project.py COSMIC_SANDBOX`.
- Файлы в корне (`Dockerfile`, `start.sh`, `openclaw.json`, `amvera.yml`, `.env.example`) относятся
  к отдельному деплою OpenClaw на Amvera. Не изменяй их при работе над игрой.
