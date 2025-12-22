#!/bin/bash

# ============================================
# НАСТРОЙКИ СЕРВЕРА - ЗАПОЛНИТЕ ЭТИ ПЕРЕМЕННЫЕ
# ============================================
SERVER_IP="109.69.16.218"        # IP адрес вашего сервера
SERVER_USER="root"                # Имя пользователя на сервере
SERVER_PASS="LcLBrkotSeoI!2"       # Пароль для SSH
GITHUB_REPO="https://github.com/iamyard/tgspacexbot.git"  # URL вашего GitHub репозитория

# ============================================
# НЕ МЕНЯЙТЕ НИЧЕГО НИЖЕ ЭТОЙ СТРОКИ
# ============================================

set -e  # Остановка при ошибке

echo "=========================================="
echo "🚀 УСТАНОВКА БОТА НА СЕРВЕР"
echo "=========================================="

# Инициализация Homebrew для macOS (если установлен, но не в PATH)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo "📦 Устанавливаю sshpass..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v brew &> /dev/null; then
            echo "❌ Нужен Homebrew. Установите: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "   После установки выполните: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
            exit 1
        fi
        brew install hudochenkov/sshpass/sshpass
    else
        # Linux
        sudo apt-get update && sudo apt-get install -y sshpass
    fi
fi

echo "✅ sshpass установлен"

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

echo ""
echo "📡 Подключаюсь к серверу $SERVER_USER@$SERVER_IP..."

# Проверка подключения
if ! run_remote "echo 'Подключение успешно'"; then
    echo "❌ Не удалось подключиться к серверу. Проверьте IP, user и password."
    exit 1
fi

echo "✅ Подключение установлено"
echo ""

# Установка зависимостей на сервере
echo "📦 Устанавливаю зависимости на сервере..."
run_remote "
    # Обновление системы
    sudo apt-get update -qq
    
    # Установка Python, pip, git
    sudo apt-get install -y python3 python3-pip git
    
    # Создание директории для бота
    mkdir -p ~/telegram-bot
    cd ~/telegram-bot
    
    # Клонирование репозитория
    if [ -d .git ]; then
        echo '⚠️  Репозиторий уже существует, обновляю...'
        git pull
    else
        echo '📥 Клонирую репозиторий...'
        git clone $GITHUB_REPO .
    fi
    
    # Установка Python зависимостей
    echo '📦 Устанавливаю Python зависимости...'
    pip3 install --user -r requirements.txt
    
    echo '✅ Зависимости установлены'
"

echo ""
echo "🔧 Настройка бота..."

# Запрос токена бота
read -p "Введите BOT_TOKEN: " BOT_TOKEN
read -p "Введите CHANNEL_ID (например: @spacex_th): " CHANNEL_ID

# Создание .env файла на сервере
run_remote "
    cd ~/telegram-bot
    cat > .env << EOF
BOT_TOKEN=$BOT_TOKEN
CHANNEL_ID=$CHANNEL_ID
EOF
    echo '✅ Файл .env создан'
"

# Создание скрипта запуска бота
run_remote "
    cd ~/telegram-bot
    cat > start_bot.sh << 'SCRIPTEOF'
#!/bin/bash
cd ~/telegram-bot
pkill -f 'python.*bot.py' || true
sleep 2
nohup python3 bot.py > bot.log 2>&1 &
echo \$! > bot.pid
echo '✅ Бот запущен (PID: '\$(cat bot.pid)')'
SCRIPTEOF
    chmod +x start_bot.sh
    echo '✅ Скрипт запуска создан'
"

# Запуск бота
echo ""
echo "🚀 Запускаю бота..."
run_remote "cd ~/telegram-bot && ./start_bot.sh"

# Проверка запуска
sleep 3
if run_remote "cd ~/telegram-bot && test -f bot.pid && ps -p \$(cat bot.pid) > /dev/null 2>&1"; then
    echo "✅ Бот успешно запущен!"
    PID=$(run_remote "cd ~/telegram-bot && cat bot.pid")
    echo "   PID процесса: $PID"
else
    echo "⚠️  Бот может быть не запущен. Проверьте логи:"
    echo "   ssh $SERVER_USER@$SERVER_IP 'cd ~/telegram-bot && tail -20 bot.log'"
fi

echo ""
echo "=========================================="
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "=========================================="
echo ""
echo "📋 Полезные команды:"
echo "   Просмотр логов: ssh $SERVER_USER@$SERVER_IP 'cd ~/telegram-bot && tail -f bot.log'"
echo "   Остановка бота: ssh $SERVER_USER@$SERVER_IP 'cd ~/telegram-bot && pkill -f bot.py'"
echo "   Перезапуск бота: ssh $SERVER_USER@$SERVER_IP 'cd ~/telegram-bot && ./start_bot.sh'"
echo ""

