"""
FastAPI сервер для Telegram Mini App
Обрабатывает запросы от веб-интерфейса и генерирует изображения
"""
from fastapi import FastAPI, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import sys
import os
import base64
import io

# Добавляем родительскую директорию в путь для импорта модулей бота
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from image_generator import generate_image, generate_story_image
from datetime import datetime
import config

app = FastAPI(title="Telegram Mini App API")

# CORS middleware для локальной разработки
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене заменить на конкретный домен
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Монтируем статические файлы
app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")


class CurrencyData(BaseModel):
    """Модель данных курсов валют"""
    rub_thb: str
    tb: str
    rub_vnd: str
    td: str


class GenerateRequest(BaseModel):
    """Запрос на генерацию изображения"""
    data: CurrencyData
    type: str = "post"  # "post" или "story"


class SendToChannelRequest(BaseModel):
    """Запрос на отправку в канал"""
    data: CurrencyData
    type: str = "post"


class SendStoryToUserRequest(BaseModel):
    """Запрос на отправку сторис пользователю"""
    data: CurrencyData
    user_id: int


@app.get("/", response_class=HTMLResponse)
async def read_root():
    """Главная страница Mini App"""
    html_path = os.path.join(os.path.dirname(__file__), "static", "index.html")
    with open(html_path, "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.post("/api/generate-preview")
async def generate_preview(request: GenerateRequest):
    """
    Генерирует превью изображения и возвращает base64
    """
    try:
        # Формируем данные для генерации
        data = {
            'rub_thb': request.data.rub_thb,
            'tb': request.data.tb,
            'rub_vnd': request.data.rub_vnd,
            'td': request.data.td,
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Генерируем изображение
        if request.type == "story":
            image = await generate_story_image(data)
        else:
            image = await generate_image(data)
        
        # Конвертируем в base64
        image.seek(0)
        image_bytes = image.read()
        image_base64 = base64.b64encode(image_bytes).decode('utf-8')
        
        return JSONResponse(content={
            "success": True,
            "image": f"data:image/png;base64,{image_base64}",
            "timestamp": data['timestamp']
        })
        
    except Exception as e:
        print(f"ERROR в generate_preview: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/send-to-channel")
async def send_to_channel(request: SendToChannelRequest):
    """
    Отправляет изображение в канал через бота
    ВАЖНО: Этот endpoint должен вызываться только из Telegram Mini App
    с валидным initData от Telegram
    """
    try:
        # Формируем данные для генерации
        data = {
            'rub_thb': request.data.rub_thb,
            'tb': request.data.tb,
            'rub_vnd': request.data.rub_vnd,
            'td': request.data.td,
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Генерируем изображение
        if request.type == "story":
            # Для сторис просто возвращаем изображение, не отправляем в канал
            image = await generate_story_image(data)
            image.seek(0)
            image_bytes = image.read()
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            
            return JSONResponse(content={
                "success": True,
                "message": "Изображение для сторис готово! Сохраните его и загрузите в Instagram.",
                "image": f"data:image/png;base64,{image_base64}",
                "type": "story"
            })
        else:
            # Для поста отправляем в канал через бота
            from aiogram import Bot
            from aiogram.types import BufferedInputFile, InlineKeyboardButton, InlineKeyboardMarkup
            from aiogram.utils.keyboard import InlineKeyboardBuilder
            
            # Проверяем наличие токена
            if not config.BOT_TOKEN:
                raise HTTPException(status_code=500, detail="BOT_TOKEN не настроен в .env файле")
            
            bot = Bot(token=config.BOT_TOKEN)
            
            # Генерируем изображение
            image = await generate_image(data)
            image.seek(0)
            
            # Создаем URL кнопки для поста
            url_keyboard = InlineKeyboardBuilder()
            url_keyboard.add(InlineKeyboardButton(
                text="💬 Отзывы",
                url="https://t.me/spacexchange_otc/4"
            ))
            url_keyboard.add(InlineKeyboardButton(
                text="❓ FAQ",
                url="https://t.me/spacexchange_otc/3"
            ))
            url_keyboard.add(InlineKeyboardButton(
                text="🔄 Начать обмен",
                url="https://t.me/spacex_th_support"
            ))
            url_keyboard.adjust(2, 1)
            
            # Отправляем в канал
            await bot.send_photo(
                chat_id=config.CHANNEL_ID,
                photo=BufferedInputFile(file=image.read(), filename="update.png"),
                reply_markup=url_keyboard.as_markup()
            )
            
            await bot.session.close()
            
            return JSONResponse(content={
                "success": True,
                "message": "✅ Изображение успешно отправлено в канал!",
                "type": "post"
            })
            
    except Exception as e:
        print(f"ERROR в send_to_channel: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/get-story-url")
async def get_story_url(request: GenerateRequest):
    """
    Генерирует изображение сторис и возвращает публичный URL
    """
    try:
        # Формируем данные для генерации
        data = {
            'rub_thb': request.data.rub_thb,
            'tb': request.data.tb,
            'rub_vnd': request.data.rub_vnd,
            'td': request.data.td,
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Генерируем изображение для сторис
        image = await generate_story_image(data)
        image.seek(0)
        image_bytes = image.read()
        
        # Сохраняем временно
        import tempfile
        import uuid
        
        # Создаем временную директорию если её нет
        temp_dir = os.path.join(os.path.dirname(__file__), "static", "temp")
        os.makedirs(temp_dir, exist_ok=True)
        
        # Генерируем уникальное имя файла
        filename = f"story_{uuid.uuid4().hex[:8]}.png"
        filepath = os.path.join(temp_dir, filename)
        
        # Сохраняем файл
        with open(filepath, 'wb') as f:
            f.write(image_bytes)
        
        # Возвращаем URL
        # Используем относительный путь
        file_url = f"/static/temp/{filename}"
        
        return JSONResponse(content={
            "success": True,
            "url": file_url,
            "filename": filename
        })
        
    except Exception as e:
        print(f"ERROR в get_story_url: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/send-story-to-user")
async def send_story_to_user(request: SendStoryToUserRequest):
    """
    Отправляет изображение сторис пользователю в личный чат с ботом
    """
    try:
        # Формируем данные для генерации
        data = {
            'rub_thb': request.data.rub_thb,
            'tb': request.data.tb,
            'rub_vnd': request.data.rub_vnd,
            'td': request.data.td,
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Проверяем наличие токена
        if not config.BOT_TOKEN:
            raise HTTPException(status_code=500, detail="BOT_TOKEN не настроен в .env файле")
        
        from aiogram import Bot
        from aiogram.types import BufferedInputFile
        
        bot = Bot(token=config.BOT_TOKEN)
        
        # Генерируем изображение для сторис
        image = await generate_story_image(data)
        image.seek(0)
        
        # Отправляем пользователю
        await bot.send_photo(
            chat_id=request.user_id,
            photo=BufferedInputFile(file=image.read(), filename="story.png"),
            caption="✨ Ваш сторис готов!\n\n📱 Сохраните изображение и поделитесь в Instagram Stories!"
        )
        
        await bot.session.close()
        
        return JSONResponse(content={
            "success": True,
            "message": "✅ Сторис отправлен в чат с ботом!"
        })
        
    except Exception as e:
        print(f"ERROR в send_story_to_user: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/health")
async def health_check():
    """Проверка здоровья сервера"""
    return JSONResponse(content={"status": "ok", "service": "telegram-miniapp-api"})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
