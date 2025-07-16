// siga_erp/static/js/script.js

// Este arquivo pode ser usado para adicionar funcionalidades JavaScript
// ao seu aplicativo Flask.

document.addEventListener('DOMContentLoaded', function() {
    // Exemplo de script: Adicionar um efeito de hover a elementos da tabela
    const tableRows = document.querySelectorAll('tbody tr');

    tableRows.forEach(row => {
        row.addEventListener('mouseenter', () => {
            row.style.backgroundColor = '#f3f4f6'; // Cor de fundo ao passar o mouse
        });
        row.addEventListener('mouseleave', () => {
            row.style.backgroundColor = ''; // Remove a cor de fundo
        });
    });

    // Você pode adicionar scripts para validação de formulário,
    // interações dinâmicas, etc.
});