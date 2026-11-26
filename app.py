import os
from functools import wraps

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
    if dados.modo_mock():
        # Só vale quando não há banco: serve para o clone rodar sem .env.
        _chave = "modo-mock-sem-seguranca-nao-use-em-producao"
    else:
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
            flash("Entre na sua conta para acessar o painel.", "erro")
            return redirect(url_for("conta"))
        return view(*args, **kwargs)

    return protegida

@app.route("/")
def index():
    return render_template("index.html", current="index")

@app.route("/produtos")
def produtos():
    lista = dados.listar_produtos()
    return render_template("produtos.html", current="produtos", produtos=lista)


@app.route("/produtos/<int:produto>")
def produto(produto):
    item = dados.buscar_produto(produto)

    if item is None:
        abort(404)

    return render_template(
        "produto.html",
        current="produtos",
        produto=item,
        relacionados=dados.listar_relacionados(produto),
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
    return render_template("carrinho.html", current="carrinho")

@app.route("/conta")
def conta():
    return render_template("conta.html", current="conta")

@app.route("/conta/entrar", methods=["POST"])
def entrar():
    if dados.modo_mock():
        flash("Modo demonstração: entrar na conta exige o banco real.", "erro")
        return redirect(url_for("conta"))

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

    if cliente is None or not bcrypt.checkpw(
        senha.encode("utf-8"), cliente["senha_hash"].encode("utf-8")
    ):
        flash("E-mail ou senha inválidos.", "erro")
        return redirect(url_for("conta"))

    session.clear()
    session["cliente_id"] = cliente["id_cliente"]
    session["cliente_nome"] = cliente["nome"]
    return redirect(url_for("painel"))


@app.route("/conta/sair", methods=["POST"])
def sair():
    session.clear()
    flash("Você saiu da sua conta.", "sucesso")
    return redirect(url_for("conta"))


@app.route("/conta/criar", methods=["POST"])
def criar_conta():
    if dados.modo_mock():
        flash("Modo demonstração: criar conta exige o banco real.", "erro")
        return redirect(url_for("conta"))

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

    if not valido:
        return redirect(url_for("conta"))

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
        return redirect(url_for("conta"))
    except psycopg.Error:
        conn.rollback()
        flash("Não foi possível criar a conta agora. Tente de novo.", "erro")
        return redirect(url_for("conta"))

    session.clear()
    session["cliente_id"] = id_cliente
    session["cliente_nome"] = nome
    flash("Conta criada com sucesso!", "sucesso")
    return redirect(url_for("painel"))


@app.route("/painel")
@login_requerido
def painel():
    return render_template("painel.html", current="painel")

@app.errorhandler(404)
def pagina_nao_encontrada(erro):
    return render_template("erro.html", current="erro"), 404

if __name__ == "__main__":
    app.run(debug=True)