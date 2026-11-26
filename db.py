import os

import psycopg
from dotenv import load_dotenv
from flask import g


def _dsn():
    load_dotenv()
    return os.getenv("DATABASE_URL")


def conectar():
    return psycopg.connect(_dsn())


def get_db():
    if "db" not in g:
        g.db = conectar()
    return g.db


def fechar_db(erro=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_app(app):
    app.teardown_appcontext(fechar_db)
