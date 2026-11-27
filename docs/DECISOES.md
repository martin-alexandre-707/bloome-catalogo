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
| ADR-011 | 2026-11-11 | Banco | Aceita | Variações, baixa no pagamento e visibilidade do produto |
| ADR-012 | 2026-11-12 | Banco | Aceita | Edge cases do schema: pingente, esgotado derivado, frete, idempotência e LGPD |
| ADR-013 | 2026-11-12 | Banco | Aceita | Endurecimento após auditoria: snapshot da baixa, total por trigger e DELETE bloqueado |
| ADR-014 | 2026-11-12 | Banco | Aceita | DDL aplicado por `db/aplicar.py` (psycopg, conexão direta), sem DROP |
| ADR-015 | 2026-11-24 | Stack | Aceita | Flask confirmado; teste Django cancelado |
| ADR-016 | 2026-11-24 | Banco | Aceita | Fotos reais do PDF e descrições em `db/06_dados_reais.sql` |
| ADR-017 | 2026-11-24 | Banco | Aceita (temporária) | Insumos e receitas FICTÍCIOS para teste, com reversão documentada |
| ADR-018 | 2026-11-25 | Auth | Aceita | Cadastro de cliente: validação no servidor + `flash` + POST-Redirect-GET |
| ADR-019 | 2026-11-25 | Auth | Aceita | Senha com bcrypt, `INSERT` em `clientes` e sessão assinada |
| ADR-020 | 2026-11-25 | Processo | Aceita | Economia de contexto por hábito; sem RTK/hook |
| ADR-021 | 2026-11-25 | Processo | Aceita | Fim do "pare e espere meu ok" em instruções |
| ADR-022 | 2026-11-25 | Auth | Aceita | Login, logout e `/painel` protegido por decorador; cookie HttpOnly/SameSite |
| ADR-023 | 2026-11-25 | Processo | Aceita | Fim do Método da Lacuna: IA escreve o código e explica linha a linha |
| ADR-024 | 2026-11-26 | Estrutura | Substituída por ADR-026 | Modo demonstração (mock) e camada `dados.py`; sem `.env` o app roda |
| ADR-025 | 2026-11-26 | Estrutura | Substituída por ADR-033 | Modal de produto vira parcial compartilhada + JS em `static/js/`; favoritos mock data-driven (3 primeiros do catálogo) |
| ADR-026 | 2026-11-26 | Estrutura | Aceita | Sem mock: toda consulta vai ao Supabase; `catalogo.py` removido |
| ADR-027 | 2026-11-26 | Estrutura | Aceita | Carrinho na sessão guarda só variação + quantidade; preço nunca vai ao cookie |
| ADR-028 | 2026-11-27 | Estrutura | Aceita (pagamento revisto na ADR-029) | Checkout do MVP: login no clique, Correios "em breve", pedido em transação |
| ADR-029 | 2026-11-27 | Estrutura | Aceita | Pagamento simulado no checkout: pedido nasce pago e "em preparação" |
| ADR-030 | 2026-11-27 | Estrutura | Aceita | Home com os dois catálogos do PDF (Bloome e Cápsula Maré) e fotos reais |
| ADR-031 | 2026-11-27 | Estrutura | Substituída por ADR-034 | `/produtos` agrupada por catálogo; agrupamento por tipo fica pronto para voltar |
| ADR-032 | 2026-11-27 | Banco | Aceita | Favoritos persistentes: tabela `bloome.favoritos`, login obrigatório e seção no painel |
| ADR-030 | 2026-11-27 | Estrutura | Aceita | URL do produto vira slug do nome (`/produtos/colar-inicial`); ID numérico sai |
| ADR-033 | 2026-11-27 | Estrutura | Aceita | Modal de produto aposentado; o card leva à página `/produtos/<slug>` (substitui ADR-025) |
| ADR-034 | 2026-11-27 | Estrutura | Aceita | Catálogo completo só na home; `/produtos` vira 301 para `/#catalogo-bloome` (substitui ADR-031) |

> **Como ler:** as entradas estão em ordem cronológica. As mais recentes ficam
> no fim. Use o índice acima para navegar.

---

## ADR-001 — Stack web: Flask + Jinja, sem build

- **Data:** 2026-11-06 *(registro retroativo em 2026-11-07)*
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
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

## ADR-011 — Banco do e-commerce: variações, baixa no pagamento e visibilidade do produto

- **Data:** 2026-11-11
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o catálogo ainda lê 6 produtos de `catalogo.py`/templates; o banco
  do gestão resolve receita e estoque por insumo, mas não tem variações de cor,
  clientes, status de pedido, pagamento/entrega nem idempotência. O Supabase está
  **sem dados** (confirmado em 2026-11-11), então o schema nasce com `CREATE`,
  não `ALTER`.
- **Decisão:**
  1. Reaproveitar a lógica de receita/estoque do gestão e criar `variacoes` (cor)
     e `composicao_variacoes` (receita por variação). `itens_pedidos` passa a
     apontar para `id_variacao`.
  2. Os itens são gravados no checkout, mas o estoque só é baixado em
     `confirmar_pagamento` (mudança para `pago`), de forma agregada e idempotente.
     Estoque insuficiente no webhook vira `pago_sem_estoque`, sem baixa.
  3. `pedidos` ganha `codigo` público, `status` (incluindo `pronto_para_retirada`),
     cliente, entrega, endereço (snapshot), `frete_valor`/`frete_pago_por`,
     rastreio e `estoque_baixado`. Cancelar antes de produzir devolve uma vez.
  4. Contas separadas: `usuarios` (admin) e `clientes` (comprador), com
     `recuperacao_senha` (token com hash, 1h). Pagamento via `eventos_pagamento`
     com `UNIQUE(gateway, evento_id)`.
  5. Visibilidade: o produto só sai da loja por ação da admin
     (`status = 'removido'`, sem `DELETE` físico). Sem o pingente
     cadastrado/disponível, aparece como `volta_em_breve`, com CTA de WhatsApp.
     A regra antiga “todas as cores esgotadas → some” fica substituída; cor
     esgotada continua cinza/desabilitada.
  6. Produto sem receita não pode ser vendido.
- **Motivo técnico:** o pedido precisa lembrar a cor antes de pagar; baixar no
  INSERT do item (como no gestão) desconta antes do pagamento. A baixa agregada
  evita depender da ordem dos itens e fecha a corrida entre dois pedidos.
  `removido` preserva o histórico de pedidos que referenciam o produto. A unique
  do evento de pagamento e a checagem de status tornam o webhook idempotente.
- **Alternativas consideradas:**
  - Manter a baixa no INSERT do item — desconta antes do pagamento e quebra a
    regra.
  - “Itens só após o pagamento” com tabela de carrinho pendente — mais tabela e
    mais limpeza; não resolve nada que o status não resolva.
  - `ALTER` no Supabase — desnecessário: o banco está vazio.
  - `DELETE` físico do produto — quebra o histórico/FK dos pedidos; `removido`
    é mais seguro.
