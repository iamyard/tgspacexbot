#!/bin/bash

echo "🔍 Ищу все процессы бота..."

# Находим все процессы
PROCESSES=$(ps aux | grep -E "[p]ython.*bot|[b]ot\.py" | awk '{print $2}')

if [ -z "$PROCESSES" ]; then
    echo "✅ Процессы бота не найдены"
else
    echo "📋 Найдены процессы:"
    ps aux | grep -E "[p]ython.*bot|[b]ot\.py" | grep -v grep
    echo ""
    echo "🛑 Останавливаю процессы..."
    echo "$PROCESSES" | xargs kill -9 2>/dev/null
    sleep 2
    echo "✅ Процессы остановлены"
fi

# Удаляем lock файл
if [ -f "bot.lock" ]; then
    echo "🗑️  Удаляю lock файл..."
    rm -f bot.lock
    echo "✅ Lock файл удален"
fi

# Сбрасываем webhook
echo "🔄 Сбрасываю webhook..."
source .env 2>/dev/null || true
if [ -n "$BOT_TOKEN" ]; then
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true" > /dev/null
    echo "✅ Webhook сброшен"
fi

echo ""
echo "✅ Готово! Теперь можно запустить бота: python3 bot.py"

