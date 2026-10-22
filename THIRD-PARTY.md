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

yt-dlp e spotDL compartilham uma única cópia do runtime Python e das dependências,
compilada para arm64. O nome usado para iniciar o processo seleciona a ferramenta:
`yt-dlp` é um link relativo para `spotdl`, preservado ao mover ou extrair o app.
O código das ferramentas não é alterado; as versões ficam fixadas em
`Packaging/spotdl-requirements.txt`. A receita
`Packaging/MediaTools.spec` não duplica os arquivos Python já compilados, remove
os recursos da interface web independente do spotDL (não usada pelo Caeser) e
mantém os catálogos português e o pequeno catálogo inglês necessário ao parser
do ytmusicapi. Nenhum extrator, codec ou dicionário de títulos é removido. O Deno
permite ao yt-dlp resolver os desafios JavaScript do YouTube. Não se instala nem
altera Homebrew, Python ou ferramentas do sistema no computador do usuário.

FFmpeg e FFprobe compartilham suas bibliotecas dentro de `Tools/Lib`, evitando
duas cópias do mesmo código. São compilados com LAME estático, sem detecção automática de
bibliotecas externas e sem `--enable-gpl` ou `--enable-nonfree`. A configuração
habilita a codificação MP3 VBR, AAC e imagens para capas, além dos decodificadores,
demuxers e muxers internos. HTTPS usa o Secure Transport do macOS, sem OpenSSL
externo, preservando os protocolos de rede usados por alguns sites compatíveis.

Na distribuição macOS 2.1.1, os arquivos-fontes exatos de FFmpeg e LAME, sem
alterações, e as receitas das ferramentas são oferecidos no download separado
`Caeser-2.1.1-macOS-AppleSilicon-Fontes-Terceiros.zip`, na área pública
[Fontes de terceiros](https://github.com/cnolli-fl/Caeser/releases/tag/fontes-terceiros),
com link direto nas notas da release do aplicativo.
Esse arquivo também contém os fontes Python correspondentes e os fontes de
dependências do Deno cujas licenças os exigem. Os avisos de todos esses componentes
ficam no aplicativo, agrupados em `Licenses.zip`, incluindo as dependências Rust
e V8 do Deno fixado. Descompacte esse arquivo para ler os avisos originais.
Não é necessário baixar esses fontes para usar o Caeser. Quem redistribuir os
binários deve disponibilizar também os fontes correspondentes e os avisos de
licença; o arquivo de fontes é obrigatório na publicação, não no computador do usuário.

Para recompilar, extraia o arquivo em uma pasta gravável, instale as ferramentas
de linha de comando do Xcode e Python 3.14 e, na pasta extraída, execute:

```bash
CAESER_PACKAGING_CACHE="$PWD/Sources" bash Receita/Scripts/PrepareBundledTools.sh "$PWD/Ferramentas"
```

A receita usa fontes/dependências com versões fixadas e precisa de internet.
As bibliotecas de FFmpeg são substituíveis em `Tools/Lib`; os executáveis continuam
como processos independentes. Ao modificar binários ou bibliotecas, refaça a
assinatura local dos arquivos alterados e do app. Não desative as proteções do sistema.

Os avisos de licença ficam em `Contents/Resources/Tools/Licenses.zip`. Os scripts de
preparação validam SHA-256 dos downloads executáveis antes de usá-los. Não são
incluídos cookies, contas, chaves de desenvolvedor ou configurações pessoais.

Veja também as condições das marcas em `BRAND-ASSETS.md`. A distribuição completa
2.1.1 está na release correspondente do GitHub. Os fontes obrigatórios ficam
gratuitamente disponíveis na área Fontes de terceiros, sem exigir cadastro.
A receita gera também um ZIP alternativo e um arquivo de hashes para validação
local; a página de downloads do aplicativo oferece o instalador DMG.
