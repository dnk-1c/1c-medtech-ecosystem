# 1C Extension Ecosystem Template

Шаблон экосистемы разработки расширений 1С:Предприятие 8.3.

VS Code + Claude Code как парный программист + GitHub/GitLab CI.

## Архитектура

```
1c-extension-ecosystem/     ← репозиторий шаблона (этот)
├── CLAUDE.md, GOALS.md...  ← артефакты PM и экосистемы
├── tools/                  ← портативные инструменты
├── scripts/                ← AI review для CI
├── .github/ / .gitlab-ci.yml
│
└── src/                    ← проект 1C: Platform Tools
    ├── packagedef           ← активирует расширение VS Code
    ├── env.json             ← подключение к ИБ
    ├── cfe/                 ← исходники расширения
    ├── epf/ erf/            ← обработки и отчёты
    ├── tasks/               ← OScript задачи
    ├── features/            ← Vanessa BDD
    └── build/               ← ИБ и результаты сборки
```

## Структура src/

`src/` содержит проект 1C: Platform Tools. Папка уже присутствует в шаблоне.
При необходимости разместить исходники вне экосистемы используйте junction:

```powershell
# Удалить встроенную src/ и создать junction на внешнюю папку
Remove-Item -Recurse -Force src
New-Item -ItemType Junction -Name src -Target <project-src-dir>
```

### Папки которые могут быть репозиториями

Если папка является отдельным репозиторием — добавьте её в `.gitignore` экосистемы.
PM сделает это автоматически после того как вы сообщите о готовности исходников.

| Папка | Назначение |
|-------|-----------|
| `src/` | Проект 1С целиком |
| `src/cfe/` | Исходники расширения |
| `src/epf/` | Внешние обработки |
| `src/erf/` | Внешние отчёты |
| `tools/cf_src/` | Исходники типовой конфигурации |

### Junction — когда использовать

Рекомендуется когда:
- Полный путь к папке с исходниками превышает ~30 символов
  (ограничение Конфигуратора 1С при выгрузке исходников)
- Нужно разместить исходники вне папки экосистемы

```powershell
# Создать junction (не требует прав администратора)
New-Item -ItemType Junction -Name <имя-папки> -Target <короткий-путь>
```

Junction можно применять к любой папке: `src/`, `src/cfe/`, `tools/cf_src/` и др.

## Стек

| Слой | Инструменты |
|------|-------------|
| IDE | VS Code + [1C: Platform Extension Pack](https://marketplace.visualstudio.com/items?itemName=yellow-hammer.1c-platform-extension-pack) |
| AI агент | Claude Code + [cc-1c-skills](https://github.com/Nikolay-Shirokov/cc-1c-skills) + [claude-code-skills-1c](https://github.com/Desko77/claude-code-skills-1c) |
| PM | Claude (CLAUDE.md / GOALS.md / TODO.md / ADR.md) |
| CI/CD | GitHub Actions / GitLab CI |

## Быстрый старт

### Способ A — из GitHub (если есть доступ к репозиторию шаблона)

```
GitHub → "Use this template" → Create new repository → клонировать
```

### Способ Б — из ZIP-архива (если нет доступа к репозиторию)

1. Скачать ZIP из [1c-extension-ecosystem-dist](https://github.com/d-n-komarov/1c-extension-ecosystem-dist) или получить у владельца
2. Распаковать в папку проекта
3. Создать репозиторий на GitHub/GitLab:
   - GitHub: [github.com/new](https://github.com/new) → имя → Private → **без README** → Create
   - GitLab: New project → Create blank project → **без README** → Create
   - Скопировать URL репозитория
4. Инициализировать git:
   ```powershell
   cd <папка-проекта>
   git init
   git branch -m production
   git add .
   git commit -m "feat: init from 1c-extension-ecosystem template"
   ```
   Если используете git-хостинг (GitHub, GitLab и др.) — опционально:
   ```powershell
   git remote add origin <url-репозитория>
   git push -u origin production
   ```

### Способ В — клонирование и очистка истории

```powershell
git clone <url-шаблона> <имя-проекта>
cd <имя-проекта>
git remote remove origin
```

Если используете git-хостинг — опционально создать репозиторий и подключить:

```powershell
git branch -m production
git remote add origin <url-нового-репозитория>
git push -u origin production
```

---

### Общие шаги после любого способа старта

1. Открыть проект в Claude (CLI или VS Code):
   ```powershell
   cd <папка-проекта>
   claude
   ```
   Первое сообщение PM:
   ```
   Прочитай CLAUDE.md и начни инициализацию проекта.
   ```
   PM сам определит структуру, настроит пути и проведёт через все шаги.

2. Заполнить `GOALS.md` (заказчик) → после анализа исходников Claude создаёт `TODO.md`

## Настройка токенов (Authorization tokens)

Для полноценной работы экосистемы нужны три токена.

### 1. GitHub Personal Access Token — для git push (если используете GitHub)

> Нужен только при работе с GitHub. При локальной работе без хостинга — не нужен.

При первом `git push` GitHub запросит авторизацию автоматически через браузер (GitHub Desktop) или терминал.

Если нужен токен вручную:
- GitHub → Settings → Developer settings → Personal access tokens → **Tokens (classic)**
- Scopes: `repo` + `workflow`
- Скопировать и сохранить — показывается один раз

### 2. ANTHROPIC_API_KEY — для AI review в CI/CD

Нужен для автоматической проверки кода в Pull Request через Claude API.

- [console.anthropic.com](https://console.anthropic.com) → API Keys → **Create Key**
- Скопировать ключ
- Репозиторий → Settings → Secrets and variables → Actions → **New repository secret**
  - Name: `ANTHROPIC_API_KEY`
  - Value: ключ

> Без `ANTHROPIC_API_KEY` шаг AI review в CI будет падать. Можно отключить в `.github/workflows/ci.yml` — удалить job `ai-review`.



См. [INTEGRATE.md](./INTEGRATE.md)

## Ссылки

| Ресурс | URL |
|--------|-----|
| 1C: Platform Extension Pack | https://marketplace.visualstudio.com/items?itemName=yellow-hammer.1c-platform-extension-pack |
| 1C: Platform Tools | https://marketplace.visualstudio.com/items?itemName=yellow-hammer.1c-platform-tools |
| vanessa-bootstrap | https://github.com/yellow-hammer/vanessa-bootstrap |
| cc-1c-skills | https://github.com/Nikolay-Shirokov/cc-1c-skills |
| claude-code-skills-1c | https://github.com/Desko77/claude-code-skills-1c |

## Лицензия

MIT
