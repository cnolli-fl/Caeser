# Mudanças

## macOS 3.1.0 — 2026-10-26

- Nova identidade azul com texto claro e campos em tons próximos, sem painel branco.
- Nota musical branca e ícone no formato nativo do macOS Tahoe, corrigindo a moldura cinza do ícone legado.
- Adicionar novos links válidos inicia ou retoma a fila em uma ação; entradas inválidas ou repetidas não retomam a fila pausada.
- Preservados fila, histórico, preferências, formatos e ferramentas incluídas. Windows permanece na 2.2.1.

## Windows 2.2.1 — 2026-10-23

- Corrigida a notificação de propriedades para o formato exigido pelo WinUI, atualizando prévia, textos e estado dos controles após operações assíncronas.
- Título e capa via dados públicos YouTube/Spotify enquanto duração e correspondência são buscadas. Falhas de extração não descartam uma prévia básica válida.
- Campos opcionais ausentes do yt-dlp agora usam `null` válido no JSON; prévia não exige formatos disponíveis para download.
- Cancelamento e troca de link impedem que resultados antigos substituam a prévia atual. Opção de tentar novamente no formulário e ilustração discreta quando não houver capa.
- Botões alinhados, altura consistente, estados normal/hover/pressionado em violeta e mais opções da fila com ícone nativo. Foco, contraste e comportamento desabilitado preservados.
- Novos testes do fluxo assíncrono, dos controles visíveis e da prévia com as ferramentas reais incluídas. Instalador online pequeno e pacote enxuto mantidos; Mac sem alterações.

## Windows 2.2.0 — 2026-10-23

- Instalador online de 248.832 bytes (~249 KB). Pacote completo de 166,3 para 136,0 MB (18,2% menor); instalação de 425,9 para 367,5 MB (13,7% menor), com 3.283 → 328 arquivos medidos após atualizar da 2.1.0.
- Instalador online nativo pequeno, com download posterior do pacote completo, progresso e cancelamento.
- URL de versão, tamanho e SHA-256 fixados na construção; conferência antes de executar e preservação dos controles de segurança do Windows.
- Instalador completo mantido como alternativa offline e para atualizar pelo aplicativo a partir da 2.1.0.
- Python compartilhado entre yt-dlp e spotDL; bibliotecas compartilhadas entre FFmpeg e FFprobe, sem remover extratores ou codecs.
- Avisos legais completos agrupados em ZIP, menos arquivos e compressão melhorada.
- Migração dos arquivos registrados antigos preservando arquivos extras do usuário, fila, histórico e preferências.
- Testes de integridade, cancelamento, instalação e redução real do pacote. Design e funções preservados; Mac permanece na 3.0.1, sem alterações.

## Windows 2.1.0 — 2026-10-22

- Download de atualizações dentro do aplicativo, com progresso e cancelamento.
- Conferência de origem, tamanho e SHA-256 antes de habilitar **Instalar e reiniciar**, com nova conferência antes de executar.
- Fila salva e pausada antes da instalação; reabertura do Caeser pelo instalador, sem reinício forçado do computador.
- Mantidos os avisos normais de segurança do Windows. Limpeza dos arquivos temporários conhecidos após um dia, sem remover dados do usuário.
- Alternativa manual para cópias portáteis ou releases incompatíveis. A primeira instalação da 2.1.0 ainda é manual; as próximas releases compatíveis podem usar o fluxo integrado.
- Testes de integridade, cancelamento, alterações de arquivo, interface nos dois temas e instalação com reabertura no runner Windows. Mac permanece na 3.0.1.

## macOS 3.0.1 e Windows 2.0.1 — 2026-10-22

- Histórico com proporções equilibradas, linhas compactas, datas e ações alinhadas.
- Títulos longos e mensagens de erro não aumentam a janela; detalhes completos continuam nas dicas de contexto.
- Cabeçalho e controles permanecem visíveis durante a rolagem, com estado vazio mais organizado.
- Windows: o diálogo acompanha o tema da janela. Mac: altura ajustada à quantidade de registros, com limite para listas grandes.
- Preservados histórico existente, fila, preferências, arquivos baixados e identidade visual.

## Windows 2.0.0 — 2026-10-22

- Funções aprovadas no Mac: prévia contextual, correspondência Spotify → YouTube preservada no download, fila serial persistente, histórico, preferências por origem e aviso de novas versões Windows.
- Colagem de vários links, organização dos pendentes, cancelamento individual, pausa entre downloads e recuperação ao reabrir.
- Mantidos o design clean, as logos, a qualidade MP3 máxima e o pacote organizado para Windows 10 22H2/11 x64.
- Testes de lógica/processos, renderização claro/escuro e novos estados de interface, ferramentas reais e instalação/desinstalação no runner Windows.

