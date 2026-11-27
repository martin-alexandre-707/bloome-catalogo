# Como rodar o Bloome em outro computador

Guia para montar o projeto do zero em uma máquina com Windows, macOS ou Linux,
usando um PostgreSQL instalado localmente. Funciona sem internet depois de
instalado.

## 1. Instale o necessário

| Programa | Versão | Como conferir |
| --- | --- | --- |
| Python | 3.11 ou mais novo | `python --version` |
| PostgreSQL | 14 ou mais novo | `psql --version` |

- Python: <https://www.python.org/downloads/> (no Windows, marque **"Add python.exe to PATH"** na instalação).
- PostgreSQL: <https://www.postgresql.org/download/> (guarde a senha do usuário `postgres` definida na instalação).

## 2. Baixe o projeto

Com Git:

```bash
git clone <URL-DO-REPOSITORIO>
cd bloome-catalogo
```

Ou baixe o ZIP pelo GitHub (**Code → Download ZIP**) e descompacte.

## 3. Crie o banco

No terminal:

```bash
createdb -U postgres bloome
```

No Windows, se `createdb` não for reconhecido, use o **pgAdmin** (instalado junto
com o PostgreSQL): clique com o botão direito em *Databases → Create → Database*
e use o nome `bloome`.

## 4. Prepare o Python

```bash
python -m venv .venv
```

Ativar o ambiente:

- **Windows (PowerShell):** `.venv\Scripts\Activate.ps1`
- **Windows (CMD):** `.venv\Scripts\activate.bat`
- **macOS/Linux:** `source .venv/bin/activate`

Instalar as dependências:

```bash
pip install -r requirements.txt
```

## 5. Configure o `.env`

Copie o modelo:

```bash
# Windows
copy .env.example .env
# macOS/Linux
cp .env.example .env
```

Abra o `.env` e preencha:

```env
SECRET_KEY=cole-uma-chave-aleatoria
DATABASE_URL=postgresql://postgres:SUA_SENHA@localhost:5432/bloome
```

Para gerar a chave:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

Se a senha do PostgreSQL tiver `@`, `:` ou `/`, troque esses caracteres pela
versão codificada (`%40`, `%3A`, `%2F`).

## 6. Monte o banco

```bash
python db/aplicar.py --aplicar
python db/aplicar.py --dados --teste
```

O primeiro comando cria schema, tabelas, funções, views, roda os 28 testes
(sem gravar nada) e insere o catálogo. O segundo acrescenta fotos, descrições
e estoque fictício para demonstração.

## 7. Suba o site

```bash
python app.py
```

Abra **http://127.0.0.1:5000**.

## 8. Crie sua conta de teste

Clique em **Entrar → Criar conta**. Não existe conta pronta no banco — qualquer
pessoa cadastrada pode testar carrinho, favoritos, checkout e painel.

## Problemas comuns

| Sintoma | Causa provável | Solução |
| --- | --- | --- |
| `python não é reconhecido` | Python fora do PATH | Reinstale marcando "Add to PATH" ou use `py` no Windows |
| `password authentication failed` | Senha errada no `.env` | Confira a senha do usuário `postgres` |
| `Connection refused` em `localhost:5432` | PostgreSQL parado | Inicie o serviço (Windows: *Serviços → postgresql*) |
| `O schema bloome já existe` | Banco já montado | Use outro banco ou apague e recrie: `dropdb bloome && createdb bloome` |
| `DATABASE_URL ausente` | `.env` não criado ou na pasta errada | O arquivo precisa estar na raiz do projeto |
| Acentuação estranha no terminal | Codificação do Windows | `chcp 65001` antes de rodar |
| Porta 5000 ocupada | Outro programa usando | Feche o outro programa ou rode `flask run --port 5001` |

## Sem internet na apresentação

Depois do passo 6, o projeto funciona **totalmente offline**: o banco é local e
as fotos estão em `static/imgs/`. Não é preciso Supabase nem conexão.
