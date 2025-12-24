#!/bin/bash

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
echo "🔧 АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ И ЗАПУСК БОТА"
echo "=========================================="
echo ""

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

echo "📡 Подключаюсь к серверу..."
if ! run_remote "echo 'Подключение успешно'" >/dev/null 2>&1; then
    echo "❌ Не удалось подключиться к серверу"
    exit 1
fi
echo "✅ Подключение установлено"
echo ""

echo "🛑 Шаг 1: Останавливаю все процессы бота..."
run_remote "
    echo 'Ищу все процессы бота...'
    ps aux | grep -E '[p]ython.*bot|[b]ot\.py' || echo 'Процессы не найдены'
    echo ''
    echo 'Останавливаю процессы...'
    pkill -9 -f 'python.*bot.py' 2>/dev/null || true
    pkill -9 -f 'bot.py' 2>/dev/null || true
    pkill -9 -f 'venv/bin/python.*bot' 2>/dev/null || true
    sleep 3
    echo 'Проверяю что все остановлено...'
    ps aux | grep -E '[p]ython.*bot|[b]ot\.py' || echo '✅ Все процессы остановлены'
"
echo ""

echo "🗑️  Шаг 2: Удаляю lock файлы..."
run_remote "
    cd ~/telegram-bot
    rm -f bot.lock bot.pid 2>/dev/null
    [ -f bot.lock ] && rm -f bot.lock || echo 'bot.lock удален'
    [ -f bot.pid ] && rm -f bot.pid || echo 'bot.pid удален'
    echo 'Lock файлы удалены'
"
echo ""

echo "🔍 Шаг 3: Проверяю наличие файлов..."
run_remote "
    cd ~/telegram-bot
    echo 'Проверка файлов:'
    [ -f bot.py ] && echo '✅ bot.py' || echo '❌ bot.py не найден'
    [ -f config.py ] && echo '✅ config.py' || echo '❌ config.py не найден'
    [ -f .env ] && echo '✅ .env' || echo '❌ .env не найден'
    [ -d venv ] && echo '✅ venv существует' || echo '❌ venv не найден'
    [ -f venv/bin/python ] && echo '✅ venv/bin/python существует' || echo '❌ venv/bin/python не найден'
"
echo ""

echo "🚀 Шаг 4: Запускаю бота..."
run_remote "
    cd ~/telegram-bot
    # Обновляю start_bot.sh
    cat > start_bot.sh << 'SCRIPTEOF'
#!/bin/bash
cd ~/telegram-bot
pkill -f 'python.*bot.py' || true
sleep 2
rm -f bot.lock bot.pid
if [ -d venv ] && [ -f venv/bin/python ]; then
    nohup venv/bin/python bot.py > bot.log 2>&1 &
    echo \$! > bot.pid
    echo '✅ Бот запущен через venv (PID: '\$(cat bot.pid)')'
else
    nohup python3 bot.py > bot.log 2>&1 &
    echo \$! > bot.pid
    echo '✅ Бот запущен через python3 (PID: '\$(cat bot.pid)')'
fi
SCRIPTEOF
    chmod +x start_bot.sh
    ./start_bot.sh
"
echo ""

echo "⏳ Шаг 5: Жду 5 секунд для запуска..."
sleep 5
echo ""

echo "🔍 Шаг 6: Проверяю статус бота..."
run_remote "
    cd ~/telegram-bot
    echo '=== Статус процесса ==='
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid 2>/dev/null)
        if [ -n \"\$PID\" ] && ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот запущен (PID: '\$PID')'
            echo ''
            echo '=== Информация о процессе ==='
            ps aux | grep \$PID | grep -v grep
        else
            echo '❌ Бот не запущен (процесс с PID '\$PID' не найден)'
        fi
    else
        echo '⚠️  Файл bot.pid не найден'
    fi
    echo ''
    echo '=== Все процессы Python связанные с ботом ==='
    ps aux | grep -E '[p]ython.*bot|[b]ot\.py' || echo 'Процессы не найдены'
    echo ''
    echo '=== Последние 20 строк лога ==='
    tail -20 bot.log 2>/dev/null || echo 'Лог пуст или не найден'
"
echo ""

echo "=========================================="
echo "✅ ПРОЦЕСС ЗАВЕРШЕН"
echo "=========================================="

