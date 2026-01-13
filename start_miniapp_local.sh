#!/bin/bash

# Скрипт для локального запуска Mini App
# Использует ngrok для создания HTTPS туннеля

set -e

echo "=========================================="
echo "🚀 ЗАПУСК MINI APP ДЛЯ ЛОКАЛЬНОГО ТЕСТА"
echo "=========================================="
echo ""

# Проверка наличия Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 не найден. Установите Python 3.8+"
    exit 1
fi

# Проверка наличия ngrok
if ! command -v ngrok &> /dev/null; then
    echo "⚠️  ngrok не найден."
    echo ""
    echo "Для локального теста Mini App нужен HTTPS туннель."
    echo "Установите ngrok:"
    echo "  macOS: brew install ngrok/ngrok/ngrok"
    echo "  или скачайте с https://ngrok.com/download"
    echo ""
    read -p "Продолжить без ngrok? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    USE_NGROK=false
else
    USE_NGROK=true
fi

# Проверка наличия виртуального окружения
if [ ! -d "venv" ]; then
    echo "📦 Создаю виртуальное окружение..."
    python3 -m venv venv
fi

# Активация виртуального окружения
echo "🔧 Активирую виртуальное окружение..."
source venv/bin/activate

# Установка зависимостей
echo "📦 Устанавливаю зависимости..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Проверка наличия .env файла
if [ ! -f ".env" ]; then
    echo "⚠️  Файл .env не найден!"
    echo "Создайте файл .env с переменными:"
    echo "  BOT_TOKEN=your_bot_token"
    echo "  CHANNEL_ID=your_channel_id"
    echo "  MINI_APP_URL=https://your-ngrok-url.ngrok.io"
    exit 1
fi

# Загрузка переменных из .env
source .env

# Если MINI_APP_URL не установлен и есть ngrok, запускаем ngrok
if [ -z "$MINI_APP_URL" ] && [ "$USE_NGROK" = true ]; then
    echo ""
    echo "🌐 Запускаю ngrok туннель..."
    echo "   (Откройте новый терминал и запустите: ngrok http 8000)"
    echo ""
    read -p "Нажмите Enter после запуска ngrok и вставьте HTTPS URL: " NGROK_URL
    if [ -n "$NGROK_URL" ]; then
        # Обновляем .env файл
        if grep -q "MINI_APP_URL" .env; then
            sed -i.bak "s|MINI_APP_URL=.*|MINI_APP_URL=$NGROK_URL|" .env
        else
            echo "MINI_APP_URL=$NGROK_URL" >> .env
        fi
        export MINI_APP_URL=$NGROK_URL
        echo "✅ MINI_APP_URL установлен: $NGROK_URL"
    fi
fi

if [ -z "$MINI_APP_URL" ]; then
    echo "⚠️  MINI_APP_URL не установлен!"
    echo "Установите MINI_APP_URL в .env файле (HTTPS URL от ngrok)"
    exit 1
fi

echo ""
echo "=========================================="
echo "📋 КОНФИГУРАЦИЯ:"
echo "=========================================="
echo "  BOT_TOKEN: ${BOT_TOKEN:0:10}..."
echo "  CHANNEL_ID: $CHANNEL_ID"
echo "  MINI_APP_URL: $MINI_APP_URL"
echo ""

# Проверка, что URL начинается с https://
if [[ ! "$MINI_APP_URL" =~ ^https:// ]]; then
    echo "⚠️  ВНИМАНИЕ: MINI_APP_URL должен начинаться с https://"
    echo "   Mini App требует HTTPS!"
    exit 1
fi

echo "🚀 Запускаю веб-сервер Mini App на порту 8000..."
echo ""
echo "📱 Откройте бота в Telegram и нажмите кнопку '🎨 Редактор (Mini App)'"
echo ""
echo "Для остановки нажмите Ctrl+C"
echo ""

# Запуск веб-сервера
cd "$(dirname "$0")"
python3 -m uvicorn webapp.main:app --host 0.0.0.0 --port 8000 --reload
