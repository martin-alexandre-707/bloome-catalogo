# Validação — Regras e escolha da stack

> Validado em 2026-11-11.
> `[x]` = decidido; `[ ]` = aberto (não bloqueia o início do site).
> Este arquivo é a fonte das regras; as decisões viram ADR no `DECISOES.md`.

---

## 0. Stack

- [x] Fazer o **teste Django** na branch `experimento/django` por 1 dia.
- [x] Critério: todo mundo **roda e explica** URL → view → template; o `/adm` cobre o CRUD; o CSS atual sobrevive.
- [x] Resultado: **passou → Django; não passou → Flask**.
- [ ] Teste executado. (Aguardando a branch; enquanto isso, o site atual continua em Flask.)

**Status:** regra fechada; falta rodar o teste. O código atual (Flask) não é jogado fora antes do resultado.

---

## 1. Produto

- [x] Feito sob encomenda: não existe estoque de colar pronto. (MVP; se um dia a dona vender peça pronta, isso é adicionado depois.)
- [x] Pingente fixo na foto; o cliente escolhe **só a cor**.
- [x] Cada modelo tem sua própria lista de cores (2–4).
- [x] Catálogo atual: 16 produtos, 49 variações, preços de R$ 18 a R$ 50. Pode crescer; os números não são limite.
- [x] Cor **não** muda o preço.
- [x] Uma foto por modelo (a mesma foto serve para todas as cores).
- [x] Peça do zero/personalizada: **só WhatsApp**.
- [x] Material fixo por modelo (courinho, camurça, fio torcido, corrente, courinho dourado). O PDF (p. 11) mostra que a escolha camurça/courinho é da **personalização do zero**; no catálogo, o material já está definido pelo modelo. Não é uma variação do site.
- [x] Status por produto e por cor: **ativo / volta em breve / esgotado**.
  - **Produto esgotado sai do site** (não aparece).
  - **Cor esgotada**: a bolinha continua visível, mas fica **cinza/opaca e desabilitada**. O produto só sai do site quando **todas** as cores estiverem esgotadas.
  - **Volta em breve** aparece com aviso e sem botão de compra.
- [x] Não mostrar quantidade; não usar selo "disponível".

**Cores inferidas:** preto, marrom, vinho, oliva, dourado. O catálogo mostra as bolinhas, não os nomes escritos; confirmar com a dona depois (não bloqueia).

---

## 2. Estoque

- [x] Estoque = **insumos** (fios, pingentes, pedras etc.).
- [x] Cada variação tem uma **receita** (insumos e quantidades).
- [x] Estoque insuficiente **bloqueia o pedido antes do pagamento**; o trigger também impede estoque negativo.
- [x] No webhook de pagamento, **rechecar o estoque**. Se acabou entre o checkout e o pagamento: pedido vira `pago_sem_estoque`; a dona reembolsa ou troca a cor.
- [x] Baixa de insumo **só depois do pagamento**.
- [x] Cancelou antes de produzir → devolve insumo.
- [x] Alerta de material acabando. **MVP: limite fixo de 5 unidades; ajustar depois.**

### Confirmação do gestão (GitHub)

O que já existe no `database.sql` + repositórios:

- `insumos`: nome, valor_unitario, quantidade_estoque (>= 0), categoria.
- `acessorios`: nome_acessorios, categoria_acessorio, valor_acessorio.
- `composicao_acessorios`: receita (insumo, acessório, quantidade > 0).
- `pedidos`: data, metodo_de_pagamento (Pix/Dinheiro/Cartão), nome_cliente, valor_total.
- `itens_pedidos`: pedido, acessório, quantidade_vendida, valor_unitario.
- Trigger `baixar_estoque` (AFTER INSERT em `itens_pedidos`): subtrai `quantidade da receita × quantidade vendida`; se algum insumo ficar negativo, levanta exceção e a venda inteira é desfeita (`rollback`).
- Trigger `devolver_estoque` (AFTER DELETE): devolve a mesma conta.
- `verificar_estoque_carrinho`: soma o consumo por insumo e bloqueia antes de gravar.
- `calcular_custo_insumos`: custo da receita (quantidade × valor_unitario).
- `deletar_acessorio`: bloqueia se houver venda no histórico (FK).
- `gerar_relatorio_financeiro`: total de vendas, faturamento, ticket médio.
- View `resumo_pedidos`: pedido, data, pagamento, cliente, produto, quantidade, unitário, subtotal.
- Login com bcrypt (`usuarios`).

