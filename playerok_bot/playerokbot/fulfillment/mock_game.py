"""Мок игрового магазина для тестов и демо-прогона."""

from __future__ import annotations

import time
from typing import Any, Callable

from ..models import Credentials, DeliveryResult, Order
from .base import DeliveryError, GameStoreAdapter, NeedOtpError


class MockGameAdapter(GameStoreAdapter):
    """Симулирует заход на аккаунт и покупку доната.

    Опции:
    * ``outcome``: ``success`` | ``bad_password`` | ``need_otp`` | ``purchase_error``
    * ``delay_sec``: пауза, имитирующая работу (по умолчанию 0.2)
    * ``otp_ok``: какой код считать верным (по умолчанию любой)
    """

    name = "mock_game"

    def __init__(self, options: dict[str, Any] | None = None) -> None:
        opts = options or {}
        self.outcome: str = str(opts.get("outcome", "success"))
        self.delay_sec: float = float(opts.get("delay_sec", 0.2))
        self.otp_ok: str = str(opts.get("otp_ok", ""))

    def deliver(
        self,
        order: Order,
        creds: Credentials,
        progress: Callable[[str], None] | None = None,
    ) -> DeliveryResult:
        if not creds.login:
            raise DeliveryError("не указан логин игрового аккаунта")

        self._progress(progress, f"mock: вхожу на аккаунт {creds.login}…")
        time.sleep(self.delay_sec)

        if self.outcome == "bad_password" and not creds.otp:
            raise DeliveryError("игра отклонила пароль (неверный логин или пароль)")

        if self.outcome == "need_otp" and not creds.otp:
            raise NeedOtpError()

        if self.otp_ok and creds.otp and creds.otp != self.otp_ok:
            raise DeliveryError("неверный одноразовый код")

        self._progress(progress, f"mock: покупаю «{order.title}» x{order.quantity}…")
        time.sleep(self.delay_sec)

        if self.outcome == "purchase_error":
            raise DeliveryError("в магазине игры недоступен нужный товар")

        self._progress(progress, "mock: покупка проведена")
        return DeliveryResult(
            ok=True,
            receipt=f"MOCK-{order.id}-{int(time.time())}",
        )
