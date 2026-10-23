# Entregáveis — 2ª Avaliação (UX/UI)

Esta pasta reúne tudo o que é entregue na avaliação. O código do protótipo fica na raiz do repositório; aqui está a documentação e a evidência visual.

## Conteúdo

| Arquivo | O que é |
| --- | --- |
| `Bloome-Documentacao-UX-UI-2AV.pdf` | **Documento principal.** 29 páginas: telas e navegabilidade, design system, acessibilidade WCAG, avaliação heurística, protocolo Think Aloud, matriz de iteração, arquitetura da informação, microcopy e roteiro de apresentação. |
| `relatorio.html` | Fonte editável do PDF. Alterou texto? Regenere o PDF a partir dele (veja abaixo). |
| `evidencias/` | 13 capturas do protótipo em execução: desktop 1440 px, tablet 768 px e mobile 390 px. |

## O que mudou no protótipo

Somente UI/UX. O backend ficou intocado.

| Arquivo | Alteração |
| --- | --- |
| `static/css/styles.css` | Reescrito: tokens, contraste AA, alvos de 44 px, estados de interação, animações, responsivo. |
| `templates/*.html` (9) | Apenas marcação: atalho "Pular para o conteúdo", `id`/`tabindex` no `<main>`, `preconnect` das fontes, `loading="lazy"` nas imagens. |
| `app.py`, `catalogo.py` | Nenhuma linha alterada. |
| Scripts inline existentes | Mantidos como estavam, sem adições. |

## Como rodar o protótipo

```bash
pip install -r requirements.txt
python app.py
# abrir http://127.0.0.1:5000
```

## Como regerar o PDF

Abra `relatorio.html` no Chrome ou Edge e use **Imprimir → Salvar como PDF** com:

- Tamanho do papel: **A4**
- Margens: **padrão**
- **Gráficos de fundo: ativado** (sem isso a capa sai branca)

O CSS do arquivo já define as quebras de página e o formato A4, então o resultado sai igual ao PDF entregue.
