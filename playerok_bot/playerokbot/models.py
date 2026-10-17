"""Доменные модели: заказ, сообщения, учётные данные, результат выдачи."""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum


class CredentialsMode(str, Enum):
    """Какие данные доступа нужны для выдачи конкретного товара."""

    LOGIN = "login"  # только логин/ID игрока (например, пополнение по Player ID)
    LOGIN_PASSWORD = "login_password"  # логин + пароль
    LOGIN_PASSWORD_OTP = "login_password_otp"  # логин + пароль + одноразовый код


class State(str, Enum):
    """Состояние диалога с покупателем (FSM)."""

    NEW = "new"
    AWAITING_ORDER_CONFIRM = "awaiting_order_confirm"
    AWAITING_LOGIN = "awaiting_login"
    AWAITING_PASSWORD = "awaiting_password"
    AWAITING_OTP = "awaiting_otp"
    PROCESSING = "processing"
    DONE = "done"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Action(str, Enum):
    """Действие, которое оркестратор должен выполнить после ответа диалога."""

    NONE = "none"
    START_FULFILLMENT = "start_fulfillment"  # запустить выдачу (покупку доната)
    CANCEL = "cancel"


def mask(value: str, keep: int = 2) -> str:
    """Маскирует значение для безопасного вывода в логи/сообщения.

    ``player123`` -> ``pl******23``; короткие значения полностью скрываются.
    """
    if not value:
        return "***"
    if len(value) <= keep * 2:
        return "*" * len(value)
    return value[:keep] + "*" * (len(value) - keep * 2) + value[-keep:]


@dataclass
class Credentials:
    """Учётные данные игрового аккаунта, присланные покупателем.

    Внимание: ``__repr__``/``__str__`` всегда маскируют значения, чтобы пароль
    случайно не попал в логи. После использования вызывайте :meth:`zero`.
    """

    login: str = ""
    password: str = ""
    otp: str = ""

    def is_login_ready(self) -> bool:
        return bool(self.login)

    def is_password_ready(self) -> bool:
        return bool(self.password)

    def is_otp_ready(self) -> bool:
        return bool(self.otp)

    def redacted(self) -> str:
        otp_state = "set" if self.otp else "-"
        return f"Credentials(login={mask(self.login)}, password=***, otp={otp_state})"

    def __repr__(self) -> str:  # pragma: no cover - защита от утечки в логи
        return self.redacted()

    def __str__(self) -> str:  # pragma: no cover
        return self.redacted()

    def zero(self) -> None:
        """Обнуляет секреты (использовать после завершения выдачи)."""
        self.password = ""
        self.otp = ""


@dataclass
class Order:
    """Заказ на донат-товар, привязанный к чату с покупателем."""

    id: str
    chat_id: str
    product_id: str
    title: str
    game: str
    adapter: str = "mock_game"
    credentials_mode: CredentialsMode = CredentialsMode.LOGIN_PASSWORD
    quantity: int = 1
    buyer_name: str = ""


@dataclass
class InboundMessage:
    """Входящее сообщение из чата площадки."""

    id: str
    chat_id: str
    sender: str  # "buyer" или имя пользователя
    text: str
    timestamp: float = field(default_factory=time.time)


@dataclass
class OutboundMessage:
    """Исходящее сообщение, которое бот отправляет в чат."""

    chat_id: str
    text: str


@dataclass
class DeliveryResult:
    """Результат выдачи товара (захода на аккаунт и покупки доната)."""

    ok: bool
    reason: str = ""
    receipt: str = ""  # номер транзакции/чек внутри игры, если есть
