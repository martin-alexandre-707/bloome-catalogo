import os
from functools import wraps
from urllib.parse import urlparse

import bcrypt
import psycopg
from dotenv import load_dotenv
from flask import Flask, abort, flash, redirect, render_template, request, session, url_for
from psycopg.rows import dict_row
import dados
import db


load_dotenv()

app = Flask(__name__)

_chave = os.environ.get("SECRET_KEY")
if not _chave:
    raise RuntimeError("SECRET_KEY não definida no .env")
app.secret_key = _chave

app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
)

db.init_app(app)


def login_requerido(view):
    @wraps(view)
    def protegida(*args, **kwargs):
        if "cliente_id" not in session:
            flash("Entre na sua conta para continuar.", "erro")
            # `next` devolve a pessoa para a página que ela tentou abrir
            # (ex.: /checkout) depois de entrar ou criar conta.
            return redirect(url_for("conta", next=request.path))
        return view(*args, **kwargs)

    return protegida

@app.route("/")
def index():
    return render_template(
        "index.html",
        current="index",
        catalogos=dados.listar_catalogos(),
    )

@app.route("/produtos")
def produtos():
    lista = dados.listar_produtos()
    return render_template(
        "produtos.html",
        current="produtos",
        produtos=lista,
        # A lista plana alimenta os <template>s do modal; as coleções
        # organizam os cards na tela, com todos os produtos.
        colecoes=dados.listar_colecoes(limite=None),
    )


@app.route("/produtos/<slug>")
def produto(slug):
    item = dados.buscar_produto(slug)

    if item is None:
        abort(404)

    return render_template(
        "produto.html",
        current="produtos",
        produto=item,
        relacionados=dados.listar_relacionados(item["id"]),
    )

def _url_de_volta(fallback):
    """Devolve o caminho da página que enviou o formulário, se for do
    próprio site; senão, o fallback. Evita redirecionar para fora
    (open redirect) e mantém o cliente no catálogo quando ele adiciona
    pelo modal."""
    origem = request.referrer
    if origem:
        partes = urlparse(origem)
        caminho = partes.path
        if (
            partes.netloc == request.host
            and caminho.startswith("/")
            and not caminho.startswith("//")
        ):
            return caminho
    return fallback


def _destino_seguro(padrao):
    """Lê o `next` do formulário/URL e devolve só caminhos internos.

    Mesma ideia do `_url_de_volta`: aceitar apenas caminhos que começam com
    uma única "/" evita redirecionar o cliente para outro site (open
    redirect). Sem `next` válido, usa o padrão.
    """
    destino = request.values.get("next", "")
    if destino.startswith("/") and not destino.startswith("//"):
        return destino
    return padrao


@app.route("/carrinho/adicionar", methods=["POST"])
def adicionar_carrinho():
    voltar = _url_de_volta(url_for("produtos"))

    try:
        id_acessorios = int(request.form.get("id_acessorios", ""))
        id_variacao = int(request.form.get("id_variacao", ""))
        quantidade = int(request.form.get("quantidade", "1"))
    except ValueError:
        flash("Escolha uma cor para adicionar ao carrinho.", "erro")
        return redirect(voltar)

    quantidade = max(1, min(quantidade, 99))

    item = dados.buscar_produto_por_id(id_acessorios)
    if item is None:
        abort(404)

    cor = next((c for c in item["cores"] if c["id_variacao"] == id_variacao), None)
    if cor is None or not cor["disponivel"]:
        flash("Essa cor não está disponível. Escolha outra.", "erro")
        return redirect(_url_de_volta(url_for("produto", slug=item["slug"])))

    carrinho = session.get("carrinho", [])
    for linha in carrinho:
        if linha["id_variacao"] == id_variacao:
            linha["quantidade"] = min(linha["quantidade"] + quantidade, 99)
            break
    else:
        carrinho.append({"id_variacao": id_variacao, "quantidade": quantidade})

    session["carrinho"] = carrinho

    flash(f"{item['nome']} ({cor['cor']}) foi para o carrinho.", "sucesso")
    return redirect(_url_de_volta(url_for("produto", slug=item["slug"])))


