# Caeser para Windows

Versão Windows do Caeser, separada do aplicativo SwiftUI. A versão macOS continua nos diretórios existentes, sem migração nem alteração do aplicativo publicado.

**Versão Windows: 2.1.0.** Implementação nativa em C#/.NET 10 e WinUI 3. A numeração é independente da edição Mac 3.0.1.

[Baixar instalador](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.1.0/Caeser-2.1.0-Windows-x64-Setup.exe) · [Novidades e instruções](https://github.com/cnolli-fl/Caeser/releases/tag/windows-v2.1.0)

### Novidade na 2.1.0

Atualizações compatíveis podem ser baixadas no aplicativo, com progresso, cancelamento e conferência de integridade. Você escolhe **Instalar e reiniciar**; a fila é salva e volta pausada. Instale a 2.1.0 manualmente uma vez para obter esse recurso nas versões seguintes. Cópias portáteis mantêm o caminho manual. [Fluxo, segurança e limites](../docs/ATUALIZACAO-WINDOWS-NO-APP.md).

### Ajuste visual na 2.0.1

Histórico com linhas compactas, ações alinhadas, datas visíveis e textos longos contidos. Janela mais proporcional e tema herdado da janela principal. Nenhuma alteração no formato dos dados salvos.

Baixe somente o instalador e siga as etapas. Ele configura o app para seu usuário, sem exigir administrador. O README é esta página; os arquivos Source code gerados pelo GitHub são para desenvolvimento.

O pacote já inclui as ferramentas. Não é necessário instalar Python, .NET, FFmpeg, Deno ou yt-dlp separadamente. O instalador não tem assinatura Authenticode; o Windows pode avisar que o fornecedor é desconhecido.

### Novidades na 2.0.0

- Prévia automática com capa, título, autor e duração quando disponíveis. Para música individual do Spotify, mostra a correspondência no YouTube e usa o mesmo vídeo no download.
- Fila de até 100 pendentes, com até 50 links por entrada. Pode misturar origens, organizar/remover pendentes, cancelar o atual e pausar antes do próximo. Cada item conserva formato, qualidade e destino.
- Histórico dos últimos 100 downloads e recuperação da fila pausada após reabrir. Limpar o histórico preserva seus arquivos.
- Preferências por origem e aviso de novas releases estáveis de Windows. O botão oferece o instalador oficial; a instalação continua manual.
- Mesmo design clean, identidade violeta, logos e componentes nativos. Os downloads MP3 mantêm a qualidade máxima de conversão.

Prévias dependem dos serviços. Se uma prévia falhar, ainda é possível adicionar o link à fila. Spotify fornece os metadados; o áudio vem do YouTube. Cole vários links, um por linha, e use Ctrl+Enter para adicionar.

### Mantido da 1.1.2

Corrigido o fechamento ao interagir com Spotify. O seletor mantém o visual original, com clique, arraste nas duas direções, navegação por teclado e respeito a Reduzir Movimento. O instalador ficou cerca de 57% menor e o ZIP, 51% menor em relação à 1.1.1.

A distribuição otimizada mantém apenas **Caeser.exe**, **Aplicativo**, **Documentacao** e **LEIA-ME.txt** na pasta principal. Abra Caeser.exe e mantenha as pastas ao lado dele. As bibliotecas e ferramentas necessárias ficam dentro de Aplicativo, sem removê-las nem mudar seus caminhos internos.

Interface e instalador usam português brasileiro. Satélites de tradução não utilizados são excluídos da saída gerada. Além de pt-BR, são preservados apenas o pequeno fallback interno en-US exigido pelo carregador nativo do WinUI, os arquivos neutros do runtime e os textos originais das licenças. O projeto referencia somente os componentes Windows App SDK que usa, sem IA/ML, Search ou Widgets.

Os [fontes das ferramentas](https://github.com/cnolli-fl/Caeser/releases/download/fontes-terceiros/Caeser-1.1.2-Windows-x64-Fontes-Terceiros.zip) ficam na área Fontes de terceiros, no arquivo correspondente ao pacote, em vez de ocuparem espaço na instalação. Os avisos de licença continuam em Documentacao. Não é necessário baixar os fontes para usar o Caeser; quem redistribuir os binários deve disponibilizar também os fontes correspondentes, conforme [THIRD-PARTY.md](THIRD-PARTY.md).

Ao atualizar uma instalação antiga, o instalador usa o desinstalador anterior para remover somente os arquivos registrados por ele. Não apaga a pasta inteira nem os downloads e preferências. O teste automatizado verifica a atualização da 1.1.1 publicada e a preservação de um arquivo extra do usuário, inclusive após desinstalar a nova versão.

Caso haja uma falha inesperada, o último relatório fica em `%LOCALAPPDATA%\Caeser\Logs\ultima-falha.txt`. Nenhum relatório é enviado automaticamente.

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

## Estrutura e desenvolvimento

- Caeser.Windows.sln: solução para abrir no Visual Studio com suporte ao .NET 10 e WinUI.
- Caeser.App: janela, temas, integração com o Windows e seletor animado.
- Caeser.Core: validação, argumentos, progresso, preferências e execução segura de processos.
- Caeser.Core.Tests: testes automatizados, sem depender da interface.
- Caeser.ProcessProbe: programa auxiliar usado pelos testes de stdout/stderr e cancelamento.
- Caeser.Launcher: entrada nativa pequena que abre a interface em Aplicativo, sem exigir outro runtime.
- Scripts e Packaging: ferramentas, fontes verificadas, construção e instalador.
- DESIGN.md: referência de fidelidade visual e critérios de acessibilidade.

No Windows, com o SDK .NET 10.0.402 e Visual Studio/Build Tools com as ferramentas C++ x64 instalados (o pequeno launcher nativo usa MSVC e o compilador de recursos do Windows):

    dotnet test Caeser.Core.Tests/Caeser.Core.Tests.csproj
    pwsh -File Scripts/Build.ps1

A interface é compilada somente no Windows. A lógica e seus testes também podem rodar no macOS; o teste específico de Job Objects é ignorado fora do Windows.

O aplicativo compilado sozinho não contém as ferramentas de download. Para o pacote completo, o workflow constrói as ferramentas, verifica a conversão para MP3 e prepara a distribuição. Não basta copiar apenas Caeser.exe.

## Compilação e pacote completo

O workflow Caeser Windows testa main e a branch de desenvolvimento. Não possui permissão para publicar Releases: a publicação é feita separadamente, após conferir o pacote e sua execução.

Etapas:

1. Executar os testes da lógica e de subprocessos reais, incluindo os específicos do Windows.
2. Compilar a interface autocontida e abrir a janela para os testes e capturas reais.
3. Construir FFmpeg/LAME a partir dos fontes fixados e spotDL com o extrator atualizado.
4. Verificar todas as ferramentas em um ambiente sem Python/FFmpeg/Deno externos e baixar um áudio original de teste, servido somente em loopback, convertendo-o para MP3 com a mesma lógica do aplicativo.
5. Conferir a versão do aplicativo e gerar ZIP portátil, instalador por usuário, arquivo separado de fontes de terceiros e checksums SHA-256.
6. Extrair o ZIP em um caminho com espaços e acentos e abrir pelo launcher, validando o pacote que o usuário recebe.
7. Instalar, conferir a versão instalada, abrir e desinstalar o app apenas na VM descartável do GitHub Actions.

O instalador aprovado é publicado na release Windows windows-v1.1.2. O Mac usa sua própria release; os instaladores de versões anteriores continuam disponíveis.

A 1.1.2 foi validada no [workflow 39783492094](https://github.com/cnolli-fl/Caeser/actions/runs/39783492094): 39 testes de lógica/processos e mais 1 teste real das ferramentas incluídas, além da interação com a interface, abertura dos pacotes e atualização/desinstalação. Os pacotes publicados são os mesmos arquivos testados nesse workflow; as notas, os links e o changelog foram atualizados depois, sem modificar o código funcional.

Testes automatizados precisam cobrir validação de links, argumentos de formato/qualidade, parsing de progresso, erros do Spotify, saída UTF-8, caminhos com espaços e cancelamento dos subprocessos. Testar downloads reais separadamente: serviços externos podem bloquear conexões de servidores na nuvem.

As capturas são inspecionadas para conferir a aparência; o teste também verifica os limites horizontais dos controles e o contraste do seletor nos dois temas. Um teste no runner Windows do GitHub não comprova, sozinho, compatibilidade com Windows 10, todas as escalas DPI, Narrator ou o funcionamento dos serviços externos.

## Releases no GitHub

Cada plataforma tem sua numeração. A distribuição Windows usa a tag windows-v1.1.2; o Mac usa v2.1.1. O README principal mantém links separados. Os nomes dos instaladores públicos identificam plataforma e arquitetura:

- `Caeser-X.Y.Z-macOS-AppleSilicon.dmg`
- `Caeser-X.Y.Z-Windows-x64-Setup.exe`

Os fontes correspondentes das ferramentas e as instruções de construção ficam na área pública Fontes de terceiros, com links diretos nas notas dos instaladores. Os hashes SHA-256 ficam nas próprias notas. ZIPs alternativos e arquivos de checksums continuam sendo gerados para validação local, mas não são anexados às releases de aplicativo.

As notas da release e o README devem apresentar links separados para **Baixar para Mac** e **Baixar para Windows 10/11 x64**, com os requisitos de cada um. O GitHub lista esses arquivos na seção Assets; não é necessário criar outro repositório.

A publicação Windows não renomeia arquivos de Mac nem reaproveita seus binários. Antes de publicar qualquer atualização, executar os testes, conferir versões e checksums e preservar os instaladores das releases anteriores.

Referência: [releases e arquivos de distribuição no GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
