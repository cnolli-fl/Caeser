# Instalar o Caeser

Esta edição requer macOS 26 ou mais recente e um Mac com chip Apple (M1 ou posterior).
Não funciona em Windows, Linux nem em Macs Intel. Não depende de Rosetta.

## Instalação

1. Abra o arquivo `.dmg` e arraste Caeser para Aplicativos.
2. Ejete a imagem de disco e abra Caeser na pasta Aplicativos.
3. Cole um link, escolha a pasta de destino e baixe.

Se usar o `.zip`, descompacte e mova Caeser.app para Aplicativos. Não separe os
arquivos que ficam dentro de Caeser.app.

yt-dlp, FFmpeg, FFprobe, Deno e o suporte ao Spotify já vêm incluídos. Não é preciso
instalar Homebrew, Python, Xcode, Spotify ou outras ferramentas para usar o app.
Internet continua necessária para obter os vídeos, músicas e metadados.

A versão 2.1.1 mantém apenas os arquivos de execução e os avisos necessários
dentro de Caeser.app. A interface usa português brasileiro. Um pequeno catálogo
inglês interno do parser de metadados e os textos originais das licenças são
preservados; não são opções de idioma da interface. Não remova bibliotecas de
Tools/Lib: são compartilhadas por FFmpeg e FFprobe.

## Primeira abertura e segurança

Esta é uma distribuição gratuita com assinatura local (ad-hoc), sem certificado
Developer ID e sem notarização da Apple. O macOS pode impedir a primeira abertura
porque não consegue verificar o desenvolvedor. A assinatura local verifica a
integridade do pacote, mas não comprova a identidade do autor perante a Apple.

Somente se você confia na origem e no arquivo: após tentar abri-lo, consulte
Ajustes do Sistema > Privacidade e Segurança e a opção “Abrir Mesmo Assim”. Não
desative as proteções globais do macOS. Macs gerenciados por empresas ou escolas
podem não permitir essa autorização. Não ignore alertas de malware ou de arquivo
adulterado: nesses casos, não execute o app e confira a origem do download.

Orientação oficial: https://support.apple.com/pt-br/102445

## Spotify

O link do Spotify serve para identificar as faixas. O áudio é procurado no YouTube
Music/YouTube e convertido em MP3; não é baixado diretamente dos servidores de
áudio do Spotify. Não é necessário login no fluxo padrão de links públicos.

## Atualizações e licenças

As ferramentas ficam dentro do aplicativo. Quando precisarem de atualização,
substitua o pacote completo por uma versão nova do Caeser; `brew upgrade` não
atualiza as ferramentas desta edição. A versão não tem atualização automática.

As licenças acompanham Caeser.app, agrupadas em Contents/Resources/Tools/Licenses.zip;
basta descompactar esse arquivo para ler os textos originais. Na 2.1.1,
os fontes de FFmpeg/LAME e as receitas das ferramentas ficam no ZIP separado
Caeser-2.1.1-macOS-AppleSilicon-Fontes-Terceiros.zip, oferecido junto dos downloads.
Você não precisa baixar esse arquivo para usar o app. O código Swift do Caeser é MIT. Use os downloads conforme
as permissões do conteúdo e dos serviços; o app não contorna DRM.
