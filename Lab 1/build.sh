#!/bin/sh

tmpdir=

cleanup() {
    if [ -n "$tmpdir" ]; then
        rm -rf -- "$tmpdir"
    fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 131' QUIT
trap 'exit 143' TERM

die() {
    echo "build.sh: $2" >&2
    exit "$1"
}

[ $# -eq 1 ] || die 1 "использование: $0 исходный_файл"

src=$1
[ -f "$src" ] && [ -r "$src" ] || die 2 "файл '$src' не существует или недоступен для чтения"

srcdir=$(cd -- "$(dirname -- "$src")" && pwd) || die 2 "нет доступа к каталогу файла '$src'"
srcname=$(basename -- "$src")

case $srcname in
    *.c)                 comment='//'; tool=cc ;;
    *.cpp|*.cc|*.cxx)    comment='//'; tool=c++ ;;
    *.tex)               comment='%';  tool=pdflatex ;;
    *)                   die 3 "неподдерживаемый тип файла '$srcname' (нужен .c, .cpp, .cc, .cxx или .tex)" ;;
esac

out=$(sed -n "s|^.*$comment[[:space:]]*Output:[[:space:]]*\([^[:space:]]\{1,\}\).*\$|\1|p" "$src" | head -n 1)

[ -n "$out" ] || die 4 "в файле '$srcname' не найден комментарий '$comment Output: имя'"
case $out in
    */*|.|..) die 4 "некорректное имя конечного файла '$out'" ;;
esac

command -v "$tool" >/dev/null 2>&1 || die 5 "не найден компилятор '$tool'"

tmpdir=$(mktemp -d) || die 6 "не удалось создать временный каталог"

cp -- "$src" "$tmpdir/$srcname" || die 6 "не удалось скопировать исходный файл во временный каталог"
cd -- "$tmpdir" || die 6 "не удалось перейти во временный каталог"

case $tool in
    cc|c++)
        "$tool" -o "$out" "$srcname" >build.log 2>&1
        status=$?
        result=$out
        ;;
    pdflatex)
        pdflatex -interaction=nonstopmode -halt-on-error "$srcname" >build.log 2>&1
        status=$?
        result=${srcname%.tex}.pdf
        ;;
esac

if [ "$status" -ne 0 ]; then
    cat build.log >&2
    die 7 "ошибка компиляции '$srcname' (код $status)"
fi

[ -f "$result" ] || die 8 "конечный файл не был создан"
cp -- "$result" "$srcdir/$out" || die 8 "не удалось скопировать '$out' в '$srcdir'"

echo "Готово: $srcdir/$out"
exit 0
