"""Адаптеры выдачи: заход на аккаунт игрока и покупка донат-товара."""

from .base import DeliveryError, GameStoreAdapter, NeedOtpError
from .mock_game import MockGameAdapter
from .registry import AdapterRegistry
from .web_game import WebGameAdapter

__all__ = [
    "AdapterRegistry",
    "DeliveryError",
    "GameStoreAdapter",
    "MockGameAdapter",
    "NeedOtpError",
    "WebGameAdapter",
]
