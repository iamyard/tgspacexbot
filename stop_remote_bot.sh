#!/bin/bash

# Скрипт для остановки бота на удаленном сервере

set -e

# Настройки сервера из deploy.sh
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

echo "=========================================="
echo "🛑 ОСТАНОВКА БОТА НА СЕРВЕРЕ"
echo "=========================================="

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен. Установите: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

echo ""
echo "📡 Подключаюсь к серверу $SERVER_USER@$SERVER_IP..."

# Остановка бота
if run_remote "
    cd ~/telegram-bot
    echo '🛑 Останавливаю бота...'
    pkill -f 'python.*bot.py' 2>/dev/null || echo '⚠️  Процесс бота не найден'
    sleep 2
    rm -f bot.lock bot.pid 2>/dev/null || true
    echo '✅ Бот остановлен'
    echo ''
    echo 'Проверка процессов:'
    ps aux | grep '[p]ython.*bot.py' || echo '✅ Процессы бота не найдены'
"; then
    echo ""
    echo "✅ Бот успешно остановлен на сервере"
    echo ""
    echo "Теперь вы можете запустить бота локально:"
    echo "  ./start_bot.sh"
else
    echo "❌ Ошибка при остановке бота на сервере"
    exit 1
fi
