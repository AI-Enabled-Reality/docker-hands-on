from datetime import date
from decimal import Decimal

from pricing.quotes import Tariff, price

N03 = Tariff("tar-site-N03-2", "site-N03", Decimal("0.49"), Decimal("0.10"), date(2026, 10, 1))


def test_energy_and_idle_fee_are_priced_separately():
    quote = price(N03, Decimal("31.4"), idle_minutes=6)
    assert quote["energy_eur"] == Decimal("15.39")  # 31.4 x 0.49 = 15.386
    assert quote["idle_fee_eur"] == Decimal("0.60")
    assert quote["amount_eur"] == Decimal("15.99")


def test_no_idle_fee_without_idle_minutes():
    assert price(N03, Decimal("10"), idle_minutes=0)["idle_fee_eur"] == Decimal("0.00")


def test_half_cents_round_up():
    assert price(N03, Decimal("0.5"), idle_minutes=0)["energy_eur"] == Decimal("0.25")  # 0.245
