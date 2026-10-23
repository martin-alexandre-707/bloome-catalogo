from flask import Flask, abort, render_template

from catalogo import PRODUTOS

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html", current="index")

@app.route("/produtos")
def produtos():
    return render_template("produtos.html", current="produtos")

@app.route("/produtos/<int:produto>")
def produto(produto):
    item = PRODUTOS.get(produto)

    if item is None:
        abort(404)

    relacionados = [{"id": chave, **dados} for chave, dados in PRODUTOS.items() if chave != produto][:3]

    print(relacionados)

    return render_template(
        "produto.html",
        current="produtos",
        produto={"id": produto, **item},
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