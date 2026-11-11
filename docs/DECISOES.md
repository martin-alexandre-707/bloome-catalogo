# DECISOES.md — Registro de Decisões de Arquitetura (ADR)

> **O que é:** a ata técnica do projeto. Cada decisão sobre banco, autenticação,
> estrutura ou processo vira uma entrada numerada — uma **ADR** (*Architecture
> Decision Record*, ou "registro de decisão de arquitetura").
>
> **Quem escreve:** a IA no papel de Mentor, com data, autor e motivo técnico.
> O time revisa, contesta e pede ajustes.
>
> **Regra de ouro (append-only):** este arquivo só cresce. Nenhuma decisão é
> apagada ou reescrita. Se a decisão mudar, crie uma **nova** ADR e marque a
> antiga como `Substituída por ADR-00X`. É como o histórico do git: o passado
> permanece registrado.

---

## Índice

| ID | Data | Tema | Status | Resumo |
|----|------|------|--------|--------|
| ADR-001 | 2026-11-06 | Stack | Aceita | Flask + Jinja, sem etapa de build |
| ADR-002 | 2026-11-06 | Banco | Aceita | Supabase é o único banco (dev e produção) |
| ADR-003 | 2026-11-06 | Migração | Aceita | Trocar aos poucos, com fallback |
| ADR-004 | 2026-11-06 | Auth | Aceita | Catálogo livre + painel com bcrypt e sessão |
| ADR-005 | 2026-11-06 | Segurança | Aceita | `.env` + `.gitignore`; `.env.example` versionado |
| ADR-006 | 2026-11-06 | Acessibilidade | Aceita | WCAG 2.1 AA é requisito não negociável |
| ADR-007 | 2026-11-07 | Git | Aceita | Sem `Co-Authored-By` de IA nos commits |
| ADR-008 | 2026-11-09 | Processo | Aceita | Ordem: fundação → banco → auth → front → pagamentos |
| ADR-009 | 2026-11-09 | Banco | Aceita | psycopg 3 + SQL puro (sem ORM) |
| ADR-010 | 2026-11-10 | Escopo | Aceita | Fora do escopo: sistema de gestão com IA e Text-to-SQL |

> **Como ler:** as entradas estão em ordem cronológica. As mais recentes ficam
> no fim. Use o índice acima para navegar.

---

## ADR-001 — Stack web: Flask + Jinja, sem build

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o catálogo nasceu como HTML/CSS estático e precisava de rotas,
  templates reutilizáveis e, depois, banco de dados.
- **Decisão:** usar **Python + Flask 3.x** com **templates Jinja**; sem framework
  JavaScript e sem etapa de build (o que roda no navegador é HTML/CSS/JS puro).
- **Motivo técnico:** stack que o time já domina; menos peças móveis, deploy
  simples e foco no aprendizado de arquitetura web.
- **Alternativas consideradas:**
  - HTML estático — não atende banco/auth no futuro.
  - Django — estrutura demais para o escopo atual.
  - Next.js/Node — muda o foco e adiciona etapa de build.
- **Consequências:**
  - Toda página nova herda de `base.html` e preenche `title`, `description` e
    `content`.
  - Nunca abrir `templates/*.html` direto no navegador: são Jinja.
  - A lógica de negócio fica no Python; o navegador só apresenta.
- **Arquivos:** `app.py`, `templates/`, `requirements.txt`

---

## ADR-002 — Banco: Supabase (Postgres na nuvem), sem Postgres local

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** os dados estão em memória (`PRODUTOS`, em `catalogo.py`).
  Precisamos de banco real sem criar diferença entre desenvolvimento e produção.
- **Decisão:** usar **Supabase (Postgres na nuvem)** como único banco, em
  desenvolvimento e produção. **Não** haverá PostgreSQL local.
- **Motivo técnico:** elimina o risco de "na minha máquina funciona" e a migração
  surpresa no fim; o free tier atende o projeto; o pooler é obrigatório em
  funções serverless (Vercel).
