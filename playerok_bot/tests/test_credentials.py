"""Тесты временного хранилища учётных данных."""

from playerokbot.credentials import CredentialVault
from playerokbot.models import Credentials, mask


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def test_mask():
    assert mask("player123") == "pl*****23"
    assert mask("ab") == "**"
    assert mask("") == "***"


def test_credentials_repr_hides_secrets():
    creds = Credentials(login="player1", password="qwerty123", otp="111111")
    text = repr(creds) + str(creds)
    assert "qwerty123" not in text
    assert "111111" not in text
    assert "player1" not in text  # логин тоже маскируется


def test_put_get_drop():
    clock = FakeClock()
    vault = CredentialVault(ttl_sec=60, clock=clock)
    vault.put("chat1", Credentials(login="u", password="p"))
    assert vault.get("chat1") is not None
    vault.drop("chat1")
    assert vault.get("chat1") is None
    assert len(vault) == 0


def test_ttl_expires_and_zeroes():
    clock = FakeClock()
    vault = CredentialVault(ttl_sec=60, clock=clock)
    creds = Credentials(login="u", password="secret")
    vault.put("chat1", creds)
    clock.now = 59
    assert vault.get("chat1") is not None
    clock.now = 61
    assert vault.get("chat1") is None
    assert creds.password == ""  # секреты затёрты


def test_merge_updates_fields():
    clock = FakeClock()
    vault = CredentialVault(ttl_sec=60, clock=clock)
    vault.merge("chat1", login="u")
    creds = vault.merge("chat1", password="p")
    assert creds.login == "u"
    assert creds.password == "p"
    creds = vault.merge("chat1", otp="1234")
    assert creds.otp == "1234"


def test_put_replaces_and_zeroes_old():
    clock = FakeClock()
    vault = CredentialVault(ttl_sec=60, clock=clock)
    old = Credentials(login="u", password="old-pass")
    vault.put("chat1", old)
    vault.put("chat1", Credentials(login="u", password="new-pass"))
    assert old.password == ""


def test_clear():
    vault = CredentialVault(ttl_sec=60)
    vault.put("a", Credentials(login="u", password="p"))
    vault.put("b", Credentials(login="u", password="p"))
    vault.clear()
    assert len(vault) == 0
