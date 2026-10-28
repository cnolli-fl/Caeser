# Windows · Caeser 2.3.0

A identidade azul do Mac chega ao Windows, com novidades dentro do aplicativo e um fluxo mais direto para baixar.

## O que mudou

- **Tema Ocean:** fundo azul, campos em tons próximos, texto claro e nota musical branca. Mesma organização, com controles nativos do Windows e alto contraste do sistema preservado.
- **O que mudou, dentro do app:** uma janela independente aparece uma vez por versão, inclusive sem internet. Pode ser reaberta pelo botão **Novidades desta versão** na barra superior, sem bloquear os downloads.
- **Adicionar e já baixar:** novos links válidos iniciam ou retomam a fila. Entradas inválidas e repetidas não retomam uma fila pausada; as opções de pausar e organizar continuam disponíveis.
- Prévia progressiva, fila, histórico, preferências por origem, MP3 em qualidade máxima e atualização pelo aplicativo preservados.

## Baixar

- **[Instalador online — recomendado](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.3.0/Caeser-2.3.0-Windows-x64-Online.exe):** pequeno; baixa o pacote completo durante a instalação, com progresso, cancelamento e conferência de integridade.
- **[Instalador completo](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.3.0/Caeser-2.3.0-Windows-x64-Setup.exe):** alternativa para instalar offline.

Escolha somente um. O online transfere o pacote completo depois, não é uma atualização diferencial.

Online com **254 KB**; pacote completo com **135,6 MB**. A instalação mantém **328 arquivos**, com as ferramentas e licenças organizadas.

Quem já tem uma versão compatível instalada pode usar **Verificar atualizações → Baixar no aplicativo → Instalar e reiniciar**. Fila, histórico, preferências e arquivos baixados são preservados.

Requer Windows 10 22H2 ou Windows 11 x64 (Intel/AMD). Ferramentas e runtimes incluídos; não precisa instalar Python, .NET, FFmpeg ou yt-dlp separadamente.

Os instaladores continuam **sem assinatura Authenticode**: podem aparecer avisos de fornecedor desconhecido/SmartScreen. As proteções do sistema não foram desativadas.

Spotify fornece os metadados; o áudio é encontrado no YouTube. Os serviços externos podem limitar consultas e downloads.

## Validação

66 testes de lógica/processos, um teste de ferramentas reais e 20 capturas da interface por cópia testada. Verificados instalação, atualização, reabertura, desinstalação, cancelamento, integridade e preservação dos dados/arquivos extras. Áudio original local convertido para MP3; sem baixar músicas de terceiros nos testes. O runner não substitui testes manuais em todos os PCs Windows 10/11.

[Execução aprovada](https://github.com/cnolli-fl/Caeser/actions/runs/40755874879) · [Verificações e limites](https://github.com/cnolli-fl/Caeser/blob/windows-v2.3.0/Windows/VALIDACAO-2.3.0.md).

<details>
<summary>Integridade e fontes de terceiros</summary>

[Fontes correspondentes e receitas](https://github.com/cnolli-fl/Caeser/releases/download/fontes-terceiros/Caeser-2.3.0-Windows-x64-Fontes-Terceiros.zip). As ferramentas não foram atualizadas nesta versão. Avisos de licença permanecem no pacote.

</details>

[Mac · Caeser 3.1.1](https://github.com/cnolli-fl/Caeser/releases/tag/v3.1.1) · [Histórico de versões Windows](https://github.com/cnolli-fl/Caeser/releases?q=tag%3Awindows-v).
