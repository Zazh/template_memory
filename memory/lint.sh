#!/bin/sh
# Гейт живых доков (вызывается из process/hooks/pre-commit; руками — `sh memory/lint.sh`).
# Канон правил — process/BACKLOG-GUIDE.md «Гейт живых доков».
#   size    — файл или секция из lint-manifest.txt не больше потолка (КБ = 1024 байта);
#   tomb    — в файле манифеста нет 🪦 (история живёт в decisions/, не в живом доке);
#   heading — заголовки файлов манифеста без дат ГГГГ-ММ-ДД, «блок N» и ID задач (AV-01);
#   anchor  — ссылка `<путь>.md#<слаг>` в живом .md резолвится: файл есть, заголовок с
#             {#слаг} в нём ровно один; дубль {#слаг} в живом файле — тоже находка.
# Заголовки внутри ``` / ~~~ блоков кода заголовками не считаются.
# Запуск: sh lint.sh [--root <каталог памяти>] (по умолчанию — каталог скрипта).
# Находки — stderr `путь:строка: правило: пояснение`; exit 0 — чисто, 1 — находки,
# 2 — ошибка запуска. POSIX sh + awk, без зависимостей; LC_ALL=C — юникод сравнивается
# байтами, поэтому кириллица в шаблонах — перечислением букв, а не диапазоном.

set -u
LC_ALL=C
export LC_ALL

root=$(cd "$(dirname "$0")" && pwd)
while [ $# -gt 0 ]; do
  case $1 in
    --root)
      [ $# -ge 2 ] || { echo "lint: --root без каталога" >&2; exit 2; }
      root=$2; shift 2 ;;
    *) echo "lint: неизвестный аргумент «$1»; запуск: sh lint.sh [--root <каталог>]" >&2; exit 2 ;;
  esac
done
cd "$root" 2>/dev/null || { echo "lint: нет каталога $root" >&2; exit 2; }
[ -f lint-manifest.txt ] || { echo "lint: нет $root/lint-manifest.txt" >&2; exit 2; }

# Где ссылки не проверяются: история, секреты; свои каталоги сырья проект дописывает сюда
# (`|^<каталог>/`).
skip='^(archive|decisions|journal|secrets)/'

tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

find . -type f -name '*.md' ! -path './.git/*' | sed 's|^\./||' | sort >"$tmp/all"
awk -v re="$skip" '$0 !~ re' "$tmp/all" >"$tmp/live"

awk -v out="$tmp/out" -v live="$tmp/live" '
function find(p, n, rule, msg) { printf "%s:%d: %s: %s\n", p, n, rule, msg >out; bad++ }