- **Alternativas consideradas:**
  - Postgres local — dois ambientes diferentes, mais risco.
  - SQLite — simples, mas não é o alvo de produção.
- **Consequências:**
  - `DATABASE_URL` no `.env`, nunca no código.
  - Porta **6543** = pooler (produção/serverless); **5432** = conexão direta
    (DBeaver/psql).
  - Ainda falta instalar o driver (`psycopg` ou SQLAlchemy) — decisão futura.
- **Arquivos:** `.env` (não versionado), `requirements.txt` (futuro)

---

## ADR-003 — Refatoração estranguladora

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o catálogo atual funciona com dados em memória. Substituir tudo
  de uma vez quebraria o site e dificultaria achar a causa.
- **Decisão:** migrar para o banco **aos poucos** (*strangler pattern*): o código
  antigo continua funcionando como **fallback** até a nova versão estar validada.
- **Motivo técnico:** cada passo é pequeno, testável e reversível; o site nunca
  fica fora do ar.
- **Alternativas consideradas:**
  - Big bang (trocar tudo de uma vez) — risco alto e difícil de depurar.
- **Consequências:**
  - Os 6 produtos de `catalogo.py` viram **seed** de migração.
  - `/produtos` passa a ler do banco mantendo `PRODUTOS` como fallback.
  - Remover o código antigo só depois de validar o novo.
- **Arquivos:** `catalogo.py`, `app.py`

---

## ADR-004 — Autenticação: painel do vendedor

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o visitante deve navegar livremente; o vendedor precisa de uma
  área protegida.
- **Decisão:** catálogo público + **painel do vendedor** protegido por **senha
  com hash bcrypt** e **sessão**. Login de clientes fica para o futuro, sem
  apagar o código legado.
- **Motivo técnico:** resolve o caso real agora com a menor superfície de ataque;
  bcrypt não guarda senha em texto puro; a sessão evita reautenticar a cada
  clique.
- **Alternativas consideradas:**
  - Login de clientes já — aumenta o escopo sem necessidade imediata.
  - OAuth/social login — complexidade desnecessária neste momento.
- **Consequências:**
  - `bcrypt` entra no `requirements.txt` (ainda não está).
  - `SECRET_KEY` passa a ser obrigatória.
  - Rotas do painel exigem guarda de sessão (sem sessão → redirecionar).
- **Arquivos:** `app.py`, `requirements.txt`, `templates/painel.html`

---

## ADR-005 — Segredos e configuração

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** `SECRET_KEY` e `DATABASE_URL` são segredos; se vazarem, qualquer
  pessoa assume sessões ou acessa o banco.
- **Decisão:** centralizar tudo em `.env`; manter `.env` no `.gitignore`;
  versionar um `.env.example` **sem valores reais**.
- **Motivo técnico:** segurança e facilidade de onboarding (o próximo dev sabe
  quais variáveis existem sem receber os segredos).
- **Alternativas consideradas:**
  - Hardcode no código — inaceitável.
  - Só variáveis na máquina — difícil de reproduzir e documentar.
- **Consequências:**
  - Adicionar `python-dotenv` (ou equivalente) para carregar o `.env`.
  - Criar `.env.example`; o `.gitignore` já está preparado para ele.
  - Nunca commitar `.env`.
- **Arquivos:** `.gitignore`, `.env.example` (a criar)

---

## ADR-006 — Acessibilidade WCAG 2.1 AA

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o projeto tem foco declarado em acessibilidade e o `styles.css`
  tem ~1.575 linhas com decisões validadas. Regressões são caras.
- **Decisão:** **WCAG 2.1 AA é requisito não negociável**; não reescrever o
  `styles.css` inteiro sem combinar.
- **Motivo técnico:** inclusão real (não só discurso) e diferencial de portfólio;
  corrigir acessibilidade depois custa muito mais.
