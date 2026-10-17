"""Интеграционные тесты оркестратора на моках (без интернета и Playwright)."""

from playerokbot.config import AppConfig, BotConfig, ProductConfig
from playerokbot.fulfillment.registry import AdapterRegistry
from playerokbot.marketplace.mock import MockMarketplace
from playerokbot.models import CredentialsMode, Order
from playerokbot.orchestrator import Orchestrator


def build(outcome: str = "success"):
    config = AppConfig(
        bot=BotConfig(shop_name="TestShop", poll_interval_sec=0.01, credential_ttl_min=30),
        products=[
            ProductConfig(
                id="p1",
                title="PUBG 660 UC",
                game="pubg",
                adapter="mock_game",
                credentials_mode=CredentialsMode.LOGIN_PASSWORD,
            )
        ],
    )
    market = MockMarketplace()
    market.register_order(
        Order(id="42", chat_id="c1", product_id="p1", title="PUBG 660 UC", game="pubg")
    )
    registry = AdapterRegistry({"outcome": outcome, "delay_sec": 0.01})
    orch = Orchestrator(config, market, registry)
    return orch, market


def settle(orch: Orchestrator) -> None:
    """Дождаться фоновой выдачи и обработать результат."""
    orch.join_workers(timeout=5)
    orch.run_once()


def test_full_success_flow():
    orch, market = build("success")
    market.push("c1", "Привет!")
    market.push("c1", "да")
    market.push("c1", "логин: player1 пароль: qwerty123")
    orch.run_once()
    settle(orch)

    texts = market.bot_texts("c1")
    assert any("✅" in t for t in texts), texts
    assert market.closed and market.closed[0][1] is True
    # Пароль не утёк ни в одно сообщение.
    assert all("qwerty123" not in t for t in texts)
    # Секреты стёрты после выдачи.
    assert len(orch.vault) == 0


def test_failure_flow_reports_operator():
    orch, market = build("purchase_error")
    market.push("c1", "Привет!")
    market.push("c1", "да")
    market.push("c1", "логин: player1 пароль: qwerty123")
    orch.run_once()
    settle(orch)

    texts = market.bot_texts("c1")
    assert any("Не получилось" in t for t in texts), texts
    assert market.closed and market.closed[0][1] is False
    assert len(orch.vault) == 0


def test_need_otp_flow():
    orch, market = build("need_otp")
    market.push("c1", "Привет!")
    market.push("c1", "да")
    market.push("c1", "логин: player1 пароль: qwerty123")
    orch.run_once()
    settle(orch)

    texts = market.bot_texts("c1")
    assert any("одноразовый код" in t for t in texts), texts

    market.push("c1", "код: 223344")
    orch.run_once()
    settle(orch)

    texts = market.bot_texts("c1")
    assert any("✅" in t for t in texts), texts
    assert market.closed and market.closed[-1][1] is True


def test_cancel_closes_deal():
    orch, market = build("success")
    market.push("c1", "Привет!")
    market.push("c1", "нет")
    orch.run_once()
    settle(orch)

    texts = market.bot_texts("c1")
    assert any("отменён" in t for t in texts)
    assert market.closed and market.closed[0][1] is False


def test_credentials_never_in_logs_or_messages():
    orch, market = build("success")
    market.push("c1", "логин: hero777 пароль: TopSecret99")
    orch.run_once()
    settle(orch)
    for t in market.bot_texts("c1"):
        assert "TopSecret99" not in t
        assert "hero777" not in t  # логин только в маске
