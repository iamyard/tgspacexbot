import os
from dotenv import load_dotenv

load_dotenv()

BOT_TOKEN = os.getenv('BOT_TOKEN')
CHANNEL_ID = os.getenv('CHANNEL_ID')

if not BOT_TOKEN:
    raise ValueError("BOT_TOKEN не найден в .env файле")
if not CHANNEL_ID:
    raise ValueError("CHANNEL_ID не найден в .env файле")
