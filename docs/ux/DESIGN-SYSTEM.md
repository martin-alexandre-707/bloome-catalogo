# Design System — Bloome

Extraído dos tokens reais em `static/css/styles.css` (`:root`). Este documento descreve **o que existe no código hoje**; o que não existe está marcado como **falta / a executar**. Não inventamos peças de Figma.

Fonte: `static/css/styles.css:35-120` (tokens), seções de componentes ao longo do arquivo.

---

## 1. Paleta

### 1.1 Cores de marca e semânticas

| Token | Hex | Papel | Contraste (texto) |
| --- | --- | --- | --- |
| `--color-wine` | `#772e3f` | Cor primária; texto forte; fundo do cabeçalho | **9,35:1** no branco · **7,08:1** no creme |
| `--color-wine-deep` | `#5e1f2e` | Hover/active de botão; rodapé | **9,30:1** no creme |
| `--color-rose` | `#b98e98` | Reserva da paleta (**não textual**) | — |
| `--color-rose-light` | `#e0aeb6` | Fundo do botão; borda de input | vinho sobre ela: **4,85:1** |
| `--color-rose-deep` | `#7d4351` | Apoio | **5,70:1** no creme |
| `--color-mauve` | `#6f4c52` | **Texto padrão do corpo** | **5,62:1** no creme |
| `--color-cream` | `#e8dedc` | Fundo da página; texto sobre vinho | — |
| `--color-taupe` | `#6b5b4b` | Texto secundário/placeholder | **4,94:1** no creme · **6,52:1** no branco |
| `--color-tan` | `#967156` | Reserva da paleta (**não textual**) | — |
| `--color-bg` | `#e8dedc` (creme) | Fundo geral | — |
| `--color-surface` | `#ffffff` | Cartões e formulários | — |
| `--color-surface-sunken` | `#f4eceb` | Botão desabilitado; fundos rebaixados | — |
| `--color-text` | `#6f4c52` (mauve) | Texto padrão | 5,62:1 no creme |
| `--color-text-strong` | `#772e3f` (wine) | Títulos e destaques | 7,08:1 no creme |
| `--color-text-muted` | `#6b5b4b` (taupe) | Texto secundário | 4,94:1 no creme |
| `--color-border` | `rgba(119,46,63,.12)` | Borda de cartão | — |
| `--color-border-strong` | `rgba(119,46,63,.28)` | Borda reforçada | — |
| `--color-danger` | `#8f2a3c` | Erro | **8,19:1** no branco · **6,21:1** no creme |
| `--color-success` | `#2a5f46` | Sucesso | **7,44:1** no branco · **5,64:1** no creme |

### 1.2 Contraste do link ativo do menu (correção da 3ª av)

O item de menu com `aria-current="page"` usa creme sobre vinho clareado por um véu de creme:

| Estado | Fundo composto | Contraste com creme `#e8dedc` |
| --- | --- | --- |
| Hover (véu creme 10%) | `#82404f` | **5,69:1** |
| Ativo `aria-current` (véu creme 14%) | `#874755` | **5,20:1** |

Todos acima de 4,5:1 (WCAG 2.1 AA para texto normal).

### 1.3 Foco

| Token | Valor | Papel |
| --- | --- | --- |
| `--focus-width` | `3px` | Espessura do contorno de foco |
| `--focus-offset` | `3px` | Distância do foco |
| `--focus-color` | vinho `#772e3f` | Foco em fundo claro |
| `--focus-color-inverse` | creme `#e8dedc` | Foco em cabeçalho/rodapé/hero (fundo escuro) |

---

## 2. Tipografia

### 2.1 Famílias

| Token | Fonte | Uso |
| --- | --- | --- |
| `--font-body` | Lato + pilha de sistema | Todo o texto funcional (100% sem serifa) |
| `--font-display` | Playfair Display (serifa) | Display de marca (títulos) |
| `--font-script` | Playball (script) | Assinatura/decoração de marca |

### 2.2 Escala

