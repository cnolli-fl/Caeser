# Caeser para Windows

Pasta reservada para a versão Windows do Caeser. A versão macOS continua nos diretórios existentes, sem migração nem alteração do aplicativo publicado.

**Estado atual:** implementação inicial em C#/.NET 10 e WinUI 3, em desenvolvimento. O código, os testes e a compilação automatizada estão nesta pasta; ainda não há uma release Windows estável. A compatibilidade precisa ser confirmada pelos testes, não apenas pelo código.

## Plataforma

- C#/.NET com WinUI 3, em um projeto independente do projeto SwiftUI.
- Um único pacote `win-x64` destinado a Windows 10 22H2 e Windows 11, em PCs Intel e AMD.
- Windows ARM64 e Windows de 32 bits ficam fora desta primeira etapa.
- As dependências e APIs escolhidas precisam ser compatíveis com os dois sistemas. Não usar recursos exclusivos do Windows 11 sem uma alternativa para Windows 10.

A mesma arquitetura x64 permite compartilhar o executável entre Windows 10 e 11; isso não substitui os testes de compatibilidade. A Microsoft encerrou o suporte regular de Windows 10 Home/Pro em outubro de 2025. O objetivo de compatibilidade do Caeser não muda o ciclo de suporte do sistema operacional.

Referências: [WinUI 3](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/) e [ciclo de vida do Windows 10](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro).

## Design: preservar, não redesenhar

A referência aprovada é o [design atual do Caeser](../DESIGN.md) e a [captura da interface](../docs/images/caeser-interface.png).

Requisitos de fidelidade:

- Manter a mesma composição: cabeçalho com logo e nome, ação Baixar no topo, formulário Novo download, seletor YouTube/Spotify, URL, opções, pasta de destino, andamento e detalhes recolhíveis.
- Preservar as proporções, os espaçamentos, os cantos arredondados e o destaque roxo da versão Mac, considerando a escala de exibição do Windows.
- Usar a logo original do Caeser, sem reconstrução por IA, rotação, deformação ou ampliação artificial. A fonte está em [CaeserLogo.png](../Sources/VideoDownloader/Resources/CaeserLogo.png).
- Reutilizar as marcas oficiais de YouTube e Spotify, sem substituí-las por ícones genéricos. Usar os [recursos existentes](../Sources/VideoDownloader/Resources/) e as fontes registradas em [BRAND-ASSETS.md](../BRAND-ASSETS.md).
- Manter o indicador roxo que desliza entre as duas origens, incluindo clique, arraste e teclado. Respeitar a preferência do sistema para reduzir animações.
- Preservar os textos em português, a ordem dos controles e os estados de carregamento, conclusão, cancelamento e erro.
- Manter os modos claro/escuro, a navegação por teclado, os nomes acessíveis, o alto contraste e a nitidez em diferentes escalas de tela.

A identidade e o layout devem ser os mesmos. A barra de título, os botões de janela, a seleção de pasta, a fonte do sistema e os materiais precisam usar equivalentes do Windows. O Liquid Glass é nativo do macOS; não prometer reprodução idêntica do efeito no Windows 10/11, nem distribuir SF Symbols ou fontes da Apple como recursos do port.

## Paridade funcional

- YouTube e demais sites compatíveis com yt-dlp: qualidade máxima ou limite de resolução; formatos automático, MP4, WebM e MP3.
- MP3 usando o melhor áudio disponível e a configuração de máxima qualidade do codificador, sem prometer qualidade superior à fonte.
- Spotify: usar o link público para identificar música, álbum ou playlist e buscar o áudio no YouTube/YouTube Music. Não apresentar isso como download do áudio diretamente do Spotify.
- Progresso e logs em tempo real, escolha e persistência de pasta, cancelamento de toda a árvore de processos e mensagens de erro com orientação.
- Chamar executáveis com argumentos separados, sem montar comandos de shell com a URL.
- Distribuir as versões Windows de yt-dlp, FFmpeg/FFprobe, Deno e spotDL com os avisos de licença correspondentes. Não reutilizar os binários macOS.
- Empacotar os runtimes necessários para que a pessoa não precise instalar Python, .NET ou ferramentas de desenvolvimento por conta própria.

## Implementação e verificação previstas

1. Criar a solução independente nesta pasta, separando interface, lógica de download, testes e empacotamento.
2. Implementar a interface fiel à referência e transportar os comportamentos atuais.
3. Preparar as ferramentas e o pacote Windows autocontido.
4. Configurar compilação e testes em um runner Windows x64 no GitHub Actions.
5. Conferir visualmente a interface, a instalação e o funcionamento nos sistemas de destino antes de declarar a versão estável.

Testes automatizados precisam cobrir validação de links, argumentos de formato/qualidade, parsing de progresso, erros do Spotify, saída UTF-8, caminhos com espaços e cancelamento dos subprocessos. Testar downloads reais separadamente: serviços externos podem bloquear conexões de servidores na nuvem.

Um teste no runner Windows do GitHub não comprova, sozinho, a aparência da interface nem a compatibilidade com Windows 10.

## Releases no GitHub

Uma mesma release poderá oferecer arquivos diferentes para cada sistema. Os nomes abaixo são uma convenção proposta, não arquivos já disponíveis:

- `Caeser-X.Y.Z-macOS-AppleSilicon.dmg`
- `Caeser-X.Y.Z-macOS-AppleSilicon.zip`
- `Caeser-X.Y.Z-Windows-x64-Setup.exe`
- `Caeser-X.Y.Z-Windows-x64.zip`, se houver uma distribuição portátil validada.
- Arquivos de checksums identificados por plataforma.

As notas da release e o README devem apresentar links separados para **Baixar para Mac** e **Baixar para Windows 10/11 x64**, com os requisitos de cada um. O GitHub lista esses arquivos na seção Assets; não é necessário criar outro repositório.

Não anunciar Windows na release atual enquanto não houver um pacote construído e validado. Não substituir os arquivos macOS já publicados. A criação da pasta não realiza commit, push, execução de workflows ou publicação de release.

Referência: [releases e arquivos de distribuição no GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