- **Consequências:**
  - O CLI do gestão quebra ao gravar `id_acessorios` em `itens_pedidos`; precisa
    ser adaptado para `id_variacao` ou virar legado do `/adm`.
  - O seed fica bloqueado até existir a lista real de modelos, cores e receitas;
    o schema não.
  - `VALIDACAO-REGRAS.md` §1/§8 precisa ser ajustado para a nova visibilidade
    (produto só some por `removido`; sem pingente → `volta_em_breve`).
  - Sem `psycopg`/`psql`, o DDL será rodado no SQL Editor do Supabase até o
    driver ser instalado.
- **Arquivos:** `docs/PLANO-BANCO-BLOOME.md`, `docs/DECISOES.md`, futuros
  `db/schema.sql`, `db/functions.sql`, `db/seed.sql`

---

## ADR-012 — Edge cases do schema: pingente, esgotado derivado, frete, idempotência e LGPD

- **Data:** 2026-11-12
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** a ADR-011 fechou as entidades principais, mas deixou decisões
  abertas que mudam o schema: como detectar "sem pingente" (`PLANO-BANCO-BLOOME.md:39`),
  se "esgotado" é manual ou derivado, o que fazer com frete indefinido, como
  impedir checkout duplicado, quais transições de status são válidas e como
  atender LGPD sem apagar histórico. O Supabase segue vazio; nada foi executado.
- **Decisão:**
  1. **Variação:** MVP só com a dimensão **cor**; `UNIQUE(id_acessorios, cor)`.
     Evolução futura acrescenta `tamanho` e nova unique, sem reescrever pedidos.
  2. **Sem pingente:** `acessorios.pingente_insumo_id` (FK nullável, `RESTRICT`)
     identifica o pingente do modelo. O produto vira `volta_em_breve` quando o
     pingente não está cadastrado ou está com `quantidade_estoque <= 0`, mesmo
     que existam cores de cordão.
  3. **Sem cor de cordão:** o produto também vira `volta_em_breve` quando
     nenhuma variação tem receita completa e saldo para 1 unidade. Cores
     individuais sem saldo continuam visíveis, cinza e desabilitadas.
  4. **Cor esgotada é derivada:** a view calcula a disponibilidade a partir da
     receita e do saldo. A coluna `variacoes.status` permanece apenas como
     bloqueio manual; a disponibilidade exibida nunca diverge do estoque.
  5. **Frete:** `frete_valor NULL` significa "a calcular/combinar";
     `valor_total = subtotal + COALESCE(frete_valor, 0)`, nunca nulo. No MVP o
     gateway cobra o subtotal; o frete é acertado à parte e preenchido depois
     não dispara nova cobrança.
  6. **Idempotência de checkout:** `pedidos.idempotencia uuid UNIQUE`, gerado
     no formulário, com `INSERT ... ON CONFLICT DO NOTHING` e leitura do
     pedido existente.
  7. **Transições de status:** matriz fixa em trigger. Cancelamento permitido
     só até `pago`/`pago_sem_estoque`; a partir de `em_producao`, proibido.
  8. **Reembolso manual:** campos `motivo_cancelamento`, `reembolsado_em` e
     `reembolso_valor`; nenhuma chamada automática ao gateway.
  9. **LGPD:** sem `DELETE` de cliente; `anonimizado_em` + função de
     anonimização, com unique de e-mail parcial (`WHERE anonimizado_em IS NULL`).
  10. **Tipos e schema:** dinheiro `NUMERIC(10,2)`, insumo `NUMERIC(12,3)`,
      datas `TIMESTAMPTZ`; schema dedicado `bloome` (não `public`), evitando
      exposição acidental via PostgREST.
  11. **Normalização:** e-mail e nomes em `lower(btrim())`; admin único via
      `UNIQUE(singleton)`; código público por sequence (`#BLO-0001`).
- **Motivo técnico:** cada regra vira garantia verificável no banco (CHECK,
  UNIQUE, FK, trigger ou função), não apenas validação no app. O pingente
  explícito evita heurística frágil na receita. "Esgotado" derivado impede
  divergência entre status e saldo. A idempotência de checkout cobre duplo
  clique, que a unique do evento de pagamento não cobre. A anonimização
  preserva o histórico de pedidos exigido pela FK.
- **Alternativas consideradas:**
  - Derivar "sem pingente" por `insumos.categoria = 'pingente'` — menos
    explícito e dependente de padronização de categoria.
  - Marcar "esgotado" manualmente — simples, mas diverge do estoque real.
  - `frete_valor` obrigatório no checkout — trava o pedido enquanto o frete não
    é calculado, e o cálculo automático está fora do MVP.
  - `DELETE` de cliente — quebra o histórico de pedidos; anonimização é mais
    segura.
  - Tabela de carrinho pendente para idempotência — mais tabela e limpeza sem
    resolver o que a chave de idempotência resolve.
- **Consequências:**
  - O seed continua bloqueado até existirem pingente, cores e receitas reais.
  - `frete_valor` preenchido após o pagamento não gera nova cobrança no MVP.
  - O app precisa enviar `idempotencia`, normalizar e-mail/nome e usar
    `search_path=bloome`.
  - `VALIDACAO-REGRAS.md` §1/§3/§7/§8 foi ajustado nesta rodada.
  - O DDL segue no SQL Editor do Supabase até o `psycopg` ser instalado.
- **Arquivos:** `docs/PLANO-BANCO-BLOOME.md`, `docs/VALIDACAO-REGRAS.md`,
  futuros `db/schema.sql`, `db/functions.sql`, `db/views.sql`, `db/tests.sql`

---

## ADR-013 — Endurecimento do schema após auditoria: snapshot da baixa, total por trigger e DELETE bloqueado

- **Data:** 2026-11-12
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** após implementar `db/01_schema.sql` e `db/02_funcoes.sql`, uma
  auditoria comparou o schema com a matriz EC-01..EC-52 e encontrou pontos em
  que a regra dependia só do app ou podia divergir: `idempotencia` anulável,
  devolução usando a receita atual (que pode mudar após o pagamento), total
  violando o CHECK ao atualizar só o frete, pedido vazio virando `pago`,
  `DELETE` físico de produto/cliente e campos opcionais aceitando string vazia.
- **Decisão:**
  1. `pedidos.idempotencia` passa a `NOT NULL DEFAULT gen_random_uuid()`;
     todo checkout tem chave, mesmo quando o formulário não enviar.
  2. `pedidos.consumo_snapshot jsonb` grava exatamente o consumo baixado no
     pagamento. A devolução usa o snapshot; pedidos antigos sem snapshot caem
     na receita atual.
  3. `valor_total` é mantido por trigger `BEFORE INSERT OR UPDATE OF
     subtotal, frete_valor`; atualizar só o frete não viola o CHECK.
  4. `confirmar_pagamento` recusa pedido sem itens (`pedido_sem_itens`).
  5. `DELETE` físico é bloqueado por trigger em `acessorios` e `clientes`;
     produto sai por `removido`, cliente por anonimização.
  6. Checks adicionais: campos de endereço/rastreio/motivo não vazios;
     `cancelado` exige motivo; `reembolsado_em` e `reembolso_valor` andam
     juntos; retirada não cobra frete; `ordem >= 0`; `expira_em > criado_em`;
     `gateway` minúsculo; `processado` exige assinatura válida.
  7. Índices novos: evento por pedido, receita por insumo, pingente, fila de
     produção (`status, criado_em`) e reset por cliente.
  8. O pingente do modelo precisa estar na receita de cada variação; senão a
     venda levanta `pingente_fora_da_receita` (o estoque do pingente nunca
     baixaria).
  9. `preco_unitario` e `custo_unitario` são calculados pelo trigger no INSERT
     (preço do modelo + custo da receita) e recalculados na troca de variação;
     com a mesma variação, o snapshot é imutável (`snapshot_imutavel`).
  10. Itens podem ser alterados em `pago_sem_estoque` para a troca de cor,
     já que nada foi baixado. A diferença de valor, se houver, é acertada
     manualmente no gateway.
