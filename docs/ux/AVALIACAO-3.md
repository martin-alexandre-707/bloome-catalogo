# Avaliação 3 de UX — Bloome

Resposta item por item às exigências da 3ª avaliação.
Data: 2026-11-27 · Equipe Bloome.

> **Legenda de status**
> - **FEITO** — existe evidência registrada neste repositório ou medição reprodutível.
> - **PARCIAL** — parte verificável no código/medição; o resto depende de pessoa ou ferramenta externa.
> - **A EXECUTAR** — depende de pessoas ou ferramentas externas. Aqui vai o **roteiro pronto** (participantes, tarefas, perguntas, critério). **Nenhum resultado é inventado.**

> **Regra que seguimos:** nada de "testei com usuário", "nota do especialista", "aprovado no Figma" ou "leitor de tela falou X" sem ter acontecido de verdade. Onde não aconteceu, está escrito **a executar**.

---

## 1. Avaliação heurística, teste A/B e teste de 5 segundos

### 1.1 Heurísticas de Nielsen (cruzada) — **A EXECUTAR**
A avaliação **cruzada** exige um avaliador de fora do grupo. Ainda não houve.
Abaixo está a **autoavaliação preliminar do próprio grupo**, com as 10 heurísticas de Nielsen, severidade de 0 a 4 e a resposta prevista "corrigiu / justificou". **Não é avaliação de terceiros e precisa ser confirmada por outro grupo** (roteiro em 1.1.2).

Escala de severidade: 0 = não é problema · 1 = cosmético · 2 = pequeno · 3 = maior · 4 = catastrófico.

| # | Heurística | Problema plausível (autoavaliação preliminar, a validar por outro grupo) | Sev. | Resposta prevista |
|---| --- | --- | --- | --- |
| H1 | Visibilidade do status do sistema | Ao ajustar quantidade ou remover item no carrinho a atualização é assíncrona (sem recarregar); não há indicador de "carregando" enquanto o servidor responde — em rede lenta a pessoa pode clicar duas vezes. | 2 | corrigir (spinner/skeleton leve no carrinho) |
| H2 | Correspondência com o mundo real | Rótulos internos como "Cápsula Maré", "Uber Flash (frete a combinar)" e "UNIMA" aparecem sem explicação para quem chega de fora. | 2 | justificar (Cápsula Maré é nome de coleção) + corrigir a sigla UNIMA com tooltip/texto |
| H3 | Controle e liberdade do usuário | Remover uma peça do carrinho é imediato e sem "desfazer"; depois de confirmar o pedido não há como editar a entrega. | 2 | corrigir (toast com "desfazer" na remoção) / justificar a edição pós-pedido (escopo) |
| H4 | Consistência e padrões | "Sair" é um botão discreto ao lado do nome; "Favoritos" só aparece logado. Visualmente coerente, mas a lógica de menu muda com o login. | 1 | justificar (Favoritos exige conta por ADR-032) |
| H5 | Prevenção de erros | Não há confirmação antes de "Confirmar pedido" além da etapa 3 de revisão; campo de WhatsApp já bloqueia letras. | 1 | justificar (a etapa 3 é a confirmação) |
| H6 | Reconhecimento em vez de memorização | O carrinho é só ícone; sem `aria-label`, quem vê não lê "carrinho". O nome no cabeçalho vira link do painel sem affordance clara de "menu". | 2 | corrigir (reforçar ícone + rótulo visual no desktop) |
| H7 | Flexibilidade e eficiência | A home tem 16 peças em dois catálogos e não há busca nem filtro por cor/tipo; é preciso rolar para achar. | 2 | corrigir (filtro/busca na próxima fase) |
| H8 | Estética e minimalismo | A home longa (16 cards) no celular vira rolagem extensa; o modal antigo foi removido (ADR-033), o que alonga o caminho até a peça. | 1 | justificar (catálogo como página é decisão de ADR-034) |
| H9 | Ajudar a reconhecer, diagnosticar e recuperar erros | A 404 é amigável e os formulários mostram erro por campo; mas erros de servidor no checkout dependem de `flash` genérico. | 2 | corrigir (mensagem de erro de checkout mais específica) |
| H10 | Ajuda e documentação | Não há FAQ nem página explicando entrega/pagamento além do texto do checkout; "Sobre" cobre a marca, não dúvidas. | 1 | corrigir (FAQ curta na próxima fase) |

