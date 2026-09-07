from pathlib import Path
import os

import psycopg
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[3]

load_dotenv(PROJECT_ROOT / ".env")


def get_connection():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("POSTGRES_PORT", "5433")),
        dbname=os.getenv("POSTGRES_DB", "vinotinto_lab"),
        user=os.getenv("POSTGRES_USER", "vinotinto"),
        password=os.getenv("POSTGRES_PASSWORD", "vinotinto_lab_dev"),
    )