# Histórico — Mac 3.0.1 e Windows 2.0.1

Pequeno ajuste de apresentação, sem migração de dados ou mudança nos downloads.

Aplicada Apple Design: `sheets.md › Desktop (macOS)` orienta tamanho apropriado ao conteúdo; `layout.md › Visual hierarchy` orienta alinhamento e agrupamento; `lists-and-tables.md › Content` recomenda texto sucinto sem linhas exageradas. Mantidas as cores semânticas, fontes do sistema, identidade violeta e componentes nativos de cada plataforma. Julgamento de proporção: Mac com 600 pt de largura e altura limitada a 520 pt; Windows com conteúdo até 548 px e rolagem interna limitada à janela. Sem novas animações nem vidro nas linhas.

Mac: testes de proporções com 0, 1, 12 e 100 registros, títulos e erros longos, além da suíte de lógica existente. Revisão do aplicativo aberto com dados demonstrativos em domínio isolado `Caeser-UITests-…`, confirmação de limpeza cancelada e saída por Escape. O modo demonstrativo é exclusivo de Debug e não integra a distribuição Release.

Windows: teste da interface real inclui histórico vazio e preenchido em claro/escuro, com títulos e erros longos, além dos testes anteriores de seletor, teclado, prévia e fila. O empacotamento mantém teste de ferramentas, conversão real MP3, ZIP portátil e instalação/atualização/desinstalação no runner Windows. Não equivale a teste manual em cada PC Windows 10/11.

Prévia e downloads dependem dos serviços externos, sem mudança nessa atualização. Atualizações são oferecidas separadamente por plataforma e a instalação continua manual.
