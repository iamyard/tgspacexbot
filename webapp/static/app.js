// Telegram WebApp API
let tg;
try {
    tg = window.Telegram?.WebApp;
} catch (e) {
    console.error('Telegram WebApp API не доступен:', e);
}

// Инициализация Telegram Mini App
if (tg) {
    tg.ready();
    tg.expand();

    // Запрос полноэкранного режима
    if (tg.requestFullscreen) {
        tg.requestFullscreen();
    }

    // Включение подтверждения закрытия
    tg.enableClosingConfirmation();

    // Установка цветов темы
    tg.setHeaderColor('secondary_bg_color');
    tg.setBackgroundColor('#000000');
} else {
    console.warn('Telegram WebApp API не найден. Работаем в режиме отладки.');
}

// Splash Screen - скрываем через 1 секунду после загрузки
function hideSplashScreen() {
    const splash = document.getElementById('splashScreen');
    if (splash) {
        splash.classList.add('hidden');
        splash.style.display = 'none';
        console.log('✅ Splash screen скрыт');
        
        // Убеждаемся, что главный экран виден
        const homeScreen = document.getElementById('homeScreen');
        if (homeScreen) {
            homeScreen.classList.add('active');
            console.log('✅ Главный экран активирован');
        }
    } else {
        console.warn('⚠️ Splash screen элемент не найден');
    }
}

// Убеждаемся, что DOM загружен перед скрытием splash screen
function initSplashScreen() {
    const init = () => {
        // Скрываем через 1 секунду после загрузки
        setTimeout(hideSplashScreen, 1000);
        
        // Принудительное скрытие через 2 секунды на случай ошибок
        setTimeout(() => {
            const splash = document.getElementById('splashScreen');
            if (splash && !splash.classList.contains('hidden')) {
                console.warn('⚠️ Принудительное скрытие splash screen');
                splash.classList.add('hidden');
                splash.style.display = 'none';
                
                // Убеждаемся, что главный экран виден
                const homeScreen = document.getElementById('homeScreen');
                if (homeScreen) {
                    homeScreen.classList.add('active');
                }
            }
        }, 2000);
    };
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        // DOM уже загружен
        init();
    }
}

// Инициализируем splash screen
initSplashScreen();

// Инициализация Lucide иконок
function initializeApp() {
    try {
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
        // Загружаем дату и время
        if (typeof updateDateTime === 'function') {
            updateDateTime();
            // Обновляем время каждую минуту
            setInterval(updateDateTime, 60000);
        }
    } catch (e) {
        console.error('Ошибка инициализации:', e);
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeApp);
} else {
    initializeApp();
}

// Инициализация иконок при динамическом добавлении элементов
function refreshIcons() {
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
}

// Вызываем сразу для первоначальных иконок
setTimeout(refreshIcons, 100);

// Success Alert
function showSuccessAlert() {
    const successAlert = document.getElementById('successAlert');
    const alertOkBtn = document.getElementById('alertOkBtn');
    const alertStoryBtn = document.getElementById('alertStoryBtn');
    
    successAlert.classList.remove('hidden');
    
    // Инициализируем иконки
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
    
    // Кнопка "Сделать Stories" - переход на экран сторис (первая кнопка)
    alertStoryBtn.onclick = async () => {
        if (tg.HapticFeedback) {
            tg.HapticFeedback.impactOccurred('medium');
        }
        successAlert.classList.add('hidden');
        
        // Генерируем превью сторис и переходим на экран
        await generateStoryPreview();
    };
    
    // Кнопка "Хорошо" - возврат на главный экран (вторая кнопка)
    alertOkBtn.onclick = () => {
        if (tg.HapticFeedback) {
            tg.HapticFeedback.impactOccurred('light');
        }
        successAlert.classList.add('hidden');
        navigateToScreen('home');
    };
}

// Обновление даты и времени
function updateDateTime() {
    const now = new Date();
    
    // Массив названий месяцев
    const months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    
    // Форматируем дату: Д месяц ГГГГ
    const day = now.getDate();
    const month = months[now.getMonth()];
    const year = now.getFullYear();
    const dateStr = `${day} ${month} ${year}`;
    
    // Форматируем время: ЧЧ:ММ
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const timeStr = `${hours}:${minutes}`;
    
    // Обновляем DOM
    const dateEl = document.getElementById('currentDate');
    const timeEl = document.getElementById('currentTime');
    
    if (dateEl) dateEl.textContent = dateStr;
    if (timeEl) timeEl.textContent = timeStr;
}

// Элементы DOM
const form = document.getElementById('currencyForm');
const publishPostBtn = document.getElementById('publishPostBtn');
const previewStoryBtn = document.getElementById('previewStoryBtn');
const sendPostBtn = document.getElementById('sendPostBtn');
const editPostBtn = document.getElementById('editPostBtn');
const sendStoryBtn = document.getElementById('sendStoryBtn');
const loadingOverlay = document.getElementById('loadingOverlay');

