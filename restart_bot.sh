#!/bin/bash

echo "🛑 Останавливаю все процессы бота..."
pkill -9 -f "python.*bot" 2>/dev/null
pkill -9 -f "bot.py" 2>/dev/null
sleep 3

echo "✅ Проверяю, что все остановлено..."
PROCESSES=$(ps aux | grep -E "[p]ython.*bot" | wc -l | tr -d ' ')
if [ "$PROCESSES" -gt 0 ]; then
    echo "⚠️  Все еще есть процессы:"
    ps aux | grep -E "[p]ython.*bot"
    echo "Попробуйте убить их вручную"
    exit 1
fi

echo "🚀 Запускаю бота..."
cd "$(dirname "$0")"
python3 bot.py > bot.log 2>&1 &

BOT_PID=$!
sleep 3

if ps -p $BOT_PID > /dev/null 2>&1; then
    echo "✅ Бот запущен (PID: $BOT_PID)"
    echo "📋 Логи: tail -f bot.log"
    echo "🛑 Остановить: kill $BOT_PID"
else
    echo "❌ Бот не запустился. Проверьте логи:"
    tail -20 bot.log
fi

