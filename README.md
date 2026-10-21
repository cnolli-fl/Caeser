# Caeser

Versão 2.1.0. Veja as mudanças em [CHANGELOG.md](CHANGELOG.md).

**Baixe vídeos e músicas no Mac de um jeito simples e muito rápido.**

O Caeser foi criado para facilitar o caminho entre o link e o arquivo salvo: cole o endereço, escolha o formato e a pasta e clique em **Baixar**. Tudo em uma interface nativa para macOS 26, sem precisar montar comandos a cada download.

[**Baixar Caeser 2.1.0 para Mac (.dmg)**](https://github.com/cnolli-fl/Caeser/releases/download/v2.1.0/Caeser-2.1.0-macOS-AppleSilicon.dmg) · [ZIP](https://github.com/cnolli-fl/Caeser/releases/download/v2.1.0/Caeser-2.1.0-macOS-AppleSilicon.zip) · [Notas da release](https://github.com/cnolli-fl/Caeser/releases/tag/v2.1.0)

Requer **macOS 26 ou mais recente e chip Apple (M1 ou posterior)**. Ferramentas incluídas, sem Homebrew ou Python separado. Esta edição não é notarizada pela Apple; veja [como instalar e conferir a segurança](docs/INSTALACAO.md). Ainda não há versão para Windows ou Mac Intel.

![Caeser 2.1.0 com seletor YouTube e Spotify, opções de download e download concluído](docs/images/caeser-interface.png)

*Interface da versão 2.1.0, com seletor YouTube/Spotify, ícones Retina e indicação de download concluído.*

## Proposta do projeto

O intuito do projeto é **facilitar e agilizar o download de vídeos e músicas**, reunindo o que você precisa em uma única janela. Dá para salvar um vídeo, extrair o áudio em MP3 ou usar um link do Spotify para encontrar as músicas no YouTube, sem fazer a busca manual de cada faixa.

A ideia é ser prático no dia a dia: poucas etapas para iniciar, pasta de destino lembrada pelo app, acompanhamento na própria tela e acesso ao arquivo pelo Finder quando terminar.

### Rapidez no uso

Depois da configuração inicial, o fluxo é direto: **colar o link → escolher as opções → baixar**. O Caeser automatiza a busca, o download e a conversão conforme a opção escolhida, tornando o processo rápido e evitando etapas manuais repetidas.

A velocidade de transferência depende da conexão, do tamanho do arquivo e do serviço de origem. No modo Spotify, a busca de correspondências e a conversão para MP3 também fazem parte do tempo total; não há um prazo fixo para todos os downloads.

Por trás da interface, o Caeser usa yt-dlp, FFmpeg e, para links do Spotify, spotDL. A edição completa inclui essas ferramentas e o Deno dentro do aplicativo, sem precisar instalar Homebrew ou Python. O código-fonte continua sem binários de terceiros versionados no Git.

## Aplicativo completo

A receita de distribuição gera um `.dmg` e um `.zip` para **macOS 26 ou mais recente em Macs com chip Apple (M1 ou posterior)**. Basta mover Caeser.app para Aplicativos; yt-dlp, FFmpeg, FFprobe, Deno e spotDL já acompanham o pacote. Não é necessário Xcode, Python, Homebrew nem o aplicativo do Spotify para usá-lo.

Esta edição tem assinatura local gratuita (ad-hoc), **sem Developer ID e sem notarização da Apple**. O macOS pode impedir a primeira abertura e exigir autorização manual. Isso não deve ser confundido com um app verificado pela Apple. Consulte [as instruções de instalação e segurança](docs/INSTALACAO.md); não desative as proteções globais do sistema.

Os instaladores estão disponíveis na [release 2.1.0](https://github.com/cnolli-fl/Caeser/releases/tag/v2.1.0), junto com os hashes SHA-256 para conferência. O GitHub também mostra arquivos **Source code**, que são apenas o projeto para desenvolvedores — para instalar, escolha o `.dmg` ou o `.zip` chamado **Caeser-2.1.0-macOS-AppleSilicon**. A receita de empacotamento gera os arquivos localmente em `dist/`, sem publicá-los automaticamente.

## Recursos

- URLs HTTP e HTTPS, com validação antes de iniciar.
- Qualidade de vídeo: melhor disponível, até 4K, 1440p, 1080p, 720p ou 480p.
- Formatos Automático, MP4, WebM e MP3.
- Links públicos de músicas, álbuns e playlists do Spotify como referência para buscar o áudio no YouTube Music ou YouTube e salvar em MP3.
- Seleção nativa e persistente da pasta de destino.
- Ferramentas incluídas na edição completa; no modo de desenvolvimento, detecção de ferramentas externas e instalação opcional do suporte ao Spotify.
- Progresso, velocidade e estimativa de tempo quando informados pela ferramenta.
- Registro técnico recolhível, cancelamento e erros na própria janela.

A qualidade de vídeo escolhida é um limite de resolução: o resultado depende da origem. Converter para MP3 não recupera qualidade que a fonte não possui.

## Tecnologias e arquitetura

| Componente | Responsabilidade |
| --- | --- |
| SwiftUI | Interface, opções, animações e estados visuais. |
| AppKit | Seleção da pasta com NSOpenPanel e integração com o Finder. |
| Foundation | URLs, arquivos, processos externos e leitura da saída. |
| yt-dlp | Extração e download de vídeos e áudio. |
| FFmpeg | Conversão de áudio e combinação de faixas. |
| spotDL | Leitura das informações das faixas a partir de links do Spotify, busca de correspondências no YouTube Music/YouTube e gravação do MP3 com metadados. |
| Core Graphics e ImageIO | Geração dos PNGs das marcas nas escalas de tela. |

```text
Sources/VideoDownloader/
├── VideoDownloaderApp.swift   Entrada do aplicativo e comandos
├── ContentView.swift          Interface e componentes visuais
├── DownloadViewModel.swift    Estado, validação e progresso
├── DownloadModels.swift       Opções e argumentos das ferramentas
├── DownloadProcess.swift      Execução, saída e cancelamento
├── DependencyLocator.swift    Localização dos executáveis
└── Resources/                 Logo original e marcas PNG 1×, 2× e 3×
Assets.xcassets/               Ícone do aplicativo
Design/BrandSources/           Fontes vetoriais das marcas
Scripts/                      Ícones, preparação das ferramentas e empacotamento
Tests/                        Testes automatizados
VideoDownloader.xcodeproj/     Projeto do Xcode
Package.swift                 Configuração do Swift Package Manager
docs/images/                  Captura da interface
```

## Requisitos para desenvolver

- macOS 26 ou mais recente e Xcode com o SDK correspondente.
- [Homebrew](https://brew.sh/).
- yt-dlp para vídeos e extração de áudio; FFmpeg para conversão e combinação de faixas nos dois modos.
- Para usar links do Spotify: spotDL 4.5.2 ou posterior e Python para instalar o suporte pelo app.
- Conexão com a internet para obter a mídia e instalar dependências.

Instale as ferramentas de vídeo:

```bash
brew install yt-dlp ffmpeg
```

Para usar links do Spotify, mantenha o FFmpeg instalado, instale também o Python (`brew install python`), abra a opção **Spotify** e clique em **Instalar suporte ao Spotify**. Esse botão instala o spotDL, não o aplicativo do Spotify. O ambiente Python fica separado em `~/Library/Application Support/Caeser/Tools/spotdl`. A instalação precisa de internet e pode ser cancelada.

Na compilação de desenvolvimento sem ferramentas incorporadas, o Caeser também reconhece `spotdl` em `~/.local/bin` (pipx), nas pastas do Homebrew ou no PATH. Na edição completa, usa exclusivamente as ferramentas internas: um pacote incompleto não é mascarado pelo Homebrew instalado na máquina do desenvolvedor.

### Gerar o pacote completo

No Mac com chip Apple, com Xcode instalado:

```bash
bash Scripts/PrepareBundledTools.sh
bash Scripts/PackageApp.sh
```

A primeira etapa baixa os executáveis yt-dlp/Deno e fontes de mídia com verificação SHA-256, compila FFmpeg/FFprobe e LAME sem bibliotecas do Homebrew e recompila spotDL com dependências Python fixadas e yt-dlp atualizado. Para preparar o pacote, o desenvolvedor precisa também de Python 3.14; os usuários do aplicativo não. A segunda compila o app em Release, inclui as ferramentas e os fontes/licenças, aplica assinatura local e gera `.dmg`, `.zip` e respectivos hashes em `dist/`. A primeira preparação demora mais por compilar as ferramentas. Arquivos gerados e caches não entram no Git.

O helper `Scripts/CollectToolLicenses.py` extrai os avisos já presentes nos arquivos PyInstaller de yt-dlp e spotDL durante a preparação. `Scripts/VerifyBundledApp.sh` confere integridade, arquitetura, versões, JavaScript e conversão MP3 em um ambiente vazio. Veja [THIRD-PARTY.md](THIRD-PARTY.md) para versões, origens e licenças.

## Abrir no Xcode

Se ainda não tiver o projeto:

```bash
git clone https://github.com/cnolli-fl/Caeser.git
cd Caeser
```

1. Abra [VideoDownloader.xcodeproj](VideoDownloader.xcodeproj).
2. Selecione o esquema **Caeser**, com destino **My Mac**.
3. Execute com **Command + R**.

O [Package.swift](Package.swift), configurado para Swift tools 6.2, também permite compilar e executar testes com Swift Package Manager. O projeto Xcode é o recomendado para gerar o aplicativo `.app`.

## Vídeos e áudio

1. Selecione **YouTube**, cole a URL e escolha qualidade e formato. Outros sites compatíveis com yt-dlp continuam aceitos.
2. Escolha a pasta de destino. O app lembra essa escolha na próxima abertura.
3. Clique em **Baixar** na barra superior ou pressione Return.
4. Acompanhe o progresso e use **Mostrar no Finder** ao terminar.

MP4 e WebM usam o FFmpeg para mesclar vídeo e áudio. MP3 usa a melhor faixa disponível e `--audio-quality 0` (qualidade variável máxima da conversão). Converter não recupera qualidade que a fonte não possui. O fluxo de vídeo solicita um item por operação, sem baixar playlists.

## Como funciona a opção Spotify

**Você cola o link do Spotify; o Caeser encontra o áudio no YouTube Music ou YouTube e salva em MP3.** O link serve para identificar a música ou a lista de faixas. Não é um download direto dos arquivos de áudio do Spotify.

1. Selecione **Spotify** ou cole o link; a origem é reconhecida automaticamente.
2. Use um link público de música, álbum ou playlist de **open.spotify.com**. URLs com `intl-pt` e URIs `spotify:track:…` também são aceitas.
3. Escolha a pasta de destino e clique em **Baixar MP3**.

O trabalho é feito pelo [spotDL](https://github.com/spotDL/spotify-downloader): ele usa as informações das faixas, procura correspondências nas fontes de áudio configuradas e salva o arquivo com capa e metadados, como título, artista e álbum, quando disponíveis. O Caeser configura YouTube Music e YouTube como fontes.

No fluxo padrão de links públicos, o Caeser não pede login na sua conta do Spotify. Isso não dá acesso a conteúdo privado: músicas curtidas, bibliotecas privadas e links curtos como spotify.link não fazem parte do fluxo desta versão.

O MP3 usa qualidade variável com `--bitrate 0`. A qualidade de origem continua sendo a do áudio encontrado no YouTube; a conversão não recupera detalhes ausentes nem transforma a faixa em áudio sem perdas. Veja a [documentação de formatos e qualidade do spotDL](https://spotdl.readthedocs.io/en/latest/usage/#audio-formats-and-quality).

A busca é automática e pode encontrar outra versão da música, como uma gravação ao vivo ou um remix. Se uma faixa não estiver disponível ou os serviços limitarem as consultas, ela pode falhar mesmo com um link válido.

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

Os argumentos são passados diretamente a `Process`, sem montar comandos de shell. stdout/stderr são drenados antes do resultado final, preservando UTF-8. O cancelamento encerra o grupo de processos quando disponível. A edição completa usa `Contents/Resources/Tools` com PATH controlado, sem herdar configurações Python ou bibliotecas externas. A compilação de desenvolvimento sem esse diretório continua procurando Homebrew, o ambiente separado do spotDL e PATH.

Execute os testes:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Os 17 testes cobrem links inválidos, URLs internacionais, URIs do Spotify, formatos, dependências, erros de playlist, preservação da saída, cancelamento, ícones nas escalas de tela, prioridade das ferramentas internas e isolamento do ambiente.

Veja [CHANGELOG.md](CHANGELOG.md) para as mudanças e [DESIGN.md](DESIGN.md) para as decisões de interface.

## Problemas comuns

| Situação | O que conferir |
| --- | --- |
| Dependência não encontrada | Na edição completa, baixe novamente o pacote; as ferramentas já deveriam estar incluídas. Em desenvolvimento, instale yt-dlp/FFmpeg pelo Homebrew e o suporte Spotify pela interface. |
| URL inválida | Confira o endereço completo; links de vídeo precisam começar com http:// ou https://. |
| Erro ao baixar | Consulte o registro; disponibilidade e suporte ao site dependem da origem e das ferramentas. |
| Falha ao salvar | Confira se a pasta de destino existe e permite gravação. |
| Qualidade diferente da escolhida | A resolução selecionada é um teto; a origem precisa disponibilizar uma versão compatível. |

Na edição completa, quando as ferramentas precisarem de atualização, instale um novo pacote do Caeser. Não há atualizador automático. O comando abaixo só vale para a compilação de desenvolvimento que usa Homebrew:

```bash
brew upgrade yt-dlp ffmpeg
```

## Limites da versão atual

- Uma operação de download por vez, sem fila independente de tarefas.
- Álbuns e playlists públicas identificados por links do Spotify são processados pelo spotDL, com áudio buscado no YouTube Music/YouTube; playlists de vídeo não são baixadas pelo fluxo de vídeo.
- Edição completa disponível pela receita de empacotamento apenas para Apple Silicon; compilação direta de desenvolvimento ainda usa ferramentas externas.
- Sem Developer ID/notarização nesta distribuição gratuita; pode haver bloqueio na primeira abertura.
- Sem fluxo de autenticação com contas de serviços na interface.

O app não contorna DRM. Use os downloads conforme as permissões do conteúdo e dos serviços.

## Licença

O código Swift deste projeto é open source sob a [licença MIT](LICENSE). Você pode usar, modificar e distribuir o código, mantendo o aviso de copyright e a licença. As ferramentas incluídas na edição completa mantêm as próprias licenças, descritas em [THIRD-PARTY.md](THIRD-PARTY.md), e os fontes de FFmpeg/LAME acompanham o app. As marcas de terceiros seguem as condições descritas em [BRAND-ASSETS.md](BRAND-ASSETS.md).

## Autor

Projeto pessoal de **Caio Nolli**.

[GitHub](https://github.com/cnolli-fl) · [LinkedIn](https://www.linkedin.com/in/caio-nolli-843580388/)
