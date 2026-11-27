// Revela os blocos com [data-reveal] quando eles entram na tela,
// dando a sensação de "descida" animada ao rolar a página.
//
// Sem JS nada desaparece: as regras de esconder só valem depois que este
// script marca o <html> com .com-reveal — então o conteúdo continua
// acessível se o script falhar ou o navegador for antigo.
(function () {
    if (!('IntersectionObserver' in window)) return;

    const alvos = document.querySelectorAll('[data-reveal]');
    if (!alvos.length) return;

    document.documentElement.classList.add('com-reveal');

    const observador = new IntersectionObserver(
        (entradas) => {
            entradas.forEach((entrada) => {
                if (!entrada.isIntersecting) return;
                entrada.target.classList.add('is-visible');
                observador.unobserve(entrada.target);
            });
        },
        { threshold: 0.12, rootMargin: '0px 0px -60px 0px' }
    );

    alvos.forEach((alvo) => {
        // Cards da grade entram em cascata (limite de 8 para não demorar).
        alvo.querySelectorAll('.colecao__card').forEach((card, indice) => {
            card.style.setProperty('--reveal-delay', `${Math.min(indice, 7) * 70}ms`);
        });
        observador.observe(alvo);
    });
})();
