# Bloome

[![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.x-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Jinja2](https://img.shields.io/badge/Jinja2-templates-B41717)](https://jinja.palletsprojects.com/)
[![WCAG 2.1 AA](https://img.shields.io/badge/WCAG-2.1%20AA-2E7D32)](https://www.w3.org/WAI/WCAG21/quickref/)

Loja de acessórios artesanais da **Bloome**: catálogo, carrinho, favoritos, cadastro,
pedidos e painel do cliente. Feita em **Flask + PostgreSQL**, com interface em
português e foco em **acessibilidade (WCAG 2.1 AA)**.

![Catálogo da Bloome](docs/capturas/catalogo.png)

> Guia detalhado para montar em outro computador (inclusive o do laboratório):
> **[COMO-RODAR.md](COMO-RODAR.md)**.

## Requisitos

- Python **3.11+**
- PostgreSQL **14+** (local ou na nuvem — o projeto usa o mesmo banco nos dois lugares)
- pip e um terminal

## Rodando localmente

```bash
# 1. Ambiente virtual
python -m venv .venv
# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# macOS/Linux:
source .venv/bin/activate

# 2. Dependências
pip install -r requirements.txt

# 3. Banco
createdb bloome

# 4. Variáveis de ambiente
#    Copie .env.example para .env e preencha:
#    - SECRET_KEY: python -c "import secrets; print(secrets.token_hex(32))"
#    - DATABASE_URL: postgresql://postgres:SUA_SENHA@localhost:5432/bloome
cp .env.example .env

# 5. Cria schema, tabelas, funções, views e catálogo inicial
python db/aplicar.py --aplicar

# 6. Dados de demonstração (descrições, fotos e estoque)
python db/aplicar.py --dados --teste

# 7. Sobe o site
python app.py
```

Abra **http://127.0.0.1:5000**.

O banco já vem com as 16 peças do catálogo e estoque fictício para testar.
**Não há conta pronta**: cadastre-se em `/conta` para testar carrinho,
favoritos, checkout e painel (o pedido é finalizado com pagamento simulado).

## Páginas

| Rota | O que é |
| --- | --- |
| `/` | Home com o catálogo completo (Catálogo Bloome e Cápsula Maré) |
| `/produtos/<slug>` | Página da peça (cores, quantidade, favoritar) |
| `/carrinho` | Carrinho (quantidade e remoção) |
| `/checkout` | Entrega, pagamento simulado e confirmação |
| `/conta` | Entrar / criar conta |
| `/favoritos` | Favoritos (requer login) |
| `/painel` | Pedidos e favoritos do cliente (requer login) |
| `/pedido/<codigo>` | Detalhe de um pedido do próprio cliente |
| `/sobre` | Sobre a marca |

`/produtos` redireciona (301) para a home, onde o catálogo vive.

## Documentação

| Documento | Conteúdo |
| --- | --- |
| [docs/PRD.md](docs/PRD.md) | Requisitos do produto: visão, personas, funcionalidades, regras e critérios de aceite |
| [docs/AUTENTICACAO.md](docs/AUTENTICACAO.md) | Sessões e cookies: como o login funciona e por quê |
| [docs/VALIDACAO-REGRAS.md](docs/VALIDACAO-REGRAS.md) | Regras de negócio validadas (fonte da verdade) |
| [docs/DECISOES.md](docs/DECISOES.md) | Decisões de arquitetura (ADR) com data e motivo |
| [COMO-RODAR.md](COMO-RODAR.md) | Instalação do zero em outra máquina |
| [AGENTS.md](AGENTS.md) | Regras de trabalho e uso de IA no desenvolvimento |

## Como o banco é montado

Todos os arquivos ficam em `db/` e são aplicados por `db/aplicar.py`:

| Arquivo | Conteúdo |
| --- | --- |
| `01_schema.sql` | Tabelas, constraints e triggers |
| `02_funcoes.sql` | Regras de negócio (estoque, totais, pagamento) |
| `03_views.sql` | Views públicas do catálogo |
| `99_tests.sql` | 28 testes em `BEGIN … ROLLBACK` (não gravam nada) |
| `04_seed.sql` | Catálogo inicial |
| `06_dados_reais.sql` | Fotos e descrições reais |
| `07_placeholder_teste.sql` | Estoque fictício para demonstração |
| `08_favoritos.sql` | Tabela de favoritos (adicionada depois) |

Cálculos de dinheiro (subtotal, frete, total) acontecem **somente no servidor**,
dentro do PostgreSQL e do Flask — nunca no JavaScript.

## Estrutura

```
app.py           rotas Flask e regras de sessão
dados.py         todas as consultas ao banco (a rota não escreve SQL)
db.py            conexão psycopg
db/              SQL versionado + aplicar.py
templates/       Jinja (base, home, produto, carrinho, checkout, conta, painel)
static/          CSS, JavaScript e fotos
docs/            PRD, autenticação, regras (ADR) e capturas
.agents/         skills de desenvolvimento usadas com IA
```

## Desenvolvimento com apoio de IA

O projeto foi construído com assistência de IA, e as regras que guiaram esse
trabalho ficam versionadas:

- `AGENTS.md` / `CLAUDE.md` — convenções do time: método de trabalho, regras de
  negócio, o que nunca pode quebrar (cálculo de dinheiro no servidor, WCAG, segredos).
- `.claude/skills/acessibilidade` e `.agents/skills/acessibilidade` — skill de
  auditoria WCAG 2.1 AA dos templates.
- `.claude/agents/auditor-wcag` — agente que revisa HTML/CSS e aponta violações.
- `.agents/skills/` — skills de desenvolvimento usadas (acessibilidade e boas
  práticas de PostgreSQL/Supabase).
- `docs/DECISOES.md` — registro de arquitetura (ADR), com data e motivo de cada escolha.

Cada decisão de banco, autenticação ou estrutura foi registrada antes de virar código.

## Front integrado ao back (Jinja2)

O HTML não é estático: cada página é um template Jinja renderizado pelo Flask
com os dados já prontos.

```python
# app.py
@app.route("/produtos/<slug>")
def produto(slug):
    return render_template("produto.html", produto=dados.buscar_produto(slug))
```

```jinja
{# templates/produto.html #}
<h1>{{ produto.nome }}</h1>
<span class="preco">{{ produto.preco }}</span>
<a href="{{ url_for('carrinho') }}">Carrinho</a>
```

- `dados.py` faz a consulta; a rota entrega o dicionário pronto.
- O template usa `{{ }}` para exibir e `{% %}` para laços/condições.
- `url_for()` gera os endereços, então mudar uma rota não quebra links.
- Formulários enviam `POST` para o Flask; o servidor valida, grava e redireciona
  (padrão POST-Redirect-GET), sem cálculo de dinheiro no navegador.

## Acessibilidade

- `lang="pt-BR"`, HTML semântico e um `h1` por página
- Contraste mínimo 4,5:1, foco visível em todos os controles, alvos de 44px
- Navegação por teclado, `aria-current`, `aria-live` para avisos
- Respeito a `prefers-reduced-motion`

## Equipe

- **Victor Xavier** — [GitHub](https://github.com/victorxavier01) · [LinkedIn](https://www.linkedin.com/in/victor-xavier-89a339378/)
- **Martin Alexandre** — [GitHub](https://github.com/martin-alexandre-707) · [LinkedIn](https://www.linkedin.com/in/martin-alexandre-724451409/)
- **Anthonio Fon** — [GitHub](https://github.com/TonysXD) · [LinkedIn](https://www.linkedin.com/in/anthonio-pontes-fon-4a25a6319/)