# Valor do rádio no carrinho -> (tipo_entrega, frete_pago_por) do banco.
# O CHECK de bloome.pedidos só aceita esses nomes e essas combinações de
# frete (§4 do VALIDACAO-REGRAS.md); o formulário usa apelidos (unima etc.),
# então a tradução mora aqui, no servidor.
ENTREGAS = {
    "unima": ("retirada", "loja"),
    "ponta-verde": ("retirada", "loja"),
    "uber-flash": ("uber_flash", "cliente"),
}

PAGAMENTOS = {"pix", "debito", "credito"}

# Status do banco -> (rótulo na tela, sufixo da classe CSS).
STATUS_PEDIDO = {
    "aguardando_pagamento": ("Aguardando pagamento", "aguardando"),
    "pago": ("Pago", "pago"),
    "pago_sem_estoque": ("Pago — sem estoque", "cancelado"),
    "em_producao": ("Em preparação", "producao"),
    "pronto_para_retirada": ("Pronto para retirada", "pronto"),
    "enviado": ("Enviado", "enviado"),
    "entregue": ("Entregue", "entregue"),
    "cancelado": ("Cancelado", "cancelado"),
}

ENTREGA_ROTULO = {
    "retirada": "Retirada combinada",
    "uber_flash": "Entrega rápida — Uber Flash (a combinar)",
    "correios": "Envio pelos Correios",
}

PAGAMENTO_ROTULO = {
    "pix": "Pix",
    "debito": "Cartão de débito",
    "credito": "Cartão de crédito",
}


def _pedido_para_template(pedido):
    """Formata um pedido do `dados.py` para o Jinja: data, dinheiro e
    rótulos de status/entrega/pagamento. O dinheiro continua vindo do banco;
    aqui só vira texto."""
    rotulo, classe = STATUS_PEDIDO.get(pedido["status"], (pedido["status"], "aguardando"))
    return {
        **pedido,
        "data": pedido["criado_em"].strftime("%d/%m/%Y"),
        "status_rotulo": rotulo,
        "status_classe": classe,
        "entrega_rotulo": ENTREGA_ROTULO.get(pedido["tipo_entrega"], pedido["tipo_entrega"]),
        "pagamento_rotulo": PAGAMENTO_ROTULO.get(pedido["metodo_pagamento"], pedido["metodo_pagamento"]),
        "subtotal_fmt": dados.formatar_preco(pedido["subtotal"]),
        "total_fmt": dados.formatar_preco(pedido["valor_total"]),
        "itens": [
            {
                **item,
                "preco_fmt": dados.formatar_preco(
                    item["preco_unitario"] * item["quantidade"]
                ),
            }
            for item in pedido["itens"]
        ],
    }


