# Validação macOS 3.1.0 — 26/10/2026

- Suíte Swift: 35 testes executados com sucesso; um teste opcional com serviços externos não habilitado.
- Regressão da fila: novos links retomam a fila pausada em uma ação; entradas inválidas e repetidas mantêm a pausa. Processamento serial, cancelamento, histórico e persistência permanecem cobertos.
- Compilação Release arm64 com identificação `com.example.Caeser`, versão 3.1.0 e build 7; preserva os dados da instalação anterior.
- Ícone nativo `CaeserApp.icon` configurado como principal. Prévia nativa no Finder conferida sem a moldura cinza grossa; marca interna aprovada preservada.
- Verificação do pacote: assinatura local profunda, arquitetura arm64, bibliotecas internas, manifesto SHA-256, licenças e execução sem Homebrew ou configurações do usuário.
- yt-dlp, spotDL, FFmpeg/FFprobe e Deno verificados; catálogos internos obrigatórios preservados.
- Download real de áudio original servido em loopback e conversão para MP3: 10.751 bytes, sem dependências externas, caminho com espaços e acentos.
- DMG verificado pelo hdiutil e montado somente para leitura; assinatura profunda, versão 3.1.0 e identificação do aplicativo conferidas dentro do instalador.
- Ferramentas reutilizadas da distribuição instalada e fontes oficiais da release 3.0.1, com hash conferido. Nenhuma atualização das ferramentas nesta versão.

A distribuição continua com assinatura local (ad-hoc), sem notarização Apple. Não foi feito teste de download externo nesta rodada. Windows sem alterações.
