# Caeser para macOS

Aplicativo nativo em SwiftUI para macOS que baixa vídeos chamando os executáveis `yt-dlp` e `ffmpeg` instalados pelo Homebrew. Nenhum binário é incorporado ao projeto.

## Requisitos

- macOS 26 ou mais recente
- Xcode compatível com macOS 26
- Homebrew
- `yt-dlp` e `ffmpeg`

Instale as dependências no Terminal:

```bash
brew install yt-dlp ffmpeg
```

## Abrir no Xcode

1. Abra `VideoDownloader.xcodeproj` no Xcode.
2. Selecione o esquema `Caeser`.
3. Escolha **My Mac** como destino.
4. Execute com **Run**.

O arquivo `Package.swift` também é mantido para compilação via Swift Package Manager, mas o `.xcodeproj` é o formato recomendado para executar a janela do aplicativo e gerar um `.app` distribuível. A interface usa o Liquid Glass nativo do macOS 26.

O ícone do aplicativo está em `Assets.xcassets/AppIcon.appiconset` e foi gerado a partir da imagem original enviada (`CaeserIconOriginal.png`), preservando o desenho em todos os tamanhos do macOS. A mesma imagem é usada como logo dentro da janela por meio do asset `CaeserIcon`.

A logo interna usa `Sources/VideoDownloader/Resources/CaeserIcon.svg`, uma versão vetorial do mesmo visual, renderizada pelo WebKit para permanecer nítida em qualquer escala.

## Como funciona

- O app procura `yt-dlp` e `ffmpeg` em `/opt/homebrew/bin` e `/usr/local/bin`.
- O usuário cola uma URL HTTP/HTTPS, escolhe qualidade, formato e pasta.
- O formato MP3 baixa a melhor faixa de áudio disponível e usa `--audio-quality 0` para a conversão de maior qualidade possível no MP3.
- Cada argumento é passado diretamente ao `Process`, sem executar um shell e sem interpolar comandos.
- A saída combinada de stdout e stderr é exibida na área de logs.
- O progresso é lido pelo `--progress-template` do yt-dlp, com fallback para o formato padrão de progresso.
- Ao selecionar MP4 ou WebM, o FFmpeg é usado pelo yt-dlp para mesclar vídeo e áudio quando necessário.

## Observações

O uso do yt-dlp deve respeitar os termos de serviço do site de origem e as leis aplicáveis. O app não contorna DRM nem incorpora credenciais.
