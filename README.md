# Bloome — Catálogo

Catálogo online de joias e acessórios artesanais da **Bloome**, desenvolvido em HTML e CSS puros, com foco em **acessibilidade** (diretrizes WCAG 2.1).

## Como executar

O projeto não tem build nem dependências. Basta abrir o `index.html` no navegador:

```bash
# ou sirva localmente (opcional)
python -m http.server
```

## Páginas

| Página | Arquivo | Status |
| ------ | ------- | ------ |
| Início | `index.html` | Concluída |
| Produtos | `produtos.html` | Concluída |
| Sobre | `sobre.html` | Em desenvolvimento |
| Carrinho | `carrinho.html` | Em desenvolvimento |

## Tecnologias

- HTML5 semântico
- CSS3 (variáveis, Grid, media queries, `clamp()`)
- Sem frameworks e sem JavaScript

## Estrutura

```
bloome-catalogo/
├── index.html      # Página inicial (hero)
├── produtos.html   # Lista de produtos
├── sobre.html      # Página institucional
├── carrinho.html   # Carrinho de compras
├── styles.css      # Estilos globais
└── imgs/           # Imagens dos produtos
```

## Acessibilidade

O projeto foi construído seguindo as boas práticas do [WCAG 2.1](https://www.w3.org/WAI/WCAG21/understanding/wcag/):

- **Idioma declarado**: `lang="pt-BR"` no `<html>` para leitores de tela.
- **HTML semântico**: uso de `header`, `nav`, `main`, `section` e `footer`.
- **Hierarquia de títulos**: um único `h1` por página e `h2` para o nome de cada produto.
- **Texto alternativo**: todas as imagens possuem `alt` descritivo (ex.: `alt="Cordão Olho Grego"`).
- **Navegação por teclado**: foco visível via `:focus-visible` com `outline` em links de menu, botões e links do rodapé.
- **Contraste de cores**: parâmetros de cor com contraste validado de pelo menos 4,5:1 entre texto e fundo.
- **Responsivo**: `meta viewport` e media queries — abaixo de 700px a grade de produtos vira coluna única.
- **Tipografia fluida**: `clamp()` nos títulos da página inicial para se adaptarem ao tamanho da tela.
- **Links seguros**: `rel="noopener"` em links externos abertos em nova aba.

## Equipe

- **Victor Xavier** — [GitHub](https://github.com/victorxavier01) · [LinkedIn](https://www.linkedin.com/in/victor-xavier-89a339378/)
- **Martin Alexandre** — [GitHub](https://github.com/martin-alexandre-707)
- **Anthonio Fon** — [LinkedIn](https://www.linkedin.com/in/anthonio-pontes-fon-4a25a6319/)
