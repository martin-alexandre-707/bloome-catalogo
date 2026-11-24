import os

from dotenv import load_dotenv
from flask import Flask, abort, render_template
from psycopg.rows import dict_row
import db


load_dotenv()

app = Flask(__name__)
app.secret_key= os.environ["SECRET_KEY"]

db.init_app(app)

def formatar_preco(valor):
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")

@app.route("/")
def index():
    return render_template("index.html", current="index")

@app.route("/produtos")
def produtos():
    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute("""
            select id_acessorios, nome_acessorios, valor_acessorario,
                   foto, descricao, status_exibicao
            from bloome.vw_catalogo_publico
            order by id_acessorios
        """)
        linhas = cur.fetchall()

    lista = [
        {
            "id": l["id_acessorios"],
            "nome": l["nome_acessorios"],
            "preco": formatar_preco(l["valor_acessorario"]),
            "imagem": l["foto"],
            "descricao": l["descricao"],
            "status_exibicao": l["status_exibicao"],
        }
        for l in linhas
    ]
    return render_template("produtos.html", current="produtos", produtos=lista)


@app.route("/produtos/<int:produto>")
def produto(produto):
    conn = db.get_db()
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute("""
            select id_acessorios, nome_acessorios, valor_acessorario,
                   foto, descricao, status_exibicao
            from bloome.vw_catalogo_publico
            where id_acessorios = %s
        """, (produto,))
        linha = cur.fetchone()

        if linha is None:
            abort(404)

        cur.execute("""
            select cor, cor_hex, disponivel
            from bloome.vw_variacoes_disponiveis
            where id_acessorios = %s
            order by ordem
        """, (produto,))
        cores = cur.fetchall()

        cur.execute("""
            select id_acessorios, nome_acessorios, valor_acessorario, foto
            from bloome.vw_catalogo_publico
            where id_acessorios <> %s
            order by id_acessorios
            limit 3
        """, (produto,))
        rel = cur.fetchall()

    item = {
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
    relacionados = [
        {
            "id": r["id_acessorios"],
            "nome": r["nome_acessorios"],
            "preco": formatar_preco(r["valor_acessorario"]),
            "imagem": r["foto"],
        }
        for r in rel
    ]

    return render_template(
        "produto.html",
        current="produtos",
        produto=item,
        relacionados=relacionados,
    )



 
@app.route("/favoritos")
def favoritos():
    return render_template("favoritos.html", current="favoritos")

@app.route("/sobre")
def sobre():
    return render_template("sobre.html", current="sobre")

@app.route("/carrinho")
def carrinho():
    return render_template("carrinho.html", current="carrinho")

@app.route("/conta")
def conta():
    return render_template("conta.html", current="conta")

@app.route("/painel")
def painel():
    return render_template("painel.html", current="painel")

@app.errorhandler(404)
def pagina_nao_encontrada(erro):
    return render_template("erro.html", current="erro"), 404

if __name__ == "__main__":
    app.run(debug=True)