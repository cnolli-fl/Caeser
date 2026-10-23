# Caeser 2.1.0 para Windows

Atualizações pelo aplicativo, mantendo o design clean, a prévia, a fila e o histórico.

## Novidade

- **Baixar no aplicativo:** progresso e opção de cancelar, sem abrir o navegador.
- Tamanho e SHA-256 conferidos antes de habilitar **Instalar e reiniciar**. Arquivos alterados ou incompletos não são executados.
- Ao confirmar, a fila é salva e pausada, o instalador aplica a atualização e reabre o Caeser.
- Sem reinício forçado do computador, sem interromper downloads em andamento e sem desativar avisos de segurança do Windows.
- Arquivos temporários antigos conhecidos são limpos depois, sem apagar músicas, vídeos ou dados do aplicativo.

## Primeira instalação

Baixe **Caeser-2.1.0-Windows-x64-Setup.exe**, feche o Caeser e execute o instalador mantendo a pasta sugerida. Preferências, histórico e fila ficam preservados.

**É preciso instalar a 2.1.0 manualmente uma vez. Nas próximas releases compatíveis, você poderá baixar, verificar e iniciar a instalação por dentro do Caeser.** Cópias portáteis e releases sem metadados de integridade usam a alternativa manual. O pacote completo ainda é transferido pela internet; não há atualização diferencial.

Requer **Windows 10 22H2 ou Windows 11 x64 (Intel/AMD)**. Ferramentas e runtime já incluídos; não é necessário instalar .NET, Python, FFmpeg, Deno ou yt-dlp separadamente. Instalação para o seu usuário, sem exigir administrador.

O instalador continua **sem assinatura Authenticode**. Os avisos normais de fornecedor desconhecido ou SmartScreen podem aparecer. Conferir o hash via GitHub/TLS verifica integridade; não é uma assinatura independente do editor. ARM64 e 32 bits não são alvos validados.

## Verificação

Testes de lógica/processos, transporte simulado do atualizador, arquivos inválidos/alterados, cancelamento, redirecionamentos não confiáveis e limpeza limitada ao cache. Interface real com download e instalação pronta nos temas claro/escuro, Escape para sair e instalação desabilitada antes da conferência. Ferramentas incluídas, conversão MP3 real de áudio original local, instalação/atualização/desinstalação e reabertura real pelo instalador no runner Windows.

Isso não substitui o ciclo completo entre duas futuras releases públicas em um PC real nem a confirmação manual de eventuais avisos do SmartScreen. Spotify continua fornecendo metadados sem login; o áudio vem do YouTube. A qualidade MP3 e o restante do app não mudam.

[Detalhes do atualizador](https://github.com/cnolli-fl/Caeser/blob/windows-v2.1.0/docs/ATUALIZACAO-WINDOWS-NO-APP.md) · [Mac 3.0.1, sem mudanças](https://github.com/cnolli-fl/Caeser/releases/tag/v3.0.1)

<details>
<summary>Integridade e fontes de terceiros</summary>

[Fontes correspondentes e receitas](https://github.com/cnolli-fl/Caeser/releases/download/fontes-terceiros/Caeser-2.1.0-Windows-x64-Fontes-Terceiros.zip). Licenças continuam na instalação. Para usar o app, baixe somente o instalador.

</details>