// Экраны
const homeScreen = document.getElementById('homeScreen');
const previewScreen = document.getElementById('previewScreen');
const storyScreen = document.getElementById('storyScreen');
const previewImage = document.getElementById('previewImage');
const storyImage = document.getElementById('storyImage');

// API базовый URL
const API_BASE_URL = window.location.origin;

// Текущий экран
let currentScreen = 'home';
const screenHistory = ['home'];

// Навигация между экранами
function navigateToScreen(screenName) {
    const screens = {
        home: homeScreen,
        preview: previewScreen,
        story: storyScreen
    };
    
    // Убираем active у текущего экрана
    Object.values(screens).forEach(screen => {
        screen.classList.remove('active', 'prev');
    });
    
    // Добавляем prev классы для анимации
    if (currentScreen !== screenName) {
        const currentScreenEl = screens[currentScreen];
        if (currentScreenEl) {
            currentScreenEl.classList.add('prev');
        }
    }
    
    // Активируем новый экран
    setTimeout(() => {
        screens[screenName].classList.add('active');
    }, 50);
    
    // Обновляем историю
    if (screenName !== currentScreen) {
        screenHistory.push(screenName);
    }
    currentScreen = screenName;
    
    // Управление кнопкой "Назад" в Telegram
    if (screenName === 'home') {
        tg.BackButton.hide();
    } else {
        tg.BackButton.show();
    }
}

// Обработчик кнопки "Назад" в Telegram
tg.BackButton.onClick(() => {
    goBack();
});

function goBack() {
    if (screenHistory.length > 1) {
        screenHistory.pop(); // Убираем текущий экран
        const previousScreen = screenHistory[screenHistory.length - 1];
        currentScreen = previousScreen;
        navigateToScreen(previousScreen);
    }
}

// Показ сообщения
function showMessage(text, type = 'success') {
    const messageOverlay = document.getElementById('messageOverlay');
    const messageBox = document.getElementById('messageBox');
    
    messageBox.textContent = text;
    messageBox.className = `message-box ${type}`;
    messageOverlay.classList.remove('hidden');
    
    // Закрытие по клику на оверлей
    messageOverlay.onclick = () => {
        messageOverlay.classList.add('hidden');
    };
    
    // Автозакрытие через 3 секунды
    setTimeout(() => {
        messageOverlay.classList.add('hidden');
    }, 3000);
}

// Показ/скрытие загрузки
function setLoading(show) {
    if (show) {
        loadingOverlay.classList.remove('hidden');
    } else {
        loadingOverlay.classList.add('hidden');
    }
}

// Получение данных формы
function getFormData() {
    return {
        rub_thb: document.getElementById('rub_thb').value,
        tb: document.getElementById('tb').value,
        rub_vnd: document.getElementById('rub_vnd').value,
        td: document.getElementById('td').value
    };
}

// Валидация данных
function validateForm() {
    const data = getFormData();
    for (const [key, value] of Object.entries(data)) {
        if (!value || value.trim() === '') {
            showMessage(`Пожалуйста, заполните все поля`, 'error');
            return false;
        }
    }
    return true;
}

// Генерация превью поста
async function generatePostPreview() {
    if (!validateForm()) {
        return;
    }

    const data = getFormData();
    setLoading(true);

    try {
        const response = await fetch(`${API_BASE_URL}/api/generate-preview`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: data,
                type: 'post'
            })
        });

        const result = await response.json();

        if (result.success) {
            previewImage.src = result.image;
            navigateToScreen('preview');
            
            // Haptic feedback
            if (tg.HapticFeedback) {
                tg.HapticFeedback.impactOccurred('light');
            }
        } else {
            showMessage('Ошибка при генерации превью', 'error');
        }
    } catch (error) {
        console.error('Error:', error);
        showMessage('Ошибка соединения с сервером', 'error');
    } finally {
        setLoading(false);
    }
}

// Генерация превью сторис
async function generateStoryPreview() {
    if (!validateForm()) {
        return;
    }

    const data = getFormData();
    setLoading(true);

    try {
        const response = await fetch(`${API_BASE_URL}/api/generate-preview`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: data,
                type: 'story'
            })
        });

        const result = await response.json();

        if (result.success) {
            storyImage.src = result.image;
            navigateToScreen('story');
            
            // Haptic feedback
            if (tg.HapticFeedback) {
                tg.HapticFeedback.impactOccurred('light');
            }
        } else {
            showMessage('Ошибка при генерации превью', 'error');
        }
    } catch (error) {
        console.error('Error:', error);
        showMessage('Ошибка соединения с сервером', 'error');
    } finally {
        setLoading(false);
    }
}

// Отправка поста в канал
async function sendPostToChannel() {
    const data = getFormData();
    setLoading(true);

    try {
        const response = await fetch(`${API_BASE_URL}/api/send-to-channel`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: data,
                type: 'post'
            })
        });

        const result = await response.json();

        if (result.success) {
            // Haptic feedback
            if (tg.HapticFeedback) {
                tg.HapticFeedback.notificationOccurred('success');
            }
            
            // Показываем алерт успеха с выбором действия
            showSuccessAlert();
        } else {
            showMessage('❌ Ошибка при отправке', 'error');
        }
    } catch (error) {
        console.error('Error:', error);
        showMessage('❌ Ошибка соединения с сервером', 'error');
    } finally {
        setLoading(false);
    }
}

