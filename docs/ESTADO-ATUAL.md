# Estado atual — Bloome

> **Para a IA:** leia este arquivo no início da sessão, junto com
> `AGENTS.md` e `docs/DECISOES.md`. Ele diz **onde paramos**; o histórico
> do *porquê* está nas ADRs.
>
> **Regra:** atualizar no fim de cada passo concluído. Manter curto — se
> crescer além de ~60 linhas, resumir em vez de empilhar.

**Última atualização:** 2026-11-27

---

## Objetivo do ciclo atual

O que o amigo pediu, em uma frase: **registrar → ver o produto → escolher cor
→ colocar no carrinho → criar conta / entrar → fechar pedido.**

| # | Passo | Status |
|---|-------|--------|
| 0 | Catálogo lendo as views do banco (`/produtos`, `/produtos/<slug>`) | ✅ |
| 0b | Fotos reais + descrições (ADR-016) e dados fictícios de estoque (ADR-017) | ✅ |
| 0c | Botão "Em breve" no card e no detalhe do produto | ✅ |
| 1 | Formulário de cadastro chega ao servidor (`POST /conta/criar`) | ✅ |
| 1b | Validação no servidor + `flash` + POST-Redirect-GET (ADR-018) | ✅ |
| 1c | bcrypt + `INSERT` em `bloome.clientes` + sessão (ADR-019) | ✅ |
| 1d | Login, logout, `/painel` protegido e header dinâmico (ADR-022) | ✅ |
| 1e | Feedback de formulário: flash global, aba de origem preservada, e-mail com `pattern` | ✅ |
| 2 | Escolher cor no detalhe + `POST /carrinho/adicionar` (session) | ✅ |
| 3 | Carrinho real: session + banco, total calculado no backend | ✅ |
| 4 | Checkout: `pedidos` + `itens_pedidos` em transação, pagamento simulado e "Em preparação" (ADR-029) | ✅ |
| 4b | Favoritos persistentes (ADR-032), toast acessível, carrinho em cartões, checkout em 3 etapas | ✅ |
| 4c | Catálogo completo só na home; `/produtos` → 301; modal aposentado; header fixo e enxuto (ADR-033/034) | ✅ |
| 5 | Mercado Pago + webhook idempotente e assinado | ⏳ próximo |

**Banco real conectado** (2026-11-26). O problema era o `.env`: prefixo
`DATABASE_URL=` duplicado e ref do projeto errado por uma letra — a senha
sempre esteve certa. O app roda contra o Supabase pelo pooler (porta 5432).

**Sem mock (ADR-026):** `dados.py` é a camada de dados e lê **só** o Supabase.
Sem `DATABASE_URL` ou `SECRET_KEY` no `.env` o app não inicia — não há mais
modo demonstração nem `catalogo.py`.

**Modal aposentado (ADR-033):** existe uma única forma de ver o produto,
a página `/produtos/<slug>`. `_modal-produto.html` e
`static/js/modal-produto.js` permanecem no repositório sem uso, para
rollback barato. O seletor de quantidade vive na página do produto.

**Catálogo = home (ADR-034):** a home mostra os dois catálogos completos
(16 peças) com o mesmo card de produto. `GET /produtos` responde 301 para
`/#catalogo-bloome`; `templates/produtos.html` fica parado, sem rota que
o renderize. O header é sticky (`--header-h` medido em
`static/js/header-offset.js`) e as âncoras usam `scroll-margin-top`.

Na sessão nova, basta: *"Bloome. Leia AGENTS.md, docs/DECISOES.md e
docs/ESTADO-ATUAL.md. Continua o passo X."*

---

## Pendências conhecidas (não bloqueiam o passo atual)

- **Validação de e-mail**: o `pattern` do HTML é mais rígido que o `if` do
  `app.py` para `@b.com`, `a@.com` e `a b@c.com`. Fechar com `re.fullmatch`
  no servidor.
- `login_requerido` não consulta o banco por requisição: conta anonimizada
  durante a sessão continua logada até o cookie sumir.
- Ainda **sem token CSRF**; `SameSite=Lax` cobre o caso cross-site comum, mas
  não é equivalente.
- O cartão "Meus dados" do painel ainda é fictício; os **pedidos** já vêm
  do banco (`listar_pedidos_cliente`).
- Contas de teste não podem ser apagadas (`trg_clientes_sem_delete`);
  usar `bloome.anonimizar_cliente(id)`.
- Dados de estoque/receita são **fictícios** (ADR-017) — remover com
  `db/07_placeholder_teste.sql` (bloco de reversão no rodapé) antes do lançamento.
- 10 descrições de produto foram escritas por IA a partir dos atributos reais
  (`db/06_dados_reais.sql`) e aguardam revisão da dona.
- Modelos 26 (Cordão Amarração) e 27 (Chocker Fita Pura) são "sem pingente" e
  pela regra D2 nunca ficam vendáveis — decisão de produto pendente.
- O spike Django foi **removido da máquina** em 2026-11-26 (ADR-015 já o tinha
  cancelado); o código dele não está versionado.
