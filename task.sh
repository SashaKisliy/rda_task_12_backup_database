#!/bin/bash
set -e

# Проверка переменных окружения
[[ -z "${DB_USER:-}" || -z "${DB_PASSWORD:-}" ]] && { echo "Ошибка: установите DB_USER и DB_PASSWORD"; exit 1; }

# Параметры
MYSQL="mysql -h ${DB_HOST:-localhost} -u $DB_USER -p$DB_PASSWORD"
MYSQLDUMP="mysqldump -h ${DB_HOST:-localhost} -u $DB_USER -p$DB_PASSWORD"

echo "Резервное копирование..."

# 1. Полный дамп ShopDB -> ShopDBReserve
$MYSQLDUMP --databases ShopDB > /tmp/full.sql
$MYSQL -e "DROP DATABASE IF EXISTS ShopDBReserve;"
sed 's/ShopDB/ShopDBReserve/g' /tmp/full.sql | $MYSQL

# 2. Дамп данных ShopDB -> ShopDBDevelopment  
$MYSQLDUMP --no-create-info ShopDB > /tmp/data.sql
$MYSQL -e "USE ShopDBDevelopment; TRUNCATE TABLE Products;"
$MYSQL ShopDBDevelopment < /tmp/data.sql

# 3. Проверка
SRC=$($MYSQL -se "SELECT COUNT(*) FROM ShopDB.Products;")
RSV=$($MYSQL -se "SELECT COUNT(*) FROM ShopDBReserve.Products;")
DEV=$($MYSQL -se "SELECT COUNT(*) FROM ShopDBDevelopment.Products;")

echo "Записей: ShopDB=$SRC, Reserve=$RSV, Dev=$DEV"
[[ "$SRC" == "$RSV" && "$SRC" == "$DEV" ]] && echo "✅ Успешно!" || { echo "❌ Ошибка!"; exit 1; }

# Очистка
rm -f /tmp/full.sql /tmp/data.sql
