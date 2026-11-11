# Plano do banco — Bloome

> **Status:** planejamento registrado em **2026-11-11**. **Nada foi executado no banco.**
> **Para quem retomar:** leia as decisões fechadas (§6) e a próxima etapa (§11).
> **Fonte das regras:** [`docs/VALIDACAO-REGRAS.md`](VALIDACAO-REGRAS.md) + decisões desta rodada (ADR-011 em [`docs/DECISOES.md`](DECISOES.md)).

---

## 1. Objetivo

Construir o banco do e-commerce do catálogo Bloome no **Supabase**, reaproveitando a lógica de receita/estoque do repositório de gestão (`martin-alexandre-707/Bloome`, clone local em `C:\Users\cgti\Documents\code\bloome-gestao`), **sem remodelar tudo** e **sem inventar dados**.

---

## 2. Estado atual e fontes

| Item | Situação em 11/11/2026 |
|---|---|
| Supabase | **Sem dados/tabelas; só as conexões configuradas** (confirmado pelo usuário). Estratégia: `CREATE`, não `ALTER`. |
| Driver no projeto | **Não existe** `psycopg`/`psycopg2` no `requirements.txt`; não há `db.py`. |
| `psql` na máquina | **Ausente.** O DDL será rodado no SQL Editor do Supabase, ou instalamos o driver depois. |
| Catálogo atual | 6 produtos em `catalogo.py` e outros 6 *hardcoded* em `templates/produtos.html`; nenhuma cor/receita no repositório. |
| Gestão | Clone local do `database.sql` + repositórios; último commit em 06/06/2026 (não foi feito `git fetch`). |

Arquivos lidos: `docs/VALIDACAO-REGRAS.md`, `docs/DECISOES.md`, `AGENTS.md`, `app.py`, `catalogo.py`, templates de catálogo/carrinho/conta/painel, `database.sql` do gestão e seus repositórios/services.

---

## 3. Regras de negócio consolidadas

- **Sob encomenda:** não existe estoque de colar pronto; o estoque é de **insumos**. Cada variação (cor) tem a própria **receita** (insumo × quantidade).
- **Cor não muda preço:** o preço fica no modelo; a cor é só uma variação. Uma foto por modelo; cada modelo tem 2–4 cores.
- **Visibilidade (regra nova, 11/11/2026):**
  - O produto **permanece visível** enquanto o pingente do produto estiver cadastrado.
  - Se o pingente não estiver cadastrado/disponível, o produto aparece como **`volta_em_breve`**, com CTA de WhatsApp para consultar.
  - O produto **só sai da loja se a admin retirar** (`removido` = retirada lógica, sem `DELETE` físico).
  - A regra antiga “todas as cores esgotadas → some” está **substituída**.
  - Cor esgotada continua visível, cinza/opaca e desabilitada.
  - **Detalhe a confirmar na execução:** como detectar “sem pingente” — receita vazia, insumo inexistente ou estoque zero.
- **Pedido:** nasce `aguardando_pagamento`; Pix, débito ou crédito; webhook **idempotente** e com assinatura validada.
- **Estoque:** pré-checar no checkout; **rechecar no pagamento**; baixar **só depois do pagamento**; se acabou, `pago_sem_estoque`; cancelar antes de produzir devolve insumo. Alerta de material com limite 5.
- **Status do pedido:** `aguardando_pagamento`, `pago`, `pago_sem_estoque`, `em_producao`, `pronto_para_retirada`, `enviado`, `entregue`, `cancelado`.
- **Conta obrigatória:** e-mail + senha (mínimo 8), histórico/rastreio, reset por e-mail com link de 1h. Um administrador só.
- **Entrega:** Maceió por Uber Flash ou retirada combinada no WhatsApp; fora por Correios; o cliente paga o frete; 3 dias úteis de confecção. O site **não lista endereços de retirada**.
- **Produto sem receita:** bloquear a venda (evita baixar nada e vender uma peça que não sabe produzir).

---

## 4. O que o gestão já resolve

