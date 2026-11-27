# Portfólio de UX — Bloome

A história única do projeto: o problema, para quem, o que decidimos, o que foi testado com evidência, o que mudou e o que fica para a próxima fase.
Data: 2026-11-27 · Equipe Bloome (Victor Xavier · Martin Alexandre · Anthonio Fon).

---

## 1. O problema

A Bloome vende acessórios artesanais feitos à mão em pequena escala, e vende pelo **Instagram e WhatsApp**. O catálogo é um **PDF**, os pedidos são anotados à mão e se perdem no direct. A cliente não acompanha o que pediu; a dona não tem uma lista única do que produzir.

**O produto** é uma loja web própria que substitui esse processo: mostra as peças, recebe o pedido e organiza a preparação.

**Proposta de valor:** comprar uma peça da Bloome é simples, bonito e funciona para todo mundo — inclusive para quem usa leitor de tela, zoom ou teclado.

## 2. Para quem

| Persona | Necessidade | Como o produto atende |
| --- | --- | --- |
| **Cliente final** (18–35, compra por celular) | ver peças, escolher cor, saber preço, comprar rápido | catálogo na home, página da peça, carrinho e checkout em 3 etapas |
| **Cliente com baixa visão / teclado** | navegar sem mouse, com contraste e foco visível | WCAG 2.1 AA, alvos 44px, `aria-live`, `prefers-reduced-motion` |
| **Dona da loja** | saber o que produzir e o que saiu | pedidos com status e itens (gestão da loja é próxima fase) |

Detalhe em [`docs/PRD.md`](../PRD.md) §3 e §6.

## 3. Decisões que moldaram a experiência

- **Catálogo na home, não em página separada.** A vitrine é a primeira coisa que a pessoa vê; `/produtos` virou redirect (ADR-034). Menos cliques até a peça.
- **Modal de produto aposentado.** O card leva à **página da peça** por slug (ADR-033): mais acessível, compartilhável e sem depender de JS.
- **Favoritos só com conta.** São por cliente, guardados no banco (ADR-032); sem login não há o que mostrar.
- **Checkout em 3 etapas** (Entrega → Pagamento → Confirmação), com progresso visível e revisão antes de confirmar.
- **Pagamento simulado** para demonstrar o fluxo sem cobrar (ADR-029).
- **Dinheiro só no servidor.** O carrinho na sessão guarda apenas variação + quantidade (ADR-027); subtotal, frete e total são calculados no Flask/PostgreSQL.

Mapa do site e fluxo completo em [`ARQUITETURA-INFORMACAO.md`](ARQUITETURA-INFORMACAO.md). Design system em [`DESIGN-SYSTEM.md`](DESIGN-SYSTEM.md).

## 4. O que foi testado — com evidência real

### 4.1 Auditoria automática de acessibilidade (axe-core 4.10.2)

| Momento | Resultado |
| --- | --- |
| **Antes** | 3 violações sérias de `color-contrast` no link ativo do menu; alvos de 83×24px nos códigos de pedido do painel |
| **Depois** | **0 violações**, 0 overflow horizontal, 0 exceções de JS — 9 páginas, viewport 360×780 |

### 4.2 Contraste, zoom e daltonismo
- Contraste do link ativo: creme `#e8dedc` sobre `#874755` = **5,20:1**; sobre `#82404f` = **5,69:1**; botão vinho sobre rosa-claro = **4,85:1**.
- **Zoom 200%** (viewport 640×450, `deviceScaleFactor 2` via CDP): 0 overflow, 0 texto cortado, 0 erro JS em 8 páginas.
- **Daltonismo:** simulação de deuteranopia na página do produto; o nome da cor é texto visível ao lado da bolinha, então não depende só de cor. Evidência: [`evidencias/daltonismo-produto.png`](evidencias/daltonismo-produto.png).

### 4.3 Responsividade e microinterações (verificado no Chrome real)
- 360, 390, 764 e 1264px sem rolagem horizontal.
- Hover do card: `translateY(-8px)`, sombra reforçada, zoom 1.05 na foto; `:active` afunda 1px; `:focus-visible` igual ao hover; `prefers-reduced-motion` desliga o transform.

Relatório completo: [`ACESSIBILIDADE.md`](ACESSIBILIDADE.md).

> **O que ainda não foi testado com pessoas** (declarado com honestidade): teste A/B, teste de 5 segundos, avaliação heurística cruzada, card sorting, tree testing, leitor de tela e teste com pessoas daltônicas. Os roteiros estão prontos em [`AVALIACAO-3.md`](AVALIACAO-3.md). Nada disso foi inventado como resultado.

## 5. O que mudou desde a 2ª avaliação

Em resumo: home virou o catálogo completo; modal removido; página da peça por slug; favoritos persistidos no banco; painel em abas; checkout em 3 etapas com pagamento simulado; e a acessibilidade fechou em 0 violações axe. Tema a tema em [`CHANGELOG.md`](CHANGELOG.md).

## 6. Próxima fase

| Item | Por quê |
| --- | --- |
| Rodar os testes com pessoas (A/B, 5s, card sorting, tree testing) | Validar as hipóteses de IA com o público real |
| Leitor de tela (NVDA/VoiceOver) | Confirmar anúncios de estado e erros |
| Biblioteca no Figma + coerência com o código | Design system de mão dupla |
| Indicador de carregamento no carrinho | Fechar a lacuna H1 (feedback de status) |
| Busca/filtro no catálogo (16 peças) | Melhorar eficiência (H7) |
| Painel administrativo (`/adm`) para a dona | Fora do MVP, mas é a dor central do negócio |
| Gateway de pagamento real e CSRF | Sair da demonstração com segurança |

---

## Índice dos documentos

- [AVALIACAO-3.md](AVALIACAO-3.md) — resposta item por item da 3ª avaliação + roteiros.
- [ACESSIBILIDADE.md](ACESSIBILIDADE.md) — método, antes/depois, contraste, zoom, roteiros.
- [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md) — paleta, tipografia, espaçamentos, componentes e estados.
- [ARQUITETURA-INFORMACAO.md](ARQUITETURA-INFORMACAO.md) — mapa, fluxo, menu, card sorting, tree testing.
- [CHANGELOG.md](CHANGELOG.md) — o que mudou desde a 2ª avaliação.
