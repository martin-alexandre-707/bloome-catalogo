"""Fonte de dados do catálogo.

As rotas pedem "lista de produtos" e não sabem (nem precisam saber) de onde
veio: toda leitura acontece aqui, direto no Supabase, para a rota não
espalhar SQL.
"""

from psycopg.rows import dict_row

import db


def formatar_preco(valor):
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


# ---------------------------------------------------------------------------
# Cores de todos os produtos em uma consulta só (usado pelo catálogo/modal).
# ---------------------------------------------------------------------------


def _cores_por_acessorio(cur):
    """Agrupa as cores do catálogo inteiro, em uma consulta só.

    Devolve {id_acessorio: [{id_variacao, cor, cor_hex, disponivel}, ...]}
    já na ordem
    da view (coluna `ordem`), para a bolinha certa vir primeiro.
    """
    cur.execute(
        """
        select id_variacao, id_acessorios, cor, cor_hex, disponivel
        from bloome.vw_variacoes_disponiveis
        order by ordem
        """
    )
    cores_por_id = {}
    for linha in cur.fetchall():
        cores_por_id.setdefault(linha["id_acessorios"], []).append(
            {
                "id_variacao": linha["id_variacao"],
                "cor": linha["cor"],
                "cor_hex": linha["cor_hex"],
                "disponivel": linha["disponivel"],
            }
        )
    return cores_por_id


# ---------------------------------------------------------------------------
# API usada pelas rotas.
# ---------------------------------------------------------------------------


def listar_produtos():
    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute("""
            select id_acessorios, nome_acessorios, valor_acessorario,
                   foto, descricao, status_exibicao
            from bloome.vw_catalogo_publico
            order by id_acessorios
        """)
        linhas = cur.fetchall()
        cores_por_id = _cores_por_acessorio(cur)

    return [
        {
            "id": linha["id_acessorios"],
            "nome": linha["nome_acessorios"],
            "preco": formatar_preco(linha["valor_acessorario"]),
            "imagem": linha["foto"],
            "descricao": linha["descricao"],
            "status_exibicao": linha["status_exibicao"],
            "cores": cores_por_id.get(linha["id_acessorios"], []),
        }
        for linha in linhas
    ]


def buscar_produto(id_acessorio):
    """Devolve o produto com `cores` ou None se não existir."""
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
            select id_variacao, cor, cor_hex, disponivel
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
            {
                "id_variacao": c["id_variacao"],
                "cor": c["cor"],
                "cor_hex": c["cor_hex"],
                "disponivel": c["disponivel"],
            }
            for c in cores
        ],
    }


def listar_relacionados(id_acessorio, limite=3):
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


def montar_carrinho(linhas):
    """Recebe [{"id_variacao", "quantidade"}] da sessão e devolve os itens
    com nome, cor, preço e imagem atuais do banco."""
    if not linhas:
        return []

    ids = [linha["id_variacao"] for linha in linhas]

    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            select v.id_variacao, v.id_acessorios, v.nome_acessorios,
                   v.cor, v.cor_hex, v.disponivel,
                   c.valor_acessorario, c.foto
            from bloome.vw_variacoes_disponiveis v
            join bloome.vw_catalogo_publico c
              on c.id_acessorios = v.id_acessorios
            where v.id_variacao = any(%s)
            """,
            (ids,),
        )
        por_id = {linha["id_variacao"]: linha for linha in cur.fetchall()}

    itens = []
    for linha in linhas:
        do_banco = por_id.get(linha["id_variacao"])
        if do_banco is None:
            continue

        preco = do_banco["valor_acessorario"]
        quantidade = linha["quantidade"]

        itens.append(
            {
                "id_variacao": linha["id_variacao"],
                "nome": do_banco["nome_acessorios"],
                "cor": do_banco["cor"],
                "cor_hex": do_banco["cor_hex"],
                "imagem": do_banco["foto"],
                "disponivel": do_banco["disponivel"],
                "quantidade": quantidade,
                "preco": formatar_preco(preco),
                "preco_valor": preco,
                "linha_total": formatar_preco(preco * quantidade),
            }
        )

    return itens
