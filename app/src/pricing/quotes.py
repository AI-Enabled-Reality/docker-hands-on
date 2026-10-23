"""Pricing rules: what a charging session costs at a site's tariff."""
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")


@dataclass(frozen=True)
class Tariff:
    tariff_id: str
    site_id: str
    price_per_kwh: Decimal
    idle_fee_per_min: Decimal
    valid_from: date


def price(tariff: Tariff, energy_kwh: Decimal, idle_minutes: int) -> dict:
    """Energy at the tariff's price per kWh plus the idle fee, each rounded to the cent."""
    energy_eur = (energy_kwh * tariff.price_per_kwh).quantize(CENT, ROUND_HALF_UP)
    idle_fee_eur = (tariff.idle_fee_per_min * idle_minutes).quantize(CENT, ROUND_HALF_UP)
    return {
        "site_id": tariff.site_id,
        "tariff_id": tariff.tariff_id,
        "price_per_kwh": tariff.price_per_kwh,
        "energy_eur": energy_eur,
        "idle_fee_eur": idle_fee_eur,
        "amount_eur": energy_eur + idle_fee_eur,
    }


TARIFF_AT = """
    SELECT tariff_id, site_id, price_per_kwh, idle_fee_per_min, valid_from
      FROM tariffs
     WHERE site_id = %s AND valid_from <= %s
     ORDER BY valid_from DESC
     LIMIT 1
"""


def tariff_at(conn, site_id: str, day: date) -> Tariff | None:
    row = conn.execute(TARIFF_AT, (site_id, day)).fetchone()
    return Tariff(*row) if row else None
