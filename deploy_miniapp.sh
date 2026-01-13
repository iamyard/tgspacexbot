#!/bin/bash

# ============================================
# ДЕПЛОЙ MINI APP С CLOUDFLARE TUNNEL
# ============================================

SERVER_IP="109.69.16.218"
SERVER_USER="root"
SERVER_PASS="LcLBrkotSeoI!2"

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
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

echo "=========================================="
echo "🚀 ДЕПЛОЙ MINI APP С CLOUDFLARE TUNNEL"
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
    COMMIT_MSG="Deploy Mini App $(date '+%Y-%m-%d %H:%M:%S')"
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
echo "🔧 Шаг 4: Установка и настройка Cloudflare Tunnel..."

run_remote "
    cd ~/telegram-bot
    
    # Установка cloudflared если не установлен
    if ! command -v cloudflared &> /dev/null; then
        echo '📦 Устанавливаю cloudflared...'
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
        echo '✅ cloudflared установлен'
    else
        echo '✅ cloudflared уже установлен'
    fi
    
    # Останавливаем старый туннель если запущен
    systemctl stop cloudflared 2>/dev/null || true
    pkill -f cloudflared 2>/dev/null || true
    sleep 2
"

echo ""
echo "🌐 Шаг 5: Настройка веб-сервера (FastAPI)..."

run_remote "
    cd ~/telegram-bot
    
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
ExecStart=/root/telegram-bot/venv/bin/uvicorn webapp.main:app --host 127.0.0.1 --port 8000
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
        echo '✅ Веб-сервер запущен'
    else
        echo '⚠️  Веб-сервер может быть не запущен. Проверьте: systemctl status miniapp'
        systemctl status miniapp --no-pager -l || true
    fi
"

echo ""
echo "🔗 Шаг 6: Запуск Cloudflare Tunnel..."

# Создаем systemd сервис для cloudflared
run_remote "
    cat > /etc/systemd/system/cloudflared.service << 'EOF'
[Unit]
Description=Cloudflare Tunnel
After=network.target miniapp.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:8000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable cloudflared
    systemctl restart cloudflared
    
    sleep 5
"

# Получаем URL из journalctl
echo "⏳ Ожидание создания туннеля..."
sleep 5

CLOUDFLARE_URL=$(run_remote "journalctl -u cloudflared --no-pager -n 50 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | head -1" | tr -d '\n\r ')

if [ -z "$CLOUDFLARE_URL" ]; then
    echo "⚠️  Не удалось получить URL из туннеля. Пытаюсь еще раз..."
    sleep 5
    CLOUDFLARE_URL=$(run_remote "journalctl -u cloudflared --no-pager -n 50 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | head -1" | tr -d '\n\r ')
fi

if [ -z "$CLOUDFLARE_URL" ]; then
    echo "❌ Не удалось получить Cloudflare URL. Проверьте логи на сервере."
    echo "   ssh $SERVER_USER@$SERVER_IP 'journalctl -u cloudflared -n 50'"
    exit 1
fi

MINI_APP_URL="${CLOUDFLARE_URL}/static/index.html"

echo "✅ Cloudflare Tunnel запущен"
echo "   URL: $CLOUDFLARE_URL"
echo "   Mini App URL: $MINI_APP_URL"

echo ""
echo "📝 Шаг 7: Обновление .env файла..."

run_remote "
    cd ~/telegram-bot
    
    # Читаем существующий .env
    if [ -f .env ]; then
        # Обновляем MINI_APP_URL если он есть, иначе добавляем
        if grep -q '^MINI_APP_URL=' .env; then
            sed -i \"s|^MINI_APP_URL=.*|MINI_APP_URL=$MINI_APP_URL|\" .env
        else
            echo \"MINI_APP_URL=$MINI_APP_URL\" >> .env
        fi
        echo '✅ .env обновлен'
        echo ''
        echo 'Текущий MINI_APP_URL:'
        grep '^MINI_APP_URL=' .env
    else
        echo '⚠️  Файл .env не найден. Создайте его вручную.'
    fi
"

echo ""
echo "🔄 Шаг 8: Перезапуск бота..."

run_remote "
    cd ~/telegram-bot
    ./start_bot.sh
    sleep 3
"

echo ""
echo "🔍 Шаг 9: Проверка статуса..."

# Проверка веб-сервера
if run_remote "curl -s http://localhost:8000/api/health" | grep -q "ok"; then
    echo "✅ Веб-сервер работает"
else
    echo "⚠️  Веб-сервер может не работать"
fi

# Проверка туннеля
if run_remote "curl -s $CLOUDFLARE_URL/api/health" | grep -q "ok"; then
    echo "✅ Cloudflare Tunnel работает"
else
    echo "⚠️  Cloudflare Tunnel может не работать. URL: $CLOUDFLARE_URL"
fi

# Проверка бота
if run_remote "cd ~/telegram-bot && test -f bot.pid && ps -p \$(cat bot.pid) > /dev/null 2>&1"; then
    PID=$(run_remote "cd ~/telegram-bot && cat bot.pid")
    echo "✅ Бот работает (PID: $PID)"
else
    echo "⚠️  Бот может быть не запущен"
fi

echo ""
echo "=========================================="
echo "✅ ДЕПЛОЙ MINI APP ЗАВЕРШЕН!"
echo "=========================================="
echo ""
echo "📋 Информация:"
echo "   Cloudflare URL: $CLOUDFLARE_URL"
echo "   Mini App URL: $MINI_APP_URL"
echo ""
echo "🧪 Проверка:"
echo "   curl $CLOUDFLARE_URL/api/health"
echo ""
echo "📱 Использование:"
echo "   1. Откройте бота в Telegram"
echo "   2. Нажмите /start"
echo "   3. Нажмите кнопку '🎨 Редактор (Mini App)'"
echo ""
echo "📊 Полезные команды:"
echo "   Статус веб-сервера: ssh $SERVER_USER@$SERVER_IP 'systemctl status miniapp'"
echo "   Статус туннеля: ssh $SERVER_USER@$SERVER_IP 'systemctl status cloudflared'"
echo "   Логи веб-сервера: ssh $SERVER_USER@$SERVER_IP 'journalctl -u miniapp -f'"
echo "   Логи туннеля: ssh $SERVER_USER@$SERVER_IP 'journalctl -u cloudflared -f'"
echo ""
