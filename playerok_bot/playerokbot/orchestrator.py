"""Оркестратор: связывает диалог, площадку и выдачу заказов.

Главный цикл (синхронный, с пуллингом):
1. забираем новые сообщения с площадки;
2. диалоговый движок формирует ответы (и, возможно, запуск выдачи);
3. выдача (заход на аккаунт + покупка доната) выполняется в фоновом потоке,
   чтобы бот продолжал отвечать другим покупателям;
4. результат выдачи превращается в финальное сообщение, сделка закрывается.
"""

from __future__ import annotations

import logging
import queue
import threading
import time
from dataclasses import dataclass

from .config import AppConfig, ProductConfig
from .credentials import CredentialVault
from .dialogue import DialogueManager, HandleResult
from .fulfillment.base import DeliveryError, NeedOtpError
from .fulfillment.registry import AdapterRegistry
from .marketplace.base import MarketplaceClient
from .models import Action, DeliveryResult, InboundMessage, Order

log = logging.getLogger("playerokbot")


@dataclass
class _Job:
    chat_id: str
    result: DeliveryResult


class Orchestrator:
    """Главный цикл бота."""

    def __init__(
        self,
        config: AppConfig,
        marketplace: MarketplaceClient,
        registry: AdapterRegistry | None = None,
    ) -> None:
        self.config = config
        self.marketplace = marketplace
        self.vault = CredentialVault(ttl_sec=config.bot.credential_ttl_min * 60)
        self.dialogue = DialogueManager(
            vault=self.vault,
            templates=config.templates,
            shop_name=config.bot.shop_name,
            reminder_after_sec=config.bot.reminder_after_min * 60,
        )
        self.registry = registry or AdapterRegistry(config.fulfillment_options)
        self._results: queue.Queue[_Job] = queue.Queue()
        self._threads: list[threading.Thread] = []
        self._stop = threading.Event()

    # -------------------------------------------------------------- main loop

    def run(self, max_cycles: int | None = None) -> None:
        """Крутит цикл опроса. ``max_cycles`` — для тестов/демо."""
        cycles = 0
        while not self._stop.is_set():
            self.run_once()
            cycles += 1
            if max_cycles is not None and cycles >= max_cycles:
                break
            time.sleep(self.config.bot.poll_interval_sec)

    def stop(self) -> None:
        self._stop.set()

    def run_once(self) -> None:
        """Один цикл: входящие сообщения → ответы → выдача → результаты."""
        self.vault.sweep()

        for msg in self.marketplace.fetch_unanswered():
            self._on_message(msg)

        for chat_id, text in self.dialogue.reminders():
            self.marketplace.send(chat_id, text)

        self._drain_results()

    # ------------------------------------------------------------- handlers

    def _on_message(self, msg: InboundMessage) -> None:
        order = self._resolve_order(msg.chat_id)
        # В лог не должны попадать пароли — показываем только безопасное поле.
        from .parser import looks_like_credentials

        preview = "<данные доступа>" if looks_like_credentials(msg.text) else msg.text[:80]
        log.info("сообщение чата %s: %r", msg.chat_id, preview)
        result = self.dialogue.handle(msg, order)
        self._apply(msg.chat_id, result)

    def _apply(self, chat_id: str, result: HandleResult) -> None:
        for text in result.replies:
            self.marketplace.send(chat_id, text)
        if result.action == Action.START_FULFILLMENT:
            self._start_fulfillment(chat_id)
        elif result.action == Action.CANCEL:
            self.marketplace.close_deal(chat_id, success=False, note="заказ отменён покупателем")

    def _start_fulfillment(self, chat_id: str) -> None:
        order = self._resolve_order(chat_id)
        thread = threading.Thread(
            target=self._fulfill_worker,
            args=(chat_id, order),
            name=f"fulfill-{chat_id}",
            daemon=True,
        )
        self._threads.append(thread)
        thread.start()

    def _fulfill_worker(self, chat_id: str, order: Order) -> None:
        """Фоновая выдача: заходит на аккаунт и покупает донат-товар."""
        creds = self.vault.get(chat_id)
        if creds is None:
            self._results.put(_Job(chat_id, DeliveryResult(ok=False, reason="нет данных доступа")))
            return
        try:
            adapter = self.registry.get(order.adapter)
            log.info(
                "выдача заказа %s (%s) на адаптере %s, аккаунт %s",
                order.id, order.title, order.adapter, creds.redacted(),
            )
            result = adapter.deliver(order, creds)
        except NeedOtpError:
            result = DeliveryResult(ok=False, reason="need_otp")
        except DeliveryError as exc:
            log.warning("выдача заказа %s не удалась: %s", order.id, exc.reason)
            result = DeliveryResult(ok=False, reason=exc.reason)
        except Exception:
            log.exception("непредвиденная ошибка выдачи заказа %s", order.id)
            result = DeliveryResult(ok=False, reason="техническая ошибка выдачи")
        # Секреты не затираем при need_otp: пароль нужен для повторного входа
        # после того, как покупатель пришлёт одноразовый код. Во всех остальных
        # случаях vault drop + TTL очистят их сразу после финального ответа.
        self._results.put(_Job(chat_id, result))

    def _drain_results(self) -> None:
        while True:
            try:
                job = self._results.get_nowait()
            except queue.Empty:
                return
            reply = self.dialogue.on_delivery_result(job.chat_id, job.result)
            self._apply(job.chat_id, reply)
            if job.result.ok:
                self.marketplace.close_deal(job.chat_id, success=True)
            else:
                self.marketplace.close_deal(
                    job.chat_id, success=False, note=f"проблема: {job.result.reason}"
                )

    def join_workers(self, timeout: float | None = None) -> None:
        """Дожидается фоновых выдач (для тестов и корректного завершения)."""
        deadline = None if timeout is None else time.monotonic() + timeout
        for t in self._threads:
            remaining = None if deadline is None else max(0.0, deadline - time.monotonic())
            t.join(timeout=remaining)

    # -------------------------------------------------------------- helpers

    def _resolve_order(self, chat_id: str) -> Order:
        """Заказ из площадки, дополненный параметрами товара из конфига."""
        order = self.marketplace.get_order(chat_id)
        product: ProductConfig | None = None
        if order is not None:
            product = self.config.product_by_id(order.product_id)
        if product is None:
            product = self.config.default_product()
        if order is None:
            order = Order(
                id=f"auto-{chat_id}",
                chat_id=chat_id,
                product_id=product.id,
                title=product.title,
                game=product.game,
            )
        # Параметры конфига приоритетнее сырых данных площадки.
        order.adapter = product.adapter or self.config.fulfillment_adapter
        order.credentials_mode = product.credentials_mode
        order.quantity = product.quantity
        if not order.title:
            order.title = product.title
        return order
