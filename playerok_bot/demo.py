#!/usr/bin/env python3
"""Демо-прогон: полный диалог «покупатель → бот → выдача» на моках.

    python playerok_bot/demo.py

Показывает, как бот общается с покупателем, принимает доступ к аккаунту,
«заходит» на него (симуляция) и проводит покупку донат-товара.
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from playerokbot.config import AppConfig, BotConfig, ProductConfig
from playerokbot.fulfillment.registry import AdapterRegistry
from playerokbot.marketplace.mock import MockMarketplace
from playerokbot.models import CredentialsMode, Order
from playerokbot.orchestrator import Orchestrator


def build_demo() -> tuple[Orchestrator, MockMarketplace]:
    config = AppConfig(
        bot=BotConfig(shop_name="Aura Store", poll_interval_sec=0.1),
        products=[
            ProductConfig(
                id="pubg-uc-660",
                title="PUBG Mobile 660 UC",
                game="pubg",
                adapter="mock_game",
                credentials_mode=CredentialsMode.LOGIN_PASSWORD,
            )
        ],
    )
    marketplace = MockMarketplace()
    marketplace.register_order(
        Order(
            id="42137",
            chat_id="buyer-1",
            product_id="pubg-uc-660",
            title="PUBG Mobile 660 UC",
            game="pubg",
        )
    )
    registry = AdapterRegistry({"outcome": "success", "delay_sec": 0.3})
    return Orchestrator(config, marketplace, registry), marketplace


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    orch, market = build_demo()

    script = [
        "Привет! Купил 660 UC, что делать дальше?",
        "да",
        "логин: player1 пароль: qwerty123",
    ]
    print("=== Демо: диалог с покупателем ===\n")
    for line in script:
        print(f"ПОКУПАТЕЛЬ > {line}")
        market.push("buyer-1", line)
        orch.run_once()
        for text in market.bot_texts("buyer-1"):
            print(f"БОТ       > {text}")
        market.sent.clear()
        time.sleep(0.2)

    # Ждём завершения фоновой выдачи и подводим итог.
    orch.join_workers(timeout=10)
    orch.run_once()
    for text in market.bot_texts("buyer-1"):
        print(f"БОТ       > {text}")
    market.sent.clear()

    print("\nПОКУПАТЕЛЬ > спасибо!")
    market.push("buyer-1", "спасибо!")
    orch.run_once()
    for text in market.bot_texts("buyer-1"):
        print(f"БОТ       > {text}")

    print("\n=== Сделки ===")
    for chat_id, success, note in market.closed:
        print(f"чат {chat_id}: {'успех' if success else 'проблема'} {note}")

    print("\n=== Учётные данные в хранилище после заказа ===")
    print(f"записей в vault: {len(orch.vault)} (0 — секреты стёрты)")
    orch.vault.clear()


if __name__ == "__main__":
    main()
