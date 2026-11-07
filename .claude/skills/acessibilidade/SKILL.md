---
name: acessibilidade
description: Audita acessibilidade e usabilidade do Bloome (WCAG 2.1 AA) nos templates Jinja e no CSS. Use antes e depois de alterar templates, CSS ou componentes de UI, ou antes de considerar uma página pronta.
---

# Acessibilidade e usabilidade — Bloome

## Quando usar

- Antes e depois de mexer em `templates/` ou `static/css/styles.css`.
- Antes de dizer que uma página ou entrega está pronta.
- Ao criar componente, formulário, modal (`<dialog>`), menu ou mensagem de erro.

## O que esta skill cobre

- Violações que dá para detectar no código (HTML/Jinja/CSS).
- Checklist WCAG 2.1 AA + usabilidade (heurísticas de Nielsen) aplicável ao projeto.
- O que precisa de teste humano (leitor de tela, zoom, daltonismo, usuários).

## Fora de escopo

Não use esta skill para: formato de entrega, notas/pesos, relatórios,
apresentação, changelog, portfólio, Figma/protótipo, card sorting, teste A/B,
teste de 5 segundos, tree testing, personas/jornada. Isso é pesquisa ou entrega,
não auditoria de código.

## Checklist

### 1. Estrutura e semântica

- [ ] `<html lang="pt-BR">` (WCAG 3.1.1)
- [ ] Um `<h1>` por página; níveis de título sem pular (1.3.1)
- [ ] Landmarks: `<header>`, `<nav>`, `<main>`, `<footer>`; um `<main>` por página (1.3.1)
- [ ] Menu com `aria-current="page"` no item ativo
- [ ] `<button>` para ação e `<a>` para navegação (4.1.2)
- [ ] Links com texto compreensível fora de contexto; evitar "clique aqui" (2.4.4)
- [ ] Skip link para o conteúdo principal, se o menu for longo (2.4.1)

### 2. Imagens e conteúdo

- [ ] Toda `<img>` tem `alt`; decorativa usa `alt=""` (1.1.1)
- [ ] Texto essencial não está dentro de imagem
- [ ] Ícone com significado tem nome acessível; decorativo tem `aria-hidden="true"`
- [ ] Nenhuma informação depende só de cor (1.4.1)

### 3. Contraste, zoom e reflow

- [ ] Texto normal ≥ 4,5:1; texto grande (≥ 24px ou 19px negrito) ≥ 3:1 (1.4.3)
- [ ] Bordas, ícones e foco ≥ 3:1 contra o fundo (1.4.11)
- [ ] Zoom 200% sem cortar ou sobrepor conteúdo (1.4.4) — teste humano
- [ ] Largura de 320px sem scroll horizontal (1.4.10)
- [ ] Espaçamento de texto (1.4.12) não quebra o layout

### 4. Teclado e foco

- [ ] Tudo que é clicável é alcançável e operável por teclado (2.1.1)
- [ ] `:focus-visible` visível em todos os interativos (2.4.7)
- [ ] Ordem de foco acompanha a ordem visual (2.4.3)
- [ ] Sem armadilha de foco; `<dialog>` prende o foco e devolve ao abrir/fechar (2.1.2)
- [ ] `Esc` fecha o `<dialog>`; foco volta ao gatilho
- [ ] Nenhum `outline: none` sem substituto visível

### 5. Formulários

- [ ] Todo campo tem `<label for="...">` ligado ao `id` (1.3.1/3.3.2)
- [ ] Erro identificado em texto, não só por cor/borda (3.3.1)
- [ ] Mensagem de erro diz como corrigir (3.3.3)
- [ ] Obrigatório indicado em texto, não só com asterisco/cor
- [ ] `autocomplete` quando fizer sentido (1.3.5)
- [ ] Dica/erro ligados por `aria-describedby`; erro com `aria-invalid="true"`
- [ ] Não pedir a mesma informação duas vezes (3.3.4)

### 6. Componentes e estados

- [ ] Botão, input, card e alerta têm: normal, hover, foco, desabilitado, erro, sucesso
- [ ] Desabilitado continua legível (não só opacidade baixa)
- [ ] Mensagem dinâmica anunciada com `role="alert"` ou `aria-live` (4.1.3)
- [ ] Loading e confirmação comunicados em texto
- [ ] Estado vazio tem mensagem clara e próximo passo
- [ ] 404 amigável com caminho de volta

### 7. Toque e responsivo

- [ ] Alvo de toque ≥ 44×44 px (2.5.5)
- [ ] Sem scroll horizontal em 320px
- [ ] Texto legível sem zoom forçado

### 8. Usabilidade (Nielsen) verificável no código

- [ ] Status do sistema visível: loading, sucesso, erro (#1)
- [ ] Consistência: mesmo componente/ação usa o mesmo padrão (#4)
- [ ] Prevenção de erro: confirmação em ação destrutiva (#5)
- [ ] Reconhecer em vez de lembrar: contexto visível, sem exigir memória (#6)
- [ ] Erro reconhecível e com solução; não só "algo deu errado" (#9)
- [ ] Ajuda contextual em campos complexos (#10)
- [ ] Linguagem clara, pt-BR, sem jargão técnico (#2)

## Procedimento

1. Leia `templates/base.html` e a página alvo.
2. Rode os comandos abaixo e inspecione o CSS relacionado.
3. Confirme cada achado no `arquivo:linha` — não reporte suspeita como fato.
4. Classifique: **bloqueia** (impede a tarefa), **atrapalha**, **cosmético**.
5. Separe o que exige teste humano e diga "não testei" quando for o caso.

## Comandos de verificação

Use a ferramenta **Grep** (não bash): cada padrão abaixo vira o campo
`pattern`, com `output_mode: "content"` e `-n: true`. Se estiver no terminal,
os mesmos padrões funcionam em bash.

```bash
# idioma e estrutura
grep -n '<html' templates/base.html
grep -rn '<main' templates/
grep -rn 'aria-current' templates/

# imagens sem alt (confirme manualmente tags quebradas em várias linhas)
grep -rn '<img' templates/ | grep -v 'alt='

# um h1 por template
for f in templates/*.html; do printf '%s: ' "$f"; grep -o '<h1' "$f" | wc -l; done

# formulários
grep -rn '<input' templates/
grep -rn '<label' templates/

# links genéricos
grep -rniE '>(clique aqui|saiba mais|leia mais|aqui)<' templates/

# foco visível
grep -n 'focus-visible\|:focus' static/css/styles.css

# dialog
grep -rn '<dialog' templates/
```

Para contraste: extraia os pares de cor (texto/fundo) do CSS e calcule a razão.
Se não conseguir calcular com segurança, marque como **teste humano**.

## Formato do retorno

```text
Achados:
- templates/produtos.html:42 — <img> sem alt — 1.1.1 — adicionar alt com o nome do produto
- static/css/styles.css:310 — :focus sem outline — 2.4.7 — adicionar outline: 2px solid + offset

Exige teste humano (não testei):
- Leitor de tela (NVDA/VoiceOver) na tarefa de finalizar compra
- Zoom 200% na home
- Simulação de daltonismo nos alertas de erro
```

## Regras

- Não invente violação sem evidência (`arquivo:linha`).
- Não reescreva `styles.css` inteiro; proponha o trecho mínimo.
- Não altere lógica de negócio nem cálculo de dinheiro (isso fica no backend).
- Se algo só pode ser verificado com ferramenta ou olho humano, diga "não testei".
- Se houver Lighthouse/axe disponíveis, rodar é opcional; WAVE é manual no navegador.
