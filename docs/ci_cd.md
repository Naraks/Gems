# CI/CD

Workflow `.github/workflows/ci.yml` использует Godot 4.7.1 и запускается для
push/PR в `main`, а также для тегов `v*`.

## Проверки

1. Скачиваются официальный Linux editor и export templates Godot.
2. Оба архива проверяются по официальному `SHA512-SUMS.txt`.
3. Проект импортируется на чистом runner.
4. Все GDScript-файлы парсятся через `--check-only`.
5. Все `tests/*_test.gd` выполняются в headless-режиме.
6. Стартовая сцена запускается на два кадра.
7. Создаётся release Web-export и ZIP artifact `gems-web`.

Локальный запуск на Linux/Git Bash:

```bash
bash tools/check_gdscript.sh godot
bash tools/run_tests.sh godot
```

## Релиз

Тег вида `v1.0.0` проходит те же проверки. Только после их успеха ZIP
публикуется в GitHub Release. Загрузка проверенного ZIP в Яндекс Игры остаётся
ручной. Секреты и `.godot/export_credentials.cfg` в artifact не включаются.
