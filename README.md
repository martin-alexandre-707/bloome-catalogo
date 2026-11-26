# Bloome — Catálogo

Catálogo online de joias e acessórios artesanais da **Bloome**, desenvolvido em HTML e CSS puros, com foco em **acessibilidade** (diretrizes WCAG 2.1).

## Como executar

O catálogo é um app **Flask** com templates Jinja. Não abra `templates/*.html`
direto no navegador — eles só renderizam pelo Flask.

```bash
pip install -r requirements.txt
python app.py          # http://127.0.0.1:5000
```

**O banco é obrigatório.** Copie `.env.example` para `.env` e preencha
`SECRET_KEY` e `DATABASE_URL` (Supabase). Sem isso o app **não inicia** — não
existe modo demonstração; toda leitura vai ao banco.

Toda tela nova lê dados por `dados.py`, nunca direto no template.

## Páginas

| Página | Arquivo | Status |
| ------ | ------- | ------ |
| Início | `index.html` | Concluída |
| Produtos | `produtos.html` | Concluída |
| Sobre | `sobre.html` | Concluída |
| Carrinho | `carrinho.html` | Concluída |

## Tecnologias

- HTML5 semântico
- CSS3 (variáveis, Grid, Flexbox, media queries, `clamp()`)
- Sem frameworks e sem JavaScript

## Estrutura

```
bloome-catalogo-main/
├── app.py           # Rotas Flask
├── dados.py         # Fonte de dados: consultas ao Supabase
├── db.py            # Conexão psycopg com o banco
├── db/              # SQL versionado (schema, funções, views, seed, testes)
├── templates/       # Jinja: base, index, produtos, produto, carrinho, conta...
├── static/          # CSS, JS e imagens (static/imgs/)
└── docs/            # Regras, decisões (ADR) e estado do projeto
```

## Acessibilidade

O projeto foi construído seguindo as diretrizes e boas práticas da [WCAG 2.1](https://www.w3.org/WAI/WCAG21/understanding/wcag/) (nível AA):

- **Idioma declarado**: `lang="pt-BR"` na tag `<html>` de todas as páginas para correta pronúncia em leitores de tela.
- **HTML semântico**: estruturação com `header`, `nav`, `main`, `section`, `article`, `aside` e `footer`.
- **Hierarquia de títulos**: fluxo lógico de cabeçalhos (`h1` principal e `h2` para produtos e etapas).
- **Página ativa**: indicação programática da página atual no menu de navegação através de `aria-current="page"`.
- **Formulário acessível de checkout**: campos com `<label for="...">` associados, agrupamento semântico com `aria-labelledby`, inputs de rádio estilizados e integrados ao botão de finalização via atributo `form`.
- **Texto alternativo**: todas as imagens possuem atributo `alt` descritivo e objetivo.
- **Navegação por teclado**: indicador visual de foco em todos os elementos interativos via `:focus-visible` com espaçamento (`outline-offset`).
- **Contraste de cores**: taxas de contraste verificadas e superiores a 4,5:1 (incluindo rodapé e botões com foco).
- **Identificação consistente (WCAG SC 3.2.4)**: padronização de descrições e `aria-label` para links com o mesmo destino em todas as páginas.
- **Links seguros e acessíveis**: `target="_blank" rel="noopener"` com aviso sonoro/textual nos links externos que abrem em nova aba.
- **Design responsivo e tipografia fluida**: layout flexível e adaptável para desktop, tablets e smartphones usando CSS Grid, Flexbox e `clamp()`.

## Equipe

- **Victor Xavier** — [GitHub](https://github.com/victorxavier01) · [LinkedIn](https://www.linkedin.com/in/victor-xavier-89a339378/)
- **Martin Alexandre** — [GitHub](https://github.com/martin-alexandre-707) · [LinkedIn](https://www.linkedin.com/in/martin-alexandre-724451409/)
- **Anthonio Fon** — [GitHub](https://github.com/TonysXD) · [LinkedIn](https://www.linkedin.com/in/anthonio-pontes-fon-4a25a6319/)