**Resumo preliminar:** 0 problemas catastróficos (sev. 4), 0 maiores (sev. 3), 6 pequenos (sev. 2), 4 cosméticos (sev. 1). **A confirmar por avaliação cruzada.**

#### 1.1.2 Roteiro da avaliação cruzada (a executar)
- **Quem:** 2 avaliadores de outro grupo (não os autores), idealmente com 1 pessoa familiarizada com WCAG.
- **Material:** app rodando (`python app.py`), roteiro impresso, planilha de achados.
- **Tarefas observadas (5):** (1) achar o colar "Cordão Coração"; (2) adicionar 2 unidades ao carrinho; (3) trocar a quantidade no carrinho; (4) finalizar um pedido; (5) favoritar uma peça e achar em Favoritos.
- **Como registrar:** para cada tela, percorrer as 10 heurísticas; anotar heurística, descrição, severidade (0–4) e evidência (print/arquivo:linha).
- **Critério de saída:** lista consolidada, cada item com resposta **"corrigiu"** (com o que mudou) ou **"justificou"** (com o motivo). Comparar com a tabela acima e registrar divergências.
- **Entrega:** planilha + prints por achado.

### 1.2 Teste A/B simples com usuários — **A EXECUTAR**
Não há variante B implementada ainda. O teste exige **duas versões** comparáveis.
- **Variante A (atual):** catálogo completo na home (16 peças).
- **Variante B (a construir):** home com vitrine reduzida (6 peças) + botão "Ver catálogo completo". *(Requer código novo; fora do escopo desta avaliação.)*
- **Participantes:** 8–12 pessoas do perfil cliente (18–35, compram por celular), divididas em 2 grupos.
- **Métrica primária:** tempo até encontrar e abrir uma peça indicada; **secundárias:** cliques até a peça, taxa de sucesso, satisfação (1–5).
- **Pergunta pós-teste:** "O que você achou de tanto produto logo na abertura? Faltou algo?"
- **Como medir:** cronômetro + gravação de tela; média e mediana por grupo; relatar diferença **só se** houver amostra suficiente (não concluir com 2 pessoas).

### 1.3 Teste de 5 segundos na home — **A EXECUTAR**
- **Participantes:** 5–8 pessoas que nunca viram o site.
- **Procedimento:** mostrar a home por 5 segundos, esconder e perguntar.
- **Perguntas:** (1) O que este site vende? (2) Que peças você lembra de ter visto? (3) Onde você clicaria para comprar? (4) É um site de loja ou de outra coisa?
- **Critério:** ≥80% acertam "acessórios artesanais / joias" e apontam "Ver/Comprar" como caminho.
- **Registro:** tempo cronometrado, respostas transcritas, prints da tela exibida.

### 1.4 Gravação/vídeo ou prints do teste — **A EXECUTAR**
Os testes acima geram o material. Prints estáticos do produto já existem em `docs/capturas/` (`catalogo.png`, `produto.png`), mas **não são gravação de teste**. Gravações ficam para `docs/ux/evidencias/` após a sessão.

---

## 2. Acessibilidade

Detalhamento completo, tabelas por página e roteiros em [`ACESSIBILIDADE.md`](ACESSIBILIDADE.md).

### 2.1 Relatório de ferramenta automática antes/depois — **FEITO**
axe-core 4.10.2, viewport 360×780, 9 páginas (`/`, `/produtos/cordao-coracao`, `/carrinho`, `/checkout`, `/favoritos`, `/painel`, `/conta`, `/sobre`, 404), tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`.

| Momento | Violações | Overflow horizontal | Exceções de JS |
| --- | --- | --- | --- |
| **Antes** | 3 sérias de `color-contrast` no link ativo do menu (`aria-current`); alvos de 83×24px nos códigos de pedido do painel; 4 inputs radio 20×20 (cada um dentro de um label de 44px) | 0 | — |
| **Depois** | **0** | 0 | 0 |

Contraste recalculado: creme `#e8dedc` sobre `#874755` = **5,20:1**; sobre `#82404f` = **5,69:1**; vinho `#772e3f` sobre rosa-claro `#e0aeb6` = **4,85:1** (todos ≥ 4,5:1).