- **Alternativas consideradas:**
  - Tratar acessibilidade só no fim — retrabalho e risco de quebrar o CSS.
- **Consequências:**
  - Checklist: `lang="pt-BR"`, um `h1` por página, `alt` descritivo,
    `:focus-visible` visível, contraste ≥ 4,5:1, `aria-current="page"`,
    HTML semântico e padrão `<dialog>`.
  - Auditoria antes de cada entrega.
  - Skill de auditoria será criada (próximo passo).
- **Arquivos:** `templates/`, `static/css/styles.css`

---

## ADR-007 — Commits sem atribuição de IA

- **Data:** 2026-11-07
- **Autor:** Martin Alexandre *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** um commit gerado com `Co-Authored-By: Claude Code
  <noreply@anthropic.com>` fez a conta **claude** aparecer no painel de
  *Contributors* do GitHub, mesmo sem autoria real. O GitHub credita o e-mail
  `noreply@anthropic.com` àquela conta.
- **Decisão:** **não incluir** `Co-Authored-By` (nem qualquer e-mail
  `@anthropic.com`) nas mensagens de commit. Autor e committer são sempre
  pessoas do time.
- **Motivo técnico:** o painel de contribuidores é calculado por e-mail de
  autor/coautor; atribuição indevida polui o histórico e o portfólio.
- **Alternativas consideradas:**
  - Deixar como está — polui o portfólio.
  - Corrigir só depois — exige reescrever histórico e force-push (custoso).
- **Consequências:**
  - Regra registrada em `AGENTS.md` (vale para todas as sessões).
  - Se um commit escapar, corrigir com `git commit --amend` ou rebase **antes**
    do push.
  - Histórico já corrigido: `4761c462` → `7ff1063` no `main`.
- **Arquivos:** `AGENTS.md`

---

## ADR-008 — Ordem de implementação do MVP

- **Data:** 2026-11-09
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o time listou várias frentes ao mesmo tempo (banco, front,
  login, pagamentos) e perguntou por onde começar. A auditoria mostrou que as
  rotas e os links entre as páginas já funcionam (9 rotas, test client 200/404)
  e que a fundação de configuração ainda não existia.
- **Decisão:** seguir a ordem do briefing: fundação de configuração → banco →
  rotas lendo do banco → login do painel → front/JS → pagamentos → deploy. A
  API de pagamentos fica para o fim e exige ADR própria.
- **Motivo técnico:** o banco depende da `DATABASE_URL`, que vive no `.env`;
  começar pelo banco sem a fundação bloqueia o passo seguinte. Polir o front
  antes da migração de dados gera retrabalho.
- **Alternativas consideradas:**
  - Começar pelo banco — bloqueado pela ausência do `.env`.
  - Começar pelo front — retrabalho quando os dados passarem a vir do banco.
  - Fazer login e pagamentos agora — amplia o escopo sem o catálogo no banco.
- **Consequências:**
  - Passos 1–2 concluídos (git, `DECISOES.md`, `.env`, `.env.example`,
    `python-dotenv`, `app.secret_key`).
  - A escolha do driver (psycopg vs SQLAlchemy), prevista na ADR-002, torna-se
    a próxima decisão.
  - Pagamentos exige provedor, sandbox e webhook — decisão futura.
- **Arquivos:** `app.py`, `requirements.txt`, `.env.example`,
  `CONTEXTO-BLOOME-PARA-IA.md`

---

## ADR-009 — Acesso ao banco: psycopg 3 com SQL puro

- **Data:** 2026-11-09
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** a ADR-002 fixou o Supabase como único Postgres, mas deixou em
  aberto como o Python conversaria com ele (`psycopg` ou SQLAlchemy). O time
  escolheu SQL puro para aprender o que acontece por baixo.
- **Decisão:** usar **psycopg 3** (`psycopg[binary]`) com **SQL escrito à mão**
  e parâmetros (`%s`). Sem ORM.
