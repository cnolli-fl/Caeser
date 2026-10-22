# Mudanças

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
