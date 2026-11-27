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
        alvo.querySelectorAll('.colecao__card').forEach((card, indice) => {
            card.style.setProperty('--reveal-delay', `${Math.min(indice, 7) * 70}ms`);
        });
        observador.observe(alvo);
    });
})();