O que **não** existe e é novo no `/adm`:

- Status de pedido, fila de produção, rastreio, alerta de estoque.
- Clientes, cores/variações, foto/descrição/status do produto.
- Pagamento/webhook, entrega, relatórios por produto/lucro.
- Chatbot.

**Mudança necessária:** hoje o trigger olha `id_acessorios` (produto). Com a tabela `variacoes`, ele passa a olhar `id_variacao`, e a receita vai para `composicao_variacoes`. O resto da lógica (baixar, devolver, bloquear negativo, pré-checar) continua igual.

---

## 3. Pedido e pagamento

- [x] Checkout cria pedido **aguardando_pagamento**; o cliente paga **antes**.
- [x] Pagamento: **Pix, débito, crédito**. Sem boleto.
- [x] Gateway proposto: **Mercado Pago** (sem CNPJ; confirmar CPF).
- [ ] CPF: coletar **só se o Mercado Pago exigir**; política de privacidade antes de produção. Não bloqueia o MVP.
- [x] Cancelamento/reembolso no MVP: **manual**. A dona marca `cancelado` no `/adm` e reembolsa pelo painel do Mercado Pago; automação depois.
- [x] Webhook **idempotente** e com assinatura validada.
  - Em português: o Mercado Pago avisa o site quando o pagamento cai. "Idempotente" = se avisar duas vezes, o site não conta duas. "Assinatura" = o site confere se o aviso veio mesmo do Mercado Pago.
- [x] Status: `aguardando_pagamento`, `pago`, `pago_sem_estoque`, `em_producao`, `enviado`, `entregue`, `cancelado`.
- [x] Nunca guardar dado de cartão.
- [x] Conta no checkout **obrigatória**: e-mail + senha, histórico e rastreio.
- [x] Layout do checkout **autoral, com a cara do Bloome**; o print da referência serve só para as funções (resumo, etapas, pagamento), não para copiar o visual.

---

## 4. Entrega

- [x] Maceió: Uber Flash ou retirada na UNIMA/Ponta Verde; combinar no WhatsApp. O site **não lista endereços**; mostra "retirada combinada".
- [x] **Uber Flash: o cliente paga**; a dona combina no WhatsApp.
- [x] Fora: Correios; endereço no checkout; **cliente paga o frete**; prazo por localização.
- [x] **3 dias úteis** mínimos de **confecção**, global. A entrega local (Uber Flash) é combinada **depois** e **não entra** nos 3 dias; para fora, soma o prazo do frete.
- [x] Rastreio só em envio; a dona digita no `/adm`; o cliente vê na conta.
- [x] Cálculo de frete fica para o futuro; no MVP, "a calcular/combinar".
- [x] Quando entrar, será por CEP (contrato/credenciais dos Correios + peso/medidas); **não bloqueia** o MVP.
- [ ] Troca/devolução: pendente (prazo e quem paga o frete de volta). Enquanto não definir: "combinar no WhatsApp".

---

## 5. Conta do cliente

- [x] E-mail + senha; histórico de pedidos; status e rastreio.
- [x] Recuperação de senha por e-mail.
  - O cliente se cadastra com o **e-mail dele**; o código/link de recuperação vai para esse mesmo e-mail. O e-mail do cliente fica em `clientes.email`.
  - **Remetente do MVP: Brevo** (conta gratuita, sem domínio), com o e-mail da dona verificado como remetente. O cliente recebe no e-mail dele; o Gmail da dona não é login do cliente.
  - Em desenvolvimento, o código/link aparece no terminal (sem enviar e-mail). Em produção, o Brevo envia.
  - Variáveis no `.env`: `MAIL_API_KEY`, `MAIL_FROM`, `MAIL_FROM_NAME`.
- [x] Checkout como visitante: **fora** (conta obrigatória).
- [x] MVP: senha mínimo 8; sem confirmação de e-mail; link de reset válido por 1h. (Revisar depois.)
- [ ] Login com Google: fase 2; não entra no MVP. (Se o grupo quiser, é OAuth do Google; não bloqueia.)

---

## 6. Gestão (`/adm`)

