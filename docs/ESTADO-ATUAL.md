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
| 0 | Catálogo lendo as views do banco (`/produtos`, `/produtos/<id>`) | ✅ |
| 0b | Fotos reais + descrições (ADR-016) e dados fictícios de estoque (ADR-017) | ✅ |
| 0c | Botão "Em breve" no card e no detalhe do produto | ✅ |
| 1 | Formulário de cadastro chega ao servidor (`POST /conta/criar`) | ✅ |
| 1b | Validação no servidor + `flash` + POST-Redirect-GET (ADR-018) | ✅ |
| 1c | bcrypt + `INSERT` em `bloome.clientes` + sessão (ADR-019) | ✅ |
| 1d | Login, logout, `/painel` protegido e header dinâmico (ADR-022) | ✅ |
| 1e | Feedback de formulário: flash global, aba de origem preservada, e-mail com `pattern` | ✅ |
| 2 | Escolher cor no detalhe + `POST /carrinho/adicionar` (session) | ✅ |
| 3 | Carrinho real: session + banco, total calculado no backend | ✅ |
| 4 | Checkout: `pedidos` + `itens_pedidos` em transação | ⏳ próximo |
| 5 | Mercado Pago + webhook idempotente e assinado | ⬜ |

**Banco real conectado** (2026-11-26). O problema era o `.env`: prefixo
`DATABASE_URL=` duplicado e ref do projeto errado por uma letra — a senha
sempre esteve certa. O app roda contra o Supabase pelo pooler (porta 5432).

**Sem mock (ADR-026):** `dados.py` é a camada de dados e lê **só** o Supabase.
Sem `DATABASE_URL` ou `SECRET_KEY` no `.env` o app não inicia — não há mais
modo demonstração nem `catalogo.py`.

**Merge com o trabalho do amigo (ADR-025):** o modal de produto
(`_modal-produto.html` + `static/js/modal-produto.js`), o seletor de
quantidade, o toast e os favoritos data-driven vieram da `origin/main`. O
botão "Adicionar ao carrinho" do modal já é um submit real para
`POST /carrinho/adicionar`. Em 2026-11-27 foi corrigido um bug em que a
consulta de cores do catálogo (`_cores_por_acessorio`) não trazia
`id_variacao`, e o modal enviava a cor vazia.

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
- Pedidos e cartão "Meus dados" do painel continuam fictícios.
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
