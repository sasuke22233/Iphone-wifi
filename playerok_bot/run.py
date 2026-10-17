#!/usr/bin/env python3
"""Точка входа бота.

Примеры запуска:

    # интерактивное демо в терминале (без площадки и без интернета):
    python run.py --mock

    # живой режим с конфигом (Playerok + web-адаптеры игр):
    python run.py --config config.toml

    # один цикл опроса (полезно для отладки):
    python run.py --config config.toml --once
"""

from __future__ import annotations

import argparse
import logging
import signal
import sys

from playerokbot.config import load_config
from playerokbot.fulfillment.registry import AdapterRegistry
from playerokbot.marketplace.mock import StdioMarketplace
from playerokbot.models import CredentialsMode, Order
from playerokbot.orchestrator import Orchestrator


def build_marketplace(driver: str, options: dict, order: Order | None = None):
    if driver == "mock":
        assert order is not None
        return StdioMarketplace(order)
    if driver == "playerok_web":
        from playerokbot.marketplace.playerok_web import PlayerokWebClient

        return PlayerokWebClient(options)
    raise SystemExit(f"Неизвестный драйвер площадки: {driver!r} (ожидается mock | playerok_web)")


def main() -> int:
    ap = argparse.ArgumentParser(description="Бот магазина донат-товаров для Playerok")
    ap.add_argument("--config", default="playerok_bot/config.toml", help="путь к TOML-конфигу")
    ap.add_argument("--mock", action="store_true", help="интерактивный режим без площадки")
    ap.add_argument("--once", action="store_true", help="выполнить один цикл опроса и выйти")
    ap.add_argument("-v", "--verbose", action="store_true", help="подробные логи")
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    # Страховка: в логи не должны попадать пароли.
    logging.getLogger().filters.append(_NoSecretsFilter())

    config = load_config(args.config)
    product = config.default_product()

    if args.mock:
        order = Order(
            id="DEMO-1",
            chat_id="local",
            product_id=product.id,
            title=product.title,
            game=product.game,
            adapter=product.adapter if product.adapter != "web_game" else "mock_game",
            credentials_mode=product.credentials_mode,
            quantity=product.quantity,
        )
        marketplace = build_marketplace("mock", {}, order)
    else:
        marketplace = build_marketplace(config.marketplace_driver, config.marketplace_options)

    # В mock-режиме выдачу всегда симулируем, даже если в конфиге web_game.
    registry = AdapterRegistry(config.fulfillment_options)

    orch = Orchestrator(config, marketplace, registry)

    def _sigterm(_sig, _frm):
        orch.stop()

    signal.signal(signal.SIGINT, _sigterm)
    signal.signal(signal.SIGTERM, _sigterm)

    print(f"Бот «{config.bot.shop_name}» запущен (площадка: {marketplace.name()}).")
    try:
        if args.once:
            orch.run_once()
            orch.join_workers(timeout=60)
            orch.run_once()  # забрать результаты выдачи
        else:
            orch.run()
    finally:
        orch.vault.clear()
        if args.mock:
            marketplace.stop()
    return 0


class _NoSecretsFilter(logging.Filter):
    """Не даёт записать в лог строки с паролями (грубая защита от утечек)."""

    _markers = ("password", "пароль", "passwd", "pwd")

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            msg = record.getMessage().lower()
        except Exception:
            return True
        return not any(m in msg for m in self._markers)


if __name__ == "__main__":
    sys.exit(main())
