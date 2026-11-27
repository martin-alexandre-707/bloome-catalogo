# PRD — Bloome

Documento de requisitos do produto (Product Requirements Document).
Versão 1.0 · 2026-11-27 · Equipe Bloome.

---

## 1. Visão

A Bloome vende acessórios artesanais feitos à mão, em pequena escala, pelo
WhatsApp e pelo Instagram. O catálogo vive em um PDF e os pedidos são anotados
manualmente. O produto é uma **loja web própria** que substitui esse processo:
mostra as peças, recebe o pedido e organiza a preparação sem depender de
mensagens soltas.

**Proposta de valor:** comprar uma peça da Bloome é simples, bonito e funciona
para todo mundo — inclusive para quem usa leitor de tela, zoom ou teclado.

## 2. Problema

- O catálogo em PDF não tem busca, preço atualizado nem estoque.
- Pedido pelo direct/WhatsApp se perde e exige copiar dados à mão.
- A cliente não consegue acompanhar o que pediu.
- A dona não tem uma lista única do que precisa produzir.

## 3. Público

| Persona | Necessidade | Como o produto atende |
| --- | --- | --- |
| **Cliente final** (18–35, compra por celular) | ver as peças, escolher cor, saber o preço, comprar rápido | catálogo na home, página da peça, carrinho e checkout em 3 etapas |
| **Cliente com baixa visão / teclado** | navegar sem mouse, com contraste e foco visível | WCAG 2.1 AA, alvos de 44px, `aria-live`, `prefers-reduced-motion` |
| **Dona da loja** | saber o que produzir e o que saiu | pedidos com status e itens (painel do cliente; gestão da loja é próxima fase) |

## 4. Objetivos do MVP

1. Exibir o catálogo completo com foto, descrição, cores e preço.
2. Permitir montar um carrinho e finalizar um pedido.
3. Guardar favoritos por cliente.
4. Dar à cliente um painel com os próprios pedidos.
5. Ser acessível em celular e desktop.

**Fora do MVP:** pagamento real, frete calculado, painel administrativo,
notificações por e-mail, cupons.

## 5. Escopo entregue

### 5.1 Funcionalidades

| ID | Requisito | Status |
| --- | --- | --- |
| RF01 | Home exibe os dois catálogos (Bloome e Cápsula Maré) com todas as peças | ✅ |
| RF02 | Página da peça por slug (`/produtos/cordao-coracao`) com foto, descrição, preço e cores | ✅ |
| RF03 | Escolher cor e quantidade e adicionar ao carrinho | ✅ |
| RF04 | Carrinho com quantidade 1–99, remoção e totais calculados no servidor | ✅ |
| RF05 | Checkout em 3 etapas: entrega, pagamento e confirmação | ✅ |
| RF06 | Pedido gravado em transação, com itens e status | ✅ |
| RF07 | Pagamento simulado aprovado e pedido em preparação | ✅ (demonstração) |
| RF08 | Cadastro, login, logout e proteção de páginas privadas | ✅ |
| RF09 | Favoritos persistentes por cliente | ✅ |
| RF10 | Painel com pedidos e favoritos em abas | ✅ |
| RF11 | Detalhe do pedido do próprio cliente | ✅ |
| RF12 | Página "Sobre" e página de erro 404 | ✅ |
| RF13 | Estoque validado antes de criar o pedido | ✅ (dados fictícios) |
| RF14 | Correios como opção "em breve", bloqueada no servidor | ✅ |

### 5.2 Regras de negócio

- **Dinheiro só no servidor.** Subtotal, frete e total são calculados no Flask
  e no PostgreSQL; o JavaScript apenas exibe o que recebe.
- **Estoque:** um pedido não é criado se alguma variação não tiver quantidade
  suficiente; o estoque é baixado na confirmação do pagamento.
- **Entrega:** retirada na UNIMA (Cruz das Almas) e Ponta Verde, gratuitas;
  Uber Flash com frete a combinar; Correios fora do MVP.
- **Pagamento:** Pix, débito e crédito são simulados — nenhum valor é cobrado.
- **Favoritos** exigem conta; o coração aparece na página da peça e nos cards.
- **Conta anonimizada** não pode ser apagada fisicamente (LGPD): os dados são
  substituídos por `bloome.anonimizar_cliente`.

