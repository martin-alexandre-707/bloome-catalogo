// Modal de detalhes no catálogo: o card ou o botão "Visualizar" abre o
// <dialog> preenchido com o <template> do produto. O conteúdo é
// renderizado pelo servidor; o JS só copia e cuida do foco.
// Compartilhado por /produtos e /favoritos (parcial _modal-produto.html).
const modal = document.getElementById('modal-produto');
const conteudo = document.getElementById('conteudo-modal-produto');
const botaoFechar = modal.querySelector('.product-modal__close');
let ultimoGatilho = null;

function selecionarCores(scope) {
    // Bolinhas de cor: comportamento de rádio (uma cor por vez).
    // A escolhida vai para o input escondido id_variacao do formulário;
    // sem escolha, o input fica vazio e o servidor recusa com flash.
    const bolinhas = scope.querySelectorAll('.color-dot');
    const campoVariacao = scope.querySelector('input[name="id_variacao"]');
    bolinhas.forEach((bolinha) => {
        bolinha.addEventListener('click', () => {
            bolinhas.forEach((outra) => outra.setAttribute('aria-pressed', 'false'));
            bolinha.setAttribute('aria-pressed', 'true');
            campoVariacao.value = bolinha.dataset.idVariacao;
        });
    });
}

function abrirDetalhes(idProduto, gatilho) {
    const template = document.querySelector(
        'template[data-produto="' + idProduto + '"]'
    );
    conteudo.replaceChildren(template.content.cloneNode(true));
    selecionarCores(conteudo);
    configurarQuantidade(conteudo);

    ultimoGatilho = gatilho;
    modal.showModal();
    botaoFechar.focus();
}

function configurarQuantidade(scope) {
    // Mínimo 1 (quantidade 0 não existe numa compra) e sem teto:
    // a validação real de estoque é do backend no checkout
    // (verificar_estoque_carrinho — VALIDACAO-REGRAS.md §2).
    const valor = scope.querySelector('.qty__valor');
    if (!valor) return; // produtos "Em breve" não têm seletor

    const menos = scope.querySelector('[data-qty="menos"]');
    const mais = scope.querySelector('[data-qty="mais"]');
    const campoQuantidade = scope.querySelector('input[name="quantidade"]');

    function atualizar(novo) {
        const n = Math.max(1, novo);
        valor.textContent = n;
        campoQuantidade.value = n;
        menos.disabled = n <= 1;
    }

    menos.addEventListener('click', () => atualizar(+valor.textContent - 1));
    mais.addEventListener('click', () => atualizar(+valor.textContent + 1));
    atualizar(1);
}

document.querySelectorAll('[data-abrir-produto]').forEach((gatilho) => {
    gatilho.addEventListener('click', () => abrirDetalhes(
        gatilho.dataset.abrirProduto,
        gatilho
    ));
});

// O restante do card (nome, preço, descrição) também abre o modal.
// A via de teclado é o botão da foto, que tem aria-label.
// Funciona em qualquer card (classe .product ou .favorite): o
// gatilho aponta o <article> pai via closest.
// Links dentro do card (ex.: "Remover dos favoritos") mantêm o
// próprio comportamento e não abrem o modal.
const cardsVinculados = new Set();
document.querySelectorAll('[data-abrir-produto]').forEach((gatilho) => {
    const card = gatilho.closest('article');
    if (!card || cardsVinculados.has(card)) return;
    cardsVinculados.add(card);
    const botao = card.querySelector('[data-abrir-produto]');
    card.addEventListener('click', (evento) => {
        // Se o clique já caiu num botão com gatilho ou num link,
        // ele cuida de si
        if (evento.target.closest('a, [data-abrir-produto]')) return;
        abrirDetalhes(botao.dataset.abrirProduto, botao);
    });
});

botaoFechar.addEventListener('click', () => modal.close());

// Clique no fundo escuro (backdrop) também fecha
modal.addEventListener('click', (evento) => {
    if (evento.target === modal) modal.close();
});

// Ao fechar, o foco volta para o gatilho que abriu (WCAG 2.4.3)
modal.addEventListener('close', () => {
    if (ultimoGatilho) ultimoGatilho.focus();
});
