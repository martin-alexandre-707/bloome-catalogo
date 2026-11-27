const modal = document.getElementById('modal-produto');
const conteudo = document.getElementById('conteudo-modal-produto');
const botaoFechar = modal.querySelector('.product-modal__close');
let ultimoGatilho = null;

function selecionarCores(scope) {
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
    const valor = scope.querySelector('.qty__valor');
    if (!valor) return;

    const menos = scope.querySelector('[data-qty="menos"]');
    const mais = scope.querySelector('[data-qty="mais"]');
    const campoQuantidade = scope.querySelector('input[name="quantidade"]');

    function atualizar(novo) {
        const n = Math.min(99, Math.max(1, novo));
        valor.textContent = n;
        campoQuantidade.value = n;
        menos.disabled = n <= 1;
        mais.disabled = n >= 99;
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

const cardsVinculados = new Set();
document.querySelectorAll('[data-abrir-produto]').forEach((gatilho) => {
    const card = gatilho.closest('article');
    if (!card || cardsVinculados.has(card)) return;
    cardsVinculados.add(card);
    const botao = card.querySelector('[data-abrir-produto]');
    card.addEventListener('click', (evento) => {
        if (evento.target.closest('a, [data-abrir-produto]')) return;
        abrirDetalhes(botao.dataset.abrirProduto, botao);
    });
});

botaoFechar.addEventListener('click', () => modal.close());

modal.addEventListener('click', (evento) => {
    if (evento.target === modal) modal.close();
});

modal.addEventListener('close', () => {
    if (ultimoGatilho) ultimoGatilho.focus();
});