- **Motivo técnico:** sem snapshot, editar a receita entre pagamento e
  cancelamento devolveria quantidade diferente da baixada. O total por trigger
  remove a dependência de o app lembrar de recalcular. Bloquear `DELETE`
  preserva histórico e LGPD. Os checks transformam combinações inválidas em
  erro de banco, não em dado inconsistente.
- **Alternativas consideradas:**
  - Tabela `movimentos_estoque` como razão de baixas/devoluções — mais
    auditável, porém mais escopo; o JSON resolve o MVP.
  - Deixar `idempotencia` anulável — o UNIQUE do Postgres aceita vários NULLs,
    então não protegeria checkout sem a chave.
  - Recalcular o total só no app — repete o problema do legado, que confiava
    `valor_total` ao cliente.
- **Consequências:**
  - O app deve enviar `gateway` em minúsculas e incluir o pingente na receita
    de todas as cores.
  - O app **não** envia preço/custo do item: o banco calcula no INSERT. Se
    enviar, o valor é ignorado.
  - Produto e cliente não podem mais ser apagados; usar `removido` e
    `anonimizar_cliente`.
  - O snapshot fica como histórico do pedido; a devolução não o apaga.
  - `db/02_funcoes.sql` implementa os efeitos; `db/01_schema.sql` já contém as
    colunas e constraints.
- **Arquivos:** `db/01_schema.sql`, `db/02_funcoes.sql`, `docs/DECISOES.md`

---

## ADR-014 — Aplicação do DDL por script psycopg (conexão direta, sem DROP)

- **Data:** 2026-11-12
- **Autor:** IA (Mentor), a pedido do time
- **Status:** Aceita
- **Contexto:** o banco nasce no Supabase e não há PostgreSQL local. Rodar os
  arquivos à mão no SQL Editor funciona, mas é fácil pular a ordem, esquecer os
  testes ou aplicar em cima de um schema já existente.
- **Decisão:** `db/aplicar.py` lê `DATABASE_URL` do `.env`, conecta em
  autocommit, roda o inventário e só aplica `01` → `02` → `03` → `99` → `04`
  com `--aplicar`. Aborta se o schema `bloome` já existir, nunca executa DROP,
  para no primeiro erro e mostra SQLSTATE/constraint.
- **Motivo técnico:** reduz erro humano e deixa o passo 8 repetível. A conexão
  direta (5432) evita as limitações de DDL do pooler (6543).
- **Alternativas consideradas:**
  - Só SQL Editor — simples, porém não repetível e sem conferência automática
    dos 28 testes.
  - Framework de migração (Alembic/Flyway) — descartado no MVP: a ADR-009 já
    fixou SQL puro; seria mais uma ferramenta sem ganho agora.
  - Rodar no pooler 6543 — descartado: DDL e estado de sessão não combinam com
    o pooler de transação.
- **Consequências:**
  - `requirements.txt` passa a incluir `psycopg[binary]` (também exigido pelo
    app, ADR-009).
  - O script não substitui a revisão: `99_tests.sql` continua sendo a prova de
    que as regras funcionam.
  - O admin continua manual (hash bcrypt gerado fora do SQL).
- **Arquivos:** `db/aplicar.py`, `requirements.txt`, `docs/DECISOES.md`

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

## ADR-015 — Stack web: Flask confirmada (teste Django cancelado)

- **Data:** 2026-11-24
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o §0 do `VALIDACAO-REGRAS.md` previa um teste de 1 dia com
  Django na branch `experimento/django`. O teste não chegou a ser executado, e
  em 2026-11-24 o time decidiu seguir com o que já está funcionando.
- **Decisão:** manter **Flask + Jinja** como stack do projeto. O teste Django
  fica **cancelado** e deixa de ser pendência.
- **Motivo técnico:** o catálogo já conecta no Supabase, lê views e renderiza
  com Jinja; migrar agora custaria retrabalho sem ganho demonstrado.
- **Consequências:**
  - O §0 do `VALIDACAO-REGRAS.md` passa a registrar a decisão.
  - Decisões futuras assumem Flask (ADR-001).
- **Arquivos:** `docs/DECISOES.md`, `docs/VALIDACAO-REGRAS.md`

---

## ADR-016 — Dados reais do catálogo: fotos do PDF e descrições

- **Data:** 2026-11-24
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o seed (ADR-014) deixa `foto`, `descricao` e `insumos` vazios,
  e por isso todos os 16 produtos aparecem como "volta em breve". O PDF oficial
  (`docs/referencias/Catalogo-BLOOME.pdf`) tem as 16 fotos reais, mas **não tem
  descrições**.
- **Decisão:**
  - Fotos: extraídas do PDF (páginas 2, 3, 4 e 6), recortadas, redimensionadas
    para 900 px e salvas como JPEG otimizado em `static/imgs/` (MVP: foto local,
    conforme §7 do `VALIDACAO-REGRAS.md`).
  - Descrições: 6 vêm do `catalogo.py` (texto já aprovado); as outras 10 foram
    escritas a partir de dados reais do PDF (nome, material, categoria) e
    **aguardam revisão da dona**. Nenhum dado de estoque foi inventado.
  - Aplicação idempotente via `python db/aplicar.py --dados`, que executa
    `db/06_dados_reais.sql` (só UPDATE; pode rodar de novo).
- **Motivo técnico:** dado real e auditável, sem quebrar o seed; o `aplicar.py`
  aborta quando o schema já existe, então o novo flag separa DDL de DML.
- **Consequências:**
  - O catálogo passa a exibir foto e descrição reais.
  - O status continua `volta_em_breve` até existirem insumos + receita
    (`pingente_insumo_id` e `composicao_variacoes` ainda vazios).
  - As 6 imagens PNG antigas em `static/imgs/` ficaram sem referência e podem
    ser removidas quando o time confirmar.
- **Arquivos:** `db/06_dados_reais.sql`, `db/aplicar.py`, `static/imgs/*.jpg`,
  `docs/DECISOES.md`

---

## ADR-017 — Dados fictícios de estoque para teste (temporária)

- **Data:** 2026-11-24
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita, **temporária** — sai antes do lançamento
- **Contexto:** sem insumos e receitas, nada é vendável e todo o catálogo
  aparece como "volta em breve". O time pediu para testar o fluxo visual
  enquanto os dados reais não chegam.
- **Decisão:** criar 19 insumos fictícios (5 fios + 14 pingentes) com saldo 99,
  receita de fio + pingente em todas as 49 variações, e manter **3 modelos**
  como "em breve" para testar os dois estados:
  - 26 Cordão Amarração — sem pingente (o modelo não tem pingente);
  - 27 Chocker Fita Pura — sem pingente (o modelo não tem pingente);
  - 28 Cordão Gota — pingente com saldo 0.
  O detalhe do produto passa a mostrar um botão desabilitado **"Em breve"**
  (mesmo visual do "Comprar", estado `:disabled` já existente no CSS).
