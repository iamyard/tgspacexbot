from PIL import Image, ImageDraw, ImageFont
from datetime import datetime
import io
import os

async def generate_image(data: dict) -> io.BytesIO:
    """
    Генерирует изображение с обновленными данными
    
    Args:
        data: Словарь с данными для отображения
        
    Returns:
        BytesIO объект с изображением
    """
    # Загружаем шаблон
    template_path = os.path.join(os.path.dirname(__file__), 'Template.png')
    if not os.path.exists(template_path):
        raise FileNotFoundError(f"Шаблон не найден: {template_path}")
    
    image = Image.open(template_path)
    width, height = image.size
    draw = ImageDraw.Draw(image)
    
    # Загружаем шрифт Nunito для всех элементов
    nunito_path = os.path.join(os.path.dirname(__file__), 'Nunito.ttf')
    font_size_currency = 96  # Размер шрифта для валютных значений
    font_size_date = 128  # Размер шрифта для даты
    font_size_month = 80  # Размер шрифта для месяца
    
    try:
        # Пытаемся загрузить Nunito для всех элементов
        if os.path.exists(nunito_path):
            font_currency = ImageFont.truetype(nunito_path, font_size_currency)
            font_date = ImageFont.truetype(nunito_path, font_size_date)
            font_month = ImageFont.truetype(nunito_path, font_size_month)
        else:
            # Fallback на системные шрифты
            try:
                font_currency = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size_currency)
                font_date = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size_date)
                font_month = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size_month)
            except:
                try:
                    font_currency = ImageFont.truetype("arial.ttf", font_size_currency)
                    font_date = ImageFont.truetype("arial.ttf", font_size_date)
                    font_month = ImageFont.truetype("arial.ttf", font_size_month)
                except:
                    font_currency = ImageFont.load_default()
                    font_date = ImageFont.load_default()
                    font_month = ImageFont.load_default()
    except Exception as e:
        # Если не удалось загрузить, используем default
        print(f"Предупреждение: не удалось загрузить шрифт Nunito: {e}")
        font_currency = ImageFont.load_default()
        font_date = ImageFont.load_default()
        font_month = ImageFont.load_default()
    
    # === НАКЛАДЫВАЕМ ДАННЫЕ НА ШАБЛОН ===
    
    # Координаты для наложения данных на шаблон 1280x960
    # Позиции для 4 карточек валют (числа справа в карточках)
    currency_cards = [
        {'x': 90, 'y': 137, 'value': data.get('rub_thb', '2.72')},   # RUB/THB (опущено на 30px)
        {'x': 90, 'y': 364, 'value': data.get('tb', '30.6')},        # USDT/THB (опущено на 30px)
        {'x': 90, 'y': 589, 'value': data.get('rub_vnd', '308')},    # VND/RUB (опущено на 30px)
        {'x': 90, 'y': 820, 'value': data.get('td', '25800')},        # USDT/VND (опущено на 30px)
    ]
    
    # Цвет текста
    text_color = '#DDE3FA'
    
    # === ДОБАВЛЯЕМ ДАТУ И МЕСЯЦ ===
    # Получаем текущую дату
    now = datetime.now()
    day = str(now.day)  # Число дня
    month_names = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
                   'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря']
    month = month_names[now.month - 1]  # Название месяца с маленькой буквы
    
    # Рисуем дату (число дня) - сдвинуто вправо на 20px и вниз на 20px
    draw.text(
        (950, 210),  # Было (901, 173), теперь (921, 193)
        day,
        fill=text_color,
        font=font_date,
        anchor='mm',  # По центру
        stroke_width=4,
        stroke_fill=text_color
    )
    
    # Рисуем месяц (под датой) - используем Nunito
    draw.text(
        (955, 320),  # Сдвинуто влево на 15px (было 970)
        month,
        fill=text_color,
        font=font_month,  # Используем Nunito
        anchor='mm',  # По центру
        stroke_width=4,
        stroke_fill=text_color
    )
    
    # Шрифт уже загружен выше (Dosis с обводкой для bold эффекта, 96px)
    
    # Накладываем значения валют на шаблон
    for card in currency_cards:
        # Используем только значение без символов
        value_str = str(card['value'])
        
        # Получаем размер текста
        bbox = draw.textbbox((0, 0), value_str, font=font_currency)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        # Рисуем текст с обводкой для bold эффекта (цвет #DDE3FA)
        # anchor='lm' означает выравнивание по левому краю, вертикально по центру
        draw.text(
            (card['x'], card['y']),
            value_str,
            fill=text_color,
            font=font_currency,
            anchor='lm',  # left-middle: левый край, вертикально по центру
            stroke_width=4,  # Толщина обводки для bold эффекта
            stroke_fill=text_color
        )
    
    # Сохраняем в BytesIO
    try:
        img_byte_arr = io.BytesIO()
        image.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        return img_byte_arr
    except Exception as e:
        raise Exception(f"Ошибка при сохранении изображения: {str(e)}")
