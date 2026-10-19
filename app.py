from flask import Flask, render_template

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html", current="index")

@app.route("/produtos")
def produtos():
    return render_template("produtos.html", current="produtos")

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

if __name__ == "__main__":
    app.run(debug=True)