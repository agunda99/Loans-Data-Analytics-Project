import pandas as pd
from sqlalchemy import create_engine

DB_USER = "postgres"      # <- your psql user
DB_PASS = "MyPasswordHere"      # <- your password
DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "learn"

engine = create_engine(
    f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# quick connectivity check
with engine.connect() as c:
    print(c.exec_driver_sql("SELECT version();").scalar())