- **Motivo técnico:** o SQL fica visível e auditável; consultas parametrizadas
  bloqueiam injeção de SQL; o pacote binário evita compilador no Windows.
- **Alternativas consideradas:**
  - SQLAlchemy ORM — esconde o SQL e adiciona uma camada de aprendizado.
  - `supabase-py`/PostgREST — outro modelo de acesso (HTTP), não usa
    `DATABASE_URL`; destoa da ADR-002.
- **Consequências:**
  - `psycopg[binary]` entra no `requirements.txt`.
  - Consultas usam `%s` como placeholder — **nunca** interpolação de string.
  - Conexão e cursor geridos manualmente (ou com helper próprio em `db.py`).
  - `DATABASE_URL` no `.env`; porta 5432 (direta) no local e 6543 (pooler)
    na Vercel.
- **Arquivos:** `requirements.txt`, `.env` (não versionado), `.env.example`,
  futuro `db.py`

---

## ADR-010 — Fora do escopo: sistema de gestão com IA e Text-to-SQL

- **Data:** 2026-11-10
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o escopo do produto descrevia o Bloome como catálogo **+ sistema
  de gestão com IA e Text-to-SQL** (briefing, Parte 4). O time decidiu cortar
  essa parte.
- **Decisão:** o Bloome fica sendo **catálogo + painel do vendedor**. Sistema de
  gestão com IA e Text-to-SQL **não faz parte do escopo**.
- **Motivo:** o sistema de gestão com IA e Text-to-SQL **não faz parte deste
  projeto**. O Bloome é um catálogo com painel do vendedor; IA e Text-to-SQL
  pertencem a outro escopo. Não houve motivo técnico ligado ao código existente.
- **Alternativas consideradas:**
  - Manter no MVP — fugiria do escopo deste projeto.
  - Construir depois — também não é escopo deste projeto.
- **Consequências:**
  - `CONTEXTO-BLOOME-PARA-IA.md` Parte 4 atualizada; a Parte 7 passa de **11
    para 10 passos** (o antigo passo 10 saiu).
  - A **ADR-009 continua válida sem mudança**: psycopg 3 + SQL puro segue como
    escolha de acesso ao banco (SQL visível e consultas parametrizadas).
  - Se a IA voltar ao escopo, exige **nova ADR** — esta não é reescrita.
- **Arquivos:** `CONTEXTO-BLOOME-PARA-IA.md`, `DECISOES.md`

---

## Modelo para novas decisões (copie)

```markdown
## ADR-00X — Título curto e específico

- **Data:** AAAA-MM-DD
- **Autor:** nome (decisão) · nome (registro)
- **Status:** Proposta | Aceita | Substituída por ADR-00Y | Revogada
- **Contexto:** qual problema ou pergunta motivou a decisão
- **Decisão:** o que foi decidido, em 1–3 frases
- **Motivo técnico:** por quê (evidência, restrição ou trade-off)
- **Alternativas consideradas:**
  - alternativa — por que foi descartada
- **Consequências:** o que muda no código/processo; o que monitorar
- **Arquivos:** caminhos afetados
```

Depois de escrever a entrada, adicione uma linha no **Índice**.

---

## Escalabilidade deste arquivo

Um arquivo só é melhor enquanto ele é pequeno: busca rápida e `git diff` legível.

- **Até ~50 ADRs (ou ~2.000 linhas):** manter tudo aqui.
- **Acima disso:** criar a pasta `decisoes/` com um arquivo por ADR
  (`decisoes/ADR-001-stack-flask.md`) e deixar este `DECISOES.md` apenas como
  índice. Os **IDs nunca mudam** na migração.
- **Nunca renumere** uma ADR: o número é a identidade dela no histórico.

## Como ver o que mudou

- `git log -p DECISOES.md` — todas as alterações, com data e autor do commit.
- `git diff DECISOES.md` — o que ainda não foi commitado.
- Cada entrada tem **ID + data**; o índice funciona como linha do tempo.
