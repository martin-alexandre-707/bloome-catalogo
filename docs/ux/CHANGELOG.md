# Changelog de UX — desde a 2ª avaliação

Baseado em `git log` desde o commit `931e4a1` ("carrinho passo 3") e nos ADRs em `docs/DECISOES.md`.
Data da consolidação: 2026-11-27 · Equipe Bloome.

> Cada item diz **o que mudou** e **por quê**. Commits citados entre parênteses.

---

## 1. Navegação

| Mudança | Por quê | Onde |
| --- | --- | --- |
| Cabeçalho (`header`) refeito; menu com link ativo via `aria-current` | Deixar claro em que página se está; melhora orientação e acessibilidade | `92cf096`, `templates/base.html` |
| `/produtos` virou **redirect 301** para a home (`#catalogo`) | Remover um passo redundante; catálogo completo agora na home (ADR-034) | `app.py`, ADR-034 |
| Menu condicional: "Favoritos" só logado; "Entrar" só deslogado; nome → painel | Refletir o estado da sessão e evitar página vazia/erro | `templates/base.html`, ADR-032 |
| Carrinho como ícone com badge e `aria-label` por extenso | Manter compra sempre acessível sem poluir; contagem anunciada | `templates/base.html` |

## 2. Catálogo

| Mudança | Por quê | Onde |
| --- | --- | --- |
| **Catálogo completo na home** (16 peças, Bloome + Cápsula Maré) | Página é a vitrine; menos cliques até a peça (ADR-034) | `ce1dcb2`, `templates/index.html`, ADR-034 |
| **Modal de produto aposentado**; o card leva à página grande | Modal escondia detalhes e dependia de JS; página por slug é mais acessível e compartilhável (ADR-033) | ADR-033 (substitui ADR-025) |
| Produtos agrupados por catálogo (Bloome / Cápsula Maré) | Refletir a coleção real do PDF | `fd83f5c` (ADR-031, depois substituída por ADR-034) |
| Página da peça por **slug** (`/produtos/cordao-coracao`) | URL legível e estável, melhor para compartilhar | ADR-030 |
| Fotos reais e descrições do PDF | Catálogo fiel ao produto | `ce1dcb2`, ADR-016 |

## 3. Carrinho e checkout

| Mudança | Por quê | Onde |
| --- | --- | --- |
| **Checkout em 3 etapas** (Entrega, Pagamento, Confirmação) reorganizado | Dividir decisão em passos com progresso visível | `eb75521`, `templates/checkout.html` |
| **Pagamento simulado** aprova e deixa o pedido "em preparação" | Permitir demonstrar o fluxo completo sem cobrança real (ADR-029) | ADR-029 |
| Quantidade no carrinho atualizada **sem recarregar** | Feedback imediato; menos atrito | `eb75521`, `templates/carrinho.html` |
| Carrinho na sessão guarda só `id_variacao` + quantidade | Dinheiro sempre no servidor; nada sensível no cookie | ADR-027 |
| Correios como "em breve", bloqueado no servidor | Não prometer frete que não existe | ADR-028 |

## 4. Favoritos e painel

| Mudança | Por quê | Onde |
| --- | --- | --- |
| **Favoritos persistentes** (tabela `bloome.favoritos`, exigem login) | Antes eram mock dos 3 primeiros; agora são reais por cliente (ADR-032) | `2126b6a`, ADR-032 |
| **Painel com abas** Pedidos / Favoritos | Concentrar "minha conta" num lugar só | `eb75521`, `templates/painel.html` |
| Seção de favoritos no painel + estados vazios | Orientar a cliente quando não há itens | `templates/painel.html` |
| Animação de revelação ao rolar | Polimento visual (respeita `prefers-reduced-motion`) | `2126b6a`, `js/reveal.js` |

## 5. Acessibilidade

| Mudança | Por quê | Onde |
| --- | --- | --- |
| **Contraste do link ativo do menu** corrigido (creme sobre véu de vinho ≥ 5,2:1) | Eliminar as 3 violações `color-contrast` sérias do axe | `static/css/styles.css` |
| **Alvos de 44px** nos códigos de pedido do painel | Cumprir toque mínimo (WCAG 2.5.5 / 44px) | `static/css/styles.css` |
| **Toast acessível** (`aria-live` polite/assertive) | Confirmar ações sem depender de visão | `templates/base.html`, `js/toast.js` |
| `prefers-reduced-motion` desliga animações | Respeitar quem tem sensibilidade a movimento | `static/css/styles.css` |
| Skip link, foco visível (`:focus-visible`), um `h1` por página | WCAG 2.1 AA | ADR-006 |
| **Resultado axe:** 0 violações, 0 overflow, 0 exceções JS em 9 páginas | Fechar a auditoria automática | ver [`ACESSIBILIDADE.md`](ACESSIBILIDADE.md) |

## 6. Documentação

| Mudança | Por quê | Onde |
| --- | --- | --- |
| **PRD** criado (visão, personas, RF, RNF, critérios) | Fonte única de requisitos | `3a47e1a`/`80035e6`, `docs/PRD.md` |
| **AUTENTICACAO.md** (sessão, cookie assinado, bcrypt) | Explicar o "como funciona" e o "por quê" | `80035e6`, `docs/AUTENTICACAO.md` |
| README e guia de instalação; limpeza do repositório | Deixar o projeto pronto para GitHub/portfólio | `3a47e1a` |
| Skills em `.agents` (acessibilidade, etc.) | Padronizar auditoria de UI | `80035e6` |
| **REMOVIDO:** modo demonstração (mock, ADR-024) | Toda consulta vai ao Supabase (ADR-026) | ADR-026 |

---

## Resumo por tema

| Tema | Principais entregas |
| --- | --- |
| Navegação | Header novo, `/produtos` → redirect, menu condicional |
| Catálogo | Home = catálogo, modal removido, slugs, agrupamento por coleção |
| Carrinho/checkout | 3 etapas, pagamento simulado, quantidade sem reload |
| Favoritos/painel | Favoritos persistentes, painel em abas |
| Acessibilidade | 0 violações axe, contraste, 44px, toast, reduced-motion |
| Documentação | PRD, AUTENTICACAO, README, skills |