@app.route("/checkout", methods=["GET", "POST"])
@login_requerido
def checkout():
    """GET mostra entrega/pagamento; POST cria o pedido numa transação.

    A conta é exigida aqui (o banco precisa de `id_cliente`); quem não está
    logado é levado para /conta?next=/checkout e volta para cá depois.
    """
    linhas = session.get("carrinho", [])
    if not linhas:
        flash("Seu carrinho está vazio.", "erro")
        return redirect(url_for("carrinho"))

    if request.method == "GET":
        itens = dados.montar_carrinho(linhas)
        subtotal_valor = sum(
            item["preco_valor"] * item["quantidade"] for item in itens
        )
        return render_template(
            "checkout.html",
            current="carrinho",
            itens=itens,
            subtotal=dados.formatar_preco(subtotal_valor),
        )

    entrega = request.form.get("entrega", "")
    if entrega == "correios":
        # Correios pede endereço completo e API de frete: MVP deixa "em breve".
        flash("Envio pelos Correios estará disponível em breve. Escolha retirada ou Uber Flash.", "erro")
        return redirect(url_for("carrinho"))

    if entrega not in ENTREGAS:
        flash("Escolha uma forma de entrega.", "erro")
        return redirect(url_for("carrinho"))
    tipo_entrega, frete_pago_por = ENTREGAS[entrega]

    pagamento = request.form.get("pagamento", "")
    if pagamento not in PAGAMENTOS:
        flash("Escolha uma forma de pagamento.", "erro")
        return redirect(url_for("carrinho"))

    conn = db.get_db()
    try:
        with conn.cursor() as cur:
            # 1) O pedido nasce "aguardando_pagamento"; preço e total vêm
            #    dos triggers a partir dos itens, nunca do formulário.
            cur.execute(
                """
                insert into bloome.pedidos
                    (id_cliente, metodo_pagamento, tipo_entrega, frete_pago_por)
                values (%s, %s, %s, %s)
                returning id_pedidos, codigo
                """,
                (session["cliente_id"], pagamento, tipo_entrega, frete_pago_por),
            )
            id_pedido, codigo = cur.fetchone()

            # 2) Os itens disparam validar_item_vendavel (cor esgotada,
            #    produto indisponível) e recalcular_pedido (subtotal).
            for linha in linhas:
                cur.execute(
                    """
                    insert into bloome.itens_pedidos
                        (id_pedidos, id_variacao, quantidade)
                    values (%s, %s, %s)
                    """,
                    (id_pedido, linha["id_variacao"], linha["quantidade"]),
                )

            # 3) Estoque dos insumos: se algum não cobre o pedido, desfaz
            #    TUDO (pedido e itens) antes de qualquer commit.
            cur.execute(
                """
                select nome
                from bloome.verificar_estoque_pedido(%s)
                where not suficiente
                """,
                (id_pedido,),
            )
            if cur.fetchall():
                conn.rollback()
                flash("Alguns itens ficaram sem estoque. Ajuste o carrinho e tente de novo.", "erro")
                return redirect(url_for("carrinho"))

            # 4) SIMULAÇÃO de pagamento aprovado, até o Mercado Pago (passo 5).
            #    confirmar_pagamento é a função do banco para confirmação
            #    manual: recheca estoque, baixa os insumos e marca o pedido
            #    como pago — o mesmo caminho que o webhook usará depois.
            cur.execute(
                "select bloome.confirmar_pagamento(%s, null, null)",
                (id_pedido,),
            )
            if cur.fetchone()[0] != "pago":
                conn.rollback()
                flash("O estoque acabou enquanto fechávamos seu pedido. Tente de novo.", "erro")
                return redirect(url_for("carrinho"))

            # 5) Pago -> fila de produção ("Em preparação" na tela).
            cur.execute(
                "update bloome.pedidos set status = 'em_producao' where id_pedidos = %s",
                (id_pedido,),
            )

        conn.commit()
    except psycopg.Error:
        # Triggers do banco (cor esgotou, produto saiu de linha) chegam aqui:
        # a transação inteira volta atrás, o carrinho fica intacto.
        conn.rollback()
        flash("Um item ficou indisponível enquanto você finalizava. Confira o carrinho.", "erro")
        return redirect(url_for("carrinho"))

    session.pop("carrinho", None)
    flash(f"Pedido {codigo} criado! Guarde o código para acompanhar.", "sucesso")
    return redirect(url_for("pedido_detalhe", codigo=codigo))


@app.route("/pedido/<codigo>")
@login_requerido
def pedido_detalhe(codigo):
    pedido = dados.buscar_pedido_cliente(session["cliente_id"], codigo)
    if pedido is None:
        abort(404)
    return render_template(
        "pedido.html",
        current="painel",
        pedido=_pedido_para_template(pedido),
    )


@app.route("/favoritos")
def favoritos():
    # Favoritos ainda não persistem (sem tabela): a página exibe os
    # 3 primeiros produtos do catálogo, com os mesmos dados de /produtos.
    lista = dados.listar_produtos()
    return render_template(
        "favoritos.html", current="favoritos", produtos=lista[:3]
    )

@app.route("/sobre")
def sobre():
    return render_template("sobre.html", current="sobre")

@app.route("/carrinho")
def carrinho():
    linhas = session.get("carrinho", [])
    itens = dados.montar_carrinho(linhas)
    subtotal_valor = sum(item["preco_valor"] * item["quantidade"] for item in itens)
    return render_template(
        "carrinho.html",
        current="carrinho",
        itens=itens,
        subtotal=dados.formatar_preco(subtotal_valor),
    )


