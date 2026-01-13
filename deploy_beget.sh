#!/bin/bash

# ============================================
# ДЕПЛОЙ НА BEGET БЕЗ CLOUDFLARE
# ============================================

# НАСТРОЙКИ - ИЗМЕНИТЕ НА СВОИ
BEGET_HOST="109.69.16.218"  # IP сервера Beget
BEGET_USER="root"
BEGET_PASS="LcLBrkotSeoI!2"
MINI_APP_DOMAIN="https://app.spacex.co.th"  # Официальный домен

set -e

# Инициализация Homebrew для macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен. Установите: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$BEGET_PASS" ssh -o StrictHostKeyChecking=no "$BEGET_USER@$BEGET_HOST" "$1"
}

echo "=========================================="
echo "🚀 ДЕПЛОЙ НА BEGET"
echo "=========================================="
echo ""

# Шаг 1: Коммит и push в Git
echo "📝 Шаг 1: Коммит изменений в Git..."

if [ ! -d .git ]; then
    echo "❌ Это не git репозиторий. Перейдите в папку проекта."
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

if ! git diff --quiet || ! git diff --cached --quiet; then
    git add .
    COMMIT_MSG="Deploy to Beget $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$COMMIT_MSG" || echo "⚠️  Коммит не создан"
    echo "✅ Изменения закоммичены"
fi

echo ""
echo "📤 Отправка в GitHub..."
if git push -u origin "$CURRENT_BRANCH" 2>/dev/null; then
    echo "✅ Код отправлен в GitHub"
else
    echo "⚠️  Push не выполнен (возможно, нет изменений)"
fi

echo ""
echo "📡 Шаг 2: Подключение к серверу..."

if ! run_remote "echo 'Подключение успешно'" > /dev/null 2>&1; then
    echo "❌ Не удалось подключиться к серверу"
    exit 1
fi
echo "✅ Подключение установлено"

echo ""
echo "📥 Шаг 3: Обновление кода на сервере..."

run_remote "
    cd ~/telegram-bot
    if [ ! -d .git ]; then
        echo '❌ Директория не является git репозиторием' >&2
        exit 1
    fi
    
    git fetch origin || exit 1
    if git rev-parse --verify $CURRENT_BRANCH >/dev/null 2>&1; then
        git checkout $CURRENT_BRANCH || exit 1
    else
        git checkout -b $CURRENT_BRANCH origin/$CURRENT_BRANCH || exit 1
    fi
    git reset --hard origin/$CURRENT_BRANCH || exit 1
    echo '✅ Код обновлен'
"

echo ""
echo "🔧 Шаг 4: Настройка веб-сервера (FastAPI)..."

# Формируем полный URL для Mini App
MINI_APP_URL="${MINI_APP_DOMAIN}/static/index.html"

run_remote "
    cd ~/telegram-bot
    
    # Обновляем .env файл с новым MINI_APP_URL
    if [ -f .env ]; then
        if grep -q '^MINI_APP_URL=' .env; then
            sed -i \"s|^MINI_APP_URL=.*|MINI_APP_URL=$MINI_APP_URL|\" .env
        else
            echo \"MINI_APP_URL=$MINI_APP_URL\" >> .env
        fi
        echo '✅ .env обновлен'
        echo 'Текущий MINI_APP_URL:'
        grep '^MINI_APP_URL=' .env
    else
        echo '⚠️  Файл .env не найден'
        exit 1
    fi
    
    # Активируем виртуальное окружение и устанавливаем зависимости
    if [ ! -d venv ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -q -r requirements.txt
    
    # Создаем systemd сервис для веб-сервера
    cat > /etc/systemd/system/miniapp.service << 'EOF'
[Unit]
Description=Telegram Mini App Web Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/telegram-bot
Environment=\"PATH=/root/telegram-bot/venv/bin\"
ExecStart=/root/telegram-bot/venv/bin/uvicorn webapp.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable miniapp
    systemctl restart miniapp
    
    # Ждем запуска
    sleep 3
    
    if systemctl is-active --quiet miniapp; then
        echo '✅ Веб-сервер запущен на порту 8000'
    else
        echo '⚠️  Веб-сервер может быть не запущен. Проверьте: systemctl status miniapp'
        systemctl status miniapp --no-pager -l || true
    fi
"

echo ""
echo "🔄 Шаг 5: Перезапуск бота..."

run_remote "
    cd ~/telegram-bot
    
    # Останавливаем старые процессы
    pkill -f 'python.*bot.py' 2>/dev/null || true
    rm -f bot.lock bot.pid
    sleep 2
    
    # Запускаем бота через start_bot.sh
    ./start_bot.sh &
    sleep 3
    
    # Проверяем процесс
    if pgrep -f 'python.*bot.py' > /dev/null; then
        echo '✅ Бот запущен'
    else
        echo '⚠️  Бот может быть не запущен'
    fi
"

echo ""
echo "🔍 Шаг 6: Проверка статуса..."

# Проверка веб-сервера
if run_remote "curl -s http://localhost:8000/api/health" | grep -q "ok"; then
    echo "✅ Веб-сервер работает"
else
    echo "⚠️  Веб-сервер может не работать"
fi

# Проверка бота
if run_remote "pgrep -f 'python.*bot.py' > /dev/null 2>&1"; then
    echo "✅ Бот работает"
else
    echo "⚠️  Бот может быть не запущен"
fi

echo ""
echo "=========================================="
echo "✅ ДЕПЛОЙ НА BEGET ЗАВЕРШЕН!"
echo "=========================================="
echo ""
echo "📋 Информация:"
echo "   Mini App Domain: $MINI_APP_DOMAIN"
echo "   Mini App URL: $MINI_APP_URL"
echo "   Веб-сервер: http://$BEGET_HOST:8000"
echo ""
echo "⚠️  ВАЖНО: Настройте ваш домен $MINI_APP_DOMAIN на Beget:"
echo "   1. Зайдите в панель Beget"
echo "   2. Настройте проксирование с домена на http://localhost:8000"
echo "   3. Или настройте веб-сервер (nginx/apache) для проксирования"
echo ""
echo "🧪 Проверка:"
echo "   curl $MINI_APP_DOMAIN/api/health"
echo ""
echo "📱 Использование:"
echo "   1. Откройте бота в Telegram"
echo "   2. Нажмите /start"
echo "   3. Нажмите кнопку '🎨 Редактор (Mini App)'"
echo ""
echo "📊 Полезные команды:"
echo "   Статус веб-сервера: ssh $BEGET_USER@$BEGET_HOST 'systemctl status miniapp'"
echo "   Логи веб-сервера: ssh $BEGET_USER@$BEGET_HOST 'journalctl -u miniapp -f'"
echo "   Логи бота: ssh $BEGET_USER@$BEGET_HOST 'cd ~/telegram-bot && tail -f bot.log'"
echo ""
