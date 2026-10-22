# Caeser 1.1.2 para Windows

Correção do fechamento ao clicar em Spotify, pastas organizadas e pacotes bem menores, mantendo o design e as logos do Caeser.

## Downloads

- **[Instalador recomendado — 166 MB](https://github.com/cnolli-fl/Caeser/releases/download/windows-v1.1.2/Caeser-1.1.2-Windows-x64-Setup.exe):** instala para seu usuário, sem exigir administrador. Quem usa a 1.1.1 pode executar este instalador para atualizar.
- **[ZIP portátil — 215 MB](https://github.com/cnolli-fl/Caeser/releases/download/windows-v1.1.2/Caeser-1.1.2-Windows-x64.zip):** extraia tudo antes de abrir Caeser.exe. Não copie somente o executável nem misture o ZIP com a pasta da versão antiga.
- **[Fontes das ferramentas — 208 MB](https://github.com/cnolli-fl/Caeser/releases/download/windows-v1.1.2/Caeser-1.1.2-Windows-x64-Fontes-Terceiros.zip):** fontes correspondentes, avisos e receitas de construção. Não é necessário baixar este arquivo para usar o aplicativo.
- **[SHA-256 dos arquivos](https://github.com/cnolli-fl/Caeser/releases/download/windows-v1.1.2/Caeser-1.1.2-Windows-x64-SHA256SUMS.txt):** conferência da integridade dos três downloads acima.

Destinado a **Windows 10 22H2 e Windows 11, x64 (Intel/AMD)**. Windows de 32 bits e ARM64 não são alvos validados. Os tamanhos são aproximados, em MB decimais.

## Correções e melhorias

- **Spotify sem fechar o app:** corrigido um recurso de tema inexistente acionado ao passar o mouse no seletor. Também foram estabilizados os cliques rápidos, o arraste nas duas direções, o teclado e a animação com movimento reduzido.
- **Menos peso:** instalador de 382 → 166 MB, cerca de **57% menor**; ZIP de 443 → 215 MB, cerca de **51% menor**. Componentes não utilizados de IA/ML, Search e Widgets foram retirados das dependências.
- **Pasta principal limpa:** apenas Caeser.exe, Aplicativo, Documentacao e LEIA-ME.txt. Bibliotecas e ferramentas ficam em Aplicativo; os avisos de licença, em Documentacao. Mantenha essas pastas ao lado do executável.
- **Português brasileiro:** interface e instalador em português, sem os demais pacotes de tradução. O pequeno fallback interno en-US obrigatório do WinUI e os textos originais das licenças são mantidos.
- **Fontes em download separado:** não ocupam mais espaço na instalação. Quem redistribuir os binários deve disponibilizar também os fontes correspondentes; consulte [as licenças e instruções](https://github.com/cnolli-fl/Caeser/blob/windows-v1.1.2/Windows/THIRD-PARTY.md).
- **Atualização mais limpa:** o instalador remove somente os arquivos registrados pela instalação antiga, sem apagar a pasta inteira. Preferências, downloads e arquivos extras do usuário são preservados.
- **Diagnóstico local:** em caso de falha inesperada, o último relatório fica em `%LOCALAPPDATA%\Caeser\Logs\ultima-falha.txt`. Não há envio automático.

## O que continua incluído

- Interface nativa com a identidade visual do Caeser, logos originais, temas claro/escuro e seletor YouTube/Spotify animado.
- Vídeos nos formatos automático, MP4 e WebM; extração de MP3 com a melhor faixa disponível e a configuração máxima de qualidade do conversor.
- Links públicos de músicas, álbuns e playlists do Spotify como referência para buscar o áudio no YouTube/YouTube Music. Não é download direto do áudio do Spotify.
- Escolha e persistência da pasta de destino, progresso, logs, cancelamento e opção de abrir a pasta no Explorador.
- Ferramentas e runtimes incluídos: não precisa instalar Python, .NET, yt-dlp, FFmpeg ou Deno separadamente.

O fluxo padrão de links públicos do Spotify não pede login na sua conta. A qualidade depende da fonte encontrada; converter para MP3 não recupera qualidade ausente. Poucas etapas para usar: colar o link, escolher as opções e baixar. A velocidade depende da conexão, do arquivo e do serviço; a busca de músicas e a conversão também levam tempo.

## Testes e limites

Os pacotes desta release são os mesmos arquivos aprovados no [workflow de validação no Windows](https://github.com/cnolli-fl/Caeser/actions/runs/39783492094). O código funcional da tag é idêntico ao testado; a documentação e os links foram atualizados para a publicação.

Passaram **40 testes de lógica, processos e ferramentas incluídas**, além de verificações reais de mouse, arraste, teclado, animação e temas claro/escuro. Também passaram conversão MP3 de um áudio original servido localmente, abertura do ZIP extraído em caminho com espaços e acentos, atualização a partir do instalador público da 1.1.1 e instalação/abertura/desinstalação, preservando um arquivo extra do usuário.

Esses testes não substituem a validação em PCs reais com Windows 10/11, diferentes escalas de tela ou Narrator. Downloads reais do YouTube/Spotify não são garantidos pelos testes locais: disponibilidade, correspondências e limites dos serviços podem variar.

A distribuição é gratuita e **não possui assinatura Authenticode**. O Windows pode mostrar um aviso de fornecedor desconhecido. Não há atualizador automático.

As ferramentas mantêm suas próprias licenças; avisos e inventário acompanham o aplicativo, com os fontes correspondentes no download separado desta release. Use downloads conforme as permissões do conteúdo e dos serviços. O app não contorna DRM.

## E o Mac?

O Windows usa numeração própria: **1.1.2**. A edição Mac continua na **2.1.0**, sem mudanças nos instaladores. As releases anteriores são mantidas.

[Baixar Caeser 2.1.0 para Mac](https://github.com/cnolli-fl/Caeser/releases/tag/v2.1.0).
