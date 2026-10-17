"""Тесты диалогового движка (FSM общения с покупателем)."""

import time

from playerokbot.credentials import CredentialVault
from playerokbot.dialogue import DialogueManager
from playerokbot.models import (
    Action,
    CredentialsMode,
    DeliveryResult,
    InboundMessage,
    Order,
    State,
)


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def make_manager(clock=None):
    clock = clock or time.monotonic
    vault = CredentialVault(ttl_sec=3600, clock=clock)
    mgr = DialogueManager(
        vault, shop_name="TestShop", reminder_after_sec=600, clock=clock
    )
    return vault, mgr


def msg(text: str, chat: str = "c1") -> InboundMessage:
    return InboundMessage(id=f"m-{text[:8]}", chat_id=chat, sender="buyer", text=text)


def order(mode=CredentialsMode.LOGIN_PASSWORD) -> Order:
    return Order(
        id="42",
        chat_id="c1",
        product_id="p1",
        title="PUBG 660 UC",
        game="pubg",
        credentials_mode=mode,
    )


def test_greeting_then_confirm_asks_login():
    _, mgr = make_manager()
    r = mgr.handle(msg("Привет!"), order())
    assert mgr.state_of("c1") == State.AWAITING_ORDER_CONFIRM
    assert any("автоматический ассистент" in t for t in r.replies)
    assert any("PUBG 660 UC" in t for t in r.replies)

    r = mgr.handle(msg("да"), order())
    assert mgr.state_of("c1") == State.AWAITING_LOGIN
    assert any("логин" in t.lower() for t in r.replies)


def test_happy_path_login_password_in_one_message():
    vault, mgr = make_manager()
    o = order()
    mgr.handle(msg("Привет!"), o)
    mgr.handle(msg("да"), o)

    r = mgr.handle(msg("логин: player1 пароль: qwerty123"), o)
    assert mgr.state_of("c1") == State.PROCESSING
    assert r.action == Action.START_FULFILLMENT
    creds = vault.get("c1")
    assert creds is not None and creds.login == "player1" and creds.password == "qwerty123"

    r = mgr.on_delivery_result("c1", DeliveryResult(ok=True, receipt="R-1"))
    assert mgr.state_of("c1") == State.DONE
    assert any("✅" in t for t in r.replies)
    assert vault.get("c1") is None  # секреты стёрты после выдачи


def test_login_then_password_separately():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("Привет!"), o)
    mgr.handle(msg("да"), o)

    r = mgr.handle(msg("логин: hero777"), o)
    assert mgr.state_of("c1") == State.AWAITING_PASSWORD
    assert any("пароль" in t.lower() for t in r.replies)

    r = mgr.handle(msg("пароль: secret99"), o)
    assert mgr.state_of("c1") == State.PROCESSING
    assert r.action == Action.START_FULFILLMENT


def test_login_only_product():
    vault, mgr = make_manager()
    o = order(CredentialsMode.LOGIN)
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("ок"), o)

    r = mgr.handle(msg("мой id: 12345"), o)
    assert mgr.state_of("c1") == State.PROCESSING
    assert r.action == Action.START_FULFILLMENT
    assert vault.get("c1").login == "12345"


def test_credentials_without_prior_dialog():
    _, mgr = make_manager()
    r = mgr.handle(msg("логин: player1 пароль: qwerty123"), order())
    assert mgr.state_of("c1") == State.PROCESSING
    assert r.action == Action.START_FULFILLMENT


def test_otp_mode_asks_code_proactively():
    _, mgr = make_manager()
    o = order(CredentialsMode.LOGIN_PASSWORD_OTP)
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    mgr.handle(msg("логин: u1 пароль: p1"), o)
    assert mgr.state_of("c1") == State.AWAITING_OTP

    r = mgr.handle(msg("код: 445566"), o)
    assert mgr.state_of("c1") == State.PROCESSING
    assert r.action == Action.START_FULFILLMENT


def test_need_otp_retry_flow():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    mgr.handle(msg("логин: u1 пароль: p1"), o)

    # Игра запросила код — бот спрашивает его у покупателя.
    r = mgr.on_delivery_result("c1", DeliveryResult(ok=False, reason="need_otp"))
    assert mgr.state_of("c1") == State.AWAITING_OTP
    assert any("код" in t.lower() for t in r.replies)

    r = mgr.handle(msg("123456"), o)
    assert mgr.state_of("c1") == State.PROCESSING
    assert r.action == Action.START_FULFILLMENT


def test_cancel_order():
    vault, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    r = mgr.handle(msg("нет, передумал"), o)
    assert mgr.state_of("c1") == State.CANCELLED
    assert r.action == Action.CANCEL
    assert any("отменён" in t for t in r.replies)
    assert vault.get("c1") is None


def test_fallback_on_garbage():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    r = mgr.handle(msg("что-то непонятное"), o)
    assert mgr.state_of("c1") == State.AWAITING_LOGIN
    assert any("логин" in t.lower() for t in r.replies)


def test_status_question_while_processing():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    mgr.handle(msg("логин: u1 пароль: p1"), o)
    r = mgr.handle(msg("ну как, где заказ?"), o)
    assert mgr.state_of("c1") == State.PROCESSING
    assert any("обработке" in t or "обрабат" in t for t in r.replies)


def test_done_and_thanks():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    mgr.handle(msg("логин: u1 пароль: p1"), o)
    mgr.on_delivery_result("c1", DeliveryResult(ok=True))
    r = mgr.handle(msg("спасибо!"), o)
    assert any("Спасибо" in t for t in r.replies)


def test_failed_delivery_message():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    mgr.handle(msg("логин: u1 пароль: p1"), o)
    r = mgr.on_delivery_result("c1", DeliveryResult(ok=False, reason="игра отклонила пароль"))
    assert mgr.state_of("c1") == State.FAILED
    assert any("оператор" in t for t in r.replies)


def test_reminder_for_stale_chat():
    clock = FakeClock()
    _, mgr = make_manager(clock)
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    assert mgr.reminders() == []
    clock.now = 700  # > reminder_after_sec
    reminders = mgr.reminders()
    assert len(reminders) == 1
    chat_id, text = reminders[0]
    assert chat_id == "c1"
    assert "Напоминаю" in text
    # Повторно не спамим сразу.
    assert mgr.reminders() == []


def test_password_never_rendered_in_messages():
    _, mgr = make_manager()
    o = order()
    mgr.handle(msg("привет"), o)
    mgr.handle(msg("да"), o)
    r = mgr.handle(msg("логин: player1 пароль: SuperSecret1"), o)
    for text in r.replies:
        assert "SuperSecret1" not in text
    r = mgr.on_delivery_result("c1", DeliveryResult(ok=True))
    for text in r.replies:
        assert "SuperSecret1" not in text
