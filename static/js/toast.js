// Notificações (toast) do feedback de ação.
// Sucesso e informação somem sozinhos (6 s); erro fica até a pessoa fechar.
// O toast NÃO recebe foco automaticamente: quem lê a tela já é avisado pelo
// role="status"/"alert" do markup (WCAG 4.1.3, sem roubar foco — 3.2.1).
const DURACAO_SUCESSO = 6000;

document.querySelectorAll('[data-toast]').forEach((toast) => {
    const botao = toast.querySelector('[data-toast-fechar]');
    const someSozinho = toast.dataset.toastTipo !== 'erro';
    let temporizador = null;

    function fechar() {
        clearTimeout(temporizador);
        toast.classList.remove('is-visivel');
        toast.addEventListener('transitionend', () => toast.remove(), { once: true });
        // Fallback: com prefers-reduced-motion a transição é ~0 ms e o
        // transitionend pode não disparar; remove de qualquer jeito.
        setTimeout(() => toast.remove(), 400);
    }

    function iniciarContagem() {
        if (!someSozinho) return;
        clearTimeout(temporizador);
        temporizador = setTimeout(fechar, DURACAO_SUCESSO);
    }

    if (botao) botao.addEventListener('click', fechar);

    // Pausa a contagem enquanto o ponteiro/foco está sobre o toast, para
    // quem tem baixa visão ou usa teclado ter tempo de ler.
    toast.addEventListener('mouseenter', () => clearTimeout(temporizador));
    toast.addEventListener('mouseleave', iniciarContagem);
    toast.addEventListener('focusin', () => clearTimeout(temporizador));
    toast.addEventListener('focusout', iniciarContagem);

    // Próximo frame: entra animando (a transição é zerada em
    // prefers-reduced-motion pelo CSS global, então aparece direto).
    requestAnimationFrame(() => toast.classList.add('is-visivel'));
    iniciarContagem();
});
