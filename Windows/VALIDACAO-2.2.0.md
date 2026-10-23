# Validação do Windows 2.2.0

Execução aprovada: [39900546450 — pacote 52](https://github.com/cnolli-fl/Caeser/actions/runs/39900546450), em 23/10/2026. Código executável: `8c9e6f2`. Notas e medições finalizadas depois, sem modificar código, configuração ou recursos do pacote testado.

## Tamanhos medidos

Comparação com o instalador público da 2.1.0, fixado por SHA-256, instalado no mesmo caminho temporário da VM:

| Medida | Windows 2.1.0 | Windows 2.2.0 |
| --- | ---: | ---: |
| Instalador online | — | 248.832 bytes (~249 KB) |
| Instalador completo | 166.256.037 bytes | 136.037.536 bytes (18,2% menor) |
| Conteúdo instalado após atualização | 425.853.559 bytes | 367.507.520 bytes (13,7% menor) |
| Arquivos regulares medidos | 3.283 | 328 (~90% menos) |

MB e KB são decimais. A soma em disco usa o tamanho lógico dos arquivos, não os blocos alocados pelo sistema de arquivos. A medição posterior inclui dois arquivos extras inseridos pelo teste para comprovar preservação. A quantidade pode variar com arquivos pessoais e instalações anteriores.

O instalador online transfere os mesmos 136,0 MB durante a instalação. Não é um aplicativo inteiro de 249 KB nem uma atualização diferencial. Ambos os instaladores entregam o mesmo app e ferramentas.

## Verificações aprovadas

- 55 testes de lógica/processos; um teste adicional com ferramentas reais: download de áudio original servido em loopback e conversão para MP3. O teste de ferramentas é ignorado na primeira etapa e executado separadamente com o pacote pronto.
- Interface real em claro/escuro, incluindo YouTube/Spotify, foco, prévia, fila, histórico e atualização. 14 capturas por rodada; versão portátil e instalada abertas pelo launcher em caminhos com espaços e acentos.
- yt-dlp, spotDL, FFmpeg, FFprobe e Deno iniciados com PATH isolado, sem Python/FFmpeg/Deno externos. Catálogos internos obrigatórios do provedor YouTube Music verificados.
- Listas de extratores e codecs idênticas às da 2.1.0 publicada. MP3 mantém o melhor áudio disponível e `libmp3lame -q:a 0`.
- Avisos legais completos preservados em ZIP; quantidade de entradas conferida contra os avisos originais. Fontes correspondentes continuam no pacote separado.
- Atualização real da 1.1.1 publicada, estrutura organizada, instalação iniciada pelo contrato do atualizador, reabertura e desinstalação, preservando arquivo extra do usuário.
- Bootstrapper com pacote local válido, alteração de byte, resposta truncada, redirecionamento não permitido e cancelamento pelo botão do diálogo. A versão distribuída rejeita as opções exclusivas dos testes.
- Atualização da 2.1.0 pelo bootstrapper de teste, reabertura real, substituição dos avisos soltos pelo ZIP e preservação de arquivos extras tanto na raiz quanto na pasta antiga de avisos.
- Testes exigem instalador completo menor, instalação menor e menos arquivos antes de aprovar. Metadados fixam URL, tamanho e SHA-256 do instalador completo na construção do online.

## Segurança e limites

Os testes do bootstrapper usam uma compilação exclusiva de testes e servidor de loopback, nunca distribuídos. Só essa compilação admite um endereço local; o executável público não permite trocar o destino por argumentos. O pacote local recém-compilado não é marcado como download da internet no cenário de execução da fixture. Na versão pública, o download é HTTPS, recebe a marca de origem da internet e é iniciado com os controles normais do Windows. Nada desativa SmartScreen, Defender ou UAC.

O runner usa Windows Server 2025 x64. Isso não substitui teste manual em PCs Windows 10/11, outras escalas de tela, todas as configurações de acessibilidade ou confirmação manual dos avisos de segurança. O ciclo público completo do instalador online no PC do usuário não foi automatizado; o transporte e a instalação foram testados com a fixture local. O instalador não tem assinatura Authenticode.

Disponibilidade e correspondências de serviços externos não são garantidas. Spotify fornece metadados e o áudio vem do YouTube. Nenhuma mudança foi feita no código, binários ou release Mac 3.0.1.
