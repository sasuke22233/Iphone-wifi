"""Мок площадки для тестов, демо и локального прогона без Playerok."""

from __future__ import annotations

import queue
import threading

from ..models import InboundMessage, Order, OutboundMessage
from .base import MarketplaceClient


class MockMarketplace(MarketplaceClient):
    """In-memory очередь сообщений: удобно драйвить сценарии из тестов."""

    def __init__(self) -> None:
        self._inbox: queue.SimpleQueue[InboundMessage] = queue.SimpleQueue()
        self.sent: list[OutboundMessage] = []
        self.orders: dict[str, Order] = {}
        self.closed: list[tuple[str, bool, str]] = []
        self._seq = 0

    # --------------------------------------------------------- test helpers

    def push(self, chat_id: str, text: str, sender: str = "buyer") -> InboundMessage:
        self._seq += 1
        msg = InboundMessage(id=f"m{self._seq}", chat_id=chat_id, sender=sender, text=text)
        self._inbox.put(msg)
        return msg

    def register_order(self, order: Order) -> None:
        self.orders[order.chat_id] = order

    # ------------------------------------------------------------ interface

    def fetch_unanswered(self) -> list[InboundMessage]:
        out: list[InboundMessage] = []
        while True:
            try:
                out.append(self._inbox.get_nowait())
            except queue.Empty:
                return out

    def send(self, chat_id: str, text: str) -> None:
        self.sent.append(OutboundMessage(chat_id=chat_id, text=text))

    def get_order(self, chat_id: str) -> Order | None:
        return self.orders.get(chat_id)

    def close_deal(self, chat_id: str, success: bool, note: str = "") -> None:
        self.closed.append((chat_id, success, note))

    def bot_texts(self, chat_id: str | None = None) -> list[str]:
        return [m.text for m in self.sent if chat_id is None or m.chat_id == chat_id]


class StdioMarketplace(MarketplaceClient):
    """Интерактивный режим: вы пишете как покупатель в терминале, бот отвечает.

    Заказ фиксирован (передаётся в конструкторе) — удобно попробовать диалог
    и логику выдачи (через mock-адаптер игры) без реальной площадки.
    """

    def __init__(self, order: Order) -> None:
        self.order = order
        self._inbox: queue.SimpleQueue[InboundMessage] = queue.SimpleQueue()
        self._stop = threading.Event()
        self._seq = 0
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    def _read_loop(self) -> None:
        print("=== Режим покупателя: пишите сообщения, Ctrl+C или /exit — выход ===")
        while not self._stop.is_set():
            try:
                line = input("ВЫ > ")
            except (EOFError, KeyboardInterrupt):
                self._stop.set()
                break
            if line.strip().lower() in {"/exit", "/quit", "exit"}:
                self._stop.set()
                break
            self._seq += 1
            self._inbox.put(
                InboundMessage(id=f"local{self._seq}", chat_id=self.order.chat_id, sender="buyer", text=line)
            )

    def fetch_unanswered(self) -> list[InboundMessage]:
        out: list[InboundMessage] = []
        while True:
            try:
                out.append(self._inbox.get(timeout=0.2))
            except queue.Empty:
                return out

    def send(self, chat_id: str, text: str) -> None:
        for line in text.splitlines() or [text]:
            print(f"БОТ > {line}")

    def get_order(self, chat_id: str) -> Order | None:
        return self.order

    def close_deal(self, chat_id: str, success: bool, note: str = "") -> None:
        status = "выполнен ✅" if success else "передан оператору ⚠️"
        print(f"БОТ > [сделка {status}]" + (f" ({note})" if note else ""))

    def stop(self) -> None:
        self._stop.set()
