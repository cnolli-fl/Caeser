# Caeser 1.1.1 para Windows

O Caeser agora tem aplicativo nativo para Windows. A ideia continua a mesma: facilitar e agilizar o download de vídeos e músicas, do link até a sua pasta.

## Downloads

- **Instalador recomendado:** Caeser-1.1.1-Windows-x64-Setup.exe. Instala para seu usuário, sem exigir administrador.
- **ZIP portátil:** Caeser-1.1.1-Windows-x64.zip. Extraia tudo antes de abrir Caeser.exe.
- **Conferência dos arquivos:** Caeser-1.1.1-Windows-x64-SHA256SUMS.txt.

Destinado a **Windows 10 22H2 e Windows 11, x64 (Intel/AMD)**. Windows de 32 bits e ARM64 não são alvos validados.

## O que vem nesta versão

- Interface nativa com a identidade visual do Caeser, logos originais, temas claro/escuro e seletor YouTube/Spotify animado.
- Vídeos nos formatos automático, MP4 e WebM; extração de MP3 com a melhor faixa disponível e a configuração máxima de qualidade do conversor.
- Links públicos de músicas, álbuns e playlists do Spotify como referência para buscar o áudio no YouTube/YouTube Music. Não é download direto do áudio do Spotify.
- Escolha e persistência da pasta de destino, progresso, logs, cancelamento e opção de abrir a pasta no Explorador.
- Ferramentas e runtimes incluídos: não precisa instalar Python, .NET, yt-dlp, FFmpeg ou Deno separadamente.

Poucas etapas para usar: colar o link, escolher as opções e baixar. A velocidade depende da conexão, do arquivo e do serviço; a busca de músicas e a conversão também levam tempo.

## Testes e limites

O pacote passa pelos testes automatizados da lógica e dos processos, abertura da interface nos dois temas, troca de origem e validação de links. Também são executados download de áudio original servido localmente com conversão para MP3 e instalação, abertura e desinstalação numa máquina Windows do GitHub.

Esses testes não substituem a validação em PCs reais com Windows 10/11, diferentes escalas de tela ou Narrator. Downloads reais do YouTube/Spotify não são garantidos pelos testes locais: disponibilidade, correspondências e limites dos serviços podem variar.

A distribuição é gratuita e **não possui assinatura Authenticode**. O Windows pode mostrar um aviso de fornecedor desconhecido. Não há atualizador automático.

As ferramentas mantêm suas próprias licenças; avisos, inventário e fontes acompanham o pacote. Use downloads conforme as permissões do conteúdo e dos serviços. O app não contorna DRM.

## E o Mac?

O Windows usa numeração própria: **1.1.1**. A edição Mac continua na **2.1.0**, sem mudanças nos instaladores:

[Baixar Caeser 2.1.0 para Mac](https://github.com/cnolli-fl/Caeser/releases/tag/v2.1.0).
