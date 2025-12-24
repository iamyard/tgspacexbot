#!/bin/bash

SERVER_IP="109.69.16.218"
SERVER_USER="root"
SERVER_PASS="LcLBrkotSeoI!2"

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

run_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

echo "🔄 Финальное исправление: сброс webhook и перезапуск бота..."
echo ""

run_remote "
    cd ~/telegram-bot
    
    echo '🛑 Останавливаю все процессы...'
    pkill -9 -f 'python.*bot.py' 2>/dev/null || true
    pkill -9 -f 'bot.py' 2>/dev/null || true
    sleep 3
    
    echo '🗑️  Удаляю lock файлы...'
    rm -f bot.lock bot.pid 2>/dev/null
    
    echo '🔄 Сбрасываю webhook в Telegram...'
    source .env 2>/dev/null
    if [ -n \"\$BOT_TOKEN\" ]; then
        curl -s \"https://api.telegram.org/bot\${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true\" > /dev/null
        echo '✅ Webhook сброшен'
        echo '⏳ Жду 5 секунд перед запуском...'
        sleep 5
    else
        echo '⚠️  BOT_TOKEN не найден в .env'
    fi
    
    echo '🚀 Запускаю бота...'
    if [ -d venv ] && [ -f venv/bin/python ]; then
        nohup venv/bin/python bot.py > bot.log 2>&1 &
        echo \$! > bot.pid
        echo '✅ Бот запущен через venv (PID: '\$(cat bot.pid)')'
    else
        nohup python3 bot.py > bot.log 2>&1 &
        echo \$! > bot.pid
        echo '✅ Бот запущен через python3 (PID: '\$(cat bot.pid)')'
    fi
    
    sleep 5
    
    echo ''
    echo '=== Финальная проверка ==='
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid 2>/dev/null)
        if [ -n \"\$PID\" ] && ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот работает (PID: '\$PID')'
            echo ''
            echo 'Последние строки лога:'
            tail -10 bot.log
        else
            echo '❌ Бот не запущен'
            echo ''
            echo 'Лог ошибок:'
            tail -20 bot.log
        fi
    fi
"

echo ""
echo "✅ Готово!"