**Aproveitar:** lógica de receita, custo por insumo, pré-checagem agregada do carrinho, guarda que impede estoque negativo com `rollback` e FK que protege o histórico de vendas.

**Não serve como está:**

| Problema | Evidência |
|---|---|
| Trigger amarrado ao **produto**, não à variação | `database.sql` linhas 64–89 |
| Baixa no **INSERT do item**, mas a regra é baixar no **pagamento** | `database.sql` linhas 86–89 |
| Devolução só no **DELETE**; cancelar por status não devolve | `database.sql` linhas 106–109 |
| Sem trigger para **UPDATE** de quantidade | — |
| PK `(pedido, acessório)` impede duas cores do mesmo modelo no mesmo pedido | `database.sql` linhas 52–58 |
| `data_pedidos` é `DATE` (perde hora) | `database.sql` linha 38 |
| `metodo_de_pagamento` só aceita `Pix/Dinheiro/Cartão` | `database.sql` linha 39 |
| `valor_total` confiado ao app, sem conferência | `database.sql` linha 41 |
| `composicao_acessorios` com `ON DELETE CASCADE` do insumo apaga receita silenciosamente | `database.sql` linhas 30–33 |
| Falta status, cliente, endereço, frete, rastreio, eventos de pagamento, variações, foto/descrição/material e reset de senha | — |

**Efeito colateral:** o CLI do gestão grava `id_acessorios` em `itens_pedidos` (`repositories/pedidos.py` linhas 51–54). Quando a coluna virar `id_variacao`, o CLI quebra até ser adaptado.

---

## 5. Divergências encontradas no catálogo

1. **6 × 16:** as regras falam em 16 produtos/49 variações, mas o código tem 6 em `catalogo.py` e outros 6 *hardcoded* em `templates/produtos.html`. São duas fontes de verdade e **não há lista de cores nem receitas** no repositório.
2. **Preço como texto:** `"R$ 30,00"` em `catalogo.py`; no banco precisa ser `NUMERIC`, com cálculo no backend.
3. **Retirada com endereço fixo:** o carrinho lista “UNIMA - Cruz das Almas” e “Ponta Verde”, mas a regra diz “não listar endereços; retirada combinada”.
4. **Status “Pronto para retirada”:** o painel do cliente usa o selo, mas ele não está na lista de 7 status.
5. **Código público do pedido:** o painel mostra `#BLO-0042`; o schema atual só tem o `SERIAL`. Falta um `codigo` único.
6. **Login/cadastro com GET:** os formulários de `conta.html` não têm `method="post"`; a senha iria na URL. O `minlength="6"` também contradiz a regra de mínimo 8.
7. **Checkout mock:** o carrinho não coleta e-mail (conta obrigatória), não coleta endereço para Correios, não escolhe cor e tem itens/totais fixos.
8. **Driver ausente:** a ADR-009 diz `psycopg[binary]`, mas o `requirements.txt` só tem Flask e python-dotenv.

---

## 6. Decisões fechadas (ver ADR-011)

| # | Decisão |
|---|---|
| **A** | Itens são gravados no checkout; o estoque baixa **na confirmação do pagamento** (`confirmar_pagamento`). A intenção “não baixar antes do pagamento” é mantida. |
| **B** | Seed só com **dado real**. Sem cores/receitas, o schema nasce, mas o seed fica incompleto — não inventar. |
| **C** | Incluir `pronto_para_retirada` no status do pedido. |
| **D** | Trocar o booleano por `frete_valor` + `frete_pago_por` (`cliente`/`loja`). |
| **E** | Endereço em colunas de `pedidos` (snapshot do pedido), nulas e preenchidas só em Correios. |
| **F** | `/painel` = cliente; `/adm` = admin. Tabelas separadas: `clientes` e `usuarios`. |
| **G** | Visibilidade nova: produto só sai por `removido` (admin); sem pingente → `volta_em_breve` + WhatsApp; cor esgotada fica cinza. |
| **H** | Supabase vazio: schema criado com `CREATE`; sem migração de dados existentes. |

---

## 7. Modelo alvo (v1)