### 2.2 Teste com leitor de tela NVDA/VoiceOver — **A EXECUTAR**
Roteiro (detalhado em `ACESSIBILIDADE.md` §6): NVDA + Firefox no Windows e/ou VoiceOver + Safari no macOS/iOS. Tarefas: ler cabeçalho, navegar ao catálogo, favoritar, adicionar ao carrinho, concluir checkout. Critério: cada ação anuncia nome/estado, o toast é lido (`aria-live`), o foco não se perde.

### 2.3 Zoom 200% — **FEITO**
Método: emulação de viewport **640×450** com `deviceScaleFactor: 2` via Chrome DevTools Protocol (equivale a 1280×900 com zoom 2×). Páginas: `/`, `/produtos/cordao-coracao`, `/carrinho`, `/checkout`, `/painel`, `/favoritos`, `/conta`, `/sobre`.
Resultado: **0 rolagem horizontal**, **0 elementos de texto com corte** (`overflow:hidden` com conteúdo excedente), **0 exceções de JS**.

### 2.4 Formulários acessíveis — **FEITO (código) + A EXECUTAR (teste manual)**
- `label` ligado ao `input` (`.form-field label`), `input` com `font-size: 16px` (evita zoom no iOS).
- Erro não depende só de cor: além de borda vermelha, há texto via `.form-field__aviso` com `role="alert"` e o `::after` "Verifique este campo antes de continuar." / "Campo válido.".
- Foco visível em input (`:focus-visible`).
- **A executar:** confirmação manual com NVDA de que o erro é anunciado (roteiro §6.3).

### 2.5 Daltonismo — **FEITO (simulação) + observação**
Simulação de **deuteranopia** aplicada à página do produto por matriz de cor (`feColorMatrix`), capturada em [`evidencias/daltonismo-produto.png`](evidencias/daltonismo-produto.png).
Observação de design: **o nome da cor é texto visível ao lado da bolinha**, então a escolha não depende só da cor (atende 1.4.1 Uso de cor). Não houve teste com pessoas daltônicas — se necessário, ver roteiro §7 de `ACESSIBILIDADE.md`.

---

## 3. Design System

Documento completo em [`DESIGN-SYSTEM.md`](DESIGN-SYSTEM.md).

### 3.1 Documento com paleta + contrastes, tipografia, espaçamentos, componentes e estados — **FEITO**
Extraído dos tokens reais em `static/css/styles.css` (`:root`): paleta com hex, papel e contraste; escala tipográfica (12→36px); espaçamentos `--space-1`…`--space-20`; raios; sombras; lista de componentes com classes e estados implementados.

### 3.2 Componentes no Figma — **A EXECUTAR**
Não há arquivo Figma do projeto. **Não inventamos** um. O que existe é o design em código (CSS). Para a próxima fase: criar biblioteca Figma espelhando `DESIGN-SYSTEM.md`.

### 3.3 Coerência Figma ↔ código — **A EXECUTAR**
Depende de 3.2. Sem Figma, a "fonte da verdade" hoje é o próprio `styles.css`.

---

## 4. Arquitetura da Informação

Mapa do site, fluxo da compra e justificativa do menu em [`ARQUITETURA-INFORMACAO.md`](ARQUITETURA-INFORMACAO.md).

### 4.1 Card sorting com usuários — **A EXECUTAR**
Roteiro com **10 cartões** pronto (§4 do doc de AI). 6–10 participantes, cartões: Início, Catálogo Bloome, Cápsula Maré, Peça, Carrinho, Checkout, Favoritos, Meus pedidos, Minha conta/Entrar, Sobre. Resultado = agrupamentos + nomes escolhidos.

### 4.2 Mapa do site e fluxograma da tarefa principal — **FEITO**
Diagramas Mermaid (mapa do site e fluxo de compra em 3 etapas) no doc de AI.

