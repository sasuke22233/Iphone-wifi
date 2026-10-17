"""Тесты парсера учётных данных и одноразовых кодов."""

from playerokbot.parser import extract_credentials, extract_otp, looks_like_credentials


def test_login_password_with_colons():
    creds = extract_credentials("логин: player1 пароль: qwerty123")
    assert creds is not None
    assert creds.login == "player1"
    assert creds.password == "qwerty123"


def test_login_password_english_with_equals():
    creds = extract_credentials("login = alfa / pass = beta")
    assert creds is not None
    assert creds.login == "alfa"
    assert creds.password == "beta"


def test_pair_with_slash():
    creds = extract_credentials("player1:qwerty123")
    assert creds is not None
    assert creds.login == "player1"
    assert creds.password == "qwerty123"

    creds = extract_credentials("alfa/beta99")
    assert creds is not None
    assert creds.login == "alfa"
    assert creds.password == "beta99"


def test_email_password():
    creds = extract_credentials("user@mail.ru:pass123")
    assert creds is not None
    assert creds.login == "user@mail.ru"
    assert creds.password == "pass123"


def test_two_tokens():
    creds = extract_credentials("player1 qwerty123")
    assert creds is not None
    assert creds.login == "player1"
    assert creds.password == "qwerty123"


def test_login_only():
    creds = extract_credentials("мой id: 12345")
    assert creds is not None
    assert creds.login == "12345"
    assert creds.password == ""

    creds = extract_credentials("логин: pro100")
    assert creds is not None
    assert creds.login == "pro100"


def test_password_only():
    creds = extract_credentials("пароль: qwerty123")
    assert creds is not None
    assert creds.login == ""
    assert creds.password == "qwerty123"


def test_plain_phrase_is_not_credentials():
    assert extract_credentials("Привет, как дела?") is None
    assert extract_credentials("как дела") is None
    assert extract_credentials("код: 123456") is None
    assert extract_credentials("где мой заказ?") is None


def test_url_is_not_credentials():
    assert extract_credentials("смотри https://playerok.com/deal/1") is None


def test_credentials_with_multiline():
    text = "логин: hero777\nпароль: secret99"
    creds = extract_credentials(text)
    assert creds is not None
    assert creds.login == "hero777"
    assert creds.password == "secret99"


def test_extract_otp():
    assert extract_otp("123456") == "123456"
    assert extract_otp("код: 556677") == "556677"
    assert extract_otp("мой код 1234 из приложения") == "1234"
    assert extract_otp("просто текст") is None
    assert extract_otp("12") is None  # слишком короткий


def test_looks_like_credentials():
    assert looks_like_credentials("login: x password: y")
    assert not looks_like_credentials("привет!")
