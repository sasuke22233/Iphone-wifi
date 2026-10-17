"""Загрузка конфигурации бота из TOML-файла (см. ``config.example.toml``)."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from .models import CredentialsMode


@dataclass
class BotConfig:
    shop_name: str = "Магазин"
    poll_interval_sec: float = 5.0
    credential_ttl_min: int = 30
    reminder_after_min: int = 10
    typing_delay_sec: tuple[float, float] = (0.3, 1.2)


@dataclass
class ProductConfig:
    """Товар (донат-пакет), который бот выдаёт."""

    id: str
    title: str
    game: str = "generic"
    adapter: str = "mock_game"
    credentials_mode: CredentialsMode = CredentialsMode.LOGIN_PASSWORD
    quantity: int = 1


@dataclass
class AppConfig:
    bot: BotConfig = field(default_factory=BotConfig)
    marketplace_driver: str = "mock"
    marketplace_options: dict = field(default_factory=dict)
    fulfillment_adapter: str = "mock_game"
    fulfillment_options: dict = field(default_factory=dict)
    products: list[ProductConfig] = field(default_factory=list)
    templates: dict[str, str] = field(default_factory=dict)

    def product_by_id(self, product_id: str) -> ProductConfig | None:
        for p in self.products:
            if p.id == product_id:
                return p
        return None

    def default_product(self) -> ProductConfig:
        if self.products:
            return self.products[0]
        return ProductConfig(id="default", title="Донат-товар")


def load_config(path: str | Path) -> AppConfig:
    """Читает TOML-конфиг; отсутствующие секции заполняются значениями по умолчанию."""
    raw: dict = {}
    p = Path(path)
    if p.is_file():
        with open(p, "rb") as fh:
            raw = tomllib.load(fh)

    bot_raw = raw.get("bot", {})
    bot = BotConfig(
        shop_name=str(bot_raw.get("shop_name", "Магазин")),
        poll_interval_sec=float(bot_raw.get("poll_interval_sec", 5.0)),
        credential_ttl_min=int(bot_raw.get("credential_ttl_min", 30)),
        reminder_after_min=int(bot_raw.get("reminder_after_min", 10)),
        typing_delay_sec=tuple(bot_raw.get("typing_delay_sec", (0.3, 1.2))),  # type: ignore[arg-type]
    )

    mkt_raw = raw.get("marketplace", {})
    ful_raw = raw.get("fulfillment", {})

    products: list[ProductConfig] = []
    for item in raw.get("products", []):
        mode_raw = str(item.get("credentials_mode", "login_password"))
        try:
            mode = CredentialsMode(mode_raw)
        except ValueError:
            mode = CredentialsMode.LOGIN_PASSWORD
        products.append(
            ProductConfig(
                id=str(item.get("id", f"product-{len(products) + 1}")),
                title=str(item.get("title", "Донат-товар")),
                game=str(item.get("game", "generic")),
                adapter=str(item.get("adapter", ful_raw.get("adapter", "mock_game"))),
                credentials_mode=mode,
                quantity=int(item.get("quantity", 1)),
            )
        )

    return AppConfig(
        bot=bot,
        marketplace_driver=str(mkt_raw.get("driver", "mock")),
        marketplace_options=dict(mkt_raw.get("options", {})),
        fulfillment_adapter=str(ful_raw.get("adapter", "mock_game")),
        fulfillment_options=dict(ful_raw.get("options", {})),
        products=products,
        templates=dict(raw.get("templates", {})),
    )
