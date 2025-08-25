#!/bin/bash
set -e

# Проверка переменных окружения
[[ -z "${DB_USER:-}" || -z "${DB_PASSWORD:-}" ]] && { echo "Ошибка: установите DB_USER и DB_PASSWORD"; exit 1; }

# Параметры
MYSQL="mysql -h ${DB_HOST:-localhost} -u $DB_USER -p$DB_PASSWORD"
MYSQLDUMP="mysqldump -h ${DB_HOST:-localhost} -u $DB_USER -p$DB_PASSWORD"

# Создание безопасных временных файлов
FULL_BACKUP=$(mktemp)
DATA_BACKUP=$(mktemp)

echo "Резервное копирование..."

# 1. Полный дамп ShopDB -> ShopDBReserve (без CREATE DATABASE)
$MYSQLDUMP --routines --triggers --events ShopDB > "$FULL_BACKUP"
$MYSQL ShopDBReserve < "$FULL_BACKUP"

# 2. Дамп данных ShopDB -> ShopDBDevelopment (только данные)
$MYSQLDUMP --no-create-info ShopDB > "$DATA_BACKUP"
$MYSQL ShopDBDevelopment < "$DATA_BACKUP"

# 3. Проверка количества записей
SRC=$($MYSQL -se "SELECT COUNT(*) FROM ShopDB.Products;")
RSV=$($MYSQL -se "SELECT COUNT(*) FROM ShopDBReserve.Products;")
DEV=$($MYSQL -se "SELECT COUNT(*) FROM ShopDBDevelopment.Products;")

echo "Записей: ShopDB=$SRC, Reserve=$RSV, Dev=$DEV"

# Проверка результата
if [[ "$SRC" == "$RSV" && "$SRC" == "$DEV" ]]; then
    echo "✅ Резервное копирование выполнено успешно!"
else
    echo "❌ Ошибка: Несоответствие количества записей!"
    rm -f "$FULL_BACKUP" "$DATA_BACKUP"
    exit 1
fi

# Очистка временных файлов
rm -f "$FULL_BACKUP" "$DATA_BACKUP"
