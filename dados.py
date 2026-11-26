"""Fonte de dados do catálogo.

A rota pede "lista de produtos" e não sabe (nem precisa saber) de onde veio:
do Supabase ou do mock. É o mesmo dado, no mesmo formato, para o mesmo
template — muda só a origem.

Duas fontes:

- banco real: usada quando `DATABASE_URL` existe no `.env`;
- mock: usada quando não existe `DATABASE_URL` (clone novo, sem chave), ou
  quando `MOCK=1` é forçado (útil para testar o próprio mock com `.env`).

Regra do contrato: as duas fontes devolvem as MESMAS chaves. Se uma tela nova
precisar de dado inventado, o mock entra AQUI — nunca no template nem na rota.
"""

import os

from dotenv import load_dotenv
from psycopg.rows import dict_row

import db

# Garante que modo_mock() funcione mesmo se este módulo for importado antes
# do app.py (o .env tem prioridade: variáveis já definidas não são sobrescritas).
load_dotenv()
from catalogo import PRODUTOS as _PRODUTOS_MOCK


def modo_mock():
    """True quando o app deve servir dados de demonstração."""
    if os.getenv("MOCK") == "1":
        return True
    return not os.getenv("DATABASE_URL")


def formatar_preco(valor):
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


# ---------------------------------------------------------------------------
# Mock — dado inventado, só para o front renderizar sem banco.
# ---------------------------------------------------------------------------

_CORES_MOCK = [
    ("Preto", "#1c1c1c"),
    ("Marrom", "#6b4a32"),
    ("Vinho", "#6e1f2a"),
    ("Cru", "#e8dcc8"),
    ("Verde-oliva", "#5a6b4a"),
]


def _mock_lista():
    itens = []
    for id_acessorio in sorted(_PRODUTOS_MOCK):
        produto = _PRODUTOS_MOCK[id_acessorio]
        itens.append(
            {
                "id": id_acessorio,
                "nome": produto["nome"],
                "preco": produto["preco"],
                "imagem": produto["imagem"],
                "descricao": produto["descricao"],
                "status_exibicao": "ativo",
            }
        )
    return itens


def _mock_cores(id_acessorio):
    inicio = id_acessorio % len(_CORES_MOCK)
    cores = []
    for posicao in range(3):
        cor, cor_hex = _CORES_MOCK[(inicio + posicao) % len(_CORES_MOCK)]
        cores.append(
            {
                "cor": cor,
                "cor_hex": cor_hex,
                "disponivel": posicao != 2,  # a última cor fica "esgotada"
            }
        )
    return cores


# ---------------------------------------------------------------------------
# API usada pelas rotas.
# ---------------------------------------------------------------------------


def listar_produtos():
    if modo_mock():
        return _mock_lista()

    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute("""
            select id_acessorios, nome_acessorios, valor_acessorario,
                   foto, descricao, status_exibicao
            from bloome.vw_catalogo_publico
            order by id_acessorios
        """)
        linhas = cur.fetchall()

    return [
        {
            "id": linha["id_acessorios"],
            "nome": linha["nome_acessorios"],
            "preco": formatar_preco(linha["valor_acessorario"]),
            "imagem": linha["foto"],
            "descricao": linha["descricao"],
            "status_exibicao": linha["status_exibicao"],
        }
        for linha in linhas
    ]


def buscar_produto(id_acessorio):
    """Devolve o produto com `cores` ou None se não existir."""
    if modo_mock():
        for item in _mock_lista():
            if item["id"] == id_acessorio:
                return {**item, "cores": _mock_cores(id_acessorio)}
        return None

    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            select id_acessorios, nome_acessorios, valor_acessorario,
                   foto, descricao, status_exibicao
            from bloome.vw_catalogo_publico
            where id_acessorios = %s
            """,
            (id_acessorio,),
        )
        linha = cur.fetchone()

        if linha is None:
            return None

        cur.execute(
            """
            select cor, cor_hex, disponivel
            from bloome.vw_variacoes_disponiveis
            where id_acessorios = %s
            order by ordem
            """,
            (id_acessorio,),
        )
        cores = cur.fetchall()

    return {
        "id": linha["id_acessorios"],
        "nome": linha["nome_acessorios"],
        "preco": formatar_preco(linha["valor_acessorario"]),
        "imagem": linha["foto"],
        "descricao": linha["descricao"],
        "status_exibicao": linha["status_exibicao"],
        "cores": [
            {"cor": c["cor"], "cor_hex": c["cor_hex"], "disponivel": c["disponivel"]}
            for c in cores
        ],
    }


def listar_relacionados(id_acessorio, limite=3):
    if modo_mock():
        return [
            {
                "id": item["id"],
                "nome": item["nome"],
                "preco": item["preco"],
                "imagem": item["imagem"],
            }
            for item in _mock_lista()
            if item["id"] != id_acessorio
        ][:limite]

    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            select id_acessorios, nome_acessorios, valor_acessorario, foto
            from bloome.vw_catalogo_publico
            where id_acessorios <> %s
            order by id_acessorios
            limit 3
            """,
            (id_acessorio,),
        )
        linhas = cur.fetchall()

    return [
        {
            "id": linha["id_acessorios"],
            "nome": linha["nome_acessorios"],
            "preco": formatar_preco(linha["valor_acessorario"]),
            "imagem": linha["foto"],
        }
        for linha in linhas
    ]