| Token | rem | px | Uso típico |
| --- | --- | --- | --- |
| `--text-xs` | 0.75rem | 12 | Legendas, `::after` de validação |
| `--text-sm` | 0.875rem | 14 | Labels, texto secundário |
| `--text-base` | 1rem | 16 | Corpo (mínimo para evitar zoom no iOS) |
| `--text-lg` | 1.125rem | 18 | Destaques |
| `--text-xl` | 1.375rem | 22 | Subtítulos |
| `--text-2xl` | 1.75rem | 28 | Títulos de seção |
| `--text-3xl` | 2.25rem | 36 | Título grande / hero |

### 2.3 Entrelinha e pesos

| Token | Valor |
| --- | --- |
| `--leading-tight` / `snug` / `normal` / `relaxed` | 1.25 / 1.4 / 1.5 / 1.7 |
| `--weight-regular` / `semibold` / `bold` | 400 / 600 / 700 |

---

## 3. Espaçamento

Base 4px, ritmo de 8px (`static/css/styles.css:83-94`).

| Token | rem | px |
| --- | --- | --- |
| `--space-1` | 0.25 | 4 |
| `--space-2` | 0.5 | 8 |
| `--space-3` | 0.75 | 12 |
| `--space-4` | 1 | 16 |
| `--space-5` | 1.25 | 20 |
| `--space-6` | 1.5 | 24 |
| `--space-8` | 2 | 32 |
| `--space-10` | 2.5 | 40 |
| `--space-12` | 3 | 48 |
| `--space-16` | 4 | 64 |
| `--space-20` | 5 | 80 |

**Grid:** `--container` 1100px · `--container-narrow` 900px · `--container-text` 800px · `--gutter` 1.5rem.

---

## 4. Forma, elevação e movimento

### 4.1 Raios
| Token | Valor |
| --- | --- |
| `--radius-sm` | 0.5rem (8px) |
| `--radius-md` | 0.75rem (12px) |
| `--radius-lg` | 1rem (16px) |
| `--radius-full` | 999px (pílula) |

### 4.2 Sombras
| Token | Valor |
| --- | --- |
| `--shadow-1` | `0 2px 10px rgba(119,46,63,.08)` |
| `--shadow-2` | `0 4px 14px rgba(119,46,63,.12)` |
| `--shadow-3` | `0 8px 22px rgba(119,46,63,.20)` |
| `--shadow-4` | `0 14px 30px rgba(119,46,63,.24)` |

### 4.3 Movimento
| Token | Valor |
| --- | --- |
| `--dur-fast` / `base` / `slow` | 120ms / 200ms / 320ms |
| `--ease` | `cubic-bezier(0.2, 0, 0, 1)` |
| `--ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` |

Todas as animações têm fallback em `@media (prefers-reduced-motion: reduce)` (desliga `transform`/zoom).

### 4.4 Toque
`--touch-target: 2.75rem` (**44px**) — área de toque mínima, aplicada como `min-height`/`min-width` nos botões e links de menu.

---

## 5. Componentes

Para cada componente: classes reais no CSS e estados **implementados** (comprovados no código).

### 5.1 Botão — `.btn`
`styles.css:763`
- **Normal:** fundo `--color-rose-light`, texto vinho, raio pílula, `min-height` 44px.
- **Hover:** fundo creme, `--shadow-1`, `translateY(-2px)`.
- **Active:** fundo `--color-wine-deep`, texto creme, `translateY(1px)`.
- **Foco:** `:focus-visible` com anel duplo (creme + vinho), `--focus-width`.
- **Desabilitado:** `[aria-disabled="true"]` / `:disabled` — fundo rebaixado, texto mudo, `cursor: not-allowed`, `pointer-events: none`.
- **Reduced motion:** hover sem `transform`.

### 5.2 Campo de formulário — `.form-field`
`styles.css:1611`
- Estrutura: `label` + `input[type=text|tel|email|password]` + `.form-field__aviso` (`role="alert"`).
- **Normal:** borda `--color-rose-light`, raio `--radius-sm`, `font-size` 16px, `min-height` 44px.
- **Foco:** borda vinho (`:focus-visible`).
- **Erro:** `:user-invalid` → borda 2px `--color-danger` + texto "Verifique este campo antes de continuar." (não depende só de cor).
- **Válido:** `:user-valid:not(:focus)` → borda `--color-success` + "Campo válido.".
- **Placeholder:** `--color-taupe` com `opacity: 1` (contraste).
- **Desabilitado:** não estilizado explicitamente (**falta** um estado `:disabled` documentado para input).