### 4.3 Teste de árvore — **A EXECUTAR**
5 tarefas prontas (§5 do doc de AI): achar peça, ver andamento do pedido, adicionar ao carrinho, ver opções de entrega, achar favoritos. Medir sucesso, caminho e tempo.

---

## 5. Produto e experiência

### 5.1 Personas e jornada atualizadas — **FEITO**
`docs/PRD.md` §3 (personas) e §6 (jornadas de compra e favoritos) estão alinhados ao estado atual do código. Resumo na história do portfólio.

### 5.2 Microinterações — **PARCIAL**
- **Confirmação:** FEITO — toast acessível (`role="region"` + `aria-live` polite/assertive) e badge do carrinho.
- **Estado vazio:** FEITO — favoritos ("Nenhum favorito ainda"), carrinho ("Seu carrinho está vazio"), painel ("Você ainda não tem pedidos.").
- **404 amigável:** FEITO — `templates/erro.html` com código 404 decorativo, explicação e dois caminhos de volta.
- **Carregamento:** A EXECUTAR — não há indicador de loading nas ações assíncronas do carrinho (ver H1).

### 5.3 Responsividade com toque ≥ 44px — **FEITO**
Testado em 360, 390, 764 e 1264px sem rolagem horizontal. Alvos de toque com `--touch-target: 2.75rem` (44px); links de pedido no painel com área clicável de 44px após a correção.

### 5.4 Linguagem clara — **PARCIAL**
Interface em pt-BR, textos diretos. Pontos a revisar (H2/H10): sigla "UNIMA", "frete a combinar". Requer validação com usuário (a executar).

---

## 6. Formato

### 6.1 Portfólio de UX único — **FEITO**
[`PORTFOLIO-UX.md`](PORTFOLIO-UX.md): problema, público, decisões, evidências e próximos passos, com links para os demais documentos.

### 6.2 Changelog desde a 2ª avaliação — **FEITO**
[`CHANGELOG.md`](CHANGELOG.md), a partir de `git log` desde `931e4a1` e dos ADRs em `docs/DECISOES.md`.

### 6.3 Apresentação com uma pergunta por aluno — **A EXECUTAR**
Estrutura pronta (abaixo); as perguntas são de cada integrante e só valem quando escritas por ele.

**Roteiro da apresentação (10–12 min):**
1. Uma frase de problema e público (1 min).
2. Demo da compra ponta a ponta (3 min).
3. Evidências: axe antes/depois, zoom 200%, contraste (3 min).
4. Decisões de design e o que mudou desde a 2ª av (2 min).
5. **Uma pergunta por aluno** (1–2 min): cada integrante levanta uma dúvida aberta do projeto para a turma.

> **Perguntas de exemplo (modelo, não respostas):** "Catálogo na home ou home + vitrine — o que reduz mais o tempo até a peça?" · "Qual microcopy substitui 'UNIMA'?" · "Vale mostrar preço de frete mesmo sem cálculo real?" — cada aluno deve trazer a sua.

---

## Resumo

| Exigência | Status |
| --- | --- |
| Heurística cruzada (Nielsen) | A EXECUTAR (autoavaliação preliminar feita) |
| Teste A/B | A EXECUTAR |
| Teste de 5 segundos | A EXECUTAR |
| Gravação/prints de teste | A EXECUTAR |
| axe antes/depois | **FEITO** |
| Leitor de tela | A EXECUTAR |
| Zoom 200% | **FEITO** |
| Formulários acessíveis | FEITO (código) + A EXECUTAR (manual) |
| Daltonismo | **FEITO** (simulação + não depende só de cor) |
| Design System (doc) | **FEITO** |
| Figma + coerência | A EXECUTAR |
| Card sorting / teste de árvore | A EXECUTAR |
| Mapa do site + fluxo | **FEITO** |
| Personas/jornada | **FEITO** |
| Microinterações | PARCIAL |
| Responsividade 44px | **FEITO** |
| Linguagem clara | PARCIAL |
| Portfólio + changelog | **FEITO** |
| Apresentação | A EXECUTAR |