## 6. Jornadas

### Compra

1. A cliente abre a home e vê os dois catálogos.
2. Toca na peça → página com foto grande, cores, quantidade e favoritar.
3. Adiciona ao carrinho → toast confirma e o ícone do carrinho mostra a contagem.
4. No carrinho, ajusta quantidade (atualiza sem recarregar) e revisa os totais.
5. "Finalizar compra" → se não estiver logada, entra e volta para o checkout.
6. Escolhe entrega e pagamento → confirma → pedido criado → vai para o painel.

### Favoritos

1. Logada, toca no coração de uma peça.
2. A peça aparece em `/favoritos` e no painel.
3. Sem login, o coração não aparece; quem tentar entrar é levado ao login.

## 7. Requisitos não funcionais

| ID | Requisito | Como é atendido |
| --- | --- | --- |
| RNF01 | Acessibilidade WCAG 2.1 AA | HTML semântico, contraste ≥4,5:1, foco visível, alvos ≥44px, `aria-live`, `prefers-reduced-motion`; auditoria automática com axe-core em 9 páginas |
| RNF02 | Responsivo | testado em 360, 390, 764 e 1264px, sem rolagem horizontal |
| RNF03 | Senhas protegidas | hash bcrypt; a senha nunca é gravada em texto |
| RNF04 | Sessão segura | cookie assinado, `HttpOnly`, `SameSite=Lax`, `Secure` em produção |
| RNF05 | Sem estado no navegador para dinheiro | o carrinho na sessão guarda só variação + quantidade |
| RNF06 | Idioma | interface em pt-BR, `lang="pt-BR"` |
| RNF07 | Banco | PostgreSQL único; SQL versionado em `db/` |

## 8. Arquitetura

```
Navegador
  │  HTML/CSS/JS
  ▼
Flask (app.py)  ──  Jinja2 (templates/)  ──  static/ (CSS, JS, fotos)
  │
  ▼
dados.py  ──  psycopg  ──  PostgreSQL (schema bloome)
```

- **Rotas finas:** só orquestram HTTP, sessão e validação.
- **`dados.py`:** todas as consultas SQL ficam aqui.
- **Templates Jinja:** recebem dados prontos; não calculam dinheiro.
- **Banco:** tabelas, funções e triggers garantem as regras críticas.

### Modelo de dados (resumo)

| Tabela | Papel |
| --- | --- |
| `clientes` | nome, e-mail, telefone, senha_hash |
| `acessorios` | peça, preço, foto, descrição |
| `variacoes` | cor de cada peça e estoque |
| `pedidos` | código, status, entrega, subtotal, frete, total |
| `itens_pedidos` | peça, variação, quantidade e preço no momento da compra |
| `favoritos` | cliente × peça |

## 9. Autenticação (resumo)

Sessão em cookie assinado; detalhes em [`docs/AUTENTICACAO.md`](AUTENTICACAO.md).
Em uma frase: o cookie guarda um identificador de sessão assinado pelo servidor,
nunca a senha; `HttpOnly` impede leitura pelo JavaScript e `SameSite=Lax`
impede o envio em requisições de outros sites.

## 10. Critérios de aceite do MVP

- [x] Todas as páginas abrem em 200 (e 404 para endereço inexistente).
- [x] Nenhuma imagem quebrada; todas em `static/imgs/`.
- [x] Um `h1` por página, sem `id` duplicado.
- [x] Nenhuma violação axe-core (WCAG 2.1 AA) em 360px nas 9 páginas.
- [x] Compra completa gera pedido e esvazia o carrinho.
- [x] Cliente não acessa pedido de outra pessoa.
- [x] Nenhum cálculo de dinheiro no JavaScript.

## 11. Riscos e próximos passos

| Risco | Mitigação |
| --- | --- |
| Pagamento simulado | integrar gateway (Mercado Pago) com webhook assinado |
| Estoque fictício | revisar dados da dona antes do lançamento |
| Sem CSRF | incluir token e limite de tentativas no login |
| Dona sem painel | criar `/adm` para produtos, estoque e pedidos |
| Render free dorme | aceitável para demonstração; plano pago para uso contínuo |

## 12. Equipe

Anthonio Fon · Martin Alexandre · Victor Xavier