## macOS 3.0.0 — 2026-10-22

- Prévia de vídeos e músicas, incluindo a correspondência Spotify → YouTube usada no download.
- Fila persistente com progresso individual, ordem editável, pausa entre downloads e recuperação após reabrir.
- Histórico local e preferências por origem, mantendo o design atual.
- Aviso de novas releases Mac e botão para baixar o instalador oficial.
- Preservado o catálogo interno obrigatório do provedor YouTube Music; nova checagem de runtime no pacote.
- Evolução aprovada a partir do candidato 2.2.0; Windows continua na 1.1.2. Detalhes em [Validação das novas funções](docs/VALIDACAO-2.2.0.md).

## macOS 2.1.1 — 2026-10-22

- Distribuição menor sem mudar o design, as logos, os formatos ou a qualidade dos downloads.
- Instalador DMG de 165,3 para 105,4 MB (36,2% menor); ZIP de 159,6 para 100,2 MB (37,2% menor).
- Conteúdo do app de 226,5 para 157,7 MB, com 29 arquivos regulares em vez de 110; fontes separados e licenças agrupadas, sem apagar os avisos obrigatórios.
- FFmpeg e FFprobe compartilham suas próprias bibliotecas, sem depender de Homebrew.
- yt-dlp e spotDL compartilham uma única cópia do Python e das dependências, apenas para Apple Silicon; eliminados dados duplicados e a interface web independente do spotDL, não usada pelo app.
- Interface declarada como português brasileiro. Removidos os demais catálogos de tradução, preservando o pequeno catálogo inglês interno obrigatório do parser de metadados e os textos originais das licenças.
- Fontes de FFmpeg/LAME e receitas de compilação em um ZIP separado, disponível na área Fontes de terceiros; avisos de licença permanecem no app.
- Empacotamento com lista explícita dos arquivos necessários, sem fontes/caches de compilação nem metadados extras do Finder no ZIP.
- Avisos de terceiros preservados em um único `Licenses.zip`, evitando milhares de arquivos soltos dentro do aplicativo.
- Verificação de assinatura, arquitetura, bibliotecas internas, extratores, MP3 e combinação de vídeo/áudio antes de gerar a distribuição.
- Validação local: 17 testes automatizados, abertura e alternância YouTube/Spotify, chamada das duas ferramentas pelo Swift, download local convertido em MP3 e extração em caminho com espaços e acentos. Os 1.752 extratores e a lista de codecs permanecem iguais aos da distribuição anterior.
- Downloads organizados: somente o instalador nas releases de aplicativo, hashes nas notas e fontes de terceiros em uma área separada, com links diretos.
- ZIPs alternativos e arquivos de checksums retirados dos downloads públicos, com cópias locais preservadas. Os instaladores das versões anteriores e o aplicativo Windows 1.1.2 permanecem disponíveis.

## Windows 1.1.2 — 2026-10-22

- Corrigido o fechamento ao passar o mouse e clicar em Spotify: o estado visual usava um recurso de tema inexistente no WinUI.
- Seletor estabilizado para cliques rápidos, arraste nas duas direções, teclado e movimento reduzido, preservando o design e as logos originais.
- Instalador reduzido de 382 para 166 MB (cerca de 57%); ZIP portátil de 443 para 215 MB (cerca de 51%).
- Pasta principal organizada em Caeser.exe, Aplicativo, Documentacao e LEIA-ME.txt, com um pequeno launcher nativo.
- Interface e instalador em português brasileiro; removidos satélites de idiomas não utilizados e componentes de IA/ML, Search e Widgets, mantendo o fallback en-US obrigatório do WinUI.
- Fontes correspondentes das ferramentas publicados em ZIP separado; avisos de licença mantidos na instalação.
- Atualização da 1.1.1 limpa apenas os arquivos registrados pelo instalador antigo, preservando preferências, downloads e arquivos extras do usuário.
- Relatório local da última falha inesperada, sem envio automático.
- Validação no Windows: 40 testes da lógica/processos/ferramentas, interação real com a interface nos dois temas, MP3, ZIP extraído em caminho com acentos e espaços, atualização da 1.1.1 e desinstalação com preservação de arquivo do usuário.
- Mac 2.1.0 e os arquivos das releases anteriores preservados.

## Windows 1.1.1 — 2026-10-22

