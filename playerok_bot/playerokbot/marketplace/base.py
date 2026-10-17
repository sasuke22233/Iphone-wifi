"""Интерфейс площадки: получение сообщений покупателей и отправка ответов."""

from __future__ import annotations

from abc import ABC, abstractmethod

from ..models import InboundMessage, Order


class MarketplaceClient(ABC):
    """Контракт интеграции с торговой площадкой (например, Playerok).

    Реализация должна:
    * отдавать только ещё не обработанные входящие сообщения;
    * уметь отправлять ответ в конкретный чат;
    * уметь подгружать заказ, привязанный к чату;
    * уметь закрывать сделку («заказ выполнен» / спор / отмена).
    """

    @abstractmethod
    def fetch_unanswered(self) -> list[InboundMessage]:
        """Возвращает новые сообщения покупателей (очередь пустеет)."""

    @abstractmethod
    def send(self, chat_id: str, text: str) -> None:
        """Отправляет сообщение в чат покупателя."""

    @abstractmethod
    def get_order(self, chat_id: str) -> Order | None:
        """Заказ, привязанный к чату (или None, если неизвестен)."""

    @abstractmethod
    def close_deal(self, chat_id: str, success: bool, note: str = "") -> None:
        """Помечает сделку выполненной или передаёт её оператору/в спор."""

    def name(self) -> str:
        return type(self).__name__