### 5.3 Card de produto — `.product`
`styles.css:850` (e `.favorite` 997)
- **Normal:** superfície branca, borda, raio.
- **Hover / focus-within:** `translateY(-8px)` + sombra reforçada + zoom `1.05` na foto (`transform: scale`), recortado no raio do cartão.
- **Active:** afunda ~1px.
- **Foco:** `:focus-visible` igual ao hover (anel visível).
- **Reduced motion:** desliga `transform`/zoom.
- **Foto:** `.product__image` com recorte (`overflow` no contêiner).
- **Tag:** `.product__tag` (rótulo de catálogo/estado).

### 5.4 Alerta/Notificação — `.toast`
`styles.css:3151`
- Contêiner: `.toast-region` (`role="region" aria-label="Notificações"`).
- Item: `.toast`, variantes `.toast--sucesso`, `.toast--erro`, `.toast--info`.
- `aria-live="polite"` para sucesso/info, `"assertive"` para erro.
- **Entrada/saída:** `.is-visivel` anima via JS; sem JS nasce visível; `prefers-reduced-motion` desliga o transform.
- **Botão fechar:** `.toast__close` com `aria-label="Fechar notificação"` e foco visível.
- **Falta:** variante de "aviso/warning" (só há sucesso/erro/info).

### 5.5 Estado vazio — `.estado-vazio`
`styles.css:3475`
- Ícone SVG `aria-hidden`, título `.estado-vazio__titulo`, texto `.estado-vazio__texto`.
- Usado em favoritos; carrinho e painel usam variantes próprias (`.cart__empty`, `.painel__vazio`).

### 5.6 Etapas do checkout — `.checkout__step`
`styles.css:1790`
- Lista ordenada `aria-label="Etapas do pedido"` com 3 passos (Entrega, Pagamento, Confirmação).
- **Atual:** `.is-atual` + `aria-current="step"`, número destacado.
- **Painel oculto:** `.checkout__panel[hidden]` (progressive enhancement: sem JS, tudo visível).
- **Erro:** `.checkout__erro` (`[hidden]` para esconder).

### 5.7 Navegação — `.navbar`
`styles.css:295`
- Link: `min-height`/`min-width` 44px, texto creme.
- **Hover:** véu creme 10%.
- **Ativo:** `[aria-current="page"]` véu 14% + traço rosa-claro decorativo (5,20:1).
- **Carrinho:** `.navbar__cart` (ícone SVG + badge `.navbar__cart-badge` `aria-hidden`; contagem por extenso no `aria-label`).
- **Usuário logado:** `.navbar__user-box` com nome → painel e "Sair".
- **Skip link:** `.skip-link` (`Pular para o conteúdo`).

### 5.8 Modal — `<dialog>`
- **Modal de produto:** **aposentado** (ADR-033) — o card leva à página da peça. `templates/_modal-produto.html` ainda existe no repositório, mas o fluxo atual não depende dele.
- **Modal de confirmação do checkout:** `.checkout-modal` (`styles.css:1515`), com `::backdrop`, ícone, título, mensagem e botão.

### 5.9 Página de erro — `.error__*`
`styles.css:2841` — `.error__code` (404 decorativo `aria-hidden`), `.error__actions`, `.error__link`.

---

## 6. O que existe x o que falta

| Item | No código | No Figma |
| --- | --- | --- |
| Paleta + contrastes | **Existe** (`:root`) | **Falta** |
| Escala tipográfica | **Existe** | **Falta** |
| Espaçamentos/raios/sombras | **Existe** | **Falta** |
| Botão com 6 estados | **Existe** | **Falta** |
| Input com erro/válido | **Existe** | **Falta** |
| Card com hover/foco | **Existe** | **Falta** |
| Toast (3 variantes) | **Existe** | **Falta** |
| Estado vazio | **Existe** | **Falta** |
| Biblioteca Figma | — | **A EXECUTAR** |
| Tokens exportáveis (JSON/`@property`) | **Falta** (hoje só CSS vars) | — |

**Próximo passo:** criar o arquivo Figma espelhando a seção 1–4 deste documento e então comparar componente a componente (coerência Figma↔código).
