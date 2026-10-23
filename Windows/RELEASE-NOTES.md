# Caeser 2.2.1 para Windows

Correções da prévia de vídeos/músicas e dos botões, mantendo o design, as logos e o pacote enxuto da 2.2.0.

Online com **249 KB**; completo com **136,0 MB**. O online baixa esses 136,0 MB durante a instalação.

## O que foi corrigido

- **Prévia progressiva:** título e capa usam os dados públicos do YouTube/Spotify, sem esperar toda a extração. Duração, artista e correspondência no YouTube são acrescentados quando disponíveis.
- Corrigida a notificação de mudanças exigida pelo WinUI para atualizar os controles depois da busca.
- Campos opcionais ausentes, como capa ou duração, não tornam o JSON da prévia inválido. A busca de metadados não exige formatos disponíveis para baixar.
- Se a extração completa falhar, uma prévia básica já carregada permanece visível. Trocar ou apagar o link cancela a busca anterior e impede títulos/capas antigos no novo link.
- Opção de **Tentar prévia novamente**, sem precisar apagar e colar tudo; imagem discreta quando não houver capa.
- **Botões alinhados:** altura consistente no topo, destaque violeta também no hover e ao pressionar, estados desabilitados e foco de teclado preservados. Mais opções da fila agora usa o ícone nativo correto.
- Sem redesenho, mudanças na fila/histórico ou redução da qualidade MP3. O Mac permanece na 3.0.1, sem alterações.

## Baixar

- **[Instalador online — recomendado](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.2.1/Caeser-2.2.1-Windows-x64-Online.exe):** pequeno; baixa o pacote completo durante a instalação, com progresso e cancelamento.
- **[Instalador completo](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.2.1/Caeser-2.2.1-Windows-x64-Setup.exe):** alternativa para guardar e instalar offline.

Escolha somente um. O online transfere o pacote completo depois, não é uma atualização diferencial. Quem já tem a 2.1.0 ou posterior instalada pode usar **Instalar e reiniciar** no aplicativo.

Windows 10 22H2 ou Windows 11 x64, Intel/AMD. Ferramentas e runtimes incluídos; não precisa instalar Python, .NET, FFmpeg ou yt-dlp separadamente. Feche o Caeser antes de instalar. Downloads, preferências, fila e histórico são preservados.

Os instaladores continuam sem assinatura Authenticode. Avisos de fornecedor desconhecido/SmartScreen podem aparecer; os controles de segurança não foram desativados. O instalador online confere tamanho e SHA-256 fixados na construção antes de iniciar o pacote.

## Testes e limites

Testes do fluxo real assíncrono de prévia até os controles XAML, resultado antigo após troca de link, atualização do botão Baixar, ausência de campos e falha dos serviços/extratores. Prévia com as ferramentas empacotadas usando áudio original local; interface em claro/escuro, ZIP portátil, instalação, atualização e reabertura do aplicativo. Os testes não baixam músicas de terceiros.

As consultas públicas YouTube/Spotify foram verificadas separadamente. Os serviços podem limitar consultas, vídeos privados/restritos podem não ter prévia e a extração completa pode continuar indisponível. Título/capa básicos não comprovam que o conteúdo poderá ser baixado. Spotify fornece metadados; o áudio vem do YouTube.

[Execução aprovada](https://github.com/cnolli-fl/Caeser/actions/runs/39903516487) · [Verificações e limites](https://github.com/cnolli-fl/Caeser/blob/windows-v2.2.1/Windows/VALIDACAO-2.2.1.md).

<details>
<summary>Integridade e fontes de terceiros</summary>

[Fontes correspondentes e receitas](https://github.com/cnolli-fl/Caeser/releases/download/fontes-terceiros/Caeser-2.2.1-Windows-x64-Fontes-Terceiros.zip). Avisos de licença permanecem na instalação, agrupados em ZIP.

</details>
