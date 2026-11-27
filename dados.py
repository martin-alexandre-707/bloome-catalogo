"""Fonte de dados do catálogo.

As rotas pedem "lista de produtos" e não sabem (nem precisam saber) de onde
veio: toda leitura acontece aqui, direto no Supabase, para a rota não
espalhar SQL.
"""

import re
import unicodedata

from psycopg.rows import dict_row

import db


def formatar_preco(valor):
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def _slug(nome):
    """Nome do produto em formato de URL (ADR-030).

    "Cordão Lua" -> "cordao-lua": NFKD separa o acento da letra, o filtro
    `combining` descarta o acento, e o `re.sub` troca tudo que não é
    letra/número por hífen. É como um apelido legível que serve de endereço.
    """
    sem_acento = unicodedata.normalize("NFKD", nome)
    sem_acento = "".join(c for c in sem_acento if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "-", sem_acento.lower()).strip("-")


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
                   foto, descricao, status_exibicao, categoria_acessorio
            from bloome.vw_catalogo_publico
            order by id_acessorios
        """)
        linhas = cur.fetchall()
        cores_por_id = _cores_por_acessorio(cur)

    return [
        {
            "id": linha["id_acessorios"],
            "slug": _slug(linha["nome_acessorios"]),
            "nome": linha["nome_acessorios"],
            "preco": formatar_preco(linha["valor_acessorario"]),
            "imagem": linha["foto"],
            "descricao": linha["descricao"],
            "status_exibicao": linha["status_exibicao"],
            "categoria": linha["categoria_acessorio"],
            "cores": cores_por_id.get(linha["id_acessorios"], []),
        }
        for linha in linhas
    ]


# Nome da coletânea na home; categorias desconhecidas caem no fallback + "s".
COLECOES_NOMES = {
    "Cordão": "Cordões",
    "Colar": "Colares",
    "Chocker": "Chockers",
}


def listar_colecoes(limite=4):
    """Agrupa o catálogo por categoria (home e /produtos).

    `limite=4` corta cada seção para a home; `limite=None` devolve todos,
    que é o que a página de produtos usa. A ordem das seções segue a
    primeira aparição de cada categoria no catálogo (ordenado por id).
    """
    colecoes = {}
    for produto in listar_produtos():
        colecoes.setdefault(produto["categoria"], []).append(produto)

    return [
        {
            "titulo": COLECOES_NOMES.get(nome, nome + "s"),
            "produtos": produtos[:limite],  # None = todos (fatiar com None é seguro)
        }
        for nome, produtos in colecoes.items()
    ]


# O catálogo do PDF tem dois volumes: o Catálogo Bloome (principal) e a
# Cápsula Maré. O banco ainda não tem coluna de coleção, então a separação
# mora aqui, pelos nomes do PDF. Produto novo cai no Catálogo Bloome; quando
# virar coluna em bloome.acessorios, esta lista some.
CAPSULA_MARE = {
    "Cordão Sol Médio",
    "Colar Peixe Colorido",
    "Chocker Estrela do Mar",
    "Cordão Concha Pérola",
}


def listar_catalogos():
    """Os dois catálogos do PDF, na ordem: Bloome e Cápsula Maré.

    Devolve todos os produtos de cada um; a home mostra as grades completas.
    """
    principais, capsula = [], []
    for produto in listar_produtos():
        if produto["nome"] in CAPSULA_MARE:
            capsula.append(produto)
        else:
            principais.append(produto)

    return [
        {
            "chave": "bloome",
            "titulo": "Catálogo Bloome",
            "subtitulo": "Peças atemporais, feitas à mão para o dia a dia.",
            "produtos": principais,
        },
        {
            "chave": "mare",
            "titulo": "Cápsula Maré",
            "subtitulo": "Inspirada no mar — edição limitada.",
            "produtos": capsula,
        },
    ]


def buscar_produto(slug):
    """Devolve o produto cujo `slug` (nome na URL) casa, ou None.

    O slug não existe no banco: ele é derivado do nome. Por isso a busca
    carrega só id + nome de todos os produtos e compara em Python — são
    poucas linhas, e uma consulta só.
    """
    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            "select id_acessorios, nome_acessorios from bloome.vw_catalogo_publico"
        )
        id_acessorio = next(
            (
                linha["id_acessorios"]
                for linha in cur.fetchall()
                if _slug(linha["nome_acessorios"]) == slug
            ),
            None,
        )

    if id_acessorio is None:
        return None

    return buscar_produto_por_id(id_acessorio)


def buscar_produto_por_id(id_acessorio):
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
        "slug": _slug(linha["nome_acessorios"]),
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
            "slug": _slug(linha["nome_acessorios"]),
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


def listar_pedidos_cliente(id_cliente):
    """Pedidos do cliente, mais recentes primeiro, cada um com `itens`.

    Duas consultas: uma para os pedidos e outra para os itens de todos os
    pedidos de uma vez (evita N+1 consultas).
    """
    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            select id_pedidos, codigo, status, subtotal, frete_valor,
                   valor_total, tipo_entrega, metodo_pagamento, criado_em
            from bloome.pedidos
            where id_cliente = %s
            order by criado_em desc, id_pedidos desc
            """,
            (id_cliente,),
        )
        pedidos = cur.fetchall()
        if not pedidos:
            return []

        cur.execute(
            """
            select ip.id_pedidos, ip.quantidade, ip.preco_unitario,
                   v.cor, a.nome_acessorios, a.foto
            from bloome.itens_pedidos ip
            join bloome.variacoes v  on v.id_variacao  = ip.id_variacao
            join bloome.acessorios a on a.id_acessorios = v.id_acessorios
            where ip.id_pedidos = any(%s)
            order by ip.id_item
            """,
            ([p["id_pedidos"] for p in pedidos],),
        )
        itens_por_pedido = {}
        for linha in cur.fetchall():
            itens_por_pedido.setdefault(linha["id_pedidos"], []).append(
                {
                    "nome": linha["nome_acessorios"],
                    "cor": linha["cor"],
                    "imagem": linha["foto"],
                    "quantidade": linha["quantidade"],
                    "preco_unitario": linha["preco_unitario"],
                }
            )

    return [
        {**dict(pedido), "itens": itens_por_pedido.get(pedido["id_pedidos"], [])}
        for pedido in pedidos
    ]


