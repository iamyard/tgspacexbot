#!/bin/bash

# Автоматическая настройка и запуск Mini App

set -e

echo "=========================================="
echo "🚀 АВТОМАТИЧЕСКАЯ НАСТРОЙКА MINI APP"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Проверка .env файла
if [ ! -f ".env" ]; then
    echo "📝 Создаю файл .env..."
    
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✅ Файл .env создан из шаблона"
    else
        cat > .env << EOF
BOT_TOKEN=
CHANNEL_ID=
MINI_APP_URL=
EOF
        echo "✅ Файл .env создан"
    fi
    
    echo ""
    echo "⚠️  ВАЖНО: Нужно заполнить .env файл!"
    echo ""
    read -p "Введите BOT_TOKEN: " BOT_TOKEN
    read -p "Введите CHANNEL_ID (например: @spacex_th или -1001234567890): " CHANNEL_ID
    
    # Обновляем .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|BOT_TOKEN=.*|BOT_TOKEN=$BOT_TOKEN|" .env
        sed -i '' "s|CHANNEL_ID=.*|CHANNEL_ID=$CHANNEL_ID|" .env
    else
        sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=$BOT_TOKEN|" .env
        sed -i "s|CHANNEL_ID=.*|CHANNEL_ID=$CHANNEL_ID|" .env
    fi
    
    echo "✅ Данные сохранены в .env"
else
    echo "✅ Файл .env уже существует"
    source .env
fi

# Проверка наличия ngrok
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok не найден. Устанавливаю..."
    if command -v brew &> /dev/null; then
        brew install ngrok/ngrok/ngrok
    else
        echo "❌ Homebrew не найден. Установите ngrok вручную: https://ngrok.com/download"
        exit 1
    fi
fi

echo ""
echo "🌐 Запускаю ngrok туннель..."
echo "   (Это откроет новый процесс в фоне)"
echo ""

# Запускаем ngrok в фоне
NGROK_PID=$(pgrep -f "ngrok http 8000" || echo "")
if [ -z "$NGROK_PID" ]; then
    ngrok http 8000 > /tmp/ngrok.log 2>&1 &
    NGROK_PID=$!
    echo "✅ ngrok запущен (PID: $NGROK_PID)"
    sleep 3  # Даем ngrok время на запуск
else
    echo "✅ ngrok уже запущен (PID: $NGROK_PID)"
fi

# Получаем URL от ngrok API
echo "📡 Получаю HTTPS URL от ngrok..."
sleep 2

NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$NGROK_URL" ]; then
    echo "⚠️  Не удалось получить URL автоматически"
    echo "   Проверьте http://localhost:4040 в браузере"
    read -p "Введите HTTPS URL от ngrok: " NGROK_URL
fi

if [ -n "$NGROK_URL" ]; then
    echo "✅ Найден URL: $NGROK_URL"
    
    # Обновляем .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|MINI_APP_URL=.*|MINI_APP_URL=$NGROK_URL|" .env
    else
        sed -i "s|MINI_APP_URL=.*|MINI_APP_URL=$NGROK_URL|" .env
    fi
    
    echo "✅ MINI_APP_URL обновлен в .env"
else
    echo "❌ Не удалось получить URL"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ НАСТРОЙКА ЗАВЕРШЕНА!"
echo "=========================================="
echo ""
echo "📋 Конфигурация:"
source .env
echo "  BOT_TOKEN: ${BOT_TOKEN:0:10}..."
echo "  CHANNEL_ID: $CHANNEL_ID"
echo "  MINI_APP_URL: $NGROK_URL"
echo ""
echo "🚀 Теперь запустите веб-сервер:"
echo "   ./start_miniapp_local.sh"
echo ""
echo "📱 Или запустите бота (в отдельном терминале):"
echo "   source venv/bin/activate && python3 bot.py"
echo ""
