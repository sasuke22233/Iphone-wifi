"""Интерфейс игрового адаптера: вход на аккаунт игрока + покупка доната."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Callable

from ..models import Credentials, DeliveryResult, Order


class DeliveryError(Exception):
    """Ошибка выдачи. ``reason`` — безопасное описание для покупателя."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


class NeedOtpError(DeliveryError):
    """Игра запросила одноразовый код — бот должен спросить его у покупателя."""

    def __init__(self) -> None:
        super().__init__("need_otp")


class GameStoreAdapter(ABC):
    """Выполняет заказ на игровом аккаунте покупателя.

    Адаптер получает учётные данные **только из памяти**, обязан:
    * не логировать и не сохранять пароли;
    * по завершении ничего не хранить (``creds.zero()`` вызывает оркестратор);
    * кидать :class:`DeliveryError` с человекочитаемой причиной.
    """

    name: str = "base"

    @abstractmethod
    def deliver(
        self,
        order: Order,
        creds: Credentials,
        progress: Callable[[str], None] | None = None,
    ) -> DeliveryResult:
        """Заходит на аккаунт и проводит покупку/зачисление донат-товара."""

    def _progress(self, cb: Callable[[str], None] | None, text: str) -> None:
        if cb is not None:
            cb(text)
