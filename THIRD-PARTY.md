# Ferramentas incluídas na distribuição completa

O código Swift do Caeser permanece sob MIT. As ferramentas abaixo são programas
independentes, chamados por processos, e mantêm suas próprias licenças. Não são
reescritas nem vinculadas ao executável Swift do aplicativo.

| Ferramenta | Versão | Origem | Licença principal |
| --- | --- | --- | --- |
| yt-dlp | 2026.08.19 | https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19 | Unlicense e licenças dos componentes incorporados |
| spotDL | 4.5.2, recompilado com yt-dlp 2026.08.19 | https://pypi.org/project/spotdl/4.5.2/ | MIT e licenças dos componentes incorporados |
| Deno | 2.9.8 | https://github.com/denoland/deno/releases/tag/v2.9.8 | MIT e licenças dos componentes incorporados |
| FFmpeg / FFprobe | 9.0.2 | https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz | LGPL 2.1 ou posterior |
| LAME | 3.100 | https://lame.sourceforge.io/ | LGPL 2 ou posterior |

As versões independentes de yt-dlp e spotDL já carregam o runtime Python. O spotDL
é recompilado sem alterações no seu código, com dependências fixadas em
`Packaging/spotdl-requirements.txt`, para evitar o yt-dlp antigo do executável
oficial 4.5.2. O Deno
permite ao yt-dlp resolver os desafios JavaScript do YouTube. Não se instala nem
altera Homebrew, Python ou ferramentas do sistema no computador do usuário.

FFmpeg e FFprobe são compilados com LAME estático, sem detecção automática de
bibliotecas externas e sem `--enable-gpl` ou `--enable-nonfree`. A configuração
habilita a codificação MP3 VBR, AAC e imagens para capas, além dos decodificadores,
demuxers e muxers internos. HTTPS usa o Secure Transport do macOS, sem OpenSSL
externo, preservando os protocolos de rede usados por alguns sites compatíveis.

Os arquivos-fontes exatos de FFmpeg e LAME, sem alterações no código, e o script
de compilação acompanham o app em `Contents/Resources/Tools/Sources`. Para
recompilar, copie essa pasta para um local gravável e execute
`bash BuildMediaTools.sh "$PWD"` com as ferramentas de linha de comando do Xcode.
O resultado fica em `media-prefix/bin` e pode substituir os executáveis incluídos.
Qualquer assinatura local deverá ser refeita depois de uma alteração.

Os avisos de licença ficam em `Contents/Resources/Tools/Licenses`. Os scripts de
preparação validam SHA-256 dos downloads executáveis antes de usá-los. Não são
incluídos cookies, contas, chaves de desenvolvedor ou configurações pessoais.

Veja também as condições das marcas em `BRAND-ASSETS.md`. A distribuição completa
está disponível na release 2.1.0 do GitHub. A receita de empacotamento gera os
arquivos localmente; a publicação é uma etapa separada, feita com aprovação.
