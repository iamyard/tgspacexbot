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

# Инициализация Homebrew для macOS (если установлен, но не в PATH)
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

echo "=========================================="
echo "🔧 ИСПРАВЛЕНИЕ КОДА НА СЕРВЕРЕ"
echo "=========================================="
echo ""

# Определяем текущую ветку
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

echo "📡 Подключаюсь к серверу $SERVER_USER@$SERVER_IP..."
echo ""

# Проверка подключения
if ! run_remote "echo 'Подключение успешно'" >/dev/null 2>&1; then
    echo "❌ Не удалось подключиться к серверу"
    exit 1
fi

echo "✅ Подключение установлено"
echo ""

# Сохраняем временные файлы и принудительно обновляем репозиторий
echo "🔄 Принудительное обновление кода на сервере..."

# Сохраняем .env отдельно
ENV_BACKUP=$(run_remote "cd ~/telegram-bot 2>/dev/null && [ -f .env ] && cat .env || echo ''")

# Останавливаем бота
run_remote "
    pkill -9 -f 'python.*bot.py' 2>/dev/null || true
    sleep 2
"

# Обновляем существующий репозиторий или создаем новый
echo "Обновляю репозиторий..."
run_remote "
    cd ~
    if [ -d telegram-bot/.git ]; then
        echo 'Обновляю существующий репозиторий...'
        cd telegram-bot
        # Удаляем конфликтующие файлы
        rm -f bot.log bot.lock bot.pid 2>/dev/null || true
        # Очищаем рабочую директорию
        git clean -fdx
        # Получаем последние изменения
        git fetch origin
        # Принудительно сбрасываем на нужную ветку
        git reset --hard origin/$CURRENT_BRANCH 2>&1 || git reset --hard origin/main 2>&1 || true
        # Проверяем что мы на правильной ветке
        git checkout $CURRENT_BRANCH 2>&1 || git checkout main 2>&1 || true
    else
        echo 'Создаю новый репозиторий...'
        rm -rf telegram-bot
        git clone $GITHUB_REPO telegram-bot
        cd telegram-bot
        git checkout $CURRENT_BRANCH 2>&1 || git checkout main 2>&1 || true
    fi
    echo ''
    echo '=== Файлы после обновления ==='
    ls -la
    echo ''
    echo '=== Проверка основных файлов ==='
    [ -f bot.py ] && echo '✅ bot.py' || echo '❌ bot.py НЕ найден'
    [ -f config.py ] && echo '✅ config.py' || echo '❌ config.py НЕ найден'
    [ -f requirements.txt ] && echo '✅ requirements.txt' || echo '❌ requirements.txt НЕ найден'
    [ -f image_generator.py ] && echo '✅ image_generator.py' || echo '❌ image_generator.py НЕ найден'
"

# Восстанавливаем .env
if [ -n "$ENV_BACKUP" ]; then
    echo "Восстанавливаю .env файл..."
    run_remote "
        cd ~/telegram-bot
        cat > .env << 'ENVEOF'
$ENV_BACKUP
ENVEOF
        echo '✅ .env восстановлен'
    "
fi

echo ""
echo "📦 Установка зависимостей Python..."
run_remote "
    cd ~/telegram-bot
    if [ -f requirements.txt ]; then
        # Устанавливаем python3-venv если нужно
        echo 'Проверяю наличие python3-venv...'
        if ! dpkg -l | grep -q python3-venv; then
            echo 'Устанавливаю python3-venv...'
            sudo apt-get update -qq
            sudo apt-get install -y python3-venv python3-full 2>&1
        fi
        # Удаляем старое venv если есть
        [ -d venv ] && rm -rf venv
        # Создаем виртуальное окружение
        echo 'Создаю виртуальное окружение...'
        python3 -m venv venv 2>&1
        # Проверяем что venv создался
        if [ -f venv/bin/python ]; then
            echo 'Устанавливаю зависимости в venv...'
            venv/bin/pip install --upgrade pip 2>&1
            venv/bin/pip install -r requirements.txt 2>&1
            echo '✅ Зависимости установлены в venv'
        else
            echo '⚠️  Не удалось создать venv, устанавливаю с --break-system-packages...'
            pip3 install --break-system-packages -r requirements.txt 2>&1
            echo '✅ Зависимости установлены системно'
        fi
    else
        echo '⚠️  requirements.txt не найден'
    fi
"

echo ""
echo "🚀 Запуск бота..."
run_remote "
    cd ~/telegram-bot
    if [ -f start_bot.sh ]; then
        ./start_bot.sh
    else
        echo '⚠️  start_bot.sh не найден, создаю...'
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
        ./start_bot.sh
    fi
"

echo ""
echo "🔍 Проверка статуса бота..."
sleep 3
run_remote "
    cd ~/telegram-bot
    if [ -f bot.pid ]; then
        PID=\$(cat bot.pid 2>/dev/null)
        if ps -p \$PID >/dev/null 2>&1; then
            echo '✅ Бот запущен (PID: '\$PID')'
            echo ''
            echo 'Последние строки лога:'
            tail -10 bot.log
        else
            echo '❌ Бот не запущен'
            echo ''
            echo 'Последние строки лога (ошибки):'
            tail -20 bot.log
        fi
    else
        echo '⚠️  Файл bot.pid не найден'
        echo 'Последние строки лога:'
        tail -20 bot.log 2>/dev/null || echo 'Лог пуст'
    fi
"

echo ""
echo "=========================================="
echo "✅ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО"
echo "=========================================="

