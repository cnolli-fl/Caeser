# Caeser para macOS

Versão 2.1.0. Veja as mudanças em [CHANGELOG.md](CHANGELOG.md).

Vídeos e músicas, do link à sua pasta. Aplicativo nativo em SwiftUI para macOS 26, com ícone original, SF Symbols e Liquid Glass nos controles.

## Requisitos

- macOS 26 ou mais recente e Xcode com o SDK correspondente.
- [Homebrew](https://brew.sh/).
- yt-dlp e FFmpeg para vídeos; spotDL 4.5.2 ou posterior para Spotify.

Instale as ferramentas de vídeo:

```bash
brew install yt-dlp ffmpeg
```

Para Spotify, instale também o Python (`brew install python`), abra a opção **Spotify** e clique em **Instalar suporte ao Spotify**. O app cria um ambiente Python separado em `~/Library/Application Support/Caeser/Tools/spotdl` e instala o spotDL pelo pip. A instalação precisa de internet e pode ser cancelada.

O Caeser também reconhece `spotdl` em `~/.local/bin` (pipx), nas pastas do Homebrew ou no PATH. Nenhum executável de terceiros é incorporado ao aplicativo ou ao repositório.

## Abrir no Xcode

1. Abra **VideoDownloader.xcodeproj**.
2. Selecione o esquema **Caeser**, com destino **My Mac**.
3. Execute com **Run**.

O `Package.swift` também permite compilar e executar testes com Swift Package Manager. O projeto Xcode é o recomendado para gerar o aplicativo `.app`.

## Vídeos e áudio

1. Selecione **YouTube**, cole a URL e escolha qualidade e formato. Outros sites compatíveis com yt-dlp continuam aceitos.
2. Escolha a pasta de destino. O app lembra essa escolha na próxima abertura.
3. Clique em **Baixar** na barra superior ou pressione Return.
4. Acompanhe o progresso e use **Mostrar no Finder** ao terminar.

MP4 e WebM usam o FFmpeg para mesclar vídeo e áudio. MP3 usa a melhor faixa disponível e `--audio-quality 0` (qualidade variável máxima da conversão). Converter não recupera qualidade que a fonte não possui.

## Spotify via YouTube

1. Selecione **Spotify** ou cole o link; a origem é reconhecida automaticamente.
2. Use um link público de música, álbum ou playlist de **open.spotify.com**. URLs com `intl-pt` e URIs `spotify:track:…` também são aceitas.
3. Clique em **Baixar MP3**.

O spotDL identifica as músicas pelo Spotify, procura uma correspondência no YouTube Music (com YouTube como alternativa), baixa o áudio e adiciona capa e informações. O fluxo padrão de links públicos não pede login no Spotify. Bibliotecas privadas, músicas curtidas e links curtos como spotify.link não são suportados nesta versão.

O áudio **vem do YouTube**, não do Spotify. A qualidade depende da fonte encontrada. O app pede MP3 com `--bitrate 0`, sem prometer um bitrate ou uma qualidade de origem que não existem. A correspondência é automática e pode selecionar outra versão da música. Faixas indisponíveis, limites dos serviços e mudanças nas APIs podem impedir o download.

Em álbuns e playlists, o progresso indica músicas processadas. Uma falha é mostrada mesmo que outras músicas tenham sido salvas. Arquivos existentes são pulados; o app não sincroniza nem remove músicas da pasta.

## Interface e atalhos

- Aparência clara/escura acompanhando o sistema e cores semânticas.
- SF Symbols, controles nativos e ação principal em Liquid Glass.
- Seletor YouTube/Spotify com barrinha roxa deslizante, por clique ou arraste, e suporte a teclado.
- Marcas oficiais de YouTube e Spotify em PNG transparente com versões 1×, 2× e 3× próprias, para nitidez na escala da tela; fontes e geração em [BRAND-ASSETS.md](BRAND-ASSETS.md).
- Ferramentas e registro recolhíveis em **Detalhes e ferramentas**, com opção de copiar.
- Erros na própria janela e pasta de destino persistente.
- **⌘L** cola um link; **⌘D** inicia o download; **Esc** cancela.
- Ações também disponíveis no menu **Downloads**.
- Respeita Reduzir Movimento, Reduzir Transparência e Aumentar Contraste.

O ícone está em `Assets.xcassets/AppIcon.appiconset`, derivado de `CaeserIconOriginal.png`. A logo interna preserva exatamente essa imagem original de 1254 × 1254 pixels, em `Sources/VideoDownloader/Resources/CaeserLogo.png`, sem redesenho. O SwiftUI carrega o arquivo em resolução completa e usa interpolação de alta qualidade para a exibição em telas Retina, sem WebKit ou uma miniatura intermediária.

## Processos e testes

Os argumentos são passados diretamente a `Process`, sem montar comandos de shell. stdout/stderr são drenados antes do resultado final, preservando UTF-8. O cancelamento encerra o grupo de processos quando disponível. O app procura ferramentas no Homebrew para Apple Silicon e Intel, no ambiente separado do spotDL e no PATH.

Execute os testes:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

A suíte cobre links inválidos, URLs internacionais, URIs do Spotify, formatos, dependências, erros de playlist, preservação da saída e cancelamento.

Veja [CHANGELOG.md](CHANGELOG.md) para as mudanças e [DESIGN.md](DESIGN.md) para as decisões de interface.

O app não contorna DRM. Use os downloads conforme as permissões do conteúdo e dos serviços.
