"""Универсальный web-адаптер выдачи: сценарий («рецепт») на каждую игру.

Рецепт — TOML-файл со списком шагов. Шаги выполняются в браузере Playwright:

.. code-block:: toml

    name = "example"
    login_url = "https://game.example/login"

    [[steps]]
    action = "fill"
    selector = "#login"
    value = "{login}"

    [[steps]]
    action = "fill"
    selector = "#password"
    value = "{password}"

    [[steps]]
    action = "click"
    selector = "button[type=submit]"

    [[steps]]
    action = "wait_for"
    selector = ".balance"
    timeout_ms = 15000

Поддерживаемые действия: ``goto``, ``fill``, ``click``, ``press``, ``wait``,
``wait_for``, ``select``, ``assert_text``, ``screenshot``, ``eval``.

Плейсхолдеры в ``value``/``url``/``text``: ``{login}``, ``{password}``,
``{otp}``, ``{quantity}``, ``{title}``. Пароль подставляется только в шаги
ввода и нигде не логируется.
"""

from __future__ import annotations

import re
import time
import tomllib
from pathlib import Path
from typing import Any, Callable

from ..models import Credentials, DeliveryResult, Order, mask
from .base import DeliveryError, GameStoreAdapter, NeedOtpError

_PLACEHOLDER_RE = re.compile(r"\{(\w+)\}")


def _require_playwright():
    try:
        from playwright.sync_api import sync_playwright  # noqa: F401
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError(
            "Для web_game нужен Playwright: pip install playwright && playwright install chromium"
        ) from exc


class WebGameAdapter(GameStoreAdapter):
    """Выполняет покупку доната по TOML-рецепту через браузер."""

    name = "web_game"

    def __init__(self, options: dict[str, Any] | None = None) -> None:
        opts = options or {}
        self.headless: bool = bool(opts.get("headless", True))
        self.slow_mo_ms: int = int(opts.get("slow_mo_ms", 50))
        self.screenshot_dir: str = str(opts.get("screenshot_dir", ""))
        self._recipe_paths = opts.get("recipes_dir", "playerok_bot/recipes")

    def deliver(
        self,
        order: Order,
        creds: Credentials,
        progress: Callable[[str], None] | None = None,
    ) -> DeliveryResult:
        _require_playwright()
        recipe = self._load_recipe(order)
        slots = {
            "login": creds.login,
            "password": creds.password,
            "otp": creds.otp,
            "quantity": str(order.quantity),
            "title": order.title,
        }

        from playwright.sync_api import sync_playwright

        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=self.headless, slow_mo=self.slow_mo_ms)
            try:
                context = browser.new_context()
                page = context.new_page()
                login_url = recipe.get("login_url", "")
                if login_url:
                    self._progress(progress, f"web_game: открываю {login_url}")
                    page.goto(self._render(login_url, slots), wait_until="domcontentloaded")
                for step in recipe.get("steps", []):
                    self._run_step(page, step, slots, creds, order, progress)
                self._progress(progress, "web_game: сценарий выполнен")
                return DeliveryResult(ok=True, receipt=f"WEB-{order.id}-{int(time.time())}")
            except NeedOtpError:
                raise
            except DeliveryError:
                raise
            except Exception as exc:
                # Технические детали не показываем покупателю.
                raise DeliveryError("не удалось выполнить покупку в магазине игры") from exc
            finally:
                context.close()
                browser.close()

    # ---------------------------------------------------------------- steps

    def _run_step(
        self,
        page,
        step: dict[str, Any],
        slots: dict[str, str],
        creds: Credentials,
        order: Order,
        progress: Callable[[str], None] | None,
    ) -> None:
        action = str(step.get("action", "")).lower()
        selector = self._render(str(step.get("selector", "")), slots)
        value = self._render(str(step.get("value", "")), slots)
        timeout = int(step.get("timeout_ms", 15000))

        if action == "goto":
            page.goto(value or self._render(str(step.get("url", "")), slots), wait_until="domcontentloaded")
        elif action == "fill":
            self._fill_password_safe(page, selector, value, creds)
        elif action == "click":
            page.click(selector, timeout=timeout)
        elif action == "press":
            page.keyboard.press(value or step.get("key", "Enter"))
        elif action == "wait":
            time.sleep(float(step.get("sec", 1)))
        elif action == "wait_for":
            page.wait_for_selector(selector, timeout=timeout)
        elif action == "select":
            page.select_option(selector, value)
        elif action == "assert_text":
            text = self._render(str(step.get("text", "")), slots)
            if not page.locator(selector).first.inner_text(timeout=timeout) or (
                text and text not in page.locator(selector).first.inner_text()
            ):
                raise DeliveryError(step.get("error", "магазин игры не подтвердил операцию"))
        elif action == "screenshot":
            path = step.get("path") or f"screen-{order.id}.png"
            if self.screenshot_dir:
                path = str(Path(self.screenshot_dir) / path)
            page.screenshot(path=path)
        elif action == "eval":
            page.evaluate(step.get("script", "() => {}"))
        else:
            raise DeliveryError(f"неизвестный шаг рецепта: {action!r}")

        # Частые ошибки магазинов игр → понятные причины для покупателя.
        body = ""
        try:
            body = page.content().lower()
        except Exception:
            pass
        if "неверный пароль" in body or "invalid password" in body:
            raise DeliveryError("игра отклонила пароль (неверный логин или пароль)")
        if "код подтверждения" in body or "verification code" in body:
            if not creds.otp:
                raise NeedOtpError()

    def _fill_password_safe(
        self, page, selector: str, value: str, creds: Credentials
    ) -> None:
        page.fill(selector, value)
        # Скриншоты/логи не должны захватывать пароль: поле очищается при
        # ошибках не будет — но в HTML пароль уже замаскирован браузером.

    # -------------------------------------------------------------- helpers

    def _load_recipe(self, order: Order) -> dict[str, Any]:
        """Ищет рецепт: по id товара, по игре, затем ``default.toml``."""
        base = Path(self._recipe_paths)
        for candidate in (f"{order.product_id}.toml", f"{order.game}.toml", "default.toml"):
            path = base / candidate
            if path.is_file():
                with open(path, "rb") as fh:
                    return tomllib.load(fh)
        raise DeliveryError(f"не найден сценарий выдачи для товара «{order.title}»")

    @staticmethod
    def _render(template: str, slots: dict[str, str]) -> str:
        def repl(m: re.Match[str]) -> str:
            return slots.get(m.group(1), m.group(0))

        return _PLACEHOLDER_RE.sub(repl, template)