def buscar_pedido_cliente(id_cliente, codigo):
    """Um pedido do cliente (pelo código) com os itens, ou None.

    O filtro por `id_cliente` é a autorização: o pedido de outra pessoa
    simplesmente não existe para quem está logado.
    """
    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            select id_pedidos, codigo, status, subtotal, frete_valor,
                   valor_total, tipo_entrega, metodo_pagamento, criado_em
            from bloome.pedidos
            where id_cliente = %s and codigo = %s
            """,
            (id_cliente, codigo),
        )
        pedido = cur.fetchone()
        if pedido is None:
            return None

        cur.execute(
            """
            select ip.quantidade, ip.preco_unitario,
                   v.cor, a.nome_acessorios, a.foto
            from bloome.itens_pedidos ip
            join bloome.variacoes v  on v.id_variacao  = ip.id_variacao
            join bloome.acessorios a on a.id_acessorios = v.id_acessorios
            where ip.id_pedidos = %s
            order by ip.id_item
            """,
            (pedido["id_pedidos"],),
        )
        itens = [
            {
                "nome": linha["nome_acessorios"],
                "cor": linha["cor"],
                "imagem": linha["foto"],
                "quantidade": linha["quantidade"],
                "preco_unitario": linha["preco_unitario"],
            }
            for linha in cur.fetchall()
        ]

    return {**dict(pedido), "itens": itens}
