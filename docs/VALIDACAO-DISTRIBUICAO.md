# Validação local do pacote completo

Data: 2026-10-21. Versão do app: 2.1.0. Plataforma de teste: Mac Apple Silicon,
macOS 26.5.2. Distribuição ad-hoc, sem Developer ID nem notarização.

## Verificações

- Build Release do projeto Xcode para arm64.
- 17 testes automatizados em cinco grupos, sem falhas.
- SHA-256 dos executáveis baixados, dos arquivos-fontes e dos pacotes finais.
- Assinatura local do app e verificação recursiva de integridade.
- Arquitetura arm64 e bibliotecas de sistema dos cinco executáveis.
- Auditoria das bibliotecas nativas incorporadas: 141 no spotDL e 103 no yt-dlp,
  sem dependências absolutas externas ao sistema.
- Inicialização de yt-dlp/spotDL, execução de JavaScript no Deno e conversão de
  áudio sintético para MP3 com FFmpeg, usando HOME temporário e PATH apenas com
  ferramentas internas e diretórios do sistema.
- Download real de um vídeo curto do YouTube, com vídeo e áudio separados,
  seguido de união em MP4 pelo FFmpeg independente.
- Download real a partir de um link público do Spotify, com busca no YouTube,
  conversão MP3 e capa, título, artista e álbum conferidos via FFprobe. Relatório
  de erros vazio; nenhum login pessoal utilizado.
- Verificação dos arquivos ZIP e DMG e abertura do app diretamente da imagem
  montada somente para leitura. A interface reconheceu as ferramentas internas.

## Correção encontrada durante os testes

O executável oficial spotDL 4.5.2 falhou com HTTP 403 no download do YouTube. O
pacote entregue usa spotDL 4.5.2 recompilado sem alterações no código, com yt-dlp
2026.08.19 e dependências fixadas. O provider YouTube foi priorizado, mantendo
YouTube Music como alternativa de busca. O teste real passou após essa mudança.

## Limites desta validação

O Homebrew não foi desinstalado do computador de testes: os processos foram
isolados por PATH/configuração e suas bibliotecas foram auditadas. Isso não
substitui testar em outro Mac físico sem ferramentas de desenvolvimento.

Não foram validados Macs Intel, todos os sites/formatos suportados pelas
ferramentas, todas as músicas/playlists, nem a primeira abertura de um download
com quarentena em outra máquina. Alterações dos serviços e bloqueios regionais
podem causar falhas. A distribuição sem notarização pode ser bloqueada pelo
Gatekeeper ou por políticas de dispositivos gerenciados.

A validação foi feita antes da publicação. Os instaladores aprovados são
distribuídos pela release 2.1.0 no GitHub, junto com os hashes SHA-256.