- **Motivo técnico:** exercitar o caminho real (views + regras D2/D3) em vez de
  mascarar a regra no template; preços e quantidades são fictícios.
- **Consequências:**
  - **Nenhum** desses números é dado real: não usar em relatório nem em venda.
  - Reversão documentada no rodapé de `db/07_placeholder_teste.sql`
    (`DELETE` receitas → `pingente_insumo_id = null` → `DELETE insumos`).
  - A regra D2 (sem pingente → "volta em breve") impede vender modelos sem
    pingente; decisão de produto pendente com a dona.
  - `python db/aplicar.py --teste` aplica dados reais + fictícios; `--dados`
    aplica só os reais.
- **Arquivos:** `db/07_placeholder_teste.sql`, `db/aplicar.py`,
  `templates/produto.html`, `docs/DECISOES.md`

---

## ADR-018 — Cadastro de cliente: validação no servidor, `flash` e POST-Redirect-GET

- **Data:** 2026-11-25
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o formulário "Criar conta" já chega ao servidor
  (`POST /conta/criar`), mas nada era validado. Atributos HTML (`required`,
  `minlength`) são só conveniência do navegador e podem ser burlados com o
  DevTools desligando-os ou com um `curl`.
- **Decisão:**
  1. Toda regra do formulário existe **também no servidor**, em
     `criar_conta()`: nome ≥ 2 caracteres, e-mail com `@` e um ponto depois
     dele, senha ≥ 8 caracteres, senha igual à confirmação.
  2. As regras são enfileiradas com uma bandeira booleana (`valido`) para
     exibir **todos** os erros de uma vez, não só o primeiro.
  3. Mensagens de erro vão por `flash()` com categoria `"erro"` e são lidas em
     `conta.html` com `get_flashed_messages(with_categories=true)`, dentro de um
     bloco `role="alert"` (WCAG: anúncio imediato por leitor de tela).
  4. E-mail é normalizado no servidor (`.strip().lower()`), como o schema exige
     em `ck_clientes_email_norm`.
  5. A resposta é sempre **302 + redirect** (POST-Redirect-GET): o POST nunca
     devolve HTML, então F5 na página final não reenvia o cadastro.
  6. Senha mínimo 8 alinhada a `docs/VALIDACAO-REGRAS.md` §5 (antes o HTML
     dizia 6).
- **Motivo técnico:** validação de servidor é a única que conta; PRG evita
  reenvio duplicado; `flash` resolve o problema de mensagem que não sobrevive a
  um `redirect`.
- **Alternativas consideradas:**
  - Renderizar `conta.html` direto no POST com a mensagem — quebra o PRG e
    permite reenvio no F5.
  - Validar só no HTML — declaradamente inseguro.
  - Regex completa de e-mail — o schema também não usa; a checagem simples é
    coerente com o banco e suficiente para o MVP.
- **Consequências:**
  - Ainda **não** persiste nada: o `INSERT` com bcrypt é o passo seguinte
    (nova ADR quando entrar).
  - O bloco `.auth__erros` está sem CSS próprio; herda o padrão da página.
  - Categoria `"erro"` já trafega e não é usada — fica pronta para estilizar.
- **Arquivos:** `app.py`, `templates/conta.html`

---

## ADR-019 — Senha com bcrypt, `INSERT` em `bloome.clientes` e sessão assinada

- **Data:** 2026-11-25
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** com as validações prontas (ADR-018), o cadastro precisava
  persistir o cliente e deixá-lo autenticado.
- **Decisão:**
  1. Senha é gravada **somente** como hash bcrypt: `bcrypt.hashpw(senha, bcrypt.gensalt())`.
     Custo padrão da biblioteca (`2b$12$` = 2¹² rodadas), 60 caracteres no total,
     o que satisfaz `ck_clientes_hash` (`length >= 20`).
  2. A senha em texto puro existe apenas na memória durante a requisição e
     nunca é logada, gravada ou devolvida.
  3. `INSERT` parametrizado (`%s` + tupla) com `returning id_cliente`.
  4. Telefone vazio vai como `NULL` (`whatsapp or None`), porque
     `ck_clientes_telefone` rejeita string vazia.
  5. E-mail duplicado é capturado por `psycopg.errors.UniqueViolation`
     (índice `ux_clientes_email_ativo`), com `rollback()` e mensagem amigável.
     A mensagem é **explícita** no cadastro ("já existe conta, tente entrar");
     no login e no reset ela será genérica, como fazem os sites grandes.
  6. `psycopg.Error` genérico captura o resto (banco fora, rede) — evita 500
     com sucesso parcial.
  7. Autenticação por `session` do Flask: grava `cliente_id` e `cliente_nome`;
     **nunca** senha, hash, CPF ou dado de cartão. O cookie da sessão é
     assinado com `SECRET_KEY`, portanto **legível** pelo cliente — assinatura
     garante integridade, não sigilo.
  8. Após criar a conta, redireciona para `/painel` já logado.
- **Motivo técnico:** bcrypt é lento por projeto (resistente a força bruta em
  GPU), diferente de MD5/SHA-256; o unique do banco é a única garantia real de
  unicidade sob concorrência; a sessão evita re-login imediato.
- **Alternativas consideradas:**
  - `bcrypt.hashpw(senha, bcrypt.gensalt(rounds=14))` — mais seguro, ~4x mais
    lento; desnecessário no MVP, dá para subir depois sem migrar hashes.
  - Guardar `senha` na sessão para pré-preencher — vazamento inaceitável.
  - Autenticação por `itsdangerous`/JWT — complexidade sem ganho no escopo.
- **Consequências:**
  - `/painel` continua **público**: a sessão é gravada, mas nada verifica ainda.
    Proteger a rota (e exibir `cliente_nome` no header) é o passo seguinte.
  - A tabela `clientes` tem trigger que bloqueia `DELETE` físico
    (`trg_clientes_sem_delete`); cadastros de teste só saem por
    `bloome.anonimizar_cliente()`.
  - Conta de teste `teste.1c@teste.local` (id 27) foi criada e **anonimizada**
    ao final do teste.
- **Arquivos:** `app.py`, `docs/DECISOES.md`

---

## ADR-020 — Economia de contexto: hábito de leitura, sem ferramenta extra

- **Data:** 2026-11-25
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** avaliou-se adotar RTK/Headroom (compressão de saída de
  terminal) e hooks `PostToolUse`. Os comandos do projeto produzem saída
  pequena (centenas de caracteres); o gasto real vem de ler arquivos grandes
  inteiros (`entregaveis/`, `DECISOES.md`, `styles.css`).
- **Decisão:** não instalar ferramenta. Economia via três hábitos:
  leitura cirúrgica (`Grep` + `Read` com trecho), delegação de varredura a
  subagente, e `/clear` por tarefa. Regras registradas no `AGENTS.md`.
- **Motivo técnico:** comprimir saída de 500 caracteres não compensa; o custo
  dominante é o contexto de entrada, não o output de shell.
- **Alternativas consideradas:**
  - RTK/Headroom — ganho marginal neste perfil de uso; mais uma dependência.
  - Hook `PostToolUse` comprimindo Bash — mesmo motivo.
  - Roteamento de modelo — já se usa modelo barato.
