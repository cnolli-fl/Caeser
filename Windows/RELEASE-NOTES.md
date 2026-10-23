# Caeser 2.2.0 para Windows

Instalador online pequeno e aplicativo mais enxuto, com o mesmo design, prévia, fila, histórico e qualidade dos downloads.

## Qual arquivo baixar?

- **[Online.exe — recomendado](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.2.0/Caeser-2.2.0-Windows-x64-Online.exe):** escolha **Baixar e instalar**; ele baixa o pacote completo e inicia a instalação. Mostra progresso e permite cancelar.
- **[Setup.exe — completo](https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.2.0/Caeser-2.2.0-Windows-x64-Setup.exe):** alternativa para guardar e instalar sem internet. Contém o mesmo aplicativo e as mesmas ferramentas.

**Escolha somente um.** O instalador online é pequeno porque baixa os arquivos depois: o pacote completo ainda será transferido durante a instalação. A janela informa o tamanho. Não é uma atualização diferencial.

Quem já usa a **2.1.0** instalada pode atualizar por **Instalar e reiniciar** dentro do Caeser. Esse fluxo continua usando o instalador completo, conferido antes de executar. Nenhuma atualização é instalada sem confirmação.

## O que ficou mais leve

- yt-dlp e spotDL compartilham uma única cópia do Python e das dependências.
- FFmpeg e FFprobe compartilham as DLLs da mesma compilação, sem depender de ferramentas instaladas no PC.
- Avisos legais completos agrupados em `Documentacao/Ferramentas.zip`, em vez de milhares de arquivos soltos. Não foram apagadas licenças.
- Compressão do instalador melhorada. Fontes, caches de construção e arquivos de testes não são instalados no PC.
- Mantidos os extratores, os codecs, MP3 na configuração de máxima qualidade e todos os recursos do aplicativo. Nenhum redesenho da interface.

## Instalação e segurança

Requer **Windows 10 22H2 ou Windows 11 x64 (Intel/AMD)**. Instalação para o seu usuário, sem exigir administrador. Não é necessário instalar .NET, Python, FFmpeg, Deno ou yt-dlp separadamente. Windows ARM64 e 32 bits não são alvos validados.

Feche o Caeser antes de instalar. Downloads, preferências, fila e histórico são preservados. A migração remove somente os arquivos registrados pelo instalador antigo, sem apagar a pasta inteira nem arquivos extras do usuário. O computador não é reiniciado à força.

O instalador online usa HTTPS e confere **tamanho e SHA-256 fixados na construção** antes de iniciar o pacote. Arquivos incompletos, alterados e redirecionamentos fora dos servidores permitidos são recusados. Os controles de segurança do Windows são preservados.

**Os dois instaladores não têm assinatura Authenticode.** Avisos de fornecedor desconhecido ou SmartScreen podem aparecer, inclusive ao abrir o pacote baixado pelo instalador online. O hash verifica integridade, mas não substitui uma assinatura independente do editor.

## Verificação

Testes no runner Windows: lógica e processos, interface nos dois temas, ferramentas com ambiente isolado, download de áudio original servido localmente e conversão MP3, ZIP extraído em caminho com espaços e acentos, instalação/atualização/desinstalação e reabertura real do aplicativo. O instalador online é testado com pacote válido, alterado, truncado, redirecionamento indevido e cancelamento pelo diálogo.

A atualização da 2.1.0 é comparada em disco e preserva arquivos extras, inclusive dentro das pastas antigas. As listas de extratores e codecs são comparadas antes e depois. Esses testes não substituem a validação em PCs reais com Windows 10/11, o ciclo público de download pelo GitHub nem a confirmação manual de eventuais avisos do SmartScreen. Serviços externos podem mudar ou limitar downloads. Spotify fornece metadados; o áudio vem do YouTube.

[Detalhes do atualizador](https://github.com/cnolli-fl/Caeser/blob/windows-v2.2.0/docs/ATUALIZACAO-WINDOWS-NO-APP.md) · [Mac 3.0.1 — sem mudanças](https://github.com/cnolli-fl/Caeser/releases/tag/v3.0.1)

<details>
<summary>Integridade e fontes de terceiros</summary>

[Fontes correspondentes e receitas](https://github.com/cnolli-fl/Caeser/releases/download/fontes-terceiros/Caeser-2.2.0-Windows-x64-Fontes-Terceiros.zip). Licenças completas continuam na instalação. Não é necessário baixar os fontes para usar o aplicativo.

</details>