// Поделиться сторис через Telegram Stories
async function publishStory() {
    const data = getFormData();
    
    try {
        setLoading(true);
        
        // Проверяем поддержку Telegram Stories API
        if (!tg.shareToStory) {
            showMessage('❌ Ваша версия Telegram не поддерживает публикацию в Stories. Обновите приложение.', 'error');
            setLoading(false);
            return;
        }
        
        // Получаем публичный URL изображения от сервера
        const response = await fetch(`${API_BASE_URL}/api/get-story-url`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: data,
                type: 'story'
            })
        });

        const result = await response.json();

        if (!result.success || !result.url) {
            showMessage('❌ Не удалось получить изображение', 'error');
            setLoading(false);
            return;
        }
        
        // Формируем полный URL
        const fullUrl = `${window.location.origin}${result.url}`;
        
        // Вызываем Telegram API для публикации в Stories
        tg.shareToStory(fullUrl);
        
        // Haptic feedback
        if (tg.HapticFeedback) {
            tg.HapticFeedback.notificationOccurred('success');
        }
        
        // Возвращаемся на главный экран (курсы остаются)
        setTimeout(() => {
            navigateToScreen('home');
        }, 1500);
        
    } catch (error) {
        console.error('Share story error:', error);
        showMessage('❌ Ошибка при публикации: ' + (error.message || 'Неизвестная ошибка'), 'error');
    } finally {
        setLoading(false);
    }
}

// Обработчики событий
// Кнопка "Опубликовать" - генерирует превью и переходит на экран подтверждения
publishPostBtn.addEventListener('click', () => {
    if (tg.HapticFeedback) {
        tg.HapticFeedback.impactOccurred('medium');
    }
    generatePostPreview();
});

// Кнопка с иконкой сторис - показывает превью сторис
previewStoryBtn.addEventListener('click', () => {
    if (tg.HapticFeedback) {
        tg.HapticFeedback.impactOccurred('light');
    }
    generateStoryPreview();
});

// Кнопка "Да" на экране превью - публикует пост
sendPostBtn.addEventListener('click', () => {
    if (tg.HapticFeedback) {
        tg.HapticFeedback.impactOccurred('heavy');
    }
    sendPostToChannel();
});

// Кнопка "Изменить" на экране превью - возврат на главный экран
editPostBtn.addEventListener('click', () => {
    if (tg.HapticFeedback) {
        tg.HapticFeedback.impactOccurred('light');
    }
    navigateToScreen('home');
});

// Кнопка публикации сторис
sendStoryBtn.addEventListener('click', () => {
    if (tg.HapticFeedback) {
        tg.HapticFeedback.impactOccurred('heavy');
    }
    publishStory();
});

// Предотвращение отправки формы по Enter
form.addEventListener('submit', (e) => {
    e.preventDefault();
});

// Инициализация значений по умолчанию (опционально)
document.addEventListener('DOMContentLoaded', () => {
    // Можно загрузить последние значения из localStorage
    const savedData = localStorage.getItem('lastCurrencyData');
    if (savedData) {
        try {
            const data = JSON.parse(savedData);
            document.getElementById('rub_thb').value = data.rub_thb || '';
            document.getElementById('tb').value = data.tb || '';
            document.getElementById('rub_vnd').value = data.rub_vnd || '';
            document.getElementById('td').value = data.td || '';
        } catch (e) {
            console.error('Error loading saved data:', e);
        }
    }
});

// Сохранение данных при изменении
form.addEventListener('input', () => {
    const data = getFormData();
    localStorage.setItem('lastCurrencyData', JSON.stringify(data));
});

// Скрытие клавиатуры при клике вне полей ввода
let isHidingKeyboard = false;

document.addEventListener('touchstart', (e) => {
    // Проверяем, что клик был не по интерактивным элементам
    const isInteractive = e.target.closest('input, button, a, label, select, textarea');
    
    if (!isInteractive && !isHidingKeyboard) {
        // Убираем фокус с активного элемента
        const activeEl = document.activeElement;
        if (activeEl && activeEl.tagName === 'INPUT') {
            isHidingKeyboard = true;
            activeEl.blur();
            
            // Сбрасываем флаг через короткое время
            setTimeout(() => {
                isHidingKeyboard = false;
            }, 300);
        }
    }
}, { passive: true });

// Скрытие клавиатуры при скролле (с debounce)
let scrollTimeout;
document.querySelectorAll('.screen-main').forEach(main => {
    main.addEventListener('scroll', () => {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(() => {
            const activeEl = document.activeElement;
            if (activeEl && activeEl.tagName === 'INPUT') {
                activeEl.blur();
            }
        }, 100);
    }, { passive: true });
});
