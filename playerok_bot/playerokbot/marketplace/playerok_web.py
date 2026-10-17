"""Playwright-адаптер для Playerok (каркас живой интеграции).

ВАЖНО:
* Адаптер работает от **вашего продавец-аккаунта** Playerok (сессия в
  ``storage_state``-файле). Учётные данные покупателей сюда не попадают.
* У Playerok нет публичного API, поэтому интеграция основана на браузерной
  автоматизации. Селекторы задаются в конфиге — их может потребоваться
  подправить под текущую вёрстку сайта.
* Автоматизация чатов может противоречить правилам площадки: используйте
  на свой риск, ставьте человекоподобные задержки и не спамьте.

Для работы: ``pip install playwright && playwright install chromium``.
"""

from __future__ import annotations

import random
import time
from typing import Any

from ..models import InboundMessage, Order
from .base import MarketplaceClient

DEFAULT_SELECTORS: dict[str, str] = {
    "chat_list_item": "[data-chat-id]",           # элемент списка чатов
    "chat_unread_badge": ".unread-badge",          # счётчик непрочитанных
    "message": "[data-message-id]",                # сообщение в чате
    "message_text": ".message-text",               # текст сообщения
    "message_author": ".message-author",           # автор сообщения
    "message_input": "textarea[placeholder]",      # поле ввода ответа
    "send_button": "button[type=submit]",          # кнопка отправки
    "complete_deal_button": "button.deal-complete",  # «заказ выполнен»
}


def _require_playwright():
    try:
        from playwright.sync_api import sync_playwright  # noqa: F401
    except ImportError as exc:  # pragma: no cover - зависит от окружения
        raise RuntimeError(
            "Для живого режима Playerok нужен Playwright: "
            "pip install playwright && playwright install chromium"
        ) from exc


class PlayerokWebClient(MarketplaceClient):
    """Пуллинг чатов Playerok через браузерную автоматизацию."""

    def __init__(self, options: dict[str, Any]) -> None:
        _require_playwright()
        self.base_url: str = options.get("base_url", "https://playerok.com").rstrip("/")
        self.chats_url: str = options.get("chats_url", f"{self.base_url}/chats")
        self.state_file: str = options.get(
            "storage_state", "playerok_bot/state/playerok_session.json"
        )
        self.headless: bool = bool(options.get("headless", True))
        self.typing_delay: tuple[float, float] = tuple(
            options.get("typing_delay_sec", (0.8, 2.5))
        )
        self.selectors = {**DEFAULT_SELECTORS, **(options.get("selectors") or {})}
        self._seen_message_ids: set[str] = set()
        self._playwright = None
        self._browser = None
        self._context = None
        self._page = None

    # ------------------------------------------------------------- lifecycle

    def open(self) -> None:
        """Запускает браузер с сохранённой сессией продавца."""
        from playwright.sync_api import sync_playwright

        self._playwright = sync_playwright().start()
        self._browser = self._playwright.chromium.launch(headless=self.headless)
        self._context = self._browser.new_context(storage_state=self.state_file)
        self._page = self._context.new_page()
        self._page.goto(self.chats_url, wait_until="domcontentloaded")

    def close(self) -> None:
        for obj in (self._context, self._browser, self._playwright):
            if obj is not None:
                try:
                    obj.close() if obj is not self._playwright else obj.stop()
                except Exception:
                    pass
        self._page = None

    # ------------------------------------------------------------ interface

    def fetch_unanswered(self) -> list[InboundMessage]:
        """Сканирует непрочитанные чаты и собирает новые сообщения покупателей."""
        page = self._page
        assert page is not None, "Сначала вызовите open()"
        out: list[InboundMessage] = []
        page.goto(self.chats_url, wait_until="domcontentloaded")

        chats = page.locator(self.selectors["chat_list_item"])
        for i in range(chats.count()):
            item = chats.nth(i)
            unread = item.locator(self.selectors["chat_unread_badge"])
            if unread.count() == 0 or not unread.first.inner_text().strip():
                continue
            chat_id = item.get_attribute("data-chat-id") or f"chat-{i}"
            item.click()
            page.wait_for_load_state("networkidle")
            out.extend(self._read_messages(chat_id))
        return out

    def _read_messages(self, chat_id: str) -> list[InboundMessage]:
        page = self._page
        assert page is not None
        out: list[InboundMessage] = []
        bubbles = page.locator(self.selectors["message"])
        for i in range(bubbles.count()):
            bubble = bubbles.nth(i)
            msg_id = bubble.get_attribute("data-message-id") or f"{chat_id}-{i}"
            if msg_id in self._seen_message_ids:
                continue
            self._seen_message_ids.add(msg_id)
            author = bubble.locator(self.selectors["message_author"])
            author_text = author.first.inner_text().strip() if author.count() else ""
            # Отвечаем только на сообщения покупателя (не свои).
            if author_text.lower() in {"вы", "я", "seller", "продавец"}:
                continue
            text = bubble.locator(self.selectors["message_text"]).first.inner_text().strip()
            out.append(
                InboundMessage(id=msg_id, chat_id=chat_id, sender=author_text or "buyer", text=text)
            )
        return out

    def send(self, chat_id: str, text: str) -> None:
        """Печатает ответ с человекоподобной задержкой и отправляет."""
        page = self._page
        assert page is not None
        box = page.locator(self.selectors["message_input"]).first
        box.click()
        # Имитация набора: посимвольно, с лёгкими паузами.
        delay_ms = random.uniform(*self.typing_delay) * 1000 / max(len(text), 1)
        for ch in text:
            box.type(ch, delay=max(delay_ms, 5))
            time.sleep(0.002)
        time.sleep(random.uniform(*self.typing_delay))
        page.locator(self.selectors["send_button"]).first.click()
        page.wait_for_load_state("networkidle")

    def get_order(self, chat_id: str) -> Order | None:
        """Подтягивает карточку заказа из чата (заголовок и номер)."""
        page = self._page
        assert page is not None
        # Каркас: адаптируйте под текущую вёрстку карточки заказа Playerok.
        title_el = page.locator(".deal-title")
        order_id_el = page.locator(".deal-id")
        if title_el.count() == 0:
            return None
        return Order(
            id=order_id_el.first.inner_text().strip() if order_id_el.count() else chat_id,
            chat_id=chat_id,
            product_id="playerok-item",
            title=title_el.first.inner_text().strip(),
            game=options_game_from_title(title_el.first.inner_text()),
        )

    def close_deal(self, chat_id: str, success: bool, note: str = "") -> None:
        if success:
            btn = self._page.locator(self.selectors["complete_deal_button"])
            if btn.count():
                btn.first.click()
        if note:
            self.send(chat_id, note)


def options_game_from_title(title: str) -> str:
    """Грубое определение игры по названию товара (для выбора адаптера)."""
    t = title.lower()
    for game in ("pubg", "free fire", "genshin", "brawl stars", "roblox", "fortnite"):
        if game in t:
            return game.replace(" ", "_")
    return "generic"