| Grupo | Tabela | Papel |
|---|---|---|
| Catálogo | `acessorios` | modelo, preço, material, foto, descrição, status |
| Catálogo | `variacoes` | cor, `cor_hex`, status; 2–4 por modelo |
| Catálogo | `insumos` | matéria-prima e saldo |
| Catálogo | `composicao_variacoes` | receita (insumo × quantidade) por cor |
| Contas | `usuarios` | admin único (bcrypt) |
| Contas | `clientes` | conta obrigatória do comprador (bcrypt) |
| Contas | `recuperacao_senha` | token com hash e validade de 1h |
| Pedido | `pedidos` | status, valores, entrega, endereço, rastreio |
| Pedido | `itens_pedidos` | variação, quantidade, preço e custo *snapshot* |
| Pedido | `eventos_pagamento` | log idempotente do webhook |
| Financeiro | `despesas` | relatórios |
| Leitura | `resumo_pedidos` (view) | resumo para o admin |

**Mudanças principais:**

- `acessorios`: manter os nomes atuais e acrescentar `material`, `foto`, `descricao`, `status`, `criado_em`. Status: `ativo`, `volta_em_breve`, `removido`.
- `variacoes`: `id_variacao`, `id_acessorios`, `cor`, `cor_hex`, `status` (`ativo`/`esgotado`); `UNIQUE(id_acessorios, cor)`.
- `insumos`: acrescentar `unidade_medida` (opcional) e `estoque_minimo DEFAULT 5`.
- `composicao_variacoes`: `id_variacao`, `id_insumos`, `quantidade > 0`; FK de insumo com `RESTRICT`.
- `pedidos`: `id_cliente`, `codigo` único, `status`, `subtotal`, `frete_valor`, `frete_pago_por`, `valor_total`, `metodo_pagamento`, `tipo_entrega`, endereço (CEP, logradouro, número, complemento, bairro, cidade, UF), `rastreio`, `estoque_baixado`, `criado_em`/`atualizado_em`.
- `itens_pedidos`: `id_acessorios` → `id_variacao`; `custo_unitario` *snapshot*; `UNIQUE(id_pedidos, id_variacao)`.
- `eventos_pagamento`: `gateway`, `evento_id`, `payload JSONB`, `assinatura_valida`, `recebido_em`, `processado_em`; `UNIQUE(gateway, evento_id)`.

**Fluxo de pagamento:**

1. Checkout valida conta, cor e status; **pré-checa** o estoque; grava pedido + itens, sem baixar.
2. Webhook valida assinatura, grava `eventos_pagamento` (a unique barra repetição) e chama `confirmar_pagamento`.
3. `confirmar_pagamento` trava o pedido, **soma o consumo de todos os itens**, recheca e:
   - com estoque: baixa tudo de uma vez, marca `pago` e `estoque_baixado = true`;
   - sem estoque: marca `pago_sem_estoque`, sem baixar.
4. Cancelar antes de produzir devolve **só se** `estoque_baixado = true`, e zera a flag. Depois de produzir, não devolve.

---

## 8. Plano de execução — 5 frentes

| # | Frente | Entrega | Pronto quando |
|---|---|---|---|
| 1 | Fechar regras | ADR-011 + ajuste da lista de status/timing nos docs | Nenhuma decisão de schema “a confirmar” |
| 2 | Inventário do Supabase | Confirmação de que está vazio + estratégia `CREATE` | Inventário registrado, sem `ALTER` desnecessário |
| 3 | Schema | `db/schema.sql` no Método da Lacuna | Roda em transação; constraints negativas falham como devem |
| 4 | Regras no banco | `db/functions.sql` + `db/tests.sql` | 7 cenários de teste passam |
| 5 | Seed e validação | `db/seed.sql` + `db/queries.sql` | Catálogo visível correto; pedido de teste consome a receita |

### Frente 1 — Fechar as regras

- Registrar A–H na ADR-011.
- Ajustar a regra de visibilidade e o timing da baixa.
- Definir “produto sem receita = venda bloqueada”.
- **Depende de:** dados do seed (só para a frente 5).

### Frente 2 — Inventário do Supabase

