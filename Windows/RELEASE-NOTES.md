# Caeser 2.0.1 para Windows

Pequena atualização visual do histórico: linhas compactas, títulos e mensagens longas contidos, datas visíveis, botões alinhados e tema herdado da janela principal. Mantidos fila, histórico salvo, preferências e arquivos.

Prévia, fila de downloads, histórico e aviso de atualização, mantendo o visual clean e as logos do Caeser.

[Baixar o instalador](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.0.1/Caeser-2.0.1-Windows-x64-Setup.exe)

Destinado a Windows 10 22H2 e Windows 11 x64 (Intel/AMD). As ferramentas e o runtime já estão incluídos; não é necessário instalar Python, .NET ou Homebrew.

## Novidades

- Prévia com capa, título, autor e duração quando disponíveis.
- Músicas individuais do Spotify mostram o vídeo correspondente no YouTube e usam essa mesma correspondência no download. Sem login; o áudio vem do YouTube.
- Cole vários links, um por linha, e use Ctrl+Enter. A fila é serial, permite organizar/remover os pendentes, cancelar o atual e pausar antes do próximo. Cada item preserva suas opções e pasta.
- Histórico local dos últimos 100 registros, com abrir pasta e repetir tentativa. Limpar os registros não apaga arquivos.
- Fila restaurada pausada ao reabrir; preferências lembradas por origem.
- Aviso de novas versões Windows e botão para baixar o instalador oficial. A instalação continua manual, com o Caeser fechado. Versões antigas precisam instalar esta atualização uma vez para ganhar o aviso.
- MP3 na melhor qualidade de conversão, temas claro/escuro/alto contraste e seletor original preservados.

Execute o instalador e mantenha o destino sugerido para atualizar. Preferências ficam em `%LOCALAPPDATA%\Caeser`. O instalador ainda não tem assinatura Authenticode. Windows ARM64 e 32 bits não são alvos validados.

Os fontes correspondentes das ferramentas ficam na [área de desenvolvedores](https://github.com/cnolli-fl/Caeser/releases/download/fontes-terceiros/Caeser-2.0.0-Windows-x64-Fontes-Terceiros.zip). Para usar o app, basta o instalador. A release inclui apenas esse instalador como anexo, além dos arquivos Source code adicionados automaticamente pelo GitHub.

Validação e limites descritos em [VALIDACAO-2.0.0.md](VALIDACAO-2.0.0.md). Prévias e buscas dependem da disponibilidade dos serviços; a busca automática pode encontrar outra versão da música.
