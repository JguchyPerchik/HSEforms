"""
Telegram-бот HSE Forms.

Делает одну простую, но критически важную для Mini App вещь — выдаёт
пользователю кнопку типа `web_app`, через которую открывается наш
сайт. Это единственный способ, которым клиент Telegram согласится
передать в WebView themeParams (цвета клиента) и initData (подписанные
данные пользователя). Любая обычная inline-кнопка с `url=` откроет
hseforms.ru как внешнюю страницу: ни темы, ни авторизации там не будет.

Бот живёт в отдельном docker-контейнере (`bot/`) и не имеет HTTP-портов
наружу — он только long-poll'ит Telegram Bot API. TELEGRAM_BOT_TOKEN
переиспользуется тот же, что использует бэкенд для HMAC-валидации
initData в `core/telegram.py` — иначе подпись на бэке не сойдётся
и привязки Telegram-аккаунта к нашему User не будет.

WEB_APP_URL обязан указывать на корень фронтенда (https://hseforms.ru),
а не на конкретный экран. Глубокие ссылки на конкретный опрос
решаются через GoRouter уже на стороне Flutter, после открытия Mini App.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys

from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    MenuButtonWebApp,
    Message,
    WebAppInfo,
)


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("hseforms.bot")


BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
WEB_APP_URL = os.environ.get("WEB_APP_URL", "https://hseforms.ru").strip()

if not BOT_TOKEN:
    # Без токена смысла стартовать нет — лучше упасть громко при
    # запуске, чем тихо висеть и ничего не отвечать.
    log.error("TELEGRAM_BOT_TOKEN не задан — бот не может стартовать")
    sys.exit(1)

if not WEB_APP_URL.startswith("https://"):
    # Telegram категорически не открывает web_app по http:// — даже
    # localhost. Лучше упасть на старте, чем разбираться, почему
    # «кнопка не работает» в проде.
    log.error("WEB_APP_URL должен быть HTTPS, получено: %s", WEB_APP_URL)
    sys.exit(1)


dp = Dispatcher()


def _open_kb() -> InlineKeyboardMarkup:
    """Inline-кнопка типа `web_app`. ИМЕННО `web_app`, не `url`:
    только этот тип триггерит Telegram передать в WebView initData
    и themeParams. Любая `url`-кнопка открывает обычный браузер
    внутри Telegram (или системный), и Mini App-режима там нет."""
    return InlineKeyboardMarkup(inline_keyboard=[[
        InlineKeyboardButton(
            text="📋 Открыть HSE Forms",
            web_app=WebAppInfo(url=WEB_APP_URL),
        )
    ]])


@dp.message(CommandStart())
async def cmd_start(message: Message) -> None:
    """Главная точка входа. Любой /start — включая deep-link вида
    `/start s_abc123` для приглашений — показывает кнопку запуска
    Mini App. Дальнейшая навигация (открыть конкретный опрос,
    показать аналитику) уже внутри Flutter."""
    await message.answer(
        "Привет! Это <b>HSE Forms</b> — конструктор опросов НИУ ВШЭ.\n\n"
        "Нажмите кнопку ниже, чтобы открыть приложение прямо в Telegram. "
        "Темы клиента (светлая/тёмная) подхватятся автоматически.",
        reply_markup=_open_kb(),
    )


@dp.message(Command("app", "open"))
async def cmd_app(message: Message) -> None:
    """Быстрый шорткат: пользователь уже видел /start однажды и не
    хочет листать историю — отправил /app, получил кнопку запуска."""
    await message.answer("Открыть HSE Forms:", reply_markup=_open_kb())


@dp.message(Command("help"))
async def cmd_help(message: Message) -> None:
    await message.answer(
        "<b>Команды</b>\n"
        "/start — открыть приложение\n"
        "/app — повторить кнопку запуска\n\n"
        "Все опросы создаются и проходятся внутри Mini App. "
        "Если что-то не открывается — напишите owner'у проекта.",
    )


@dp.message(F.text)
async def fallback(message: Message) -> None:
    """На любое произвольное сообщение тоже отдаём кнопку — это
    дешевле для пользователя, чем «команда не распознана»."""
    await message.answer(
        "Я умею только открывать HSE Forms. Вот кнопка:",
        reply_markup=_open_kb(),
    )


async def _set_menu_button(bot: Bot) -> None:
    """Меняет «гамбургер» слева от поля ввода в чате с ботом на
    Menu Button типа web_app. Это самый заметный для пользователя
    способ войти в Mini App — одно касание из любого места истории.
    Telegram запоминает настройку у себя на сервере, так что вызов
    однократный при старте контейнера; повторный вызов идемпотентен."""
    try:
        await bot.set_chat_menu_button(
            menu_button=MenuButtonWebApp(
                text="Открыть",
                web_app=WebAppInfo(url=WEB_APP_URL),
            )
        )
        log.info("Menu button установлен → %s", WEB_APP_URL)
    except Exception as e:
        # Не валим запуск из-за этого: пользователь всё равно сможет
        # запустить Mini App через /start или /app.
        log.warning("Не удалось поставить menu button: %s", e)


async def main() -> None:
    bot = Bot(
        BOT_TOKEN,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    await _set_menu_button(bot)
    log.info("Бот стартует в режиме long-polling, web_app=%s", WEB_APP_URL)
    # allowed_updates=resolve_used_update_types() — фильтрует апдейты
    # на стороне Telegram: получаем только то, что у нас реально есть
    # обработчики (message). Снижает трафик и нагрузку на нас.
    await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        log.info("Бот остановлен")