- **Consequências:** arquivo grande lido sem `Grep` prévio é considerado erro
  de processo nas revisões. Reavaliar se surgir build/log volumoso.
- **Arquivos:** `AGENTS.md`, `docs/DECISOES.md`

---

## ADR-021 — Ritmo sem a frase obrigatória "pare e espere meu ok"

- **Data:** 2026-11-25
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** a regra "Ritmo" exigia encerrar toda instrução com
  "pare e espere meu ok", o que virava ruído em respostas de consulta e de
  pergunta.
- **Decisão:** remover a frase obrigatória. Mantêm-se "passo a passo, um de
  cada vez, em português" e a proibição de despejar cinco tarefas juntas.
- **Motivo técnico:** a confirmação explícita continua fazendo sentido em
  mudanças de arquivo/estrutura — isso é coberto pela regra "Não faça sem
  pedir", aplicada por contexto, não mecanicamente em toda resposta.
- **Alternativas consideradas:**
  - Manter só em instruções de código — rejeitada: duplica "Não faça sem pedir".
  - Remover "Não faça sem pedir" também — rejeitada: protege mudanças grandes.
- **Consequências:** pedidos de confirmação passam a ocorrer apenas em
  mudanças grandes ou irreversíveis.
- **Arquivos:** `AGENTS.md`, `docs/DECISOES.md`

---

## ADR-022 — Login, logout e `/painel` protegido por decorador

- **Data:** 2026-11-25
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o cadastro (ADR-019) já criava a sessão, mas o `/painel`
  continuava público, o header mostrava "Lucas" fixo e o formulário "Entrar"
  era um GET para `/painel` — a senha ia para a URL, o histórico, os logs e o
  header `Referer` de links seguintes.
- **Decisão:**
  1. `POST /conta/entrar` lê `request.form`, normaliza o e-mail
     (`.strip().lower()`) e **não** mexe na senha.
  2. A consulta é parametrizada e filtra `anonimizado_em is null` — conta
     anonimizada não loga.
  3. A senha é conferida com `bcrypt.checkpw`; e-mail inexistente e senha
     errada devolvem a **mesma** mensagem genérica (evita enumeração de
     contas).
  4. Em sucesso, `session.clear()` antes de gravar `cliente_id` e
     `cliente_nome` (session fixation); nenhum segredo entra na sessão.
  5. O decorador `login_requerido` (com `functools.wraps`) protege rotas
     privadas; ele checa só a presença de `cliente_id` na sessão já validada
     pelo Flask. Hoje só o `/painel` usa.
  6. `POST /conta/sair` limpa a sessão **antes** do `flash` (o flash mora na
     sessão) e redireciona para `/conta`.
  7. O formulário "Entrar" vira POST para `/conta/entrar`; "Sair" vira
     `<form method="post">` no header e no painel. GET não altera estado.
  8. O header e a saudação do painel leem `session["cliente_nome"]`; o bloco
     só aparece quando existe `cliente_id`.
  9. Cookie de sessão com `HttpOnly` e `SameSite=Lax` explícitos
     (`SESSION_COOKIE_HTTPONLY`, `SESSION_COOKIE_SAMESITE`). `Secure` fica para
     o deploy com HTTPS.
- **Motivo técnico:** POST-Redirect-GET evita reenvio no F5; a mensagem
  genérica fecha enumeração; o decorador centraliza a regra e reduz a chance de
  esquecer uma rota nova; POST no logout impede disparo por prefetch/crawler;
  HttpOnly e SameSite reduzem roubo de sessão por XSS e CSRF.
- **Alternativas consideradas:**
  - Checar `cliente_id` dentro de cada rota — funciona, mas repete a regra e é
    fácil esquecer.
  - `@app.before_request` com lista de exceções — mais automático, porém fácil
    de bloquear o catálogo por engano.
  - Logout por link GET — quebra a semântica de método seguro.
  - JWT/itsdangerous puro — complexidade sem ganho no MVP.
- **Consequências:**
  - O decorador **não** consulta o banco por requisição: conta anonimizada
    durante a sessão continua logada até o cookie sumir.
  - Ainda **não** há token CSRF; `SameSite=Lax` cobre o caso cross-site mais
    comum, mas não substitui o token.
  - Mensagem de sucesso do login não é exibida porque o painel não renderiza
    `get_flashed_messages()`; evitar `flash` no login até existir um bloco
    global (ou mover o bloco para `base.html`).
  - Pedidos e cartão "Meus dados" do painel continuam fictícios.
  - Testado com `test_client` e cursor falso no fluxo login → painel → logout;
    com `SELECT` real de e-mail inexistente; login real com conta no Supabase
    ainda não testado.
- **Arquivos:** `app.py`, `templates/conta.html`, `templates/base.html`,
  `templates/painel.html`, `static/css/styles.css`

---

## ADR-023 — Fim do Método da Lacuna: a IA escreve e explica

- **Data:** 2026-11-25
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** o Método da Lacuna pedia que o time preenchesse esqueletos com
  lacunas. Na prática, preencher as lacunas travava o andamento, então o método
  foi trocado.
- **Decisão:** a IA passa a **entregar o código completo**, explicando o quê, o
  porquê e como funciona (com foco na lógica HTTP), em passos pequenos. O time
  revisa e aprova antes do próximo passo. O modo auditoria continua disponível
  quando alguém do time escrever código.
- **Motivo:** manter o aprendizado sem travar o projeto; a explicação linha a
  linha preserva o objetivo didático.
- **Alternativas consideradas:**
  - Manter a lacuna e esperar — rejeitada: bloqueava o avanço.
  - Entregar código sem explicação — rejeitada: perde o ensino.
- **Consequências:** `AGENTS.md` atualizado (método, papéis e economia de
  contexto). `docs/CONTEXTO-BLOOME-PARA-IA.md` é briefing histórico e pode
  continuar descrevendo o método antigo.
- **Arquivos:** `AGENTS.md`

---

## ADR-024 — Modo demonstração (mock) e camada `dados.py`

> **Substituída por ADR-026** (2026-11-26): o mock foi removido do projeto.

- **Data:** 2026-11-26
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Status:** Aceita
- **Contexto:** quem clona o repositório não conseguia rodar o app: sem
  `.env`, `app.py` estourava em `SECRET_KEY` e `db.py` tentava conectar com
  `DSN = None`. Isso bloqueava o trabalho paralelo — o front precisava ver o
  fluxo renderizado sem acesso ao Supabase — e impedia um avaliador de testar
  o projeto localmente.
- **Decisão:**
  1. Criar `dados.py` como **camada de dados** entre rota e banco. As rotas do
     catálogo passam a chamar `listar_produtos()`, `buscar_produto()` e
     `listar_relacionados()` em vez de abrir cursor.
  2. `dados.modo_mock()` decide a origem: `MOCK=1` força o mock; sem
     `DATABASE_URL`, mock; com `DATABASE_URL`, Supabase.
  3. O mock reaproveita `catalogo.py` (6 produtos) e devolve **as mesmas
     chaves** que a view — o template não muda.
  4. Sem `SECRET_KEY` e em modo mock, o app usa uma chave de demonstração
     explicitamente insegura; sem `.env` mas com banco configurado, continua
     levantando `RuntimeError`.
  5. Em modo mock, `POST /conta/entrar` e `POST /conta/criar` respondem com
     `flash` explicando que a conta exige o banco real, em vez de dar 500.
