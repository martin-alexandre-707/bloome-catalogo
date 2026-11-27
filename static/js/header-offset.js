// Mantém a variável CSS --header-h com a altura REAL do cabeçalho sticky.
// Assim as âncoras internas (#catalogo-bloome, etc.) não caem atrás do
// header quando a navbar quebra em duas linhas (celular/tablet).
// Recalcula no resize, no load (fontes podem mudar a altura) e sempre que
// o próprio header mudar de tamanho.
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
