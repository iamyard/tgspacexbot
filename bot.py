import asyncio
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command, StateFilter
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton, BufferedInputFile, InputMediaPhoto, ReplyKeyboardMarkup, KeyboardButton
from aiogram.utils.keyboard import InlineKeyboardBuilder, ReplyKeyboardBuilder
import config
from image_generator import generate_image
from datetime import datetime

bot = Bot(token=config.BOT_TOKEN)
dp = Dispatcher()

# Список разрешенных пользователей
ALLOWED_USER_IDS = [445773887, 41186481, 6511972362]

# Функция для проверки доступа
def check_access(user_id: int) -> bool:
    """Проверяет, есть ли у пользователя доступ к боту"""
    return user_id in ALLOWED_USER_IDS

# Функция для создания reply keyboard (кнопки под полем ввода)
def get_main_keyboard() -> ReplyKeyboardMarkup:
    """Создает основную клавиатуру с кнопками быстрого доступа"""
    keyboard = ReplyKeyboardBuilder()
    keyboard.add(KeyboardButton(text="📝 Создать пост"))
    keyboard.add(KeyboardButton(text="🖼️ Превью"))
    keyboard.add(KeyboardButton(text="📊 Данные"))
    keyboard.adjust(2, 1)
    return keyboard.as_markup(resize_keyboard=True)

# Функция для удаления клавиатуры
def remove_keyboard() -> ReplyKeyboardMarkup:
    """Удаляет reply keyboard"""
    return ReplyKeyboardMarkup(keyboard=[], resize_keyboard=True)

# Middleware для проверки доступа
class AccessMiddleware:
    async def __call__(self, handler, event, data):
        # Получаем user_id из события
        user_id = None
        
        if isinstance(event, types.Message) and event.from_user:
            user_id = event.from_user.id
        elif isinstance(event, types.CallbackQuery) and event.from_user:
            user_id = event.from_user.id
        
        # Если user_id найден и не в списке разрешенных
        if user_id and not check_access(user_id):
            print(f"❌ Доступ запрещен для пользователя {user_id}")
            # Отправляем сообщение об отказе в доступе
            try:
                if isinstance(event, types.Message):
                    await event.answer("❌ У вас нет доступа к этому боту.")
                elif isinstance(event, types.CallbackQuery):
                    await event.answer("❌ У вас нет доступа к этому боту.", show_alert=True)
            except:
                pass
            return  # Прерываем выполнение обработчика
        
        # Если доступ разрешен, продолжаем выполнение
        return await handler(event, data)

# Регистрируем middleware
dp.message.middleware(AccessMiddleware())
dp.callback_query.middleware(AccessMiddleware())

# Состояния для FSM
class CurrencyInput(StatesGroup):
    waiting_rub_thb = State()    # RUB/THB
    waiting_tb = State()         # USDT/THB
    waiting_rub_vnd = State()    # VND/RUB
    waiting_td = State()         # USDT/VND

# Текущие данные валютных курсов
current_data = {
    'rub_thb': '2.72',      # RUB/THB
    'tb': '30.6',           # USDT/THB
    'rub_vnd': '308',       # VND/RUB
    'td': '25800'           # USDT/VND
}