- **Motivo técnico:** separa "de onde vem o dado" de "como o dado é exibido".
  O mock fica em **um arquivo só**, nunca no template; trocar mock por dado
  real é automático quando o `.env` existe. Permite que o front seja
  desenvolvido em paralelo, na mesma branch, por quem não tem credencial.
- **Alternativas consideradas:**
  - Mandar `DATABASE_URL` para o colega — rejeitada: credencial de escrita em
    histórico de conversa; e o backup do free tier é inexistente.
  - PostgreSQL local com Docker — adiada: não se sabe se o SQL do Supabase roda
    limpo em Postgres puro (grants/roles), e não resolve o clone sem instruções.
  - Deploy público só (Render/Vercel) — insuficiente: não permite rodar local.
- **Consequências:** dois caminhos de leitura no catálogo. O mock deve ficar
  pequeno e restrito a leitura; telas novas seguem o mesmo padrão
  (`dados.py` → aba `MOCK`). `README.md` e `.env.example` atualizados.
- **Arquivos:** `dados.py`, `app.py`, `.env.example`, `README.md`

---

## ADR-025 — Modal de produto compartilhado + favoritos data-driven

- **Data:** 2026-11-26
- **Autor:** Claude *(escreveu e registrou)* · Equipe Bloome *(solicitou)*
- **Status:** Aceita
- **Contexto:** o card com modal de detalhes existia só em `/produtos`, com
  todo o HTML e o JS embutidos no template. A página `/favoritos` repetia
  cards em HTML estático (nomes, preços e fotos hardcoded) — e os ids `1/3/6`
  que os links apontavam não existem no banco real (ids 24–39), o que
  geraria 404 ao rodar com `DATABASE_URL`. Pedido do time: "na aba
  favoritos, faça as mesmas mudanças que fizemos na aba produtos".