- Usuário confirmou: **sem dados**, só conexões. Portanto, `CREATE`.
- Ainda assim, rodar uma consulta somente leitura em `information_schema` antes do DDL, para não criar tabela duplicada.
- Não usar `DROP`; se algo existir, parar e decidir.
- **Trava:** sem `psycopg`/`psql`, rodar no SQL Editor do Supabase ou instalar o driver depois.

### Frente 3 — Schema

Ordem interna: catálogo → contas → pedido → financeiro/leitura.

- `insumos`, `acessorios`, `variacoes`, `composicao_variacoes`
- `usuarios`, `clientes`, `recuperacao_senha`
- `pedidos`, `itens_pedidos`, `eventos_pagamento`
- `despesas`, view `resumo_pedidos`, índices

Entregar em **esqueleto com lacunas** (FKs, CHECKs e índices comentados para o aluno preencher). Testar com inserções inválidas: preço negativo, cor duplicada, status inválido, FK inexistente.

### Frente 4 — Regras dentro do banco

Funções/triggers:

- `verificar_estoque_pedido` — pré-check agregado.
- `confirmar_pagamento` — idempotente; trava, recheca, baixa ou marca `pago_sem_estoque`.
- `baixar_estoque_pedido` — baixa **agregada**, não item a item.
- `devolver_estoque_pedido` — só no cancelamento antes de produzir e só se `estoque_baixado = true`.
- `calcular_custo_variacao` — custo da receita.
- Trigger de `atualizado_em`.

Testes obrigatórios:

1. Estoque suficiente → `pago` e saldo correto.
2. Estoque insuficiente → `pago_sem_estoque`, sem baixa.
3. Webhook repetido → uma baixa só.
4. Cancelar antes de produzir → devolve uma vez.
5. Cancelar depois de produzir → não devolve.
6. Dois pedidos disputando o mesmo insumo → o segundo não deixa negativo.
7. Produto sem receita → venda bloqueada.

### Frente 5 — Seed e validação

Ordem: insumos → acessórios → variações → receitas → admin. Clientes e pedidos só em teste.

Consultas de validação: catálogo visível, cor esgotada, produto sem pingente, alerta de estoque ≤ 5, fila de produção, resumo e lucro por produto.

---

## 9. Dados que faltam

- **6 produtos do código ou 16/49 das regras?**
- **Quais cores por modelo?** (2–4 por modelo; paleta inferida: preto, marrom, vinho, oliva, dourado).
- **Receita de cada cor:** insumo × quantidade.
- **Estoque inicial e custo unitário dos insumos.**
- **Qual insumo é o “pingente” de cada produto** (para a regra de `volta_em_breve`).

Sem esses dados, o schema pode ser criado, mas o seed fica incompleto. **Não inventar.**

---

## 10. Como executar

1. Abrir o SQL Editor do Supabase.
2. Rodar o inventário somente leitura.
3. Rodar o schema dentro de `BEGIN`/`COMMIT`; se falhar, `ROLLBACK`.
4. Rodar as funções/triggers e os testes em `BEGIN`/`ROLLBACK`.
5. Só depois rodar o seed.
6. Para o Flask ler o banco: adicionar `psycopg[binary]` ao `requirements.txt`, criar `db.py` e migrar as rotas aos poucos (ADR-003), mantendo `PRODUTOS` como fallback.

---

## 11. Próxima etapa

1. Confirmar a fonte dos dados do seed (§9).
2. Criar `db/schema.sql` em esqueleto com lacunas.
3. Auditar o preenchimento, rodar no Supabase e seguir para as funções.

**Nada foi executado no banco nesta rodada.**

---

## 12. Referências

- `docs/VALIDACAO-REGRAS.md` — regras de negócio.
- `docs/DECISOES.md` — ADR-011.
- `app.py`, `catalogo.py`, `templates/` — estado do catálogo.
- `C:\Users\cgti\Documents\code\bloome-gestao\database.sql\database.sql` — schema do gestão.
- `C:\Users\cgti\Documents\code\bloome-gestao\repositories\pedidos.py` — venda, pré-checagem e histórico.
