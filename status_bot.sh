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
    echo '=== Статус процесса ==='
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid)
        if ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот запущен (PID: '\$PID')'
        else
            echo '❌ Бот не запущен (PID файл есть, но процесса нет)'
        fi
    else
        echo '⚠️  Файл bot.pid не найден'
    fi
    echo ''
    echo '=== Процессы Python ==='
    ps aux | grep -E '[p]ython.*bot' || echo 'Процессы не найдены'
    echo ''
    echo '=== Последние 15 строк лога ==='
    tail -15 bot.log 2>/dev/null || echo 'Лог пуст или не найден'
"








