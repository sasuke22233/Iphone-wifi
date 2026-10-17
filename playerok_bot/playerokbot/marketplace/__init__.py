"""Адаптеры площадки продаж (Playerok и др.)."""

from .base import MarketplaceClient
from .mock import MockMarketplace, StdioMarketplace

__all__ = ["MarketplaceClient", "MockMarketplace", "StdioMarketplace"]