# Читает файл p в T[p,i]; H[p,i] — уровень заголовка вне блоков кода (0 — не заголовок).
function load(p,    n, r, line, fence, i) {
  if (p in N) return N[p]
  n = 0
  while ((r = (getline line < p)) > 0) T[p, ++n] = line
  if (r < 0) { N[p] = -1; return -1 }
  close(p)
  N[p] = n
  fence = 0
  for (i = 1; i <= n; i++) {
    H[p, i] = 0
    line = T[p, i]
    if (line ~ /^[ ]*(```|~~~)/) { fence = !fence; continue }
    if (!fence && line ~ /^#+ / && match(line, /^#+/) && RLENGTH <= 6) H[p, i] = RLENGTH
  }
  return n
}

# Слаг первого {#...} в строке или "".
function slugof(line) {
  if (match(line, /\{#[a-z0-9-]+\}/)) return substr(line, RSTART + 2, RLENGTH - 3)
  return ""
}

# Сколько заголовков с {#s} в файле p.
function count(p, s,    n, i, c) {
  if ((p, s) in C) return C[p, s]
  n = load(p); c = 0
  for (i = 1; i <= n; i++) if (H[p, i] && index(T[p, i], "{#" s "}")) c++
  C[p, s] = c
  return c
}

function bytes(p, a, b,    i, s) { s = 0; for (i = a; i <= b; i++) s += length(T[p, i]) + 1; return s }

BEGIN {
  L = "([A-Z]|А|Б|В|Г|Д|Е|Ж|З|И|Й|К|Л|М|Н|О|П|Р|С|Т|У|Ф|Х|Ц|Ч|Ш|Щ|Ъ|Ы|Ь|Э|Ю|Я)"
  ID = L L L "?-[0-9][0-9][0-9]?"
  DATE = "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]"
  BLOCK = "(б|Б)лок [0-9]"
  LINK = "[A-Za-z0-9_./-]+\\.md#[a-z0-9-]+"

  # --- манифест: size; файлы манифеста — tomb и heading
  ml = 0
  while ((getline m < "lint-manifest.txt") > 0) {
    ml++
    if (m ~ /^[ \t]*(#|$)/) continue
    k = split(m, f, /[ \t]+/)
    if (f[1] == "") { f[1] = f[2]; f[2] = f[3]; k-- }
    if (k != 2 || f[2] !~ /^[0-9]+$/) { find("lint-manifest.txt", ml, "size", "строка не по формату «<путь>[#<якорь>] <потолок_КБ>»"); continue }
    p = f[1]; a = ""; lim = f[2] * 1024
    if ((j = index(p, "#")) > 0) { a = substr(p, j + 1); p = substr(p, 1, j - 1) }
    n = load(p)
    if (n < 0) { find("lint-manifest.txt", ml, "size", "нет файла " p); continue }
    files[p] = 1
    if (a == "") {
      b = bytes(p, 1, n)
      if (b > lim) find(p, 1, "size", b " Б больше потолка " f[2] " КБ (" lim " Б)")
      continue
    }
    s = 0
    for (i = 1; i <= n; i++) if (H[p, i] && index(T[p, i], "{#" a "}")) { s = i; break }
    if (!s) { find("lint-manifest.txt", ml, "size", "нет секции {#" a "} в " p); continue }
    e = n
    for (i = s + 1; i <= n; i++) if (H[p, i] && H[p, i] <= H[p, s]) { e = i - 1; break }
    b = bytes(p, s, e)
    if (b > lim) find(p, s, "size", "секция {#" a "} " b " Б больше потолка " f[2] " КБ (" lim " Б)")
  }
  close("lint-manifest.txt")

  for (p in files) {
    n = N[p]
    for (i = 1; i <= n; i++) {
      if (index(T[p, i], "🪦")) find(p, i, "tomb", "🪦 в живом доке — история уходит в decisions/")
      if (!H[p, i]) continue
      if (T[p, i] ~ DATE) find(p, i, "heading", "дата в заголовке")
      if (T[p, i] ~ BLOCK) find(p, i, "heading", "номер блока в заголовке")
      if (T[p, i] ~ ID) find(p, i, "heading", "ID задачи в заголовке")
    }
  }

  # --- живые .md: дубли якорей и ссылки на якоря
  while ((getline src < live) > 0) {
    n = load(src)
    if (n < 0) continue
    delete seen
    for (i = 1; i <= n; i++) {
      if (H[src, i] && (s = slugof(T[src, i])) != "") {
        if (s in seen) find(src, i, "anchor", "дубль якоря {#" s "} (первый — строка " seen[s] ")")
        else seen[s] = i
      }
      rest = T[src, i]
      while (match(rest, LINK)) {
        lk = substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
        j = index(lk, ".md#")
        p = substr(lk, 1, j + 2); s = substr(lk, j + 4)
        t = p
        if (load(t) < 0) {
          d = src; if (!sub(/\/[^\/]*$/, "", d)) d = "."
          t = d "/" p
          if (load(t) < 0) { find(src, i, "anchor", "нет файла " p " (ссылка " lk ")"); continue }
        }
        c = count(t, s)
        if (c == 0) find(src, i, "anchor", "нет якоря {#" s "} в " p)
        else if (c > 1) find(src, i, "anchor", "якорь {#" s "} не уникален в " p " (" c ")")
      }
    }
  }
  close(live)
  exit 0
}
'

if [ -s "$tmp/out" ]; then
  sort -t: -k1,1 -k2,2n "$tmp/out" >&2
  echo "lint: $(wc -l <"$tmp/out" | tr -d ' ') находок" >&2
  exit 1
fi
echo "lint: чисто"
exit 0
