import os
from dotenv import load_dotenv

load_dotenv()

BOT_TOKEN = os.getenv('BOT_TOKEN')
CHANNEL_ID = os.getenv('CHANNEL_ID')
# URL для Mini App (для локального теста используйте ngrok или другой туннель)
MINI_APP_URL = os.getenv('MINI_APP_URL', 'http://localhost:8000')

# Проверка только при реальном использовании (не при импорте модулей)
def validate_config():
    """Проверяет наличие обязательных переменных конфигурации"""
    if not BOT_TOKEN:
        raise ValueError("BOT_TOKEN не найден в .env файле")
    if not CHANNEL_ID:
        raise ValueError("CHANNEL_ID не найден в .env файле")
