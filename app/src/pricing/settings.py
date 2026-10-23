"""Settings, read from environment variables with the prefix PRICING_.

A container gets its configuration from outside: the same image runs in the lab, on staging and
in production, with different environment variables (and, from module 9, secret files).
"""
from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="PRICING_")

    environment: Literal["lab", "staging", "production"] = "lab"
    # Where the pricing database is. The password can come from the URL, from
    # PRICING_DATABASE_PASSWORD, or from a file named by PRICING_DATABASE_PASSWORD_FILE.
    database_url: str = "postgresql://pricing@db:5432/pricing"
    database_password: str | None = None
    database_password_file: Path | None = None
    database_connect_timeout: int = Field(default=3, ge=1)
    export_dir: Path = Path("/exports")
    log_format: Literal["text", "json"] = "text"
    # Where `pricing api` listens. 0.0.0.0 means every interface of the container.
    host: str = "0.0.0.0"
    port: int = 8000
    # Set at build time (module 11) to the git commit the image was built from.
    build: str = "dev"

    def password(self) -> str | None:
        if self.database_password_file:
            return self.database_password_file.read_text().strip()
        return self.database_password


@lru_cache
def get_settings() -> Settings:
    return Settings()