- **Decisão:**
  1. Extrair `<template>`s + `<dialog>` + toast para a parcial
     `templates/_modal-produto.html` e o script para
     `static/js/modal-produto.js` (padrão do projeto: JS em `static/js/`).
     `/produtos` e `/favoritos` dão `{% include %}` no mesmo bloco —
     uma única fonte de verdade para o modal.
  2. O JS deixa de buscar o card pela classe `.product` e passa a
     resolver `gatilho.closest('article')`: qualquer card com
     `data-abrir-produto` ganha o comportamento de "card clicável"
     sem classe específica; links dentro do card (ex.: "Remover dos
     favoritos") mantêm o próprio comportamento.
  3. `/favoritos` passa a receber os **3 primeiros produtos do
     catálogo** via `dados.listar_produtos()[:3]` (mock e real).
     Enquanto a tabela de favoritos não existir, "favoritos" é um
     mock visual alimentado pelos mesmos dados do catálogo.
- **Motivo técnico:** duplicar ~120 linhas de HTML + JS em dois
  templates obrigaria sincronizar qualquer ajuste futuro do modal em
  dois lugares; e o mock hardcoded deixava a página quebrada (404) no
  modo real. Dados vindos da camada `dados.py` garantem os mesmos
  campos — incluindo `cores` — nos dois modos.
- **Alternativas consideradas:**
  - Manter favoritos estáticos e hardcodar cores nos `<template>`s —
    rejeitada: dados inventados na UI e 404s no banco real.
  - Ids fixos `1/3/6` com estado vazio no modo real — rejeitada: a
    página esvaziaria silenciosamente ao ligar o banco; "3 primeiros"
    funciona nos dois modos.
- **Consequências:** o link "Remover dos favoritos" continua no-op
  (sem persistência); a tabela de favoritos + rotas segue como
  pendência do roadmap. Mudanças futuras no modal passam a ser feitas
  em `static/js/modal-produto.js` / `_modal-produto.html`.
- **Arquivos:** `static/js/modal-produto.js`, `templates/_modal-produto.html`,
  `templates/produtos.html`, `templates/favoritos.html`, `app.py`,
  `static/css/styles.css`

---

## ADR-026 — Sem mock: toda consulta vai ao Supabase

- **Data:** 2026-11-26
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** a ADR-024 criou o modo demonstração para rodar sem `.env`.
  O banco real foi conectado no mesmo dia e passou a ser a única fonte
  verdadeira; manter dois caminhos de leitura deixava código morto e dúvida
  sobre qual ramo rodava.

- **Decisão:**
  1. Remover `modo_mock()`, `_mock_lista()`, `_mock_cores()`, `_CORES_MOCK` e
     os ramos `if modo_mock()` de `dados.py`. Só sobra SQL.
  2. Remover `catalogo.py` (a lista de 6 produtos escrita à mão).
  3. Remover de `app.py`: a `SECRET_KEY` insegura de demonstração, a entrada
     fake em `/conta/entrar`, o cadastro fake em `/conta/criar` e a tarja de
     demonstração do painel.
  4. Sem `SECRET_KEY` ou `DATABASE_URL`, o app **falha na inicialização** com
     erro claro — não há plano B.
  5. Variável `MOCK` e documentação do modo demonstração saem de
     `.env.example` e `README.md`.

- **Alternativas consideradas:**
  - Manter o mock como fallback — rejeitada: dois caminhos para o mesmo dado,
    mock envelhece e confunde a leitura.
  - Manter só a flag `MOCK=1` — rejeitada: sem outro dado fictício, a flag
    não tem função.

- **Consequências:** clonar o repositório exige `.env` com Supabase para
  rodar; o teste do projeto passa a usar o banco real (apenas leitura no
  catálogo). `dados.py` ganha `id_variacao` em `buscar_produto` para o passo 2
  do carrinho.

- **Arquivos:** `dados.py`, `app.py`, `catalogo.py` (removido),
  `templates/painel.html`, `.env.example`, `README.md`

---

## ADR-027 — Carrinho na sessão: referência à variação, não cópia do produto

- **Data:** 2026-11-26
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** o detalhe do produto agora tem um formulário que envia a cor
  escolhida (`POST /carrinho/adicionar`). Era preciso decidir o que guardar na
  `session` — cookie assinado, legível pelo visitante — e como validar.

- **Decisão:**
  1. A sessão guarda **apenas** `[{"id_variacao": int, "quantidade": int}]`.
     Nome, cor e preço são relidos do banco na hora de exibir (passo 3).
  2. O POST valida no servidor: o `id_variacao` precisa existir **e** estar
     disponível para aquele `id_acessorios`; entrada inválida → `flash` + 302.
  3. Adicionar a mesma variação duas vezes soma `quantidade` em vez de criar
     outra linha.
  4. Resposta segue POST-Redirect-GET (302 de volta ao detalhe do produto).

- **Alternativas consideradas:**
  - Guardar nome/preço/imagem na sessão — rejeitada: preço no cookie fica
    velho e é dado do cliente; cálculo de dinheiro pertence ao backend.
  - Carrinho em tabela do banco — adiada para o checkout (passo 4), quando o
    pedido vira registro transacional.

- **Consequências:** o passo 3 precisa de uma função em `dados.py` que receba
  os `id_variacao` e devolva os detalhes atuais para renderizar o carrinho. O
  total é sempre recalculado no servidor.

- **Arquivos:** `app.py`, `dados.py`, `templates/produto.html`,
  `static/css/styles.css`

---

## ADR-028 — Checkout do MVP: login no clique, Correios "em breve", pedido em transação

- **Data:** 2026-11-27
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** passo 4. O schema exige `id_cliente` em `pedidos`, e o
  `CHECK ck_pedidos_endereco` exige endereço completo quando `tipo_entrega =
  'correios'`. O MVP não tem API dos Correios nem gateway de pagamento — o
  objetivo é o fluxo funcionando de ponta a ponta.

- **Decisão:**
  1. `POST /carrinho/finalizar` exige conta. Sem sessão, responde `302` para
     `/conta?next=/carrinho`; entrar ou criar conta **preserva o carrinho** e
     volta para o `next` (validado como caminho interno, contra open redirect).
  2. O rádio dos Correios continua visível, mas `disabled` e marcado
     **"em breve"**. O servidor também recusa se o valor chegar.
  3. O pedido nasce numa **transação única**: `INSERT` em `pedidos` →
     `INSERT` nos `itens_pedidos` (triggers de preço/custo/validade) →
     `verificar_estoque_pedido`. Qualquer falha → `rollback` e carrinho
     intacto; sucesso → `commit`, carrinho esvaziado e `302` para
     `/carrinho?pedido=#BLO-XXXX`.
  4. Preço e custo vêm dos triggers do banco; o formulário envia só
     `id_variacao` e `quantidade`.
  5. Os campos Nome e WhatsApp saem do carrinho: os dados vêm da conta.

- **Alternativas consideradas:**
  - Exigir login antes de montar o carrinho — rejeitada: atrito desnecessário.
  - Criar conta dentro do checkout — adiada: `/conta` já tem as abas e o
    `next` resolve o retorno com menos código.
  - Coletar endereço dos Correios agora — adiada: sem API de frete, no MVP o
    envio fica "em breve" e o contato é pelo WhatsApp.

- **Consequências:** status fica `aguardando_pagamento` até o passo 5
  (Mercado Pago). Ainda sem token de idempotência explícito no formulário:
  o POST-Redirect-GET e o carrinho esvaziado cobrem o caso comum de
  duplo clique. O passo dos Correios precisará de endereço + frete.

- **Arquivos:** `app.py`, `templates/carrinho.html`, `templates/conta.html`,
  `static/css/styles.css`

---

## ADR-029 — Pagamento simulado no checkout: pedido nasce pago e "em preparação"

- **Data:** 2026-11-27
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** a ADR-028 deixava o pedido em `aguardando_pagamento` até o
  Mercado Pago (passo 5). O time decidiu que, no MVP de portfólio, o fluxo
  precisa dar a sensação de compra concluída: nada de "pague pelo WhatsApp".

- **Decisão:**
  1. Depois de criar o pedido e validar o estoque, o checkout chama
     `bloome.confirmar_pagamento(id, null, null)` — a função que o banco já
     tem para **confirmação manual**: recheca estoque, baixa os insumos e
     marca o pedido como `pago`.
  2. Em seguida o pedido vai para `em_producao`; a tela mostra
     **"Em preparação"** e **"Pagamento aprovado"**.
  3. Removidos os textos de pagamento por WhatsApp do checkout e da
     página do pedido.

- **Alternativas consideradas:**
  - Mostrar "Aguardando pagamento" — rejeitada pelo time: quebra a sensação
    de MVP real.
  - Gerar QR Pix falso — rejeitada: QR de pagamento que não funciona é pior
    que não ter QR.
  - Só esconder o status na tela — rejeitada: o banco diria uma coisa e a
    tela outra; a simulação usa o caminho real de confirmação.

- **Consequências:** pedidos feitos no MVP **baixam estoque de verdade**;
  `cancelar_pedido` devolve os insumos. O passo 5 (Mercado Pago) deve
  remover a chamada de simulação e deixar o webhook assinar a confirmação.

---

## ADR-030 — URL do produto: slug do nome no lugar do ID numérico

- **Data:** 2026-11-27
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(implementação e registro)*
- **Contexto:** o detalhe do produto era `/produtos/<int:produto>`
  (`/produtos/1`, `/produtos/3`…). ID na URL não diz nada a quem lê nem a
  buscadores, e o time pediu o nome da peça no endereço.

- **Decisão:**
  1. A rota passa a `@app.route("/produtos/<slug>")`: `/produtos/colar-inicial`.
  2. O **slug** é derivado do `nome_acessorios` por `dados._slug` — NFKD
     separa o acento, o filtro `combining` descarta, `re.sub` troca o resto
     por hífen. (`"Cordão Lua"` → `"cordao-lua"`.)
  3. O slug **não existe no banco**; é calculado na leitura e anexado a todo
     produto que sai de `dados.py` (`listar_produtos`, `buscar_produto`,
     `listar_relacionados`).
  4. `buscar_produto(slug)` resolve slug → id comparando em Python (o catálogo
     é pequeno) e então chama `buscar_produto_por_id`, que continua sendo a
     consulta por ID usada pelo carrinho.
  5. URLs de ID deixam de existir: `/produtos/1` responde **404**, sem
     redirect de compatibilidade — não há fluxo antigo para preservar.

- **Alternativas consideradas:**
  - Coluna `slug` no banco — rejeitada por ora: exige DDL e migration para um
    dado totalmente derivável do nome; pode virar ADR própria se o catálogo
    crescer e a busca em Python pesar.
  - Manter as duas rotas (`<int>` e `<slug>`) — rejeitada: dois endereços
    para a mesma página confundem SEO e criam conteúdo duplicado.

- **Risco conhecido:** dois produtos com o mesmo nome geram o mesmo slug (o
  primeiro na ordem do catálogo vence). No catálogo atual não há duplicados;
  se aparecer, adicionar sufixo (`-2`) ou coluna `slug` no banco.

- **Arquivos:** `dados.py`, `app.py`, `templates/index.html`,
  `templates/produto.html`, `docs/DECISOES.md`
  Pedidos criados nesta fase ficam com `gateway_payment_id` nulo.

- **Arquivos:** `app.py`, `templates/pedido.html`, `templates/checkout.html`

---

## ADR-030 — Home com os dois catálogos do PDF e fotos reais

- **Data:** 2026-11-27
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** o PDF `docs/referencias/Catalogo-BLOOME.pdf` tem dois
  volumes: o **Catálogo Bloome** (12 peças) e a **Cápsula Maré** (4 peças).
  O banco não tem coluna de coleção — só `categoria_acessorio`
  (Cordão/Colar/Chocker), que atravessa os dois.

- **Decisão:**
  1. A home mostra o herói com a foto de capa do PDF
     (`hero-bloome.jpg`) e, descendo, os dois catálogos: **Catálogo
     Bloome** e **Cápsula Maré** (esta com banner `capsula-mare.jpg`).
  2. A separação Cápsula Maré ↔ resto fica em `dados.CAPSULA_MARE`, por
     **nome de produto**, até existir uma coluna em `bloome.acessorios`.
  3. As fotos do herói e do banner foram extraídas do próprio PDF.
  4. A página `/produtos` continua agrupada por **tipo** (Cordões,
     Colares, Chockers), não por catálogo.

- **Alternativas consideradas:**
  - Criar `acessorios.colecao` agora — adiada: exige migração, ADR de
    banco e ajuste das views; o MVP prioriza o fluxo.
  - Home com as categorias como antes — rejeitada: não refletia o PDF.

- **Consequências:** produto novo entra no Catálogo Bloome até a coluna
  existir; renomear um produto da cápsula o move para o catálogo
  principal silenciosamente (a lista é por nome). O véu do herói é só
  no lado do texto para a foto continuar viva.

- **Arquivos:** `dados.py`, `app.py`, `templates/index.html`,
  `static/css/styles.css`, `static/imgs/hero-bloome.jpg`,
  `static/imgs/capsula-mare.jpg`

---

## ADR-031 — `/produtos` agrupada por catálogo (com volta fácil)

- **Data:** 2026-11-27
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** a home passou a mostrar os dois catálogos do PDF
  (ADR-030), mas `/produtos` continuava separada por tipo (Cordões,
  Colares, Chockers). Duas lógicas para a mesma vitrine confundem — e o
  PDF vende a Cápsula Maré como bloco, não diluída nos tipos.

- **Decisão:**
  1. `/produtos` passa a ter as mesmas seções da home: **Catálogo
     Bloome** e **Cápsula Maré**, com todos os produtos e o mesmo modal
     de visualizar.
  2. `dados.listar_colecoes` (agrupamento por tipo) **fica no código**,
     documentada, para o futuro filtro "Cordões · Colares · Chockers" e
     para reverter o agrupamento com uma linha.
  3. A troca foi feita em commit separado, depois de um checkpoint do
     estado anterior.

- **Alternativas consideradas:**
  - Manter por tipo — rejeitada: inconsistente com a home.
  - Filtro por tipo agora — adiado: 16 peças não justificam o custo;
    volta como fileira de atalhos quando a vitrine crescer.

- **Consequências:** para voltar ao agrupamento por tipo basta trocar
  `catalogos=dados.listar_catalogos()` por
  `colecoes=dados.listar_colecoes(limite=None)` na rota e o laço do
  template; ou `git revert` do commit desta mudança.

- **Arquivos:** `app.py`, `dados.py`, `templates/produtos.html`

---

## ADR-032 — Favoritos persistentes, com login e seção no painel

- **Data:** 2026-11-27
- **Status:** Aceita
- **Autor:** Equipe Bloome *(decisão)* · Claude *(registro)*
- **Contexto:** favoritos eram mock (3 primeiros do catálogo, ADR-025).
  O time pediu favoritos de verdade e fáceis de ver no painel.

- **Decisão:**
  1. Nova tabela `bloome.favoritos` (`id_cliente` + `id_acessorios`,
     chave composta, FKs, `criado_em`) em `db/08_favoritos.sql`.
  2. Favoritar **exige login**: sem sessão, `302 /conta?next=...` e
     volta para a página de origem (o coração já enviado não se perde
     porque o redirect é POST-Redirect-GET).
  3. `POST /favoritos/<id>` **alterna** (insere ou remove, com
     `on conflict do nothing`) e devolve para o referrer validado.
  4. Coração na página do produto e no modal de visualizar; estado
     `aria-pressed` e rótulo "Adicionar/Remover dos favoritos".
  5. `/painel` mostra até 4 favoritos + link para a lista completa.
  6. `/favoritos` passa a exigir login e lista os favoritos reais.

- **Alternativas consideradas:**
  - Favoritar na sessão (sem conta) e migrar no login — adiada: mais
    código e casos de borda sem ganho no MVP.
  - Coração em todo card — rejeitada: conflita com o clique que abre o
    modal e pede CSS extra; detalhe + modal cobrem o uso.

- **Consequências:** favoritos só existem para contas. A migration é
  idempotente (`if not exists`) e foi aplicada com script avulso, porque
  `db/aplicar.py` aborta em schema existente (ADR-014). Remover o
  favorito não apaga produto nem conta (FKs sem cascade).

- **Arquivos:** `db/08_favoritos.sql`, `dados.py`, `app.py`,
  `templates/_modal-produto.html`, `templates/produto.html`,
  `templates/favoritos.html`, `templates/painel.html`,
  `static/css/styles.css`

---

## ADR-033 — Modal de produto aposentado: card leva à página grande

- **Data:** 2026-11-27
- **Autor:** mentor (IA), a pedido do dono do projeto
- **Status:** Aceita — substitui a ADR-025
- **Contexto:** duas formas de ver o mesmo produto (modal no catálogo e
  página `/produtos/<slug>`) com comportamentos diferentes. O modal é
  `<dialog>` preenchido por `<template>` + JS, não tem URL própria (não
  dá para compartilhar), e o dono o considerou visualmente ruim.
- **Decisão:** existe **uma** forma de ver produto — a página
  `/produtos/<slug>`. O card inteiro é o link (o "Visualizar" é um
  `span` estilizado de botão, para não aninhar link em link). O seletor
  de quantidade, que só existia no modal, passa a viver na página do
  produto.
- **Alternativas consideradas:**
  - Manter modal + página — rejeitada: dois padrões para a mesma coisa,
    e o modal não tem endereço próprio.
  - Modal só para "olhar rápido" — rejeitada: duplica markup e JS.
- **Consequências:** `_modal-produto.html` e `modal-produto.js` ficam no
  repositório **sem uso** (mantidos para rollback barato: basta voltar a
  incluir o parcial). Como o navegador "volta" para a página em que a
  pessoa estava, a posição de rolagem é restaurada — não é preciso JS.
  Favoritos continuam: o coração vive no card das páginas e na página do
  produto.
- **Arquivos:** `templates/produtos.html`, `templates/favoritos.html`,
  `templates/produto.html`, `templates/_modal-produto.html`,
  `static/js/modal-produto.js`

---

## ADR-034 — Catálogo completo mora só na home; `/produtos` vira redirect

- **Data:** 2026-11-27
- **Autor:** mentor (IA), a pedido do dono do projeto
- **Status:** Aceita — substitui a ADR-031
- **Contexto:** a home já renderiza os dois catálogos com todas as 16
  peças e a mesma grade de cards de `/produtos`. Manter uma segunda
  página com o mesmo conteúdo obrigava a pessoa a ir e voltar para
  comparar, e duplicava manutenção de template.
- **Decisão:** a home é o catálogo. O botão "Ver catálogo completo" do
  hero é âncora (`#catalogo-bloome`) e desce a página com o header fixo
  acompanhando. `GET /produtos` responde **301** para
  `/#catalogo-bloome`: link antigo (favorito do navegador, mensagem no
  WhatsApp) continua funcionando e o navegador passa a ir direto na
  próxima vez.
- **Alternativas consideradas:**
  - Apagar a rota e deixar 404 — rejeitada: quebra link compartilhado.
  - Manter as duas páginas — rejeitada pelo dono: experiência duplicada.
- **Consequências:** `templates/produtos.html` fica no repositório sem
  uso (rollback = devolver o `render_template` na rota). `/produtos/<slug>`
  (página do produto) **não muda**. `listar_colecoes` segue parada,
  disponível para um futuro filtro por tipo na home.
- **Arquivos:** `app.py`, `templates/index.html`, `templates/base.html`,
  `templates/carrinho.html`, `templates/favoritos.html`,
  `templates/produto.html`, `static/css/styles.css`

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
