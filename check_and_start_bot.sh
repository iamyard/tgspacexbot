#!/bin/bash

# Проверка и запуск бота с проверкой конфликтов

cd "$(dirname "$0")"

source .env 2>/dev/null || {
    echo "❌ Файл .env не найден!"
    exit 1
}

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ BOT_TOKEN не установлен в .env"
    exit 1
fi

echo "🔍 Проверяю статус бота..."

# Проверяем, есть ли конфликт
RESPONSE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=-1&limit=1" 2>&1)

if echo "$RESPONSE" | grep -q "Conflict"; then
    echo ""
    echo "⚠️  КОНФЛИКТ ОБНАРУЖЕН!"
    echo ""
    echo "Бот с этим токеном уже запущен где-то еще."
    echo "Telegram не позволяет запускать несколько экземпляров одновременно."
    echo ""
    echo "Решения:"
    echo "1. Остановите бота на сервере (если он там запущен)"
    echo "2. Создайте нового бота через @BotFather для локального теста"
    echo ""
    echo "Текущий бот:"
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | python3 -m json.tool 2>/dev/null | grep -E '"username"|"first_name"'
    echo ""
    exit 1
fi

echo "✅ Конфликтов не обнаружено"
echo ""
echo "🚀 Запускаю бота..."

source venv/bin/activate
export UVLOOP_DISABLED=1

pkill -f "python.*bot.py" 2>/dev/null
rm -f bot.lock bot.pid

python3 bot.py
