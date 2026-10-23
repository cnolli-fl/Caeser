# Atualização pelo aplicativo — candidato Windows 2.1.0

A implementação permanece na branch `codex/windows-in-app-updates`, sem mudar a release pública 2.0.1 ou o aplicativo Mac.

## Fluxo

1. Consultar as releases Windows estáveis oficiais, como antes.
2. Escolher **Baixar no aplicativo**, acompanhar a porcentagem e cancelar se desejar.
3. O arquivo precisa ter tamanho e SHA-256 correspondentes aos metadados publicados pelo GitHub. Sem esses dados, permanece disponível o download manual.
4. Só depois da conferência aparece **Instalar e reiniciar** habilitado. **Depois** descarta o arquivo baixado sem instalar.
5. Salvar e pausar a fila, revalidar o arquivo e abrir o instalador oficial. O instalador mostra progresso e erros, atualiza no mesmo diretório e reabre o Caeser. A fila volta pausada.

Atualizações não são instaladas automaticamente no início. Não instala durante downloads de mídia. Cópias portáteis e instaladores anteriores à 2.1.0 usam o caminho manual; o modo integrado exige uma instalação registrada para o mesmo usuário. Para obter o recurso, é necessário instalar a primeira versão 2.1.0 manualmente uma vez. O fluxo integrado serve para as versões seguintes compatíveis.

O pacote completo ainda é transferido pela internet. Não há atualização diferencial ou promessa de redução no tamanho do download.

## Integridade e segurança

- URLs exatas do próprio repositório, via HTTPS. Redirecionamentos somente para domínios de distribuição conhecidos do GitHub.
- Limite de 512 MiB, até cinco redirecionamentos e quinze minutos; cancelamento interrompe a transferência e remove o arquivo parcial.
- Conferência de tamanho, SHA-256 e cabeçalho executável. Nova conferência com o arquivo bloqueado para escrita imediatamente antes de executá-lo.
- O marcador de origem da internet do Windows é preservado; a abertura usa o mecanismo normal do sistema. Sem `Unblock-File`, alteração de antivírus, supressão de SmartScreen/UAC ou reinício forçado do computador.
- O instalador continua sem Authenticode. Hash conferido via GitHub/TLS verifica integridade, não constitui assinatura independente do editor. Avisos normais do Windows podem exigir confirmação.
- Arquivos temporários antigos conhecidos são limpos em uma inicialização posterior, após um dia. Limpeza limitada ao cache do atualizador, sem seguir junções ou links e sem remover arquivos desconhecidos.
- Falha ao salvar a fila ou abrir o instalador mantém o aplicativo disponível. Nenhum arquivo de música/vídeo é apagado.

## Design e testes

Mantido o diálogo WinUI, tipografia, cores semânticas e temas existentes. Aplicada Apple Design: `progress-indicators.md › Best practices` recomenda progresso determinado e cancelamento; `modality.md › Best practices` orienta uma tarefa curta, clara e com saída explícita. Sem mudar a tela principal.

Testes de transporte simulado cobrem download válido, corrupção, executável inválido, alteração posterior, tamanho inesperado, falta de hash, cancelamento e redirecionamento não confiável. Nenhuma versão pública falsa é criada. Testes de UI mostram download e arquivo pronto nos dois temas, com instalação inicialmente desabilitada e Escape para sair. O teste do instalador na VM descartável também verifica o parâmetro de atualização e a reabertura real, preservando arquivo extra do usuário.

Essas verificações não substituem o ciclo completo entre duas futuras releases públicas em um PC do usuário nem a confirmação manual de eventuais avisos do SmartScreen.