@dp.message(Command("start"))
async def cmd_start(message: types.Message):
    try:
        print(f"DEBUG: Получена команда /start от {message.from_user.id}")
        # Создаем inline клавиатуру с кнопками управления
        keyboard = InlineKeyboardBuilder()
        keyboard.add(InlineKeyboardButton(
            text="📝 Создать пост",
            callback_data="create_post"
        ))
        keyboard.add(InlineKeyboardButton(
            text="🔄 Обновить данные",
            callback_data="update_data"
        ))
        keyboard.add(InlineKeyboardButton(
            text="📊 Показать текущие данные",
            callback_data="show_current_data"
        ))
        keyboard.add(InlineKeyboardButton(
            text="🖼️ Сгенерировать превью",
            callback_data="generate_preview"
        ))
        keyboard.adjust(2, 2)
        
        await message.answer(
            "👋 Привет! Я бот для генерации изображений с курсами валют.\n\n"
            "📋 Используйте кнопки ниже или кнопки под полем ввода:",
            reply_markup=keyboard.as_markup()
        )
        
        # Показываем reply keyboard (кнопки под полем ввода)
        await message.answer(
            "💡 Используйте кнопки под полем ввода для быстрого доступа:",
            reply_markup=get_main_keyboard()
        )
        print(f"DEBUG: Сообщение отправлено пользователю {message.from_user.id}")
    except Exception as e:
        print(f"ERROR в /start: {e}")
        import traceback
        traceback.print_exc()
        try:
            await message.answer(f"❌ Ошибка: {str(e)}")
        except:
            pass

@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "ℹ️ Справка по боту:\n\n"
        "/generate - Генерирует изображение с текущими данными и отправляет его в канал\n"
        "/update - Обновляет данные (пример)\n"
        "/help - Показать эту справку\n\n"
        "После отправки в канал, изображение будет содержать инлайн-кнопки для взаимодействия."
    )

@dp.message(Command("cancel"))
async def cmd_cancel(message: types.Message, state: FSMContext):
    """Отменяет текущий процесс ввода"""
    await state.clear()
    await message.answer("❌ Процесс отменен. Вы можете начать заново с помощью /start")

@dp.message(Command("update"))
async def cmd_update(message: types.Message):
    """Обновляет данные (пример)"""
    global current_data
    # Пример обновления данных - можно получать из API
    import random
    current_data['rub_thb'] = f"{2.70 + random.uniform(-0.1, 0.1):.2f}"
    current_data['tb'] = f"{30.5 + random.uniform(-0.5, 0.5):.1f}"
    current_data['rub_vnd'] = f"{int(308 + random.uniform(-5, 5))}"
    current_data['td'] = f"{int(25800 + random.uniform(-100, 100))}"
    
    await message.answer("✅ Данные обновлены! Используйте /generate для создания нового поста.")