@app.route("/conta")
def conta():
    return render_template(
        "conta.html",
        current="conta",
        destino=_destino_seguro(url_for("painel")),
    )

@app.route("/conta/entrar", methods=["POST"])
def entrar():
    email = request.form.get("email", "").strip().lower()
    senha = request.form.get("senha", "")

    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            select id_cliente, nome, senha_hash
            from bloome.clientes
            where email = %s and anonimizado_em is null
            """,
            (email,),
        )
        cliente = cur.fetchone()

    destino = _destino_seguro(url_for("painel"))

    if cliente is None or not bcrypt.checkpw(
        senha.encode("utf-8"), cliente["senha_hash"].encode("utf-8")
    ):
        flash("E-mail ou senha inválidos.", "erro")
        return redirect(url_for("conta", next=destino))

    # O carrinho mora na sessão; limpar a sessão (anti-fixação) não pode
    # levar o carrinho junto quando o login acontece no checkout.
    carrinho = session.get("carrinho")
    session.clear()
    session["cliente_id"] = cliente["id_cliente"]
    session["cliente_nome"] = cliente["nome"]
    if carrinho is not None:
        session["carrinho"] = carrinho
    return redirect(destino)


@app.route("/conta/sair", methods=["POST"])
def sair():
    session.clear()
    flash("Você saiu da sua conta.", "sucesso")
    return redirect(url_for("conta"))


@app.route("/conta/criar", methods=["POST"])
def criar_conta():
    nome = request.form.get("nome", "").strip()
    email = request.form.get("email", "").strip().lower()
    whatsapp = request.form.get("whatsapp", "").strip()
    senha = request.form.get("senha", "")
    confirmar = request.form.get("confirmar-senha", "")

    valido = True

    if len(nome) < 2:
        flash("Informe seu nome completo.", "erro")
        valido = False

    if not ("@" in email and "." in email.split("@")[-1]):
        flash("Informe um e-mail válido, por exemplo nome@email.com.", "erro")
        valido = False

    if len(senha) < 8:
        flash("A senha precisa ter pelo menos 8 caracteres.", "erro")
        valido = False

    if senha != confirmar:
        flash("As senhas não conferem.", "erro")
        valido = False

    destino = _destino_seguro(url_for("painel"))

    if not valido:
        # Volta para a aba "Criar conta", não para "Entrar", sem perder
        # o destino (ex.: voltar ao carrinho depois de se cadastrar).
        return redirect(url_for("conta", aba="criar", next=destino))

    hash_senha = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    conn = db.get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                insert into bloome.clientes (nome, email, senha_hash, telefone)
                values (%s, %s, %s, %s)
                returning id_cliente
                """,
                (nome, email, hash_senha, whatsapp or None),
            )
            id_cliente = cur.fetchone()[0]
        conn.commit()
    except psycopg.errors.UniqueViolation:
        conn.rollback()
        flash("Já existe uma conta com esse e-mail. Tente entrar.", "erro")
        return redirect(url_for("conta", aba="criar", next=destino))
    except psycopg.Error:
        conn.rollback()
        flash("Não foi possível criar a conta agora. Tente de novo.", "erro")
        return redirect(url_for("conta", aba="criar", next=destino))

    # Mesma regra do login: preserva o carrinho ao trocar de sessão.
    carrinho = session.get("carrinho")
    session.clear()
    session["cliente_id"] = id_cliente
    session["cliente_nome"] = nome
    if carrinho is not None:
        session["carrinho"] = carrinho
    flash("Conta criada com sucesso!", "sucesso")
    return redirect(destino)


@app.route("/painel")
@login_requerido
def painel():
    pedidos = [
        _pedido_para_template(pedido)
        for pedido in dados.listar_pedidos_cliente(session["cliente_id"])
    ]
    return render_template("painel.html", current="painel", pedidos=pedidos)

@app.errorhandler(404)
def pagina_nao_encontrada(erro):
    return render_template("erro.html", current="erro"), 404

if __name__ == "__main__":
    app.run(debug=True)