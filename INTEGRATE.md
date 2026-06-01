# INTEGRATE.md — Интеграция существующего расширения

> Этот документ описывает как взять **уже существующее** расширение 1С
> и поставить его под управление экосистемы шаблона.
>
> Если начинаете расширение с нуля — используйте README.md.

---

## Как работает разборка .cfe

Бинарный файл `.cfe` нельзя открыть напрямую. Нужен **pipeline из 4 шагов**:

```
.cfe (бинарник)
    ↓ Шаг 1: бинарная распаковка (e8tools/v8unpack -E)
Бинарные блоки с хешами вместо имён (~21 000 файлов)
    ↓ Шаг 2: конвертация в JSON
Структурированные данные метаданных
    ↓ Шаг 3: декодирование заголовков
Читаемые имена (Document_РеализацияТоваров.json)
    ↓ Шаг 4: организация кода
Читаемые .bsl файлы + структура папок
```

**`tasks/unpack.os` автоматически выбирает метод** который реализует весь pipeline:

| Метод | Инструмент | Требует | Результат |
|-------|-----------|---------|-----------|
| `gitsync` ⭐ | oscript-library/gitsync | Платформа 1С | XML + .bsl (стандарт) |
| `saby` | saby-integration/v8unpack | Python 3.8+ | .bsl + .json |
| `binary` | e8tools/v8unpack | ничего | ⚠ бинарные блоки — НЕ код |

> **Никогда не используйте `binary` как конечный результат** — это только шаг 1.

---

## Предварительные требования

- [ ] Репозиторий создан из шаблона и клонирован
- [ ] VS Code открыт в папке проекта
- [ ] Claude Code запущен (`claude` в PowerShell из папки проекта)
- [ ] Есть `.cfe` файл и/или доступ к базе 1С с расширением

---

## Шаг 1 — Установить инструмент разборки

### Вариант A: gitsync (рекомендуется — платформа 1С уже есть)

```powershell
# Установить OneScript если нет
winget install EvilBeaver.OneScript

# Установить gitsync
opm install gitsync

# Проверить
gitsync --version
```

### Вариант Б: saby v8unpack (Python, без платформы 1С)

```powershell
# Установить Python если нет: python.org/downloads
pip install v8unpack

# Проверить
python -m v8unpack --version
```

---

## Шаг 2 — Заполнить среду разработки

Откройте `CLAUDE.md`, заполните yaml-блок `## Среда разработки`:

```yaml
platform_version_min: "8.3.XX"
base_config_name: ""
base_config_version_min: ""
base_config_vendor: ""
base_config_is_standard: false
extension_name: ""
extension_prefix: ""
```

---

## Шаг 3 — Получить исходники расширения

### Из .cfe файла

Положите `.cfe` в `tools/source/`, затем:

```powershell
# Автовыбор метода (gitsync если установлен, иначе saby)
oscript tasks/unpack.os --src tools/source/МоёРасширение.cfe --dst src/cfe/

# Явный выбор метода
oscript tasks/unpack.os --src tools/source/МоёРасширение.cfe --dst src/cfe/ --method gitsync
oscript tasks/unpack.os --src tools/source/МоёРасширение.cfe --dst src/cfe/ --method saby
```

### Из базы 1С (через Конфигуратор — всегда актуально)

```
Конфигуратор → Конфигурация → Расширения конфигурации
→ Выбрать расширение → Открыть конфигурацию расширения
→ Конфигурация → Выгрузить конфигурацию в файлы...
→ Папка: <путь_к_репозиторию>\src\cf\
```

Или через gitsync напрямую из хранилища:

```powershell
gitsync sync --ext ИМЯ_Расширения C:\Хранилище_1С\ src\cf\
```

### Если доступны оба источника

```powershell
# Проверить количество файлов в каждом результате
(Get-ChildItem src\cf\ -Recurse -File).Count

# Если из базы больше файлов — это актуальнее
```

---

## Шаг 4 — Исходная конфигурация для анализа PM

PM (Claude) должен проанализировать базовую конфигурацию,
чтобы заполнить KNOWLEDGE.md — что уже есть, что нельзя дублировать.

```powershell
# Разобрать базовую конфигурацию
oscript tasks/unpack.os --src tools/source/base.cf --dst tools/cf_src/ --method gitsync
```

Или выгрузить из Конфигуратора:
```
Конфигурация → Выгрузить конфигурацию в файлы... → tools\source\cf_src\
```

Для типовых конфигураций 1С (`base_config_is_standard: true`) PM найдёт
информацию через ИТС и публичную документацию — файлы не обязательны.

---

## Шаг 5 — Анализ через Claude Code (PM)

```powershell
claude
```

Скажите:

```
Прочитай CLAUDE.md. Я интегрирую существующее расширение.
Исходники расширения — в src/cf/.
Базовая конфигурация — в tools/cf_src/ (если есть).

Действуй как PM:
1. Проанализируй .bsl файлы в src/cf/ — что уже реализовано
2. Заполни KNOWLEDGE.md: объекты, переопределённые процедуры,
   подписки на события, публичный API
3. Уточни в CLAUDE.md: extension_prefix, platform_version_min
4. Создай TODO.md: задачи на приведение к стандартам BSL
   и дальнейшее развитие (используй чеклист декомпозиции)
```

---

## Шаг 6 — Первый коммит

```powershell
# GitHub Desktop → Changes → два коммита:

# Коммит 1: исходники
feat: import existing extension v<версия>

# Коммит 2: после анализа PM
docs: fill CLAUDE.md, KNOWLEDGE.md from analysis
```

> ⚠️ В `.gitignore` уже прописаны: `*.cfe`, `*.cf`, `tools/v8unpack.exe`
> XML-выгрузки (`src/cf/`, `tools/cf_src/`) коммитятся.

---

## Шаг 7 — Настроить env.json

```json
{
  "infobase": {
    "dev": { "connection": "File=\"C:\\bases\\ИмяБазы\"" },
    "test": { "connection": "" }
  },
  "platform": {
    "path": "C:\\Program Files\\1cv8\\8.3.XX.XXXX\\bin\\1cv8.exe"
  }
}
```

---

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| 21 000+ бинарных блоков вместо кода | Используйте `--method gitsync` или `--method saby`, не `binary` |
| gitsync не найден | `opm install gitsync` |
| saby v8unpack ошибка | `pip install v8unpack` |
| Claude Code не видит файлы | Проверить `/mcp` в Claude Code — filesystem должен быть connected |
| Много файлов, анализ медленный | Попросить Claude анализировать только `*.bsl` файлы |

---

## Ссылки

| Инструмент | URL |
|-----------|-----|
| gitsync | https://github.com/oscript-library/gitsync |
| saby v8unpack | https://github.com/saby-integration/v8unpack |
| e8tools v8unpack | https://github.com/e8tools/v8unpack/releases |
| OneScript / opm | https://oscript.io |
