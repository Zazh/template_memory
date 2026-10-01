# template_memory — процессный фреймворк для проектов

Эталонный подход к ведению проекта через бэклоги с LLM-сессиями (Claude Code).
Извлечён из практики реального проекта, критически переработан
(разбор — `memory/process/RATIONALE.md`). Стек по умолчанию: Go + Vue 3 SPA; от стека
зависят только команды верификации.

## Состав

```
CLAUDE.md                  # правила для Claude в этом проекте (входная точка)
.gitignore                 # .DS_Store + memory/secrets/ (кроме README)
.claude/commands/          # slash-команды ролей: /brief /backlog /worker /critic
                           #   /accept /dir-review /cleanup — запуск сессий конвейера;
                           #   /next — диспетчер: читает STATE#now, называет ОДИН шаг
memory/                    # «память» проекта — единый каталог, копируется целиком
├── lint.sh                # гейт живых доков: потолки КБ, 🪦, даты в заголовках, якоря
├── lint-selftest.sh       #   его самотест (sh memory/lint-selftest.sh)
├── lint-manifest.txt      #   живые файлы и потолки (пример — STATE, frontend/)
├── process/               # фреймворк (гайды, шаблоны, хук)
│   ├── PROCESS.md         # чистая логика: инварианты, роли, режимы S/M/L
│   ├── BRIEF-GUIDE.md     # этап брифа: вопросы до полной ясности
│   ├── BACKLOG-GUIDE.md   # ведение бэклога: артефакты, протокол сессий
│   ├── RATIONALE.md       # критический разбор исходного подхода
│   ├── MODELS.md          # роль → модель/эффорт (сменный листок)
│   ├── CLAUDE-CODE.md     # интеграция с примитивами Claude Code (hooks, plan mode…)
│   ├── hooks/pre-commit   # гвард секретов + lint (git config core.hooksPath memory/process/hooks)
│   ├── templates/         # шаблоны: brief, 00-backlog, task, SESSION, REVIEW, STATE,
│   │                      #   screen-doc (скелет живого дока экрана), ci-go.yml, ci-web.yml
│   └── example/avatar-upload/  # заполненный сквозной пример (бриф → бэклог → Handoff)
├── STATE.md               # статус: указатель «где мы сейчас» {#now} (≤ 3 КБ) + таблицы
├── journal/               # журнал конвейера YYYY-MM.md — запись каждой сессии, append-only
├── frontend/              # живые доки фронта: README (правила, скелет, карта), design.md
├── backlog/               # активные бэклоги будущего проекта
├── archive/               # закрытые бэклоги + README (итог строкой и уроки)
├── decisions/             # журнал изменённых решений
└── secrets/               # локальные секреты — НЕ в git (инвариант 11)
```

## Быстрый старт нового проекта из шаблона (основной путь)

В ПУСТОМ корне нового проекта запустить `claude` и набрать:

```
/init-memory
```

(команда установлена на уровне пользователя, `~/.claude/commands/init-memory.md`;
путь к шаблону можно передать аргументом). Она скопирует фреймворк (без
`memory/process/example/` и этого README), сделает `git init` + включит хук (секреты и
lint) и закоммитит. Затем перезапустить сессию (подхватится CLAUDE.md) и — `/brief <слаг>
<идея>`.

Без команды — то же самое промптом: «инициализируй проект из шаблона
`~/Projects/template_memory`: скопируй CLAUDE.md, .gitignore, .claude/commands/,
memory/ без process/example/; git init; git config core.hooksPath memory/process/hooks;
chmod +x memory/process/hooks/pre-commit memory/lint.sh memory/lint-selftest.sh;
sh memory/lint.sh; первый коммит».

Сам шаблон при этом не меняется — он переиспользуется для каждого нового проекта;
улучшения процесса вносить сюда, в эталон.

## Как начать проект в этом каталоге

1. `git init` (если ещё не сделан) — доки и бэклоги живут в git наравне с кодом —
   и сразу `git config core.hooksPath memory/process/hooks` (включает гвард секретов и
   lint живых доков; `.gitignore` уже настроен: `memory/secrets/` в git не попадает).
2. Владелец описывает первый блок работ и запускает `/brief <слаг> <описание>`
   (или свободно — Claude сам начнёт интервью по CLAUDE.md).
3. Бриф-интервью (`memory/process/BRIEF-GUIDE.md`) — раунды уточняющих вопросов до
   полной ясности → резюме → подтверждение владельца.
4. `/backlog <слаг>` строит бэклог; дальше конвейер идёт командами:
   `/worker → /critic → /accept` на блок (L-блоки: + `/dir-review`, `/cleanup`),
   каждая — в свежей сессии. Первый бэклог проекта заводит CI из
   `memory/process/templates/ci-*.yml`. Не знаешь, что дальше, — `/next`.
5. Каждая роль закрывает сессию ритуалом: указатель `memory/STATE.md#now` переписан,
   запись в `memory/journal/<YYYY-MM>.md`, `sh memory/lint.sh` зелёный, коммит.

## Как перенести фреймворк в другой проект

Проще всего скопировать каталог целиком (`cp -R template_memory <новый-проект>`)
и удалить `memory/process/example/`. Поштучно: `CLAUDE.md`, `.gitignore`,
`.claude/commands/` (slash-команды), `memory/process/` (включая `hooks/`), гейт
`memory/lint.sh` + `lint-selftest.sh` + `lint-manifest.txt` и скелет `memory/` (STATE.md,
journal/, frontend/, archive/README.md, пустые backlog/decisions, secrets/README.md).
В новом репо включить хук: `git config core.hooksPath memory/process/hooks`.
`MODELS.md` при переносе сверить с актуальным поколением моделей.
