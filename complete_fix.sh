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
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1" 2>&1
}

echo "=========================================="
echo "🔧 ПОЛНОЕ ИСПРАВЛЕНИЕ И ЗАПУСК БОТА"
echo "=========================================="
echo ""

echo "1️⃣ Останавливаю все процессы бота..."
run_remote "
    cd ~/telegram-bot
    pkill -9 -f 'python.*bot.py' 2>/dev/null || true
    pkill -9 -f 'bot.py' 2>/dev/null || true
    sleep 3
    ps aux | grep -E '[p]ython.*bot' || echo '✅ Все процессы остановлены'
"
echo ""

echo "2️⃣ Удаляю lock файлы..."
run_remote "
    cd ~/telegram-bot
    rm -f bot.lock bot.pid
    ls -la bot.lock bot.pid 2>&1 || echo '✅ Lock файлы удалены'
"
echo ""

echo "3️⃣ Сбрасываю webhook..."
run_remote "
    cd ~/telegram-bot
    source .env 2>/dev/null
    if [ -n \"\$BOT_TOKEN\" ]; then
        curl -s \"https://api.telegram.org/bot\${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true\"
        echo ''
        echo '✅ Webhook сброшен'
    fi
    sleep 5
"
echo ""

echo "4️⃣ Запускаю бота..."
run_remote "
    cd ~/telegram-bot
    if [ -d venv ] && [ -f venv/bin/python ]; then
        nohup venv/bin/python bot.py > bot.log 2>&1 &
        PID=\$!
        echo \$PID > bot.pid
        echo '✅ Бот запущен (PID: '\$PID')'
        sleep 5
        if ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Процесс работает'
        else
            echo '❌ Процесс не работает'
            echo 'Лог:'
            tail -20 bot.log
        fi
    else
        echo '❌ venv не найден'
    fi
"
echo ""

echo "5️⃣ Финальная проверка..."
run_remote "
    cd ~/telegram-bot
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid)
        echo 'PID из файла: '\$PID
        if ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот работает!'
            echo ''
            echo 'Последние строки лога:'
            tail -10 bot.log
        else
            echo '❌ Бот не работает'
            echo ''
            echo 'Полный лог:'
            tail -30 bot.log
        fi
    else
        echo '❌ bot.pid не найден'
    fi
"

echo ""
echo "=========================================="
echo "✅ ЗАВЕРШЕНО"
echo "=========================================="




