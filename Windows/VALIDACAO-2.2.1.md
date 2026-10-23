# Validação do Windows 2.2.1

Execução aprovada: [39903516487 — pacote 55](https://github.com/cnolli-fl/Caeser/actions/runs/39903516487), em 23/10/2026. Código executável: `890f3c9`. Documentação finalizada depois, sem alterar o código do pacote testado.

## Correções verificadas

- Notificações gerais usam `PropertyChangedEventArgs(string.Empty)`, conforme o contrato do [WinUI](https://learn.microsoft.com/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.data.inotifypropertychanged), em vez de `null`.
- Título/capa públicos são informados primeiro; a extração acrescenta os detalhes sem substituir a capa já exibida. Uma falha do extrator não descarta metadados públicos válidos.
- Campos opcionais do comando de prévia usam `--output-na-placeholder null`; a ausência de formatos não bloqueia a consulta de metadados. Nenhuma dessas opções altera os comandos de download.
- Cancelamento/troca de link rejeitam respostas antigas. Limpar o campo recolhe a prévia e desabilita o botão real; a chegada de dados atualiza os textos XAML, não só o modelo.
- Botões do topo com altura de 34 DIP, ícones em áreas de 34×34 DIP, foco/estados nativos e alinhamento uniforme. A ação principal mantém a forma arredondada e o destaque violeta.
- Texto branco sobre violeta: contraste calculado de 6,19:1 normal, 5,26:1 hover e 7,76:1 pressionado. Alto contraste usa as cores do Windows. A skill Apple Design orientou consistência de tamanhos, estados perceptíveis, feedback de carregamento e preservação da identidade; controles, ícones e fonte continuam sendo do Windows.

## Testes aprovados

- 61 testes de lógica/processos; um teste adicional com ferramentas empacotadas. Na primeira etapa, esse último é ignorado e depois executado com o pacote completo.
- Prévia real de áudio original servido em loopback, sem autor ou capa, usando o mesmo comando/encaminhador nativo do aplicativo. Depois, download e conversão real para MP3.
- Testes determinísticos de dados públicos antes da extração, falha do serviço/extrator, campos nulos, título com aspas/acentos/percentual, cancelamento, rejeição de capa local e preservação da capa durante enriquecimento.
- Interface real: busca assíncrona, troca de link durante a busca, comparação entre o modelo e os controles visíveis, botão Baixar habilitado/desabilitado e estados normal/hover/pressionado. 18 capturas por rodada nos dois temas, incluindo prévias de vídeo e Spotify.
- Interface e ferramentas testadas no pacote portátil e instalado. Atualização a partir da 1.1.1 e da 2.1.0 publicadas, instalação pelo contrato do atualizador, reabertura/desinstalação e preservação de arquivos extras.
- Instalador online: pacote válido, corrompido, truncado, redirecionamento indevido e cancelamento pelo diálogo. SHA-256 e tamanho fixados na construção; opções de fixture ausentes da versão pública.

## Distribuição

- Online: **248.832 bytes (~249 KB)**.
- Completo: **136.001.000 bytes (136,0 MB)**; é esse pacote que o online baixa durante a instalação.
- Instalação medida após atualizar da 2.1.0: **367.526.336 bytes**, 328 arquivos, incluindo os arquivos extras inseridos para comprovar preservação.
- Mantidas as ferramentas compartilhadas e os avisos legais agrupados da 2.2.0. Sem mudanças no código ou pacote Mac 3.0.1.

## Limites

O runner é Windows Server 2025 x64. Os testes determinísticos não dependem de contas, músicas de terceiros ou serviços externos. Consultas HTTPS reais aos endpoints públicos YouTube/Spotify foram conferidas separadamente no ambiente local e retornaram título e URL de capa; isso não testa todas as redes, CDNs, vídeos ou álbuns. Restrições, limites dos serviços, outras escalas de tela e acessibilidade em PCs Windows 10/11 ainda exigem validação manual. Uma prévia básica não garante que o conteúdo possa ser baixado.

Sem assinatura Authenticode; SmartScreen/Defender/UAC não foram desativados. Spotify fornece os metadados e o áudio continua vindo do YouTube.
