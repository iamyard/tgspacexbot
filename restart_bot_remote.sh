#!/bin/bash

# ============================================
# НАСТРОЙКИ СЕРВЕРА
# ============================================
SERVER_IP="109.69.16.218"
SERVER_USER="root"
SERVER_PASS="LcLBrkotSeoI!2"

# Инициализация Homebrew для macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

echo "🔄 Обновляю start_bot.sh и перезапускаю бота..."

run_remote "
    cd ~/telegram-bot
    cat > start_bot.sh << 'SCRIPTEOF'
#!/bin/bash
cd ~/telegram-bot
pkill -f 'python.*bot.py' || true
sleep 2
if [ -d venv ] && [ -f venv/bin/python ]; then
    nohup venv/bin/python bot.py > bot.log 2>&1 &
else
    nohup python3 bot.py > bot.log 2>&1 &
fi
echo \$! > bot.pid
echo '✅ Бот запущен (PID: '\$(cat bot.pid)')'
SCRIPTEOF
    chmod +x start_bot.sh
    ./start_bot.sh
    sleep 3
    echo ''
    echo '=== Статус бота ==='
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid)
        if ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот запущен (PID: '\$PID')'
        else
            echo '❌ Бот не запущен'
        fi
    fi
    echo ''
    echo '=== Последние строки лога ==='
    tail -10 bot.log
"








