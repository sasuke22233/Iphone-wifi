"""Реестр адаптеров выдачи по имени."""

from __future__ import annotations

from typing import Any, Callable

from .base import GameStoreAdapter
from .mock_game import MockGameAdapter
from .web_game import WebGameAdapter

_FACTORIES: dict[str, Callable[[dict[str, Any]], GameStoreAdapter]] = {
    "mock_game": lambda opts: MockGameAdapter(opts),
    "web_game": lambda opts: WebGameAdapter(opts),
}


class AdapterRegistry:
    """Создаёт адаптеры по имени из конфига (``adapter = "web_game"``)."""

    def __init__(self, shared_options: dict[str, Any] | None = None) -> None:
        self._shared = shared_options or {}
        self._cache: dict[str, GameStoreAdapter] = {}

    def register(self, name: str, factory: Callable[[dict[str, Any]], GameStoreAdapter]) -> None:
        _FACTORIES[name] = factory

    def get(self, name: str, overrides: dict[str, Any] | None = None) -> GameStoreAdapter:
        if name not in _FACTORIES:
            raise KeyError(f"Неизвестный адаптер выдачи: {name!r}")
        if name not in self._cache:
            options = {**self._shared, **(overrides or {})}
            self._cache[name] = _FACTORIES[name](options)
        return self._cache[name]