- Primeira distribuição Windows x64, com instalador por usuário e ZIP portátil.
- Interface nativa WinUI 3, preservando a identidade visual e as logos originais.
- YouTube e sites compatíveis com yt-dlp: qualidade de vídeo, MP4, WebM e MP3 na configuração máxima de conversão.
- Links públicos do Spotify usados para buscar correspondências no YouTube/YouTube Music, sem baixar o áudio diretamente do Spotify.
- Seletor animado, temas claro/escuro, atalhos, pasta persistente, progresso, logs e cancelamento de subprocessos.
- yt-dlp, FFmpeg/FFprobe, Deno, spotDL e runtimes incluídos; sem exigir instalações separadas de ferramentas.
- Testes automatizados da lógica, processos e pacote; abertura real da interface, download local convertido para MP3 e instalação/desinstalação no runner Windows.
- Distribuição gratuita sem assinatura Authenticode. Testes em PCs reais com Windows 10/11 e disponibilidade dos serviços externos continuam sendo limites de validação.
- Numeração independente por plataforma: Windows 1.1.1 não substitui nem renomeia o Mac 2.1.0.

## 2.1.0 — 2026-10-21

### Aplicativo pronto para instalar

- Ferramentas dentro do aplicativo: yt-dlp, FFmpeg, FFprobe, spotDL e Deno.
- spotDL recompilado com yt-dlp atualizado; busca no YouTube priorizada para maior compatibilidade sem login.
- Uso sem Homebrew, Python, Xcode ou instalação inicial do suporte Spotify.
- Ferramentas internas prioritárias e ambiente isolado das instalações externas.
- Receita de distribuição `.dmg`/`.zip` com assinatura local gratuita, sem notarização.
- Downloads de executáveis com SHA-256 fixado; FFmpeg/LAME compilados sem dependências do Homebrew.
- Licenças, fontes correspondentes de FFmpeg/LAME e instruções de instalação no pacote.
- Dois novos testes de localização das ferramentas e isolamento do ambiente (17 no total).
- Instaladores DMG/ZIP e hashes SHA-256 na release do GitHub; Windows e Mac Intel não incluídos.

### Spotify via YouTube

- Nova opção Spotify para links públicos de música, álbum e playlist.
- Identificação automática ao colar um link de open.spotify.com ou uma URI spotify:.
- Busca automática de correspondências no YouTube, com YouTube Music como alternativa de busca.
- MP3 na melhor configuração de qualidade variável, com capa e informações da faixa.
- Suporte já incluído nos instaladores; instalação opcional em ambiente separado para a compilação de desenvolvimento.
- Nenhum pedido de login no fluxo padrão de links públicos.
- Progresso por músicas processadas e tratamento de erros parciais em playlists.

### Interface macOS

- Revisão baseada na Apple Design Skill e nas Human Interface Guidelines.
- Aparência clara/escura acompanhando o sistema e cores semânticas.
- Liquid Glass concentrado nas ações, com superfícies de conteúdo mais legíveis.
- Seleção de origem, campo com botão Colar e configurações apropriadas a cada tipo de download.
- Ferramentas e registro técnico recolhíveis, com opções de copiar e limpar.
- Erros e resultados na própria janela, ação Mostrar no Finder e pasta de destino persistente.
- Comandos no menu Downloads, atalhos de teclado e respeito a Reduzir Movimento/Transparência.
- Seletor YouTube/Spotify com indicador roxo que desliza por clique ou arraste, mantendo acesso por teclado.
- Transição discreta do conteúdo e animações desativadas com Reduzir Movimento.
- Logo interna original preservada em 1254 × 1254 pixels, com renderização nativa e interpolação de alta qualidade em telas Retina, sem redesenho ou WebKit.
- Ícone original do aplicativo preservado.
- Textos do Spotify mais concisos, sem o selo redundante de áudio no título.
- Caminho da pasta de destino visível, abreviado com `~` quando possível.
- Erros com símbolo e texto, além da ação Tentar novamente quando as ferramentas estão disponíveis.
- Ação principal com título e SF Symbol visíveis na toolbar.
- Marcas oficiais de YouTube e Spotify em PNG transparente de alta resolução, no seletor e na indicação da origem do áudio; ícone e logo do Caeser inalterados.
- PNGs das marcas preparados diretamente das curvas vetoriais nas escalas 1×, 2× e 3×, sem redimensionamento durante a exibição; círculo e cantos preservados, com antialiasing no tamanho final.

### Confiabilidade

- Leitura da saída dos processos sem perder caracteres UTF-8 ou a última mensagem de erro.
- Cancelamento com encerramento do grupo do processo quando disponível.
- Argumentos passados diretamente aos executáveis e configuração externa do yt-dlp ignorada.
- Testes de validação de links, parâmetros, dependências, progresso, saída e cancelamento.
