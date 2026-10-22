# Caeser Windows 2.0.0 — escopo e validação

A edição Windows recebe as funções aprovadas no Mac 3.0.0: prévia, correspondência Spotify → YouTube, fila persistente serial, histórico, preferências por origem e aviso de atualização. Mantidos Windows 10 22H2/11 x64, WinUI 3, ferramentas incluídas e a estrutura organizada do instalador.

## Design

Aplicada a skill Apple Design como princípios de organização, traduzidos para controles Windows. Preservados os tokens em `Themes/Caeser.xaml`: violeta #7445C4 para destaque; superfícies sem efeitos de vidro; texto 14 pt e apoio 13 pt; temas claro, escuro e alto contraste; logo original e seletor animado. Novos botões têm nomes acessíveis e controles nativos. A prévia aparece no formulário, a fila só aparece com itens e mantém rolagem limitada; histórico e atualização abrem diálogos com saída explícita. Referências: `layout.md › Visual hierarchy`, `accessibility.md › Vision`, `lists-and-tables.md › Content` e `liquid-glass.md › The two layers`.

## Verificações

O workflow Windows compila a aplicação autocontida, executa testes de lógica/processos, interage com o seletor por mouse, arraste, teclado e automação de acessibilidade, captura os temas claro e escuro e exercita os novos estados de prévia e fila. Os testes adicionais cobrem lote misto, URL Spotify fixada no comando de download, metadados ausentes, recuperação sem reinício automático e seleção numérica/segura da release Windows.

O empacotamento testa ferramentas reais, download de áudio gerado servido localmente, conversão MP3, aplicativo extraído em pasta com acento/espaço, instalação, abertura e desinstalação. Capturas do runner são evidência de renderização WinUI; não equivalem a um teste manual em cada computador com Windows 10/11.

A prévia de Spotify não faz login e pode demorar por limites externos. Coleções exibem seus metadados e resolvem as correspondências durante o download. O aviso consulta a API pública de releases; ignora Mac, fontes, rascunhos, pré-releases e versões sem instalador Windows x64 válido. Nenhum instalador é executado automaticamente. Para ganhar o aviso, versões antigas precisam instalar esta atualização uma vez.