@dp.message(Command("generate"))
async def cmd_generate(message: types.Message):
    """Генерирует изображение и показывает превью"""
    await message.answer("⏳ Генерирую изображение...")
    
    try:
        # Добавляем timestamp к данным
        data_with_timestamp = current_data.copy()
        data_with_timestamp['timestamp'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Генерируем изображение
        image = await generate_image(data_with_timestamp)
        
        # Создаем клавиатуру для превью (отправка в канал или отмена)
        preview_keyboard = InlineKeyboardBuilder()
        preview_keyboard.add(InlineKeyboardButton(
            text="✅ Отправить в канал",
            callback_data="send_to_channel"
        ))
        preview_keyboard.add(InlineKeyboardButton(
            text="❌ Отмена",
            callback_data="cancel_preview"
        ))
        preview_keyboard.adjust(1)
        
        # Показываем превью пользователю
        image.seek(0)  # Убеждаемся, что позиция в начале
        await message.answer_photo(
            photo=BufferedInputFile(file=image.read(), filename="preview.png"),
            caption=f"📊 Превью изображения\n\n"
                   f"🕐 Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
                   f"Проверьте изображение и нажмите кнопку для отправки в канал:",
            reply_markup=preview_keyboard.as_markup()
        )
        
    except Exception as e:
        error_msg = str(e)
        import traceback
        traceback.print_exc()
        await message.answer(
            f"❌ Ошибка при генерации:\n{error_msg}"
        )

@dp.callback_query(F.data == "create_post")
async def create_post_callback(callback: types.CallbackQuery, state: FSMContext):
    """Начинаем процесс создания поста - запрашиваем курсы по очереди"""
    await callback.answer("Начинаем создание поста")
    await state.set_state(CurrencyInput.waiting_rub_thb)
    await callback.message.answer(
        "📝 Создание нового поста\n\n"
        "Введите курс RUB/THB:",
        reply_markup=remove_keyboard()  # Убираем клавиатуру для удобства ввода
    )

# Функция для форматирования чисел
def format_currency_value(value):
    """Форматирует число: целое без точки, дробное с точкой"""
    float_value = float(value)
    # Проверяем, является ли число целым
    if float_value.is_integer():
        return str(int(float_value))
    else:
        # Для дробных чисел убираем лишние нули в конце
        return str(float_value).rstrip('0').rstrip('.')

# Обработчики для reply keyboard кнопок
@dp.message(F.text == "📝 Создать пост")
async def handle_create_post_button(message: types.Message, state: FSMContext):
    """Обработка нажатия кнопки 'Создать пост' из reply keyboard"""
    await state.set_state(CurrencyInput.waiting_rub_thb)
    await message.answer(
        "📝 Создание нового поста\n\n"
        "Введите курс RUB/THB:",
        reply_markup=remove_keyboard()  # Убираем клавиатуру для удобства ввода
    )

@dp.message(F.text == "🖼️ Превью")
async def handle_preview_button(message: types.Message, state: FSMContext):
    """Обработка нажатия кнопки 'Превью' из reply keyboard"""
    global current_data
    await message.answer("⏳ Генерирую изображение...")
    
    try:
        data_with_timestamp = current_data.copy()
        data_with_timestamp['timestamp'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        image = await generate_image(data_with_timestamp)
        
        preview_keyboard = InlineKeyboardBuilder()
        preview_keyboard.add(InlineKeyboardButton(
            text="✅ Отправить в канал",
            callback_data="send_to_channel"
        ))
        preview_keyboard.add(InlineKeyboardButton(
            text="❌ Отмена",
            callback_data="cancel_preview"
        ))
        preview_keyboard.adjust(1)
        
        image.seek(0)
        await message.answer_photo(
            photo=BufferedInputFile(file=image.read(), filename="preview.png"),
            caption=f"📊 Превью изображения\n\n"
                   f"🕐 Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
                   f"Проверьте изображение и нажмите кнопку для отправки в канал:",
            reply_markup=preview_keyboard.as_markup()
        )
    except Exception as e:
        await message.answer(f"❌ Ошибка при генерации:\n{str(e)}")

@dp.message(F.text == "📊 Данные")
async def handle_data_button(message: types.Message):
    """Обработка нажатия кнопки 'Данные' из reply keyboard"""
    global current_data
    details = f"RUB/THB: {current_data.get('rub_thb', 'N/A')}\n"
    details += f"USDT/THB: {current_data.get('tb', 'N/A')}\n"
    details += f"VND/RUB: {current_data.get('rub_vnd', 'N/A')}\n"
    details += f"USDT/VND: {current_data.get('td', 'N/A')}"
    await message.answer(f"📊 Текущие курсы валют:\n\n{details}")

# Обработчики для ввода курсов
@dp.message(StateFilter(CurrencyInput.waiting_rub_thb))
async def process_rub_thb(message: types.Message, state: FSMContext):
    """Обработка ввода RUB/THB"""
    try:
        value = float(message.text.replace(',', '.'))
        formatted_value = format_currency_value(value)
        await state.update_data(rub_thb=formatted_value)
        await state.set_state(CurrencyInput.waiting_tb)
        await message.answer(f"✅ RUB/THB: {formatted_value}\n\nВведите курс USDT/THB:")
    except ValueError:
        await message.answer("❌ Неверный формат. Введите число (например: 2.72):")

@dp.message(StateFilter(CurrencyInput.waiting_tb))
async def process_tb(message: types.Message, state: FSMContext):
    """Обработка ввода USDT/THB"""
    try:
        value = float(message.text.replace(',', '.'))
        formatted_value = format_currency_value(value)
        await state.update_data(tb=formatted_value)
        await state.set_state(CurrencyInput.waiting_rub_vnd)
        await message.answer(f"✅ USDT/THB: {formatted_value}\n\nВведите курс VND/RUB:")
    except ValueError:
        await message.answer("❌ Неверный формат. Введите число (например: 30.6):")

@dp.message(StateFilter(CurrencyInput.waiting_rub_vnd))
async def process_rub_vnd(message: types.Message, state: FSMContext):
    """Обработка ввода VND/RUB"""
    try:
        value = float(message.text.replace(',', '.'))
        formatted_value = format_currency_value(value)
        await state.update_data(rub_vnd=formatted_value)
        await state.set_state(CurrencyInput.waiting_td)
        await message.answer(f"✅ VND/RUB: {formatted_value}\n\nВведите курс USDT/VND:")
    except ValueError:
        await message.answer("❌ Неверный формат. Введите число (например: 308):")

@dp.message(StateFilter(CurrencyInput.waiting_td))
async def process_td(message: types.Message, state: FSMContext):
    """Обработка ввода USDT/VND и генерация превью"""
    try:
        value = float(message.text.replace(',', '.'))
        formatted_value = format_currency_value(value)
        await state.update_data(td=formatted_value)
        
        # Получаем все данные из state
        state_data = await state.get_data()
        
        # Формируем данные для генерации изображения
        data = {
            'rub_thb': state_data.get('rub_thb', '2.72'),
            'tb': state_data.get('tb', '30.6'),
            'rub_vnd': state_data.get('rub_vnd', '308'),
            'td': state_data.get('td', '25800'),
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Генерируем изображение
        await message.answer("⏳ Генерирую изображение...")
        try:
            print(f"DEBUG: Генерирую изображение с данными: {data}")
            image = await generate_image(data)
            # Убеждаемся, что позиция файла в начале
            image.seek(0)
            print(f"DEBUG: Изображение сгенерировано, размер: {len(image.getvalue())} байт")
        except Exception as e:
            error_msg = f"❌ Ошибка генерации изображения: {str(e)}"
            print(f"DEBUG ERROR: {error_msg}")
            import traceback
            traceback.print_exc()
            await message.answer(error_msg)
            return
        
        # Сохраняем данные в state для отправки в канал
        await state.update_data(image_data=data)
        
        # Создаем URL кнопки для поста (как в канале)
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
        
        # Создаем клавиатуру для управления превью
        preview_keyboard = InlineKeyboardBuilder()
        preview_keyboard.add(InlineKeyboardButton(
            text="✅ Отправить в канал",
            callback_data="send_to_channel"
        ))
        preview_keyboard.add(InlineKeyboardButton(
            text="❌ Отмена",
            callback_data="cancel_preview"
        ))
        preview_keyboard.adjust(1)
        
        # Показываем превью с URL кнопками (как будет в канале)
        try:
            # Сбрасываем позицию перед отправкой
            image.seek(0)
            print(f"DEBUG: Отправляю превью, размер изображения: {len(image.getvalue())} байт")
            await message.answer_photo(
                photo=BufferedInputFile(file=image.read(), filename="preview.png"),
                reply_markup=url_keyboard.as_markup()
            )
            print("DEBUG: Превью отправлено успешно")
        except Exception as e:
            error_msg = f"❌ Ошибка отправки превью: {str(e)}"
            print(f"DEBUG ERROR: {error_msg}")
            import traceback
            traceback.print_exc()
            await message.answer(error_msg)
            return
        
        # Отправляем сообщение с кнопками управления
        await message.answer(
            "📊 Превью поста с URL кнопками\n\n"
            "Проверьте изображение и нажмите кнопку для отправки в канал:",
            reply_markup=preview_keyboard.as_markup()
        )
        
        # Оставляем состояние для отправки в канал
        await state.set_state(CurrencyInput.waiting_td)
        
        # Показываем reply keyboard после завершения ввода
        await message.answer(
            "💡 Используйте кнопки под полем ввода для быстрого доступа:",
            reply_markup=get_main_keyboard()
        )
        
    except ValueError:
        await message.answer("❌ Неверный формат. Введите число (например: 25800):")
    except Exception as e:
        await message.answer(f"❌ Ошибка: {str(e)}")
        import traceback
        traceback.print_exc()

@dp.callback_query(F.data == "generate_preview")
async def generate_preview_callback(callback: types.CallbackQuery, state: FSMContext):
    """Генерирует превью с текущими данными"""
    await callback.answer("Генерирую превью...")
    global current_data
    
    try:
        await callback.message.answer("⏳ Генерирую изображение...")
        
        # Добавляем timestamp к данным
        data_with_timestamp = current_data.copy()
        data_with_timestamp['timestamp'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Генерируем изображение
        image = await generate_image(data_with_timestamp)
        
        # Создаем клавиатуру для превью
        preview_keyboard = InlineKeyboardBuilder()
        preview_keyboard.add(InlineKeyboardButton(
            text="✅ Отправить в канал",
            callback_data="send_to_channel"
        ))
        preview_keyboard.add(InlineKeyboardButton(
            text="❌ Отмена",
            callback_data="cancel_preview"
        ))
        preview_keyboard.adjust(1)
        
        # Показываем превью пользователю
        image.seek(0)
        await callback.message.answer_photo(
            photo=BufferedInputFile(file=image.read(), filename="preview.png"),
            caption=f"📊 Превью изображения\n\n"
                   f"🕐 Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
                   f"Проверьте изображение и нажмите кнопку для отправки в канал:",
            reply_markup=preview_keyboard.as_markup()
        )
        
    except Exception as e:
        error_msg = str(e)
        import traceback
        traceback.print_exc()
        await callback.message.answer(
            f"❌ Ошибка при генерации:\n{error_msg}"
        )

@dp.callback_query()
async def handle_callback(callback: types.CallbackQuery, state: FSMContext):
    """Обработка нажатий на инлайн кнопки"""
    global current_data
    
    # Пропускаем обработку, если callback уже обработан специфичным обработчиком
    # (create_post и generate_preview обрабатываются отдельно)
    if callback.data in ["create_post", "generate_preview"]:
        return
    
    action = callback.data
    
    if action == "send_to_channel":
        # Отправляем изображение в канал
        await callback.answer("⏳ Отправляю в канал...")
        
        try:
            # Получаем данные из state или используем current_data
            state_data = await state.get_data()
            if state_data and 'image_data' in state_data:
                data = state_data['image_data']
            else:
                data = current_data.copy()
                data['timestamp'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Генерируем изображение
            image = await generate_image(data)
            # Убеждаемся, что позиция файла в начале
            image.seek(0)
            
            # Создаем URL кнопки для поста в канале
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
            
            # Отправляем в канал (только картинка и URL кнопки, без caption)
            image.seek(0)  # Сбрасываем позицию перед отправкой
            await bot.send_photo(
                chat_id=config.CHANNEL_ID,
                photo=BufferedInputFile(file=image.read(), filename="update.png"),
                reply_markup=url_keyboard.as_markup()
            )
            
            await callback.message.answer(
                "✅ Изображение успешно отправлено в канал!",
                reply_markup=get_main_keyboard()
            )
            
            # Обновляем current_data и очищаем состояние
            current_data = {k: v for k, v in data.items() if k != 'timestamp'}
            await state.clear()
            
        except Exception as e:
            error_msg = str(e)
            import traceback
            traceback.print_exc()
            await callback.message.answer(
                f"❌ Ошибка при отправке в канал:\n{error_msg}\n\n"
            f"Проверьте:\n"
            f"1. Бот добавлен как администратор в канал\n"
            f"2. CHANNEL_ID указан правильно в .env\n"
            f"3. Бот имеет права на отправку сообщений"
        )

    elif action == "cancel_preview":
        # Отменяем превью
        await callback.answer("❌ Отправка отменена")
        try:
            await callback.message.delete()
        except:
            pass
        await state.clear()
    
    elif action == "update_data":
        # Обновляем данные
        await callback.answer("🔄 Обновляю данные...")
        import random
        current_data['rub_thb'] = format_currency_value(2.70 + random.uniform(-0.1, 0.1))
        current_data['tb'] = format_currency_value(30.5 + random.uniform(-0.5, 0.5))
        current_data['rub_vnd'] = format_currency_value(int(308 + random.uniform(-5, 5)))
        current_data['td'] = format_currency_value(int(25800 + random.uniform(-100, 100)))
        
        # Обновляем сообщение с новыми данными
        keyboard = InlineKeyboardBuilder()
        keyboard.add(InlineKeyboardButton(
            text="📝 Создать пост",
            callback_data="create_post"
        ))
        keyboard.add(InlineKeyboardButton(
            text="🔄 Обновить данные",
            callback_data="update_data"
        ))
        keyboard.add(InlineKeyboardButton(
            text="📊 Показать текущие данные",
            callback_data="show_current_data"
        ))
        keyboard.add(InlineKeyboardButton(
            text="🖼️ Сгенерировать превью",
            callback_data="generate_preview"
        ))
        keyboard.adjust(2, 2)
        
        details = f"RUB/THB: {current_data.get('rub_thb', 'N/A')}\n"
        details += f"USDT/THB: {current_data.get('tb', 'N/A')}\n"
        details += f"VND/RUB: {current_data.get('rub_vnd', 'N/A')}\n"
        details += f"USDT/VND: {current_data.get('td', 'N/A')}"
        
        try:
            await callback.message.edit_text(
                f"✅ Данные обновлены!\n\n"
                f"📊 Текущие курсы валют:\n\n{details}\n\n"
                f"Используйте кнопки для управления:",
                reply_markup=keyboard.as_markup()
            )
        except:
            await callback.message.answer(
                f"✅ Данные обновлены!\n\n"
                f"📊 Текущие курсы валют:\n\n{details}\n\n"
                f"Используйте кнопки для управления:",
                reply_markup=keyboard.as_markup()
            )
    
    elif action == "show_current_data":
        details = f"RUB/THB: {current_data.get('rub_thb', 'N/A')}\n"
        details += f"USDT/THB: {current_data.get('tb', 'N/A')}\n"
        details += f"VND/RUB: {current_data.get('rub_vnd', 'N/A')}\n"
        details += f"USDT/VND: {current_data.get('td', 'N/A')}"
        await callback.answer(f"📊 Текущие курсы:\n\n{details}", show_alert=True)
    
    # Старые обработчики refresh_data, show_details, delete_post удалены
    # В канале теперь только URL кнопки
    
    else:
        await callback.answer()

async def main():
    import os
    import sys
    
    # Защита от множественных запусков
    lock_file = "bot.lock"
    if os.path.exists(lock_file):
        print("❌ Бот уже запущен! (найден lock файл)")
        print("   Если бот не работает, удалите файл: rm bot.lock")
        sys.exit(1)
    
    # Создаем lock файл
    with open(lock_file, "w") as f:
        f.write(str(os.getpid()))
    
    try:
        print("🚀 Бот запущен...")
        print(f"📢 Канал: {config.CHANNEL_ID}")
        print(f"🔒 Lock файл создан: {lock_file}")
        print("✅ Ожидаю обновления...")
        await dp.start_polling(bot)
    except KeyboardInterrupt:
        print("\n⏹️ Бот остановлен")
    except Exception as e:
        print(f"❌ КРИТИЧЕСКАЯ ОШИБКА: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # Удаляем lock файл при выходе
        if os.path.exists(lock_file):
            os.remove(lock_file)
        await bot.session.close()

if __name__ == "__main__":
    asyncio.run(main())
