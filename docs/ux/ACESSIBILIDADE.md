# Acessibilidade — Bloome

Registro do que foi **medido de verdade** e do que ainda depende de pessoa/ferramenta externa.

Data: 2026-11-27 · Equipe Bloome.
Critério de referência: **WCAG 2.1 nível AA**.

> Regra: "executado" só aparece com método e resultado registrados. O resto é **a executar**, com roteiro — sem resultado fabricado.

---

## 1. Método e ferramenta

- **Ferramenta automática:** axe-core **4.10.2**.
- **Viewport:** 360×780 (mobile).
- **Tags:** `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`.
- **Páginas:** 9 — `/`, `/produtos/cordao-coracao`, `/carrinho`, `/checkout`, `/favoritos`, `/painel`, `/conta`, `/sobre` e a 404.
- **Também verificado:** rolagem horizontal (overflow) e exceções de JavaScript.
- **Complementos executados:** zoom 200% (CDP), contraste recalculado, simulação de daltonismo.

Ferramenta automática cobre só parte dos critérios (estima-se ~30–40%); por isso há testes manuais abaixo.

---

## 2. Antes / depois por página (axe-core)

**Antes da correção:**

| Página | Violação axe | Severidade |
| --- | --- | --- |
| Páginas com link ativo no menu (`aria-current`) — total de **3 ocorrências** | `color-contrast` no link ativo | séria |
| `/painel` | alvos de toque de **83×24px** nos códigos de pedido | séria |
| Formulários (radios) | 4 inputs radio **20×20px** — porém cada um **dentro de um `<label>` de 44px** | (não contava como falha isolada) |
| Todas | overflow horizontal: **0** | — |

> O export bruto por página do "antes" não foi preservado individualmente; o que ficou registrado é o agregado acima.

**Depois da correção:**

| Página | Violações | Overflow horizontal | Exceções JS |
| --- | --- | --- | --- |
| `/` | 0 | 0 | 0 |
| `/produtos/cordao-coracao` | 0 | 0 | 0 |
| `/carrinho` | 0 | 0 | 0 |
| `/checkout` | 0 | 0 | 0 |
| `/favoritos` | 0 | 0 | 0 |
| `/painel` | 0 | 0 | 0 |
| `/conta` | 0 | 0 | 0 |
| `/sobre` | 0 | 0 | 0 |
| 404 | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** |

Correções aplicadas:
- Contraste do link ativo do menu elevado para ≥ 4,5:1 (ver §3).
- Códigos de pedido do painel passaram a ter **área clicável de 44px**.

---

## 3. Contraste

Recalculado sobre as cores reais:

| Combinação | Razão | Mínimo AA | Situação |
| --- | --- | --- | --- |
| Creme `#e8dedc` sobre `#874755` (menu ativo) | **5,20:1** | 4,5:1 | passa |
| Creme `#e8dedc` sobre `#82404f` (menu hover) | **5,69:1** | 4,5:1 | passa |
| Vinho `#772e3f` sobre rosa-claro `#e0aeb6` (botão) | **4,85:1** | 4,5:1 | passa |
| Creme `#e8dedc` sobre vinho `#772e3f` (cabeçalho) | 7,08:1 | 4,5:1 | passa |
| Mauve `#6f4c52` sobre creme (corpo) | 5,62:1 | 4,5:1 | passa |
| Taupe `#6b5b4b` sobre creme (secundário) | 4,94:1 | 4,5:1 | passa |

Ver a paleta completa em [`DESIGN-SYSTEM.md`](DESIGN-SYSTEM.md) §1.

---

## 4. Alvos de toque (≥ 44px) — FEITO

- Token `--touch-target: 2.75rem` (44px) aplicado como `min-height`/`min-width` em botões e links de menu.
- Códigos de pedido do painel: área clicável de **44px** após correção.
- Radios 20×20 ficam dentro de `<label>` de 44px, então a área efetiva de toque é o label inteiro.

---

## 5. Zoom 200% — FEITO

- **Método:** emulação de viewport **640×450** com `deviceScaleFactor: 2` via Chrome DevTools Protocol (equivale a 1280×900 com zoom 2×).
- **Páginas:** `/`, `/produtos/cordao-coracao`, `/carrinho`, `/checkout`, `/painel`, `/favoritos`, `/conta`, `/sobre`.
- **Resultado:** **0** rolagem horizontal · **0** elementos de texto com corte (`overflow:hidden` com conteúdo excedente) · **0** exceções de JS.

---

## 6. Leitor de tela — A EXECUTAR

Requisito: validar com **NVDA** (Windows + Firefox/Chrome) e/ou **VoiceOver** (macOS/iOS + Safari). Ainda não executado.

### 6.1 Tarefas observadas
1. Ler o cabeçalho e o menu principal.
2. Chegar ao catálogo e abrir a peça "Cordão Coração".
3. Favoritar a peça (logado).
4. Adicionar ao carrinho e ouvir o toast de confirmação.
5. Ajustar a quantidade no carrinho.
6. Concluir o checkout.

### 6.2 Por tarefa, verificar
- O elemento é anunciado com **nome, papel e estado** (ex.: "Adicionar aos favoritos, botão, não pressionado").
- O **toast** é lido (`aria-live`): "polite" no sucesso, "assertive" no erro.
- A **badge do carrinho** não é lida em dobro (é `aria-hidden`; a contagem vem do `aria-label`).
- O **foco** não se perde após navegação; o skip link ("Pular para o conteúdo") funciona no primeiro Tab.
- O **foco** é sempre visível.

### 6.3 Formulários (erro anunciado)
- Submeter o cadastro com e-mail inválido e senha curta.
- Verificar se o erro é anunciado: `.form-field__aviso` tem `role="alert"` e há texto "Verifique este campo antes de continuar.".
- Confirmar que a mensagem **não depende só de cor** (há texto, não só borda vermelha).

### 6.4 Critério de aprovação
Todas as tarefas concluíveis só com o leitor, com os anúncios acima. Divergências viram itens de correção com `arquivo:linha`.

---

## 7. Daltonismo — FEITO (simulação) + observação

- **Simulação:** deuteranopia aplicada à página do produto por matriz de cor (`feColorMatrix`).
- **Evidência:** [`evidencias/daltonismo-produto.png`](evidencias/daltonismo-produto.png).
- **Observação de design:** o **nome da cor é texto visível ao lado da bolinha** de seleção; a escolha não depende só da cor — atende ao critério 1.4.1 (Uso de cor).

### Roteiro (se quiser testar com pessoas daltônicas — a executar)
- 3–5 participantes com diferentes tipos de daltonismo.
- Tarefa: escolher a cor "vinho" de uma peça e adicionar ao carrinho.
- Pergunta: "Como você sabe qual cor está selecionada?".
- Critério: identificam a cor sem depender só do matiz.

---

## 8. Resumo

| Item | Status |
| --- | --- |
| axe antes/depois (9 páginas) | **FEITO** — 0 violações depois |
| Contraste | **FEITO** — todos ≥ 4,5:1 |
| Alvos de toque 44px | **FEITO** |
| Zoom 200% | **FEITO** — 0 overflow, 0 corte, 0 erro JS |
| Formulários (código) | **FEITO** — label, `role="alert"`, texto além da cor |
| Formulários (manual com leitor) | A EXECUTAR |
| Leitor de tela NVDA/VoiceOver | A EXECUTAR |
| Daltonismo (simulação) | **FEITO** |
| Teste com pessoas daltônicas | A EXECUTAR (opcional) |
