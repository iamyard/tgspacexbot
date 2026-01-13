#!/bin/bash

# Автоматический запуск всех компонентов Mini App

set -e

cd "$(dirname "$0")"

echo "=========================================="
echo "🚀 ЗАПУСК MINI APP (ВСЕ КОМПОНЕНТЫ)"
echo "=========================================="
echo ""

# Проверка .env
if [ ! -f ".env" ]; then
    echo "❌ Файл .env не найден!"
    echo "   Запустите сначала: ./setup_miniapp.sh"
    exit 1
fi

source .env

if [ -z "$BOT_TOKEN" ] || [ -z "$CHANNEL_ID" ]; then
    echo "❌ BOT_TOKEN или CHANNEL_ID не настроены в .env!"
    echo "   Запустите: ./setup_miniapp.sh"
    exit 1
fi

# Проверка виртуального окружения
if [ ! -d "venv" ]; then
    echo "📦 Создаю виртуальное окружение..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -q --upgrade pip
    pip install -q -r requirements.txt
else
    source venv/bin/activate
fi

# Проверка ngrok
if ! pgrep -f "ngrok http 8000" > /dev/null; then
    echo "🌐 Запускаю ngrok..."
    ngrok http 8000 > /tmp/ngrok.log 2>&1 &
    sleep 3
    
    # Получаем URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$NGROK_URL" ]; then
        echo "✅ ngrok запущен: $NGROK_URL"
        
        # Обновляем .env если URL изменился
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|MINI_APP_URL=.*|MINI_APP_URL=$NGROK_URL|" .env
        else
            sed -i "s|MINI_APP_URL=.*|MINI_APP_URL=$NGROK_URL|" .env
        fi
        export MINI_APP_URL=$NGROK_URL
    else
        echo "⚠️  ngrok запущен, но URL пока не доступен"
        echo "   Проверьте http://localhost:4040"
    fi
else
    echo "✅ ngrok уже запущен"
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$NGROK_URL" ]; then
        echo "   URL: $NGROK_URL"
    fi
fi

echo ""
echo "=========================================="
echo "🚀 ЗАПУСКАЮ ВЕБ-СЕРВЕР MINI APP"
echo "=========================================="
echo ""
echo "📱 Откройте бота в Telegram и нажмите кнопку '🎨 Редактор (Mini App)'"
echo ""
echo "🌐 Веб-сервер будет доступен на: http://localhost:8000"
if [ -n "$NGROK_URL" ]; then
    echo "🌐 Mini App URL: $NGROK_URL"
fi
echo ""
echo "Для остановки нажмите Ctrl+C"
echo ""

# Запуск веб-сервера
python3 -m uvicorn webapp.main:app --host 0.0.0.0 --port 8000 --reload
