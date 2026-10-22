# Validação do Caeser macOS 2.1.1

Data: 2026-10-22. Mac Apple Silicon com macOS 26.5.2 e Xcode 26.6.
Distribuição com assinatura local (ad-hoc), sem Developer ID nem notarização.

## Resultado

- Build Release arm64 concluído; versão 2.1.1, build 3, localização pt-BR.
- 17 testes automatizados em cinco grupos, sem falhas.
- Abertura da cópia extraída do ZIP e troca YouTube/Spotify verificadas na interface nativa.
- Inicialização das duas ferramentas pelo Process do Swift: yt-dlp 2026.08.19 e spotDL 4.5.2. O link relativo yt-dlp → spotdl foi preservado no ZIP e no DMG.
- 1.752 extratores, com saída idêntica à distribuição anterior; lista de codecs também idêntica.
- Arquitetura arm64, assinatura e dependências das ferramentas/bibliotecas conferidas. Auditoria de 141 bibliotecas nativas incorporadas ao runtime Python, sem dependências absolutas externas ao sistema.
- Conversão MP3 com qualidade 0, geração de vídeo/áudio e remux para MKV usando as ferramentas do pacote.
- Download de áudio original servido somente em loopback, convertido para MP3 de 10.751 bytes, verificado pelo FFprobe. O teste usou somente as ferramentas internas, HOME temporário e pasta com espaços e acentos.
- Deno executando JavaScript em ambiente isolado.
- Arquivos ZIP e fontes sem erro de CRC; hashes SHA-256 dos artefatos e ferramentas conferidos.
- DMG montado somente para leitura, assinatura recursiva verificada e imagem ejetada após o teste.
- Licenses.zip íntegro; avisos originais preservados. Catálogos internos limitados a português e ao pequeno fallback inglês exigido pelo parser.
- Ausência de Sources, caches de compilação, .DS_Store e metadados __MACOSX no ZIP do app.

## Tamanhos

Valores em bytes; os arquivos regulares não incluem pastas nem links.

| Item | 2.1.0 | 2.1.1 |
| --- | ---: | ---: |
| DMG | 165.349.828 | 105.437.109 |
| ZIP alternativo de validação local | 159.570.176 | 100.211.397 |
| Conteúdo do app | 226.456.893 | 157.656.438 |
| Arquivos regulares | 110 | 29 |

O download público da versão oferece o DMG. Os fontes de terceiros ficam disponíveis em uma área separada, com link direto nas notas. O ZIP alternativo e seu manifesto permanecem disponíveis localmente para validação e recuperação.

## Limites

O Homebrew não foi removido do Mac: os subprocessos foram isolados por ambiente e suas bibliotecas auditadas. Isso não substitui testar em outro Mac físico sem ferramentas de desenvolvimento. Esta rodada usou áudio original servido localmente, sem novos testes de faixas reais do Spotify/YouTube. Serviços externos, correspondências e restrições regionais podem variar.

Macs Intel, todos os formatos/sites, primeira abertura em outra máquina com quarentena e todas as políticas do Gatekeeper não foram validados. A assinatura local verifica a integridade, mas não equivale a notarização ou certificado de identidade da Apple.
