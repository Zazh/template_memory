#!/bin/sh
# Самотест lint.sh: мини-docs во временном каталоге, по одному нарушению на правило.
# Запуск: sh lint-selftest.sh → «selftest: ok …» (exit 0) или первое расхождение (exit 1).
# POSIX sh, без зависимостей.

set -u
here=$(cd "$(dirname "$0")" && pwd)
lint="$here/lint.sh"
work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT HUP INT TERM
checks=0

# Чистая фикстура: файл и секция под манифестом, живая ссылка на оба якоря.
fixture() {
  fx="$work/fx"
  rm -rf "$fx"
  mkdir -p "$fx/sub"
  cat >"$fx/lint-manifest.txt" <<'EOF'
# фикстура самотеста
a.md 1
b.md#sec 1
EOF
  cat >"$fx/a.md" <<'EOF'
# Файл А {#top}

Короткий живой док.

```sh
# 2026-09-30 комментарий в коде — не заголовок
```
EOF
  cat >"$fx/b.md" <<'EOF'
# Файл Б

## Секция {#sec}

Текст секции.

## Соседняя {#next}

Текст соседней секции.
EOF
  cat >"$fx/sub/c.md" <<'EOF'
# Ссылки

Смотри `a.md#top`, `b.md#sec` и соседа `sub/d.md#here`, а также `d.md#here`.
EOF
  cat >"$fx/sub/d.md" <<'EOF'
# Сосед {#here}
EOF
}

# pad <файл> <КБ>: дописать строк примерно на КБ.
pad() {
  i=0
  while [ "$i" -lt $(($2 * 16)) ]; do
    echo "строка-заполнитель строка-заполнитель" >>"$1"
    i=$((i + 1))
  done
}

# expect <имя> <код> [<правило>]
expect() {
  checks=$((checks + 1))
  sh "$lint" --root "$fx" >"$work/stdout" 2>"$work/stderr"
  code=$?
  if [ "$code" -ne "$2" ]; then
    echo "selftest: FAIL «$1»: exit $code, ждали $2" >&2
    sed 's/^/  /' "$work/stderr" >&2
    exit 1
  fi
  if [ $# -ge 3 ] && ! grep -q ": $3: " "$work/stderr"; then
    echo "selftest: FAIL «$1»: в stderr нет правила $3" >&2
    sed 's/^/  /' "$work/stderr" >&2
    exit 1
  fi
}

# (а) чистая фикстура
fixture
expect "чистая фикстура" 0

# (б) по одному нарушению на правило
fixture; pad "$fx/a.md" 2
expect "size: файл больше потолка" 1 size

fixture
awk '{print} /^## Секция/{print ""; for (i = 0; i < 40; i++) print "строка-заполнитель строка-заполнитель строка-заполнитель"}' "$fx/b.md" >"$fx/b.tmp" && mv "$fx/b.tmp" "$fx/b.md"
expect "size: секция больше потолка" 1 size

fixture; echo "Надгробие 🪦 в живом доке." >>"$fx/a.md"
expect "tomb" 1 tomb

fixture; printf '\n## Итоги 2026-09-30\n' >>"$fx/a.md"
expect "heading: дата" 1 heading

fixture; printf '\n## Итоги блок 3\n' >>"$fx/a.md"
expect "heading: блок" 1 heading

fixture; printf '\n## Задача AV-01\n' >>"$fx/a.md"
expect "heading: ID задачи" 1 heading

fixture; echo "Битая: \`nofile.md#top\`." >>"$fx/sub/c.md"
expect "anchor: нет файла" 1 anchor

fixture; echo "Битая: \`a.md#nope\`." >>"$fx/sub/c.md"
expect "anchor: нет якоря" 1 anchor

fixture; printf '\n## Ещё раз {#top}\n' >>"$fx/a.md"
expect "anchor: дубль якоря" 1 anchor

# (в) каталог-исключение не проверяется
fixture; mkdir -p "$fx/archive"
echo "Старая ссылка \`a.md#gone\` и \`nofile.md#x\`." >"$fx/archive/old.md"
expect "archive/ не проверяется" 0

echo "selftest: ok ($checks проверок)"
