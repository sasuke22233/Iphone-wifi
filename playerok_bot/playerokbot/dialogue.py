"""Диалоговый движок: FSM общения с покупателем и разбор намерений.

Бот вежливо доводит покупателя от приветствия до передачи доступа,
запускает выдачу и подводит итог. Никогда не выпрашивает данные вне
рамок заказа и не просит лишнего.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum

from .credentials import CredentialVault
from .models import Action, CredentialsMode, DeliveryResult, InboundMessage, Order, State
from .parser import extract_credentials, extract_otp
from .templates import DEFAULT_TEMPLATES, render


class Intent(str, Enum):
    GREETING = "greeting"
    CONFIRM = "confirm"
    DECLINE = "decline"
    STATUS = "status"
    THANKS = "thanks"
    HELP = "help"
    HUMAN = "human"
    OTHER = "other"


_GREETING_RE = {
    "привет", "здравствуйте", "здравствуй", "добрый день", "доброе утро",
    "добрый вечер", "хай", "hello", "hi", "доброго времени суток",
}
_CONFIRM_WORDS = {
    "да", "ага", "ок", "окей", "окай", "oke", "ok", "окее", "давай",
    "подтверждаю", "согласен", "согласна", "конечно", "готово", "го", "пошли",
}
_DECLINE_WORDS = {
    "нет", "неа", "отмена", "отменить", "отменяю", "передумал", "передумала",
    "не хочу", "не буду", "cancel", "no",
}
_STATUS_WORDS = (
    "где", "статус", "когда", "сколько ждать", "заказ", "выдача", "выпол",
    "процесс", "обработ", "готово?", "ну как", "как дела",
)
_THANKS_WORDS = {
    "спасибо", "спс", "благодарю", "спасибки", "thanks", "thx", "супер",
    "круто", "отлично", "работает", "зачислил", "пришло", "получил",
}
_HELP_WORDS = {"помогите", "помощь", "помоги", "что делать", "как получить", "help"}
_HUMAN_WORDS = {"оператор", "человек", "живой", "поддержк", "менеджер", "support"}


@dataclass
class HandleResult:
    """Ответ диалога: сообщения покупателю + действие для оркестратора."""

    replies: list[str] = field(default_factory=list)
    action: Action = Action.NONE


def classify(text: str) -> Intent:
    """Грубая классификация намерения по ключевым словам."""
    t = text.strip().lower()
    if not t:
        return Intent.OTHER
    if any(w in t for w in _DECLINE_WORDS) and len(t) <= 40:
        return Intent.DECLINE
    if t in _GREETING_RE or any(t.startswith(w) for w in sorted(_GREETING_RE, key=len, reverse=True)):
        return Intent.GREETING
    if t in _CONFIRM_WORDS or any(
        t.startswith(w) and t[len(w):len(w) + 1] in {" ", ",", "!", ".", ":", ""}
        for w in _CONFIRM_WORDS
    ):
        return Intent.CONFIRM
    if any(w in t for w in _HUMAN_WORDS):
        return Intent.HUMAN
    if any(w in t for w in _HELP_WORDS):
        return Intent.HELP
    if any(w in t for w in _THANKS_WORDS):
        return Intent.THANKS
    if any(w in t for w in _STATUS_WORDS):
        return Intent.STATUS
    return Intent.OTHER


class _Chat:
    """Состояние одного диалога."""

    def __init__(self, chat_id: str) -> None:
        self.chat_id = chat_id
        self.state = State.NEW
        self.order: Order | None = None
        self.last_activity: float = time.monotonic()
        self.last_reminder: float = 0.0


class DialogueManager:
    """Управляет всеми диалогами (по одному FSM на чат)."""

    def __init__(
        self,
        vault: CredentialVault,
        templates: dict[str, str] | None = None,
        shop_name: str = "Магазин",
        reminder_after_sec: float = 10 * 60,
        clock=time.monotonic,
    ) -> None:
        self.vault = vault
        self.templates = {**DEFAULT_TEMPLATES, **(templates or {})}
        self.shop_name = shop_name
        self.reminder_after_sec = reminder_after_sec
        self._clock = clock
        self._chats: dict[str, _Chat] = {}

    # ------------------------------------------------------------------ API

    def handle(self, message: InboundMessage, order: Order | None) -> HandleResult:
        chat = self._chat(message.chat_id)
        if order is not None:
            chat.order = order
        chat.last_activity = self._clock()

        if chat.state in (State.DONE, State.FAILED, State.CANCELLED):
            return self._handle_terminal(chat, message)

        text = message.text.strip()
        creds = extract_credentials(text)
        otp = extract_otp(text)
        intent = classify(text)

        # Готовые данные принимаем в любом состоянии (покупатель может
        # прислать всё сразу, не дожидаясь вопросов).
        if creds is not None:
            return self._intake_credentials(chat, creds, intent)

        if chat.state == State.PROCESSING:
            return self._handle_processing(chat, intent)

        if otp and chat.state == State.AWAITING_OTP:
            return self._intake_otp(chat, otp)

        return self._handle_by_state(chat, intent)

    def on_delivery_result(self, chat_id: str, result: DeliveryResult) -> HandleResult:
        """Финальное сообщение после попытки захода на аккаунт и покупки."""
        chat = self._chat(chat_id)
        chat.last_activity = self._clock()
        order = self._order_or_default(chat)
        slots = self._slots(order, chat_id)

        if result.ok:
            chat.state = State.DONE
            self.vault.drop(chat_id)  # секреты больше не нужны
            return HandleResult([self._t("done", **slots)])

        if result.reason == "need_otp":
            chat.state = State.AWAITING_OTP
            return HandleResult([self._t("ask_otp")])

        chat.state = State.FAILED
        self.vault.drop(chat_id)
        slots = {**slots, "reason": result.reason or "ошибка выдачи"}
        return HandleResult([self._t("failed", **slots)])

    def reminders(self) -> list[tuple[str, str]]:
        """Напоминания покупателям, которые «зависли» на передаче доступа."""
        now = self._clock()
        out: list[tuple[str, str]] = []
        waiting = {
            State.AWAITING_ORDER_CONFIRM,
            State.AWAITING_LOGIN,
            State.AWAITING_PASSWORD,
            State.AWAITING_OTP,
        }
        for chat in self._chats.values():
            if chat.state not in waiting:
                continue
            idle = now - chat.last_activity
            if idle >= self.reminder_after_sec and now - chat.last_reminder >= self.reminder_after_sec:
                chat.last_reminder = now
                out.append((chat.chat_id, self._t("reminder", **self._slots(self._order_or_default(chat), chat.chat_id))))
        return out

    def state_of(self, chat_id: str) -> State:
        return self._chat(chat_id).state

    # ------------------------------------------------------------- handlers

    def _handle_terminal(self, chat: _Chat, message: InboundMessage) -> HandleResult:
        order = self._order_or_default(chat)
        slots = self._slots(order, chat.chat_id)
        text = message.text.strip().lower()
        if classify(text) == Intent.THANKS:
            return HandleResult([self._t("thanks_reply")])
        if chat.state == State.DONE:
            return HandleResult([self._t("already_done", **slots)])
        if chat.state == State.FAILED:
            slots = {**slots, "reason": "заказ уже передан оператору"}
            return HandleResult([self._t("failed", **slots)])
        # CANCELLED: новый диалог начинается с чистого листа.
        chat.state = State.NEW
        creds = extract_credentials(message.text)
        if creds is not None:
            return self._intake_credentials(chat, creds, classify(message.text))
        return self._handle_by_state(chat, classify(message.text))

    def _handle_processing(self, chat: _Chat, intent: Intent) -> HandleResult:
        slots = self._slots(self._order_or_default(chat), chat.chat_id)
        if intent == Intent.STATUS:
            return HandleResult([self._t("processing_status", **slots)])
        return HandleResult([self._t("processing", **slots)])

    def _handle_by_state(self, chat: _Chat, intent: Intent) -> HandleResult:
        order = self._order_or_default(chat)
        slots = self._slots(order, chat.chat_id)

        if chat.state == State.NEW:
            replies = [self._t("greet", **slots)]
            if intent in (Intent.GREETING, Intent.HELP, Intent.OTHER, Intent.STATUS):
                chat.state = State.AWAITING_ORDER_CONFIRM
                replies.append(self._t("order_confirm", **slots))
                return HandleResult(replies)
            if intent == Intent.CONFIRM:
                return self._confirm_order(chat, replies)
            if intent == Intent.DECLINE:
                return self._cancel(chat, replies)
            chat.state = State.AWAITING_ORDER_CONFIRM
            replies.append(self._t("order_confirm", **slots))
            return HandleResult(replies)

        if chat.state == State.AWAITING_ORDER_CONFIRM:
            if intent == Intent.CONFIRM:
                return self._confirm_order(chat)
            if intent == Intent.DECLINE:
                return self._cancel(chat)
            return HandleResult([self._t("fallback_confirm")])

        if chat.state == State.AWAITING_LOGIN:
            return HandleResult([self._t("fallback_login")])

        if chat.state == State.AWAITING_PASSWORD:
            return HandleResult([self._t("fallback_password")])

        if chat.state == State.AWAITING_OTP:
            return HandleResult([self._t("fallback_otp")])

        return HandleResult([self._t("fallback", **slots)])

    def _confirm_order(self, chat: _Chat, prefix: list[str] | None = None) -> HandleResult:
        # Один и тот же вопрос: сначала логин/ID, пароль (если нужен) — следом.
        replies = list(prefix or [])
        chat.state = State.AWAITING_LOGIN
        replies.append(self._t("ask_login"))
        return HandleResult(replies)

    def _cancel(self, chat: _Chat, prefix: list[str] | None = None) -> HandleResult:
        chat.state = State.CANCELLED
        self.vault.drop(chat.chat_id)
        replies = list(prefix or [])
        replies.append(self._t("cancelled", **self._slots(self._order_or_default(chat), chat.chat_id)))
        return HandleResult(replies, Action.CANCEL)

    def _intake_credentials(self, chat: _Chat, creds, intent: Intent) -> HandleResult:
        """Принимает логин/пароль и двигает FSM к запуску выдачи."""
        order = self._order_or_default(chat)
        slots = self._slots(order, chat.chat_id)
        mode = order.credentials_mode if order else CredentialsMode.LOGIN_PASSWORD

        if chat.state == State.AWAITING_ORDER_CONFIRM and intent == Intent.DECLINE:
            return self._cancel(chat)

        merged = self.vault.merge(
            chat.chat_id,
            login=creds.login,
            password=creds.password,
        )
        slots = self._slots(order, chat.chat_id)
        replies = [self._t("credentials_ok", **slots)]

        need_password = mode in (CredentialsMode.LOGIN_PASSWORD, CredentialsMode.LOGIN_PASSWORD_OTP)
        if not merged.is_login_ready():
            chat.state = State.AWAITING_LOGIN
            replies.append(self._t("fallback_login"))
            return HandleResult(replies)
        if need_password and not merged.is_password_ready():
            chat.state = State.AWAITING_PASSWORD
            replies.append(self._t("ask_password"))
            return HandleResult(replies)

        if mode == CredentialsMode.LOGIN_PASSWORD_OTP:
            chat.state = State.AWAITING_OTP
            replies.append(self._t("ask_otp"))
            return HandleResult(replies)

        return self._start_fulfillment(chat, replies)

    def _intake_otp(self, chat: _Chat, otp: str) -> HandleResult:
        self.vault.merge(chat.chat_id, otp=otp)
        return self._start_fulfillment(chat)

    def _start_fulfillment(self, chat: _Chat, prefix: list[str] | None = None) -> HandleResult:
        chat.state = State.PROCESSING
        replies = list(prefix or [])
        replies.append(self._t("processing", **self._slots(self._order_or_default(chat), chat.chat_id)))
        return HandleResult(replies, Action.START_FULFILLMENT)

    # -------------------------------------------------------------- helpers

    def _chat(self, chat_id: str) -> _Chat:
        if chat_id not in self._chats:
            self._chats[chat_id] = _Chat(chat_id)
        return self._chats[chat_id]

    def _order_or_default(self, chat: _Chat) -> Order:
        if chat.order is not None:
            return chat.order
        return Order(
            id="—",
            chat_id=chat.chat_id,
            product_id="default",
            title="Донат-товар",
            game="—",
        )

    def _slots(self, order: Order, chat_id: str) -> dict[str, str]:
        creds = self.vault.get(chat_id)
        login_masked = ""
        if creds is not None and creds.login:
            from .models import mask

            login_masked = mask(creds.login)
        return {
            "shop": self.shop_name,
            "product": order.title,
            "order_id": order.id,
            "login_masked": login_masked or "вашему аккаунту",
            "game": order.game,
            "reason": "",
        }

    def _t(self, name: str, **slots: str) -> str:
        return render(self.templates.get(name, DEFAULT_TEMPLATES.get(name, name)), **slots)
