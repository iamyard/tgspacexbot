#!/bin/bash

SERVER_IP="109.69.16.218"
SERVER_USER="root"
SERVER_PASS="LcLBrkotSeoI!2"

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "
    cd ~/telegram-bot
    echo '🛑 Останавливаю старые процессы...'
    pkill -9 -f 'python.*bot.py' 2>/dev/null || true
    sleep 2
    
    echo '🗑️  Удаляю lock файлы...'
    rm -f bot.lock bot.pid 2>/dev/null
    [ -f bot.lock ] && rm -f bot.lock || true
    [ -f bot.pid ] && rm -f bot.pid || true
    echo 'Lock файлы удалены'
    
    echo '🚀 Запускаю бота...'
    if [ -d venv ] && [ -f venv/bin/python ]; then
        nohup venv/bin/python bot.py > bot.log 2>&1 &
        echo \$! > bot.pid
    else
        nohup python3 bot.py > bot.log 2>&1 &
        echo \$! > bot.pid
    fi
    
    sleep 3
    
    echo ''
    echo '=== Результат ==='
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid)
        if ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот успешно запущен (PID: '\$PID')'
        else
            echo '❌ Бот не запустился'
            echo ''
            echo 'Последние строки лога:'
            tail -20 bot.log
        fi
    fi
"

