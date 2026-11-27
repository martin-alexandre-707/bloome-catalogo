const cabecalho = document.querySelector('.site-header');

if (cabecalho) {
    const aplicarAltura = () => {
        document.documentElement.style.setProperty(
            '--header-h',
            cabecalho.offsetHeight + 'px'
        );
    };

    aplicarAltura();
    window.addEventListener('resize', aplicarAltura);
    window.addEventListener('load', aplicarAltura);

    if ('ResizeObserver' in window) {
        new ResizeObserver(aplicarAltura).observe(cabecalho);
    }
}
