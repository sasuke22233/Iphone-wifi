"""Временное хранилище учётных данных с авто-очисткой.

Секреты живут только в оперативной памяти, привязаны к чату/заказу и
автоматически стираются по TTL. На диск ничего не пишется.
"""

from __future__ import annotations

import threading
import time

from .models import Credentials


class CredentialVault:
    """Потокобезопасное in-memory хранилище учётных данных."""

    def __init__(self, ttl_sec: float = 30 * 60, clock=time.monotonic) -> None:
        self._ttl = ttl_sec
        self._clock = clock
        self._data: dict[str, tuple[float, Credentials]] = {}
        self._lock = threading.Lock()

    def put(self, key: str, creds: Credentials) -> None:
        with self._lock:
            self._sweep_locked()
            old = self._data.get(key)
            if old is not None:
                old[1].zero()  # затираем предыдущие секреты
            self._data[key] = (self._clock() + self._ttl, creds)

    def get(self, key: str) -> Credentials | None:
        with self._lock:
            self._sweep_locked()
            entry = self._data.get(key)
            if entry is None:
                return None
            expires_at, creds = entry
            if self._clock() > expires_at:
                creds.zero()
                del self._data[key]
                return None
            return creds

    def merge(self, key: str, **fields: str) -> Credentials:
        """Дополняет учётные данные полями (login/password/otp)."""
        with self._lock:
            self._sweep_locked()
            entry = self._data.get(key)
            creds = entry[1] if entry else Credentials()
            for name, value in fields.items():
                if value and hasattr(creds, name):
                    setattr(creds, name, value)
            self._data[key] = (self._clock() + self._ttl, creds)
            return creds

    def drop(self, key: str) -> None:
        with self._lock:
            entry = self._data.pop(key, None)
            if entry is not None:
                entry[1].zero()

    def sweep(self) -> int:
        """Стирает протухшие записи. Возвращает количество удалённых."""
        with self._lock:
            return self._sweep_locked()

    def clear(self) -> None:
        with self._lock:
            for _, creds in self._data.values():
                creds.zero()
            self._data.clear()

    def __len__(self) -> int:
        with self._lock:
            return len(self._data)

    def _sweep_locked(self) -> int:
        now = self._clock()
        expired = [k for k, (exp, _) in self._data.items() if now > exp]
        for k in expired:
            self._data[k][1].zero()
            del self._data[k]
        return len(expired)
