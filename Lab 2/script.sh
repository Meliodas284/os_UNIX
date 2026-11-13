#!/bin/sh

dir=/shared
lock=$dir/lock_file

id=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
count=0

exec 9>"$lock"

echo "Контейнер $id запущен"

while true; do
    count=$((count + 1))

    flock -x 9
    i=1
    name=$(printf "%03d" $i)
    while [ -e "$dir/$name" ]; do
        i=$((i + 1))
        name=$(printf "%03d" $i)
    done
    echo "$id $count" > "$dir/$name"
    flock -u 9

    echo "$id: создан $name (файл $count)"
    sleep 1

    rm -f "$dir/$name"
    echo "$id: удалён $name"
    sleep 1
done
