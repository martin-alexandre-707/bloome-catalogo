# Autenticação: sessões e cookies

Como o Bloome sabe quem é quem entre uma página e outra — e por que isso é
seguro o suficiente para o MVP.

## 1. O problema

O navegador e o servidor não se lembram um do outro. Cada requisição HTTP chega
"sem memória": o servidor não sabe se quem pediu `/painel` é a mesma pessoa que
fez login dois segundos antes. É como uma loja em que o atendente troca a cada
cliente: alguém precisa entregar um crachá.

- **Cookie** é o crachá: um pequeno texto que o servidor manda e o navegador
  devolve em toda requisição para aquele site.
- **Sessão** é a ficha do crachá guardada no servidor: "crachá nº X pertence à
  cliente Y, com o carrinho Z".

## 2. O que o Flask faz

O Bloome usa a sessão nativa do Flask, que é **um cookie assinado** — não um
arquivo no servidor. O cookie carrega os dados da sessão em base64 e uma
assinatura HMAC feita com `SECRET_KEY`.

```
session = {cliente_id: 12, cliente_nome: "Maria", carrinho: [...]}
cookie  = base64(session) + "." + assinatura
```

- Qualquer pessoa consegue **ler** o conteúdo (base64 não é criptografia).
- Ninguém consegue **alterar** sem a `SECRET_KEY`: a assinatura deixa de bater
  e o Flask descarta o cookie.

Por isso a regra do projeto: **nada sensível dentro da sessão**. Guardamos
apenas `cliente_id`, `cliente_nome` e a lista do carrinho (`id_variacao` +
`quantidade`). Nunca senha, nunca preço.

## 3. Configuração do cookie

Em `app.py`:

```python
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=bool(os.environ.get("RENDER"))
    or os.environ.get("SESSION_COOKIE_SECURE") == "1",
)
```

| Opção | O que impede | Analogia |
| --- | --- | --- |
| `HttpOnly` | JavaScript da página ler o cookie | o crachá fica no bolso, não na mão |
| `SameSite=Lax` | outro site disparar requisições autenticadas | o crachá só vale dentro da loja |
| `Secure` | o cookie viajar em HTTP comum | só entregar o crachá em portão com cancela (HTTPS) |

`Secure` liga sozinho no Render (variável `RENDER`) e fica desligado no
`localhost`, que roda em HTTP.

## 4. Cadastro e login

### Cadastro (`POST /conta/criar`)

1. Nome, e-mail, WhatsApp e senha chegam por formulário.
2. O servidor valida o formato — o HTML ajuda, mas não é confiável.
3. A senha vira hash com **bcrypt** (custo aleatório por conta):
   `bcrypt.hashpw(senha.encode(), bcrypt.gensalt())`.
4. O hash é gravado em `bloome.clientes.senha_hash`; a senha original não é
   armazenada em lugar nenhum.

Hash é uma função de mão única: dá para conferir a senha depois
(`bcrypt.checkpw`), mas não dá para voltar do hash para a senha.

### Login (`POST /conta`)

```python
if cliente is None or not bcrypt.checkpw(senha.encode(), cliente["senha_hash"].encode()):
    flash("E-mail ou senha inválidos.", "erro")
```

A mensagem é sempre a mesma para e-mail inexistente e senha errada: dizer
"esse e-mail não existe" entregaria a lista de clientes para quem tenta.

## 5. Anti-fixação de sessão

Se o servidor aproveitasse a sessão anônima da visitante e apenas colocasse o
`cliente_id` dentro, um atacante que tivesse plantado um cookie antes poderia
continuar usando a sessão já autenticada.

Por isso o login **descarta a sessão antiga** e cria uma nova:

```python
carrinho = session.get("carrinho")
session.clear()                 # joga fora a sessão anônima
session["cliente_id"] = cliente["id_cliente"]
session["cliente_nome"] = cliente["nome"]
if carrinho is not None:
    session["carrinho"] = carrinho   # preserva a compra em andamento
```

O carrinho é o único dado que sobrevive, porque quem entrou no checkout não
pode perder as peças escolhidas. Logout (`POST /conta/sair`) limpa tudo.

## 6. Protegendo páginas

`login_requerido` é um decorador aplicado nas rotas privadas (`/painel`,
`/favoritos`, `/checkout`, `/pedido/<codigo>`):

```python
def login_requerido(view):
    @wraps(view)
    def protegida(*args, **kwargs):
        if not session.get("cliente_id"):
            return redirect(url_for("conta", next=request.path))
        return view(*args, **kwargs)
    return protegida
```

O parâmetro `next` devolve a pessoa ao lugar de onde saiu (o checkout, por
exemplo). Como `next` vem da URL, ele passa por `_destino_seguro`: só caminhos
internos são aceitos, senão vira um **open redirect** — um link do Bloome que
jogaria a cliente em outro site.

## 7. Autorização por dono

Estar logado não basta: cada pedido é buscado com `where id_cliente = %s and
codigo = %s`. O pedido de outra pessoa simplesmente "não existe" para quem
está logado — a rota responde 404.

## 8. Por que não JWT?

JWT é útil quando há um cliente separado (SPA, app) que precisa de um token
autocontido. Aqui o HTML é renderizado pelo próprio Flask, cookie de sessão
resolve, e o logout é imediato (o servidor descarta a sessão). JWT traria
complexidade sem ganho para o MVP.

## 9. Limites conhecidos (próxima fase)

- **Sem token CSRF**: `SameSite=Lax` cobre o caso comum, mas não é equivalente.
- **Sem limite de tentativas** no login (rate limiting).
- **Sem expiração explícita** da sessão; o cookie dura enquanto o navegador.
- **Recuperação de senha** ainda não envia e-mail.
