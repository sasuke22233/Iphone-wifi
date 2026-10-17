"""Извлечение учётных данных и одноразовых кодов из текста покупателя.

Поддерживаются типичные форматы, которыми пользуются покупатели:

* ``логин: player1 пароль: qwerty123``
* ``login = alfa / pass = beta``
* ``player1:qwerty123`` (пара через двоеточие/слэш на отдельной строке)
* ``user@mail.ru:pass123``
* ``player1 qwerty123`` (два токена через пробел — если похожи на доступ)
* ``мой id: 12345`` (только логин/ID — для режима ``login``)
* одноразовый код: ``123456`` или ``код: 123456``

Фразы вроде «как дела» или «код: 123456» доступами не считаются.
"""

from __future__ import annotations

import re

from .models import Credentials

_LOGIN_KEYS = r"(?:логин|login|e-?mail|почта|никн?ейм?|nick|id|аккаунт)"
_PASSWORD_KEYS = r"(?:пароль|password|passwd|pass|pwd)"
_OTP_KEYS = r"(?:код|code|otp|2fa|подтверждени\w*)"

_KEYWORDS = (
    r"(?:логин|login|e-?mail|почта|никн?ейм?|nick|id|аккаунт|"
    r"пароль|password|passwd|pass|pwd|код|code|otp|2fa|подтверждени\w*)"
)
_KEYWORD_FULL_RE = re.compile(rf"^{_KEYWORDS}$", re.IGNORECASE)

# Ключ поля, затем обязательный разделитель (двоеточие/пробел/дефис).
_LOGIN_RE = re.compile(
    rf"(?<![\w@.-])(?:{_LOGIN_KEYS})\b\s*(?:[:=–—-]\s*|\s+)([^\s,;=]+)",
    re.IGNORECASE,
)
_PASSWORD_RE = re.compile(
    rf"(?<![\w@.-])(?:{_PASSWORD_KEYS})\b\s*(?:[:=–—-]\s*|\s+)([^\s,;=]+)",
    re.IGNORECASE,
)
# user@mail.ru:pass123
_EMAIL_PASS_RE = re.compile(
    r"(?m)^\s*([\w.+-]+@[\w.-]+\.\w+)\s*[:=]\s*([^\s:;=]+)\s*$"
)
# Пара "значение[/:=]значение" на отдельной строке (не URL).
_PAIR_RE = re.compile(r"(?m)^\s*([^\s:/=;]+)\s*[:=/]\s*([^\s:/=;]+)\s*$")
# Два токена через пробел.
_TWO_TOKENS_RE = re.compile(r"(?m)^\s*(\S+)\s+(\S+)\s*$")
# Одноразовый код: 4–8 цифр, возможно с ключевым словом.
_OTP_WITH_KEY_RE = re.compile(
    rf"(?<![\w@.-])(?:{_OTP_KEYS})\b\s*(?:[:=–—-]\s*|\s+)(\d{{4,8}})\b",
    re.IGNORECASE,
)
_OTP_ONLY_RE = re.compile(r"^\s*(?:код[:\s]*)?(\d{4,8})\s*$", re.IGNORECASE)

_URL_RE = re.compile(r"https?://", re.IGNORECASE)
# Токен «похож на доступ»: есть латиница или цифра (не просто слово).
_HAS_LATIN_OR_DIGIT_RE = re.compile(r"[A-Za-z0-9]")


def _strip_urls(text: str) -> str:
    """Убирает URL, чтобы ``http://...`` не приняли за пару логин:пароль."""
    return "\n".join(line for line in text.splitlines() if not _URL_RE.search(line))


def _looks_like_secret_token(token: str) -> bool:
    return bool(_HAS_LATIN_OR_DIGIT_RE.search(token))


def extract_credentials(text: str) -> Credentials | None:
    """Достаёт логин/пароль из текста. ``None`` — если ничего не найдено."""
    cleaned = _strip_urls(text)
    if not cleaned.strip():
        return None

    login = ""
    password = ""

    # 1. user@mail.ru:pass123 — до общих правил, чтобы «mail» не сработал.
    m = _EMAIL_PASS_RE.search(cleaned)
    if m:
        return Credentials(login=m.group(1).strip(), password=m.group(2).strip())

    # 2. Ключевые слова: «логин: …», «пароль …».
    m = _LOGIN_RE.search(cleaned)
    if m:
        login = m.group(1).strip()
    m = _PASSWORD_RE.search(cleaned)
    if m:
        password = m.group(1).strip()

    # 3. Пара «значение:значение» / «значение/значение» построчно.
    if not login or not password:
        for m in _PAIR_RE.finditer(cleaned):
            a, b = m.group(1).strip(), m.group(2).strip()
            if _KEYWORD_FULL_RE.match(a) or _KEYWORD_FULL_RE.match(b):
                continue  # это «код: 123456» и т.п.
            if not (_looks_like_secret_token(a) or _looks_like_secret_token(b)):
                continue
            login = login or a
            password = password or b
            break

    # 4. Запасной вариант: два токена через пробел («player1 qwerty123»).
    if not login or not password:
        for line in cleaned.splitlines():
            line = line.strip()
            if not line or " " not in line or any(ch in line for ch in ":=;,!?"):
                continue
            m = _TWO_TOKENS_RE.match(line)
            if not m:
                continue
            a, b = m.group(1), m.group(2)
            if _KEYWORD_FULL_RE.match(a) or _KEYWORD_FULL_RE.match(b):
                continue
            if not (_looks_like_secret_token(a) or _looks_like_secret_token(b)):
                continue
            login = login or a
            password = password or b
            break

    if not login and not password:
        return None
    return Credentials(login=login, password=password)


def extract_otp(text: str) -> str | None:
    """Достаёт одноразовый код (4–8 цифр) из сообщения."""
    m = _OTP_ONLY_RE.match(text.strip())
    if m:
        return m.group(1)
    m = _OTP_WITH_KEY_RE.search(text)
    if m:
        return m.group(1)
    return None


def looks_like_credentials(text: str) -> bool:
    """True, если сообщение похоже на передачу доступа к аккаунту."""
    return extract_credentials(text) is not None