- [x] Um administrador, sem papéis. O cadastro público fica fechado; o admin é criado manualmente.
- [x] CRUD de produto, insumo, receita e pedido. (Insumos, produtos e receita já existem no CLI; pedidos hoje são criar/listar.)
- [x] Fila de produção, mudança de status e rastreio. (**novo**; não existe no CLI)
- [x] Alertas de estoque e relatórios básicos. (O relatório financeiro simples existe; alerta com limite 5 e relatórios por produto/lucro são novos.)
- [x] Cancelamento no MVP: manual; reembolso no painel do Mercado Pago.
- [x] Chatbot: fase 2.

**Do GitHub:** o CLI já tem login bcrypt, CRUD de insumos, CRUD de acessórios com receita e custo, vendas com carrinho e pré-checagem, histórico, relatório financeiro e os triggers. O que falta é a camada web e os itens marcados como novos acima.

---

## 7. Banco (mínimo)

- [x] Reaproveitar o `database.sql`; não remodelar tudo.
- [x] `acessorios` ganha: **material, foto, descrição, status**. `nome_acessorios` é o modelo e `categoria_acessorio` é o tipo (Cordão/Colar/Chocker). A **cor não fica aqui**. **MVP: foto em `static/imgs/`; Supabase Storage depois.**
- [x] Tabela **`variacoes`**: `id_variacao`, `id_acessorios`, `cor`, `cor_hex`, `status`. Cada cor é uma linha em `variacoes`; a mesma peça muda só a cor.
- [x] Receita por variação: **`composicao_variacoes`** (`id_variacao`, `id_insumos`, `quantidade`).
- [x] `itens_pedidos` passa a apontar para **`id_variacao`** (não `id_acessorios`).
- [x] `pedidos` ganha: status, cliente, entrega, endereço, frete, **frete_pago**, rastreio, pagamento. O carrinho fechado vira `itens_pedidos` (não precisa de coluna "carrinho").
- [x] Liberar o check de pagamento para **Pix/Débito/Crédito**. (Dinheiro só se o CLI antigo continuar.)
- [x] `clientes` (conta obrigatória) e `eventos_pagamento` (idempotência).
- [x] O trigger fica; itens entram **só após o pagamento**.

**Prazos:** 3 dias úteis de **confecção**, global; não precisa de coluna `prazo` por produto.

---

## 8. Fluxos

**Cliente:** catálogo → cor → carrinho → conta/checkout → pagamento → pedido pago → produção → envio/entrega → conta com rastreio.

**Dona:** login → insumos → produto/cores → receita → pedidos pagos → produz → status/rastreio → relatórios.

**Pagamento:** gateway → webhook → valida assinatura → marca pago → **recheca estoque** → baixa insumos → fila de produção. Se o estoque acabou: `pago_sem_estoque` → reembolso/troca.

- [x] Fluxos ok.
- [x] Produto esgotado sai da loja; cor esgotada fica cinza/opaca; "volta em breve" aparece com aviso.

---

## 9. Pendências

Abertas (não bloqueiam o início do site):

1. [ ] Teste Django de 1 dia (branch `experimento/django`).
2. [ ] Gateway e aceitação de CPF (Mercado Pago). CPF só se o gateway exigir.
3. [ ] Troca/devolução (prazo e frete de volta). MVP: combinar no WhatsApp.
4. [ ] Login com Google (fase 2; decidir depois).
5. [ ] Alguma peça descontinuada? (ver com a dona)
6. [ ] Cálculo de frete por CEP (fase 2; precisa de contrato/credenciais e peso/medidas).
7. [ ] Política de privacidade/LGPD (antes de produção).

Resolvidas:

- [x] Conta obrigatória.
- [x] Nomes das cores: inferir (preto, marrom, vinho, oliva, dourado); confirmar depois.
- [x] 3 dias = confecção; Uber Flash fora dos 3 dias e pago pelo cliente.
- [x] Endereços de retirada: combinar no WhatsApp; não listar.
- [x] E-mail: pessoal como remetente; cliente usa o e-mail dele; sem `@bloome.com`.
- [x] Frete: cálculo fica para o futuro ("a calcular/combinar").
- [x] Cor esgotada: bolinha cinza/opaca; produto só sai se todas as cores esgotarem.
- [x] Estoque no pagamento: rechecar; `pago_sem_estoque` → reembolso/troca.
- [x] Cancelamento/reembolso no MVP: manual.
- [x] Foto no MVP: `static/imgs/`.
- [x] Senha/reset no MVP: mínimo 8; sem confirmação de e-mail; token 1h.
