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
