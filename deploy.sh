#!/bin/bash

# ============================================
# НАСТРОЙКИ СЕРВЕРА - ЗАПОЛНИТЕ ЭТИ ПЕРЕМЕННЫЕ
# ============================================
SERVER_IP="109.69.16.218"        # IP адрес вашего сервера
SERVER_USER="root"                # Имя пользователя на сервере
SERVER_PASS="LcLBrkotSeoI!2"       # Пароль для SSH

# ============================================
# НЕ МЕНЯЙТЕ НИЧЕГО НИЖЕ ЭТОЙ СТРОКИ
# ============================================

set -e  # Остановка при ошибке

# Инициализация Homebrew для macOS (если установлен, но не в PATH)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

echo "=========================================="
echo "🔄 ОБНОВЛЕНИЕ И ПЕРЕЗАПУСК БОТА"
echo "=========================================="

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен. Запустите сначала setup.sh"
    exit 1
fi

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

# Проверка, что мы в git репозитории
if [ ! -d .git ]; then
    echo "❌ Это не git репозиторий. Перейдите в папку проекта."
    exit 1
fi

echo ""
echo "📝 Шаг 1: Коммит изменений в Git..."

# Определяем текущую ветку
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# Проверяем, есть ли коммиты в репозитории
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "📦 Первый коммит в репозитории..."
    # Добавляем все файлы (кроме тех, что в .gitignore)
    git add .
    COMMIT_MSG="Initial commit $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$COMMIT_MSG" || {
        echo "❌ Ошибка при создании первого коммита"
        exit 1
    }
    echo "✅ Первый коммит создан"
elif ! git diff --quiet || ! git diff --cached --quiet; then
    # Есть изменения для коммита
    git add .
    COMMIT_MSG="Update $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$COMMIT_MSG" || {
        echo "⚠️  Коммит не создан (возможно, нет изменений)"
    }
    echo "✅ Изменения закоммичены"
else
    echo "⚠️  Нет изменений для коммита"
fi

echo ""
echo "📤 Шаг 2: Отправка в GitHub (ветка: $CURRENT_BRANCH)..."

# Проверяем, настроен ли remote
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "❌ Remote 'origin' не настроен. Проверьте настройки Git."
    exit 1
fi

# Push в репозиторий с указанием ветки
if git push -u origin "$CURRENT_BRANCH"; then
    echo "✅ Код отправлен в GitHub"
else
    echo "❌ Ошибка при отправке в GitHub"
    exit 1
fi

echo ""
echo "📡 Шаг 3: Подключение к серверу..."

# Проверка подключения
if ! run_remote "echo 'Подключение успешно'"; then
    echo "❌ Не удалось подключиться к серверу"
    exit 1
fi

echo ""
echo "📥 Шаг 4: Обновление кода на сервере (ветка: $CURRENT_BRANCH)..."

# Обновление кода на сервере
if run_remote "
    cd ~/telegram-bot
    if [ ! -d .git ]; then
        echo '❌ Директория не является git репозиторием' >&2
        exit 1
    fi
    
    # Сохраняем временные файлы (логи, lock, pid) перед обновлением
    mkdir -p .backup
    [ -f bot.log ] && mv bot.log .backup/bot.log.backup 2>/dev/null || true
    [ -f bot.lock ] && mv bot.lock .backup/bot.lock.backup 2>/dev/null || true
    [ -f bot.pid ] && mv bot.pid .backup/bot.pid.backup 2>/dev/null || true
    
    # Переключаемся на нужную ветку и обновляем
    git fetch origin || exit 1
    
    # Переключаемся на ветку или создаем новую
    if git rev-parse --verify $CURRENT_BRANCH >/dev/null 2>&1; then
        git checkout $CURRENT_BRANCH || exit 1
    else
        git checkout -b $CURRENT_BRANCH origin/$CURRENT_BRANCH || exit 1
    fi
    
    # Принудительно обновляем код (используем reset --hard для чистого состояния)
    git reset --hard origin/$CURRENT_BRANCH || exit 1
    
    # Восстанавливаем временные файлы
    [ -f .backup/bot.log.backup ] && mv .backup/bot.log.backup bot.log 2>/dev/null || true
    [ -f .backup/bot.lock.backup ] && mv .backup/bot.lock.backup bot.lock 2>/dev/null || true
    [ -f .backup/bot.pid.backup ] && mv .backup/bot.pid.backup bot.pid 2>/dev/null || true
    
    rm -rf .backup
    
    echo '✅ Код обновлен'
"; then
    echo "✅ Код успешно обновлен на сервере"
else
    echo "❌ Ошибка при обновлении кода на сервере"
    exit 1
fi

echo ""
echo "🔄 Шаг 5: Перезапуск бота..."

# Перезапуск бота
if run_remote "
    cd ~/telegram-bot
    ./start_bot.sh
"; then
    echo "✅ Бот перезапущен"
else
    echo "❌ Ошибка при перезапуске бота"
    exit 1
fi

# Проверка запуска
sleep 3
echo ""
echo "🔍 Проверка статуса бота..."

if run_remote "cd ~/telegram-bot && test -f bot.pid && ps -p \$(cat bot.pid) > /dev/null 2>&1"; then
    PID=$(run_remote "cd ~/telegram-bot && cat bot.pid")
    echo "✅ Бот работает (PID: $PID)"
    echo ""
    echo "📋 Последние строки лога:"
    run_remote "cd ~/telegram-bot && tail -5 bot.log"
else
    echo "⚠️  Бот может быть не запущен. Проверьте логи:"
    echo "   ssh $SERVER_USER@$SERVER_IP 'cd ~/telegram-bot && tail -20 bot.log'"
fi

echo ""
echo "=========================================="
echo "✅ ДЕПЛОЙ ЗАВЕРШЕН!"
echo "=========================================="

