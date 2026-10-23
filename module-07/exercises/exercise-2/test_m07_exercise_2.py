"""Exercise 7.2: the database is back as it was before the accident, from a backup in .lab/m07x2/."""
import pytest

from common.dockerlab import REPO, docker, require_docker

BACKUPS = REPO / ".lab" / "m07x2"


def setup_module():
    require_docker()
    if docker("ps", "-q", "--filter", "name=^m07x2-db$") == "":
        pytest.fail("m07x2-db isn't running. Your restore must leave a running container with that name.")


def value(query):
    return docker("exec", "m07x2-db", "psql", "-U", "pricing", "-d", "pricing", "-tAc", query, check=False)


def test_a_backup_exists():
    files = [p for p in BACKUPS.glob("*") if p.is_file() and p.stat().st_size > 100_000]
    assert files, "No backup in .lab/m07x2/ (a pg_dump file or a volume archive, more than 100 kB)."


def test_every_charge_is_back():
    assert value("SELECT count(*) FROM session_charges") == "73440", \
        "The Coast sites' charges are missing: the restore didn't bring session_charges back."


def test_mondays_tariff_is_back():
    assert value("SELECT price_per_kwh FROM tariffs WHERE tariff_id = 'tar-site-N03-3'") == "0.52", \
        "Monday's tariff for site-N03 is missing."


def test_the_quotes_are_back():
    assert value("SELECT count(*) FROM quotes") == "25", "The quotes table isn't back with its 25 quotes."
