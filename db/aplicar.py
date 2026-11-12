"""Aplica os SQLs da Bloome no Supabase.

Uso (na raiz do projeto):

    python db/aplicar.py              # SOMENTE LEITURA: roda o inventário
    python db/aplicar.py --aplicar    # inventário + schema + funções +
                                      # views + testes + seed

Regras de segurança (ADR-014):
- lê `DATABASE_URL` do `.env` e nunca imprime a conexão;
- prefere a conexão direta (5432); avisa se estiver no pooler (6543);
- aborta se o schema `bloome` já existir — aqui não existe DROP;
- para no primeiro erro e mostra o arquivo e o SQLSTATE;
- `99_tests.sql` roda em BEGIN ... ROLLBACK: nada dos testes fica gravado.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parent.parent
PASTA_SQL = RAIZ / "db"
ARQUIVOS_APLICAR = (
    "01_schema.sql",
    "02_funcoes.sql",
    "03_views.sql",
    "99_tests.sql",
    "04_seed.sql",
)
NOTICE_TESTE = re.compile(r"T\d{2} OK")


def conectar():
    load_dotenv(RAIZ / ".env")
    dsn = os.getenv("DATABASE_URL", "").strip()

    if not dsn:
        sys.exit(
            "DATABASE_URL ausente no .env.\n"
            "Abra .env na raiz do projeto e cole a conexao direta do Supabase\n"
            "(porta 5432). Ela nao e versionada."
        )

    if ":6543" in dsn:
        print("AVISO: porta 6543 e o pooler. Para DDL, use a conexao direta (5432).\n")

    try:
        conn = psycopg.connect(
            dsn,
            autocommit=True,
            connect_timeout=15,
            prepare_threshold=None,
        )
    except Exception as erro:  # noqa: BLE001 - queremos qualquer falha de conexão
        sys.exit(f"Falha ao conectar: {type(erro).__name__}: {erro}")

    notices: list[str] = []
    conn.add_notice_handler(
        lambda diag: notices.append(f"{diag.severity}: {diag.message_primary}")
    )

    print("Conectado ao banco.\n")
    return conn, notices


def executar_sql(conn: psycopg.Connection, notices: list[str], nome: str):
    """Executa o arquivo inteiro e devolve (resultados, notices).

    `resultados` é uma lista de (colunas, linhas) para SELECTs; DDL não gera
    resultado. Com autocommit=True, o BEGIN/COMMIT/ROLLBACK de cada arquivo
    vale como escrito no próprio SQL.
    """
    caminho = PASTA_SQL / nome
    if not caminho.is_file():
        sys.exit(f"Arquivo nao encontrado: {caminho}")

    sql = caminho.read_text(encoding="utf-8")
    notices.clear()
    resultados = []

    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            while True:
                if cur.description is not None:
                    colunas = [d.name for d in cur.description]
                    resultados.append((colunas, cur.fetchall()))
                if not cur.nextset():
                    break
    except Exception as erro:  # noqa: BLE001
        try:
            conn.rollback()
        except Exception:  # noqa: BLE001 - melhor esforço
            pass

        diag = getattr(erro, "diag", None)
        partes = [f"FALHA em {nome}: {type(erro).__name__}"]
        if diag is not None:
            if diag.sqlstate:
                partes.append(f"SQLSTATE={diag.sqlstate}")
            if diag.message_primary:
                partes.append(diag.message_primary)
            if diag.message_detail:
                partes.append(f"detalhe: {diag.message_detail}")
            if diag.constraint_name:
                partes.append(f"constraint={diag.constraint_name}")
        else:
            partes.append(str(erro))
        sys.exit("\n".join(partes))

    return resultados, list(notices)


def imprimir_resultados(resultados) -> None:
    if not resultados:
        print("  (sem resultado: comando de estrutura)")
        return

    for i, (colunas, linhas) in enumerate(resultados, 1):
        print(f"  resultado {i}: {' | '.join(colunas)}")
        if not linhas:
            print("    (vazio)")
        for linha in linhas:
            valores = ["" if v is None else str(v) for v in linha]
            print("    " + " | ".join(valores))


def schema_existe(conn: psycopg.Connection) -> bool:
    with conn.cursor() as cur:
        cur.execute("select 1 from pg_namespace where nspname = 'bloome'")
        return cur.fetchone() is not None


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    aplicar = "--aplicar" in sys.argv[1:]

    conn, notices = conectar()
    try:
        print(">> 00_inventario.sql (somente leitura)")
        resultados, _ = executar_sql(conn, notices, "00_inventario.sql")
        imprimir_resultados(resultados)

        if schema_existe(conn):
            sys.exit(
                "\nO schema `bloome` ja existe. Nada foi alterado.\n"
                "Sem DROP: decida o que fazer antes de continuar."
            )

        if not aplicar:
            print(
                "\nInventario concluido. Nada foi criado.\n"
                "Para criar schema, funcoes, views, rodar os testes e o seed:\n"
                "    python db/aplicar.py --aplicar"
            )
            return

        for nome in ARQUIVOS_APLICAR:
            print(f"\n>> {nome}")
            resultados, avisos = executar_sql(conn, notices, nome)

            if nome == "99_tests.sql":
                oks = [n.strip() for n in avisos if NOTICE_TESTE.search(n)]
                for linha in oks:
                    print(f"   {linha}")
                print(f"   testes com OK: {len(oks)}/28")
                if len(oks) != 28:
                    print(
                        "   ATENCAO: nao vi os 28 OK. Confira os NOTICEs acima;\n"
                        "   um teste que nao imprimiu OK nao passou."
                    )
            elif nome == "04_seed.sql":
                imprimir_resultados(resultados)
            else:
                print("   ok")

        print("\nConcluido: schema, funcoes, views, testes e seed aplicados.")
        print("Falta apenas criar o admin com o hash bcrypt (ver 04_seed.sql).")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
