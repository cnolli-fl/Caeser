# Windows 2.3.0 — validação de 28/10/2026

Código validado: `1d7cd47abf66c5ca4196987b4e9083d1c04f7a02`.
[Execução Windows aprovada](https://github.com/cnolli-fl/Caeser/actions/runs/40755874879), pacote `Caeser-Windows-package-64`. Os ajustes posteriores são apenas de documentação.

## Interface e lógica

- 66 testes de lógica/processos aprovados, mais um teste separado de download/conversão com ferramentas reais empacotadas.
- Build WinUI autocontido x64 aprovado. Interface real aberta no runner, com 20 capturas: YouTube/Spotify, prévia, fila, histórico vazio/preenchido, atualização e novidades em ambas as bases de tema.
- Conferidas troca por clique/arraste/teclado, movimento reduzido, foco visível, acessibilidade do seletor e prévia assíncrona com rejeição de resultados antigos.
- Novidades carregadas sem rede, versão e três itens conferidos, fechamento por Return/Escape e persistência entre instâncias validados. Estado separado de `library.json` e `settings.json`.
- Fila retoma apenas ao adicionar novas entradas válidas; duplicatas, entradas inválidas e limite de 100 não alteram a pausa. Testes não iniciam downloads externos.
- Na revisão visual, corrigidos o hover que cobria a aba selecionada e o contraste dos ícones do histórico na base clara. Capturas finais revisadas após repetir os testes.

## Diagnóstico do instalador online

Uma rodada anterior falhou na asserção de cancelamento, antes da publicação. O teste passou a registrar os códigos de saída e recebeu um cenário lento com intervalo controlado entre blocos. Não foi alterado o código de produção do bootstrapper nem removida a asserção de cancelamento.

[Diagnóstico isolado aprovado](https://github.com/cnolli-fl/Caeser/actions/runs/40755875381): configuração `0`, opção de teste rejeitada no binário público `87`, corrupção `23`, truncamento `13`, redirecionamento não confiável `5`, cancelamento pelo diálogo `1223` e download íntegro `0`. O payload pequeno de teste não é publicado.

## Design

- Identidade azul aprovada no Mac, sem redesign da estrutura; fontes e ícones de ação nativos do Windows, sem distribuir SF Symbols ou fontes Apple.
- Logo aprovada preservada em uma cópia independente `Windows/BrandSources/Ocean`; ICO gerado com os mesmos PNGs em cinco tamanhos.
- Textos: branco sobre `#0D2666` **14,13:1**; texto secundário `#CFDFF5` sobre campos `#244580` **6,94:1**. Botão principal: **8,69:1**, hover **9,99:1**, pressionado **6,70:1**.
- Cada brush personalizado tem um mapeamento explícito para cores do sistema em HighContrast. Teste estático cobre o mapeamento; não equivale a testar manualmente todos os temas de contraste do Windows.
- Skill Apple Design aplicada à hierarquia, legibilidade, alvos e janela auxiliar não modal; controles e comportamento continuam nativos do Windows.

## Limites

O runner Windows não substitui testes manuais em PCs reais Windows 10/11, monitores/DPI variados, SmartScreen e temas de contraste personalizados. Consultas e downloads YouTube/Spotify dependem dos serviços externos. Nenhum DRM ou controle de segurança é contornado.

Aplicativo Mac, ferramentas de mídia e receitas de compilação das ferramentas não foram alterados. A distribuição Windows continua sem assinatura Authenticode.

## Pacote e instalação

- ZIP portátil, instalação e atualização sobre versões anteriores, reabertura, desinstalação e preservação de arquivos extras do usuário aprovados. As mesmas 20 capturas são verificadas também nas cópias portátil, instalada e atualizada pelo bootstrapper.
- Conferência das ferramentas incluídas, prévia e conversão MP3 de áudio original servido em loopback aprovadas, sem instalar dependências externas no ambiente de teste.
- Teste completo do instalador online aprovado: corrupção, truncamento e redirecionamento não confiável rejeitados; Cancelar funciona; pacote válido verificado e instalado com reabertura do aplicativo.
- Instalador online: **254.464 bytes** (~254 KB). Completo: **135.635.303 bytes** (~135,6 MB). O pequeno transfere o pacote completo depois, não é atualização diferencial.
- Instalação medida: **367.507.620 bytes**, **328 arquivos**. Referência 2.1.0 no mesmo ambiente: 425.853.559 bytes, 3.283 arquivos e instalador de 166.256.037 bytes. Inclui os sentinelas de preservação do usuário; bytes lógicos, não espaço alocado em disco.
- Inventários de codecs e extratores idênticos à referência. Nenhuma ferramenta, qualidade ou função foi removida para reduzir o pacote.
