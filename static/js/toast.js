const DURACAO_SUCESSO = 6000;

document.querySelectorAll('[data-toast]').forEach((toast) => {
    const botao = toast.querySelector('[data-toast-fechar]');
    const someSozinho = toast.dataset.toastTipo !== 'erro';
    let temporizador = null;

    function fechar() {
        clearTimeout(temporizador);
        toast.classList.remove('is-visivel');
        toast.addEventListener('transitionend', () => toast.remove(), { once: true });
        setTimeout(() => toast.remove(), 400);
    }

    function iniciarContagem() {
        if (!someSozinho) return;
        clearTimeout(temporizador);
        temporizador = setTimeout(fechar, DURACAO_SUCESSO);
    }

    if (botao) botao.addEventListener('click', fechar);

    toast.addEventListener('mouseenter', () => clearTimeout(temporizador));
    toast.addEventListener('mouseleave', iniciarContagem);
    toast.addEventListener('focusin', () => clearTimeout(temporizador));
    toast.addEventListener('focusout', iniciarContagem);

    requestAnimationFrame(() => toast.classList.add('is-visivel'));
    iniciarContagem();
});